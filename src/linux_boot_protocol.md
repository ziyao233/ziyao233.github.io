# How Linux Boots: the Linux Boot Protocol (RISC platforms)

I've worked on riscv64/loongarch64 Linux boot protocol support for limine and
found that there was little precise and complete documentation on this topic,
even doc.kernel.org only yields some general instructions, which doesn't help
for writing a fully-functional bootloader. Finally I wasted a lot of time
digging through kernel, U-boot and grub :/

We won't cover x86_64 (bzImage format) and armv7 (zImage format) in this blog,
since it's some type of conclusion after some learning and I had seldom worked
with these kernels. We also omit the 32bit variants of RISC-V and LoongArch.

## Image header format

They are ALL 64bytes in size[1].

```
// arch/riscv/include/asm/image.h
struct riscv_header {
        u32 code0;
        u32 code1;
        u64 text_offset;
        u64 image_size;
        u64 flags;
        u32 version;
        u32 res1;
        u64 res2;
        u64 magic;
        u32 magic2;
        u32 res3;
};

// arch/arm64/include/asm/image.h
struct arm64_header {
        __le32 code0;
        __le32 code1;
        __le64 text_offset;
        __le64 image_size;
        __le64 flags;
        __le64 res2;
        __le64 res3;
        __le64 res4;
        __le32 magic;
        __le32 res5;
};

// No headers available, described in Documentation/arch/loongarch/booting.rst
struct loongarch_header {
    uint32_t mz;
    uint32_t res0;
    uint64_t kernel_entry;
    uint64_t image_size;
    uint64_t load_offset;
    uint64_t res1;
    uint64_t res2;
    uint64_t res3;
    uint32_t magic;
    uint32_t pe_offset;
};
```

## Boot with EFIstub

Linux officially supports booting with UEFI through a small piece of code,
called EFIstub[2], which allows the kernel to be loaded directly as UEFI
application.

The biggest gap to achieve this is executable format: the "standard image
format" in UEFI environment is PE (thank you Micro$oft!). Our kernel image has
to mimic a PE executable to be recognized by UEFI.

Luckily, this is possible without messing the kernel header too much. To stay
compatible with previous MZ-DOS executables, PE headers aren't located at the
beginning of the file, its offset is stored at 0x3c (60 bytes)[3]. When
EFIstub is enabled, the kernel header will start with `"MZ"`
(`arm64/riscv_header.code0` and `loongarch_header.mz` serve for this purpose)
and a PE header will be embedded in the image, pointed by `arm64_header.res5`,
`riscv_header.res3` or `loongarch_header.pe_offset`.

When the kernel is started as a UEFI image, EFIstub is executed first. It
collects system information which isn't available after exiting UEFI boot
services, setups kernel parameters, exits UEFI boot services and transfers
control to the real image entry point.

It's the best place[4] to learn about parameter passing convention, since
kernel knows itself best.

## General steps to boot a kernel, without EFIstub

- Load the kernel image into RAM
- Prepare necessary arguments for kernel
  - kernel command line
  - devicetree blob
  - ACPI table
  - UEFI System table
  - Memory mappings
  - address of initrd (optional)
- Jump to the kernel

## Load the kernel image into RAM

### Where the kernel should be

For RISC-V, the answer is simple: any 2MB-aligned address.

For AArch64, it starts to be interesting: if BIT(3) of arm64_header.flags is
set, it's exactly the RISC-V behavior; otherwise the 2MB-aligned base address
should be chosen as close as possible to the RAM base.

For most modern kernels, you could follow the RISC-V behavior, since after
commit
`a7f8de168ace (arm64: allow kernel Image to be loaded anywhere in physical memory, 2016-02-16)`[5],
the bit is always set.

LoongArch case seems a little complex. The kernel enables DMW (Direct Mapping
Window[6]) instead of paging in privileged mode, which results in stricter
requirements for address layout.

- If the the kernel is built with `CONFIG_RELOCATABLE`, it'll relocate itself
  and fix relocations up during startup, so you could load it to any address
  aligned to page size.
- Otherwise, loading the image to RAM base address plus
  `loongarch_header.load_offset` always works.

### Verify whether it's a valid kernel

Check the kernel header,

- RISC-V
  - `magic2` should be `0x05435352` (`"RSC\x05"`)
  - `version` describes boot protocol version, currently 0.2. High 16 bits
    represents major version and low 16 bits for minor.
  - `magic` is a deprecated field, it should be `0x5643534952`
    (`"RISCV\0\0\0"`)
- AArch64
  - `magic` should be `0x644d5241`
- LoongArch
  - `magic` should be `0x818223cd`

## Prepare necessary arguments for kernel

There are roughly 3 ways to pass an argument to the kernel

- Pass it in the register
- Add it to `/chosen` node in DTB
- Install it as UEFI configuration table with Linux-specific GUID

For the third method, please note that installation of a UEFI configuration
table is only provided as UEFI boot service through
`EFI_BOOT_SERVICES.InstallConfigurationTable()`, which means you'll lose access
to it after exiting boot services.

### kernel command line

- On LoongArch, it's passed in `a1` register
- Assign the string to `/chosen/linux,bootargs` in DTB

### devicetree blob

- LoongArch retrieves it from UEFI tables
- On AArch64, it's passed in `x0`
- On RISC-V, it's passed in `a1`

### ACPI table

- Installed as UEFI configuration table

### UEFI System table

- On LoongArch, it's passed in `a2`
- Assign its address to `/chosen/linux,uefi-system-table` (u64) in DTB

### Memory mappings

- `/memory` nodes in DTB
- Add information of UEFI memory mappings to DTB, including following
  properties,
  - u64 `/chosen/linux,uefi-mmap-start`
  - u32 `/chosen/linux,uefi-mmap-size`
  - u32 `/chosen/linux,uefi-mmap-desc-size`
  - u32 `/chosen/linux,uefi-mmap-desc-ver`
- Register an `efi_boot_memmap` structure as UEFI configuration table with
  GUID `{ 0x800f683f, 0xd08b, 0x423a,
          { 0xa2, 0x93 , 0x96, 0x5c, 0x3c, 0x6f, 0xe2, 0xb4} }`

`efi_boot_memmap` is defined as follows,

```C
struct efi_boot_memmap {
        unsigned long           map_size;
        unsigned long           desc_size;
        u32                     desc_ver;
        unsigned long           map_key;
        unsigned long           buff_size;
        efi_memory_desc_t       map[];
};
```

For the last two methods, the memory mapping information should be obtained
through `EFI_BOOT_SERVICES.GetMemoryMap()`. These mappings should also be
installed with `EFI_RUNTIME_SERVICES.SetVirtualAddressMap()`, a 1:1 mapping
works well for RISC-V and AArch64.

LoongArch kernel requires extra care: it expects runtime memory regions to
be mapped to the third direct mapping window, which starts at (0x8ULL << 60)
and is optionally-cached and privileged-only. A simple way to achieve this is
setting virtual address to corresponding physical address OR'ed with
`(0x8 << 60)`.

### Address of initrd

- Set its start and end address to `/chosen/linux,initrd-start` and
  `/chosen/linux,initrd-end` in DTB. Both of them should be u64.
- Install `linux_efi_initrd` structure as UEFI configuration table, with
  GUID `{ 0x5568e427, 0x68fc, 0x4f3d,
          { 0xac, 0x74, 0xca, 0x55, 0x52, 0x31, 0xcc, 0x68} }`

`linux_efi_initrd` is defined as follows

```C
struct linux_efi_initrd {
        unsigned long   base;
        unsigned long   size;
};
```

## Jump to the kernel

### AArch64

Jump directly to the start of the image.

- `x0`: devicetree blob
- `x1`, `x2`, `x3`: reserved, should be zeroed for now

### RISC-V

Jump directly to the start of the image.

- `a0`: ID of this RISC-V hart (retrieve it from `mhartid` CSR[7] or through
  SBI calls)
- `a1`: devicetree blob

### LoongArch

In short, the offset of kernel entry could be calculated with

```
(loongarch_header.kernel_entry & ((1ULL << 48) - 1)) - loongarch_header.load_offset
````

The AND takes the low 48bits of the address. This is required since virtual
address (DMW-mapped address) was used in `loongarch_header.kernel_entry` and
clearing the high 16bits converts it to physical address. This quirk has been
fixed in
`beb2800074c1 (LoongArch: Fix entry point in kernel image header, 2024-06-03)`[8].

- `a0`: If UEFI is available, set to 1
- `a1`: address of kernel command line
- `a2`: address of UEFI system table. This is necessary even UEFI is
  unavailable (`a0` is set to zero). In this case, you should construct a fake
  UEFI system table and install the devicetree blob as vendor table, it'll only
  be used to search for the DTB.

### Does jump to the start of kernel image work? There may be the signature!

Yes, even the kernel is built with EFIstub.

The "MZ" signature represents a valid instruction on both AArch64
(`ccmp x18, #0, #0xd, pl`) and RISC-V (`c.li s4,-13`). There follows a jump
instruction targeting the real entrypoint.

## Some helpful material

- EFIstub source: the kernel knows itself best.
- systemd-boot: a simple and straight bootloader, implementing most of the
  features through UEFI-calls.
- UEFI Specification: it does help to know about these basic terms when reading
  source of UEFI-capable bootloaders. The specification also serves as a
  manual.
- U-boot source. `arch/<ARCH>/lib/bootm.c` and `arch/<ARCH>/lib/image.c` are.
  most related to Linux kernel booting. For WIP LoongArch support, see[9]

Specially, thank you FlyGoat for explaining LoongArch stuff!

- [1] [AArch64](https://elixir.bootlin.com/linux/v6.11-rc1/source/arch/arm64/include/asm/image.h)
       [RISC-V](https://elixir.bootlin.com/linux/v6.11-rc1/source/arch/riscv/include/asm/image.h)
  [LoongArch documentation](https://elixir.bootlin.com/linux/v6.11-rc1/source/Documentation/arch/loongarch/booting.rst)
- [2] [More information on EFIstub](https://elixir.bootlin.com/linux/v6.11-rc1/source/Documentation/admin-guide/efi-stub.rst)
- [3] [PE documentation](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#ms-dos-stub-image-only)
- [4] It locates at `drivers/firmware/efi/libstub` in Linux source tree
- [5] [commit on GitHub](https://github.com/torvalds/linux/commit/a7f8de168ace)
- [6] [More information on LoongArch DMW window](https://elixir.bootlin.com/linux/v6.11-rc1/source/Documentation/arch/loongarch/introduction.rst#L290)
- [7] The RISC-V Instruction Set Manual: Volume II: Privileged Architecture
     (20241101 version), 3.1.5
- [8] [commit on GitHub](http://github.com/torvalds/linux/commit/beb2800074c1)
- [9] [series on lore.kernel.org](https://lore.kernel.org/u-boot/20240522-loongarch-v1-0-1407e0b69678@flygoat.com/)
