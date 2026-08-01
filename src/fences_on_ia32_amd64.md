# 四个 ISA 上的小栅栏（IA-32 & AMD64）

Notice: the English translation is working in progress, but there isn't an
ETA.

本系列文章将梳理一下 IA-32 & AMD64，AArch64，RISC-V 和 LoongArch 四个 ISA
上的小栅栏。

小栅栏（内存屏障，fence）是好的，它挡住访存，保证不同操作间的顺序不会乱掉。
这四个架构上小栅栏之间的区别主要在，

- 影响对哪些目标（Memory/IO），何种类型（cached/uncached）的访存？
- 是否影响非访存指令？

本系列文章将从这几点进行总结，同时以 Linux v7.2-rc4 中对 `mb()`, `rmb()`,
`wmb()` 以及其 SMP 变种的实现作为例子。

关于 IA-32 & AMD64 架构内存序的定义主要位于 Intel® 64 and IA-32
Architectures Software Developer’s Manual 的 Volume 3, 10.2 Memory Ordering
一节。下文不区分位长时，将该架构简称为 x86。

## sfence，lfence，mfence

x86 上仅有的三种内存同步指令，除去 lfence 外仅同步访存，均定义于文档的
Volume 2, Instruction Set Reference 一节，

- sfence: 保证程序序前的写在后续的写前全局可见（W -> W 序）
- mfence: 保证程序序前的读写均在后续读写前全局可见（RW -> RW 序）
- lfence: 保证程序序前的读在后续访存前完成（R -> RW 序）；
  - 不同于 sfence 和 mfence，lfence 带有一定的 serializing 语义，在程序序前的指
    令***局部完成***前，会阻止程序序后的指令预测执行，但不阻止取指。
  - 关于***局部完成***：lfence 前的写不要求在 lfence 完成前全局可见。
    > An LFENCE that follows an instruction that stores to memory might
    > complete before the data being stored have become globally visible.

lfence 的特殊性在文档中有多处描述，如 Volume 2, lfence 一节两次提及，

> Specifically, LFENCE does not execute until all prior instructions have
> completed locally, and no later instruction begins execution until LFENCE
> completes.

> Instructions following an LFENCE may be fetched from memory before the
> LFENCE, but they will not execute (even speculatively) until the LFENCE
> completes.

在 Volume 3, 10.3 Serializing Instructions 的脚注中也有提到,

> LFENCE does provide some guarantees on instruction ordering. It does not
> execute until all prior instructions have completed locally, and no later
> instruction begins execution until LFENCE completes.

### 关于可用性

非常反直觉地，x86 直到 SSE 才开始引入小栅栏，

- sfence: SSE
- lfence, mfence: SSE2

SSE 首次出现在基于 P6 微架构的 Pentium III 中，而 P6 微架构本身早已引入会导致
W -> R 乱序的 store-buffer forwarding 机制并实装在 Pentium Pro/Pentium II 了，
见 Volume 3，10.2.2 Memory Ordering in P6 and More Recent Processor Families，

> The Intel Core 2 Duo, Intel Atom, Intel Core Duo, Pentium 4, and P6 family
> processors also use a processor-ordered memory-ordering model that can be
> further defined as “write ordered with store-buffer forwarding.”

在 store-buffer forwarding 前，存在于 MMX 的 non-temporal 内存写也已经开始使用
了弱内存序。所以对这段时间的处理器，我们需要别的“小栅栏”。

## 不纯粹小栅栏

> Reads or writes cannot be reordered with I/O instructions,
> locked instructions, or serializing instructions.

你不是纯粹小栅栏[1]。

### IO 指令和 serializing 指令

IO 指令和具有 serializing 语义的指令（定义于手册 Volume 3, 10.3 Serialinzg
Instructions）。Serializing 指令串行执行，不能与任何前后的***操作***乱序。IO
指令仅允许程序序后的取指与页表遍历提前执行。见手册
Volume 3, 10.2.5 Strengthening or Weakening the Memory-Ordering Model，

> Prior to executing an I/O instruction, the processor waits for all previous
> instructions in the program to complete and for all buffered writes to drain
> to memory. Only instruction fetch and page tables walks can pass I/O
> instructions. Execution of subsequent instructions do not begin until the
> processor determines that the I/O instruction has been completed.

> Like the I/O instructions, the processor waits until all previous
> instructions have been completed and all buffered writes have been drained
> to memory before executing the serializing instruction.

手册 Volume 3, 10.3 Serializing Instructions 对 serializing 指令的语义有更清晰
的描述，

> These instructions force the
processor to complete all modifications to
> flags, registers, and memory by previous instructions and to drain all
> buffered writes to memory before the next instruction is fetched and
> executed.

### Locked Instrutions

尽管初衷是为了实现原子操作，x86 带 lock 前缀的指令同样具有一定的内存
内存屏障语义，其保证程序序后的访存在之前的访存完成后执行；弱于 IO 和
serializing 指令地，它不阻塞非访存指令，也可能无法正确为目标为弱序内存的访存
保序，见手册 Volume 3, 10.1.2.2 Software Controlled Bus Locking，

> For the P6 family processors, locked operations serialize all outstanding
> load and store operations (that is, wait for them to complete). This rule is
> also true for the Pentium 4 and Intel Xeon processors, with one exception.
> Load operations that reference weakly ordered memory types (such as the WC
> memory type) may not be serialized.

## Linux 里的 x86 小栅栏

- `mb()`: `lock addl $0, -4(%esp)` 或 `mfence`
- `rmb()`: `lock addl $0, -4(%esp)` 或 `lfence`
- `wmb()`: `lock addl $0, -4(%esp)` 或 `sfence`
- `smp_mb()`: `lock addl $0, -4(%Xsp)`
- `smp_rmb()`: NOP，x86 天然保证 R -> R 序
- `smp_wmb()`: NOP，x86 天然保证 W -> W 序

2016 年的一笔内核补丁，
`bd922477d935 ("locking/x86: Add cc clobber for ADDL")` 错误地将在 IA-32 上使用
sfence 的条件提高到了 SSE2。本文纂写时笔者正在修复该问题。

64-bit 上，由于 SSE2 为 ISA 的必选部分，内核总是会使用纯粹的内存栅栏。

2017 年的一笔补丁，
`450cbdd0125c ("locking/x86: Use LOCK ADD for smp_mb() instead of MFENCE")`
指出使用 locked instruction 充当 full SMP memory barrier 效率高于 mfence，遂
内核目前无条件使用 locked instruction 作为 `smp_mb()`。

## 结语

- 绝大部分 x86 的小栅栏作用于所有类型所有目标的访存（除 locked instructions）
- 除 sfence，mfence 与 locked instructions 外，均影响非访存指令

笔者个人认为，IA-32 & AMD64 是 DEC Alpha 外小栅栏最 cursed 的架构。希望本文
能帮助到忘记看脚注，需要 quick reference，或者单纯不想对 IA-32 & AMD64
进行为期四小时的内存序大发现的人。

- [1] 请游玩平台跳跃游戏《空洞骑士》。
