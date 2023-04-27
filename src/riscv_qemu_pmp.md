# 记录 RISC-V QEMU 的一个坑

> 开源灵车，创！

## 起因

[这个富有攻击性的仓库](https://github.com/ziyao233/cocox-rv64) 中包含一个
（WIP 的）RISC-V 64 内核。~~代码写不动的时候就会想到去借鉴一下别人的逻辑~~，
在 GitHub 以 riscv 和 kernel 为关键词进行搜索，排名靠前的项目之一就是
[xv6-riscv](https://github.com/mit-pdos/xv6-riscv)。这个仓库在 QEMU 虚拟化
的 RISC-V 系统上复刻了经典的 UNIX v6。

`git clone`，看代码。

## RISC-V Priviledged Specification

If no PMP entry matches an M-mode access, the access succeeds. If no PMP
entry matches an S-mode or U-mode access, but at least one PMP entry is
implemented, the access fails.

If at least one PMP entry is implemented, but all PMP entries’ A fields are set
to OFF, then all S-mode and U-mode memory accesses will fail.

标准这么说。

## 奇怪的 Issue

[mret 之后 QEMU 炸出不合法的指令](https://github.com/mit-pdos/xv6-riscv/issues/103)
[QEMU 卡死](https://github.com/mit-pdos/xv6-riscv/issues/66)
[QEMU v6 在执行 mret 后卡死](https://github.com/mit-pdos/xv6-riscv/issues/84)
[mret 切换到 S 模式时 QEMU 挂起](https://stackoverflow.com/questions/69133848/risc-v-illegal-instruction-exception-when-switching-to-supervisor-mode)


呃，一个很怪的问题。

## 分析

根据上面给出的 issue, 问题集中出现在 QEMU v6.0.0 的更新上，所以就此着手查找问题
。

从 QEMU GitHub 镜像仓获得代码，我用了 treeless 模式来减少克隆时间（由于要在提交
树内回溯，不能 shallow clone）

```
git clone https://github.com/qemu/qemu.git --filter=blob:none
```

此时只有在检出时才会同步对应的对象文件。

QEMU 为每一个 release 都打了 tag，我们大体了解一下代码结构，能发现

```
/ -
  |- target
       | --- riscv
```

riscv 目录下包含了 RISC-V 的具体实现。以 RISCV\_EXCP\_ILLEGAL\_INST 为关键词
grep 各源代码（这个关键词怎么找到的？根据 Issue 对应的异常是 Illegal
instruction，以 illegal 为关键词进行 case-insensitive grep 很容易在
`cpu_bits.h` 发现对应的定义），发现 mret\_helper() 函数中确实在 v5.0.0 和
v6.0.0 中有较大差别。

v5.0.0:

```
target_ulong helper_mret(CPURISCVState *env, target_ulong cpu_pc_deb)
{
    if (!(env->priv >= PRV_M))			// 鉴权
        riscv_raise_exception(env, RISCV_EXCP_ILLEGAL_INST, GETPC());

    target_ulong retpc = env->mepc;		// 返回地址
    if (!riscv_has_ext(env, RVC) && (retpc & 0x3))	// 检查地址对齐
        riscv_raise_exception(env, RISCV_EXCP_INST_ADDR_MIS, GETPC());

    target_ulong mstatus = env->mstatus;
    target_ulong prev_priv = get_field(mstatus, MSTATUS_MPP);
    target_ulong prev_virt = MSTATUS_MPV_ISSET(env);
    mstatus = set_field(mstatus,
        env->priv_ver >= PRIV_VERSION_1_10_0 ?
        MSTATUS_MIE : MSTATUS_UIE << prev_priv,
        get_field(mstatus, MSTATUS_MPIE));
    mstatus = set_field(mstatus, MSTATUS_MPIE, 1);
    mstatus = set_field(mstatus, MSTATUS_MPP, PRV_U);
    mstatus = set_field(mstatus, MSTATUS_MPV, 0);
    env->mstatus = mstatus;
    riscv_cpu_set_mode(env, prev_priv);

    if (riscv_has_ext(env, RVH)) {
        if (prev_virt) {
            riscv_cpu_swap_hypervisor_regs(env);
        }

        riscv_cpu_set_virt_enabled(env, prev_virt);
    }

    return retpc;
}
```

可以看到，v5.0.0 此函数只会在鉴权失败时抛出 Illegal Instruction。

v6.0.0:

```
target_ulong helper_mret(CPURISCVState *env, target_ulong cpu_pc_deb)
{
    if (!(env->priv >= PRV_M)) {		// 鉴权
        riscv_raise_exception(env, RISCV_EXCP_ILLEGAL_INST, GETPC());
    }

    target_ulong retpc = env->mepc;
    if (!riscv_has_ext(env, RVC) && (retpc & 0x3)) {	// 检查对齐
        riscv_raise_exception(env, RISCV_EXCP_INST_ADDR_MIS, GETPC());
    }

    uint64_t mstatus = env->mstatus;
    target_ulong prev_priv = get_field(mstatus, MSTATUS_MPP);

    if (!pmp_get_num_rules(env) && (prev_priv != PRV_M)) {	// 这里！
        riscv_raise_exception(env, RISCV_EXCP_ILLEGAL_INST, GETPC());
    }

    target_ulong prev_virt = get_field(env->mstatus, MSTATUS_MPV);
    mstatus = set_field(mstatus, MSTATUS_MIE,
                        get_field(mstatus, MSTATUS_MPIE));
    mstatus = set_field(mstatus, MSTATUS_MPIE, 1);
    mstatus = set_field(mstatus, MSTATUS_MPP, PRV_U);
    mstatus = set_field(mstatus, MSTATUS_MPV, 0);
    env->mstatus = mstatus;
    riscv_cpu_set_mode(env, prev_priv);

    if (riscv_has_ext(env, RVH)) {
        if (prev_virt) {
            riscv_cpu_swap_hypervisor_regs(env);
        }

        riscv_cpu_set_virt_enabled(env, prev_virt);
    }

    return retpc;
}
```

从函数名字容易推断 `pmp_get_num_rules()` 能够获取已经定义的 PMP 规则的数量
（实际定义于 `pmp.c` at line 74），即在 v6.0.0 版本的 QEMU 中会检查 PMP
规则的数量，一旦为零（没有任何规则被定义）且 mret 将会切换到的模式不为机器
模式，就会引发 Illegal Instruction 异常。

> If at least one PMP entry is implemented, but all PMP entries’ A fields are
> set to OFF, then all S-mode and U-mode memory accesses will fail.

## 群友踩雷

于是我成功避坑了，自己的 [cocox-rv64](https://github.com/ziyao233/cocox-rv64)
内核没有掉进这个问题~~虽然掉进了另一个问题~~。

直到群友的出现，一个叫做 `switch_to` 的文件，一个 mcause = 0x01 的异常一样挂死
了 QEMU，我立马想到 Issue 中的问题，给出了设置 PMP 寄存器的解决方案。

```
csrw	pmpcfg0,	0xf
li	t0,		0x3fffffffffffff
csrw	pmpaddr0,	t0
```

问题解决了。

但是新的问题出现了：为什么这时候 mcause 变成了 0x1（Instruction Access
Fault）而非原来的 Illegal Instruction 了呢？

继续从代码中找问题：

这次我直接在[QEMU Maillist](https://lists.nongnu.org/archive/html/qemu-riscv) 的
Archive 里查找 mret 关键词（先前 STFW 时有注意到相关邮件），直接抓到了更改的发生
原因：

[修复 QEMU 行为的 PATCH](https://lists.nongnu.org/archive/html/qemu-riscv/2022-12/msg00030.html)
的提交者发现文档中指定的异常不是非法指令，而是访存错误；从此真相大白。

Patch 见此：

```
Fixes: d102f19a2085 ("target/riscv/pmp: Raise exception if no PMP entry is 
configured")
Signed-off-by: Bin Meng <bmeng@tinylab.org>
---

 target/riscv/op_helper.c | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git a/target/riscv/op_helper.c b/target/riscv/op_helper.c
index 09f1f5185d..d7af7f056b 100644
--- a/target/riscv/op_helper.c
+++ b/target/riscv/op_helper.c
@@ -202,7 +202,7 @@ target_ulong helper_mret(CPURISCVState *env)
 
     if (riscv_feature(env, RISCV_FEATURE_PMP) &&
         !pmp_get_num_rules(env) && (prev_priv != PRV_M)) {
-        riscv_raise_exception(env, RISCV_EXCP_ILLEGAL_INST, GETPC());
+        riscv_raise_exception(env, RISCV_EXCP_INST_ACCESS_FAULT, GETPC());
     }
 
     target_ulong prev_virt = get_field(env->mstatus, MSTATUS_MPV);
-- 
2.34.1
```

## Summary

- RISC-V 必须配置 PMP 项（让人联想到 i386 上大小 4G 的数据段和代码段）
- 软件版本严重影响其行为，查找代码最能够解决问题
- ~~RISC-V 是灵车~~
