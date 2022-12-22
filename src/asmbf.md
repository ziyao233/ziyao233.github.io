# asmbf: 一个汇编 brainfuck 解释器的实现

前几天写了一个小玩具，[asmbf](https://github.com/ziyao233/asmbf)，用纯汇编
做了一个 ``brainfuck`` 解释器，这里总结一下过程里遇到的一些坑。

## x86-64 还是 amd64

在一个技术群里差点和一位吵起来，当年 Intel 力推 ``IA-64`` 的时候，AMD 推出了
兼容原 ``x86`` 架构的 ``amd64`` 架构，依靠兼容性干倒了 ``IA-64``，于是从此
兼容 ``x86`` 架构的 ``amd64`` （Intel 称之为 ``x86-64``）成为了现行主流架构

## 系统调用

在 ``x86_64 Call Convention`` 中，``Linux`` 系统调用传参方式和用户空间函数
传参方式使用的寄存器是不同的，后者与本文无关不加赘述。

进行系统调用时，我们使用 ``syscall`` 指令陷入内核，此时按照此顺序传递参数

```
%rdi, %rsi, %rdx, %r10, %r8, %r9
```

``%rax`` 中存放系统调用号，详见本文末附表

## 汇编

（描述编译汇编程序的过程用汇编 (assemble) 更合适）

代码是纯 ``AT&T`` 汇编（也叫 ``GAS`` 汇编）开始我用 ``as`` 直接编译代码，
然而 as 生成的代码仍需要链接，同时无法使用宏（简单的常量定义可以使用
``.equ`` 伪指令），最后使用了 ``gcc`` 进行编译

作为纯汇编程序，我不使用任何标准库，又因为我用的程序结构自行定义了
``_start`` 作为入口，``-nostdlib`` 被用来禁用标准库。

这种汇编代码没办法编译为运行时地址无关的目标文件，所以要用 ``-no-pie`` 让
``gcc`` 闭嘴

文件命名使用了 ``.S`` 作为后缀，用来指示 ``gcc`` 对其调用 C 预处理器

最后使用的指令类似

```
gcc asmbf.S -o asmbf -nostdlib -no-pie
```

## 代码结构

```
	.global		_start		// 导出 _start 符号
	.code				// 唯一代码段
_start:					// 代码入口点
	/*	...	*/
	movq		$60,		%rax
	movq		$0,		%rdi
	syscall				// 60 号系统调用，结束程序

	.data				// 唯一数据段
msg:	.asciz		"Hello"
```

## 调试

``gdb`` 是个好东西，甚至可以拿来调汇编代码。

在编译时打开 ``-g -O0`` 之后，我们可以直接用 ``gdb`` 单步调试代码

一个常用的指令是 ``info register``，缩写为 ``i r``，可以查看寄存器信息

## 指令格式

要记住一条指令必须换行必须换行

``asmbf`` 末尾有一串定义跳转表的伪指令，开始我想用类似

```
#define fill(x)		\
.rept	x		\
.quad	xxxxx		\
.endr
```

的代码省事少写几行，结果发现这么写之后会报无效指令

原因是 ``\`` 是续行符号，在宏替换时这些内容都会被合成一行，而在一行类似
``.rept 1 .quad xxxx .endr`` 的内容汇编器是不认识的

## mmap 偷内存

我不想通过开大 ``.data`` 段的方式去分配内存（用来储存 ``brainfuck`` 机器的
纸带内容），所以就用了 ``mmap()`` 来分配内存。

``fd = -1,addr = NULL`` 同时 type 置位 ``MAP_ANONYMOUS`` 时，``mmap()`` 会
分配 ``length`` 长度的内存

## 内核常量附录

### 文件打开方式

```
O_RDONLY		00
```

### fseek() / lseek()

```
SEEK_SET		0
SEEK_CUR		1
SEEK_END		2
```

### mmap()

```
PROT_READ		0x1
PROT_WRITE		0x2
MAP_SHARED		0x01
MAP_ANONYMOUS		0x20
```
