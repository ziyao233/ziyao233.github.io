# Alpine Linux 打包

注：本文作于 2022.08.16，Alpine Linux 包维护规则可能变动，请参考最新的
[aports](https://gitlab.alpinelinux.org/alpine/aports)

## 背景

没什么背景。有人说 Alpine Linux 有亿点灵，我感觉还好吧（x

至少暂时还没踩过大坑。

以下将 Alpine Linux 简写为 Alpine

## 前置知识

Alpine 通过 aports 管理它的软件包。aports 本质上是一个 Git 仓库，其中
保存有所有包的打包脚本。

Alpine 的源中将软件包分为三类：main，community 以及 testing。

- main：系统的核心软件包，例如内核和 busybox；同时也包括用作服务器的
        必须软件包，例如 Nginx
- community： 社区提供的软件包
- testing： 测试中的软件包，经过维护者审核后可以合入 community/main

Alpine 的源中包括每个发行版的稳定分支以及 edge 分支，后者包含最新的
软件包，但是可能包含不稳定性

Alpine 中的 Lua 模块应当以 lua- 开头，Perl 模块应当以 perl- 开头

## 配置

首先你需要自己的 Alpine Linux 安装。我在 QEMU 中做这件事情。需要注意
的是，QEMU 如果使用 User Mode 网卡模拟（这是默认的）无法转发 ICMP 包，
进而 ping 不通外网（QEMU 会模拟一个小内网）。Alpine Linux 安装之后
可以随时通过 setup-xxx 系列命令进行配置。

打包中需要一些来自 community 的软件包，它可能是被禁用的。请在
/etc/apk/repository 中解注释对应的源

我们需要

- abuild
- atools (community)

使用 apk 可以很容易地安装这些软件包

您需要创建 /var/cache/distfiles，
abuild 在该目录中储存包文件，请确保您的用户对该目录拥有写权限。

您需要 abuild-keygen 生成密钥，例如

```Shell
$ abuild-keygen -i -a
```

您当然需要 git，此处不再赘述配置

## 开始

您需要 aports 仓库，使用 git 从
https://gitlab.alpinelinux.org/alpine/aports.git 克隆是个好主意。
但是受限于网络环境，您可以 `` git init`` 新建一个仓库再通过
``git fetch URL`` 拉取代码。

git 的 ``http.proxy`` 选项对 SOCKS5 代理有效。

当您拥有仓库的时候，我们可以开始打包了

## APKBUILD

aports 通过 abuild 构建软件包。我们建议将软件包首先加入到
testing 分支，即使这不是必须的。

进入 aports/testing，您可以使用 ``newapkbuild PACKAGENAME` 来
初始化对应的 APKBUILD 文件。编辑对应的 APKBUILD 文件，您会看到
类似这样的内容：

```Shell
# Contributor:
# Maintainer:
pkgname=test
pkgver=
pkgrel=0
pkgdesc=""
url=""
arch="all"
license=""
depends=""
makedepends=""
checkdepends=""
install=""
subpackages="$pkgname-dev $pkgname-doc"
source=""
builddir="$srcdir/"

build() {
	# Replace with proper build command(s)
	:
}

check() {
	# Replace with proper check command(s)
	:
}

package() {
	# Replace with proper package command(s)
	:
}
```

### 包信息

您应当在开头的注释中填写 Maintainer（包维护者）以及
Contributor （作者），形式类似
``Ziyao <tswuyin_st127@163.com>``。值得注意的是，原作者
可以填写多个，但是包维护者只能填写一个。

### pkgver & pkgrel

前者是包版本号，请参见 wiki 的要求；后者是包修订号，
当包需要升级又不比更改版本号的时候才需要增加。当包版本号
更新时应当被清零

# depends & makedepends

前者是软件包的依赖，后者是构建时的包依赖，checkdepends
也类似。请注意，出现在 depends 的包不需要重复出现在
makedepends 中。

### source

source 变量指定下载源代码的位置。如果下载的软件包名字不是
``pkgname-pkgver.tar.gz`` 的形式，请使用 ``FILENAME::URL``
的格式。否则 abuild 无法使用它。

### build()

build() 函数中指定了构建的方式。请注意，如果解压之后的源代码
包包括一个名为 ``pkgname-pkgver` 的目录，abuild 会自动切换
至该目录下，否则会工作在 $srcdir 下。

### check()

检查构建是否成功，不是必须的。

### package()

安装目标文件。脚本中有预设变量 $pkgdir，指定了构建产物应当
安装到的根目录。您可以书写类似
``install -Dm 664 fn.lua -T $pkgdir/usr/share/lua/`` 的内容

## 检查代码

您应当阅读 aports 下的两个 README 文件，其中包含了好的建议。

如果你可能已经把事情弄糟了，使用 ``apkbuild-lint`` 工具检查
代码风格

粗略地说，您应当去除默认 APKBUILD 中任何不必要的空赋值
（类似 ``makedepends=""``），不应该留下行尾空白符，不应该
留下模板中的注释，不应该留下空函数 ~~这些问题我都犯了~~

## 构建！

您准备好了。现在运行 ``abuild -r`` 自动安装依赖进行构建

如果构建成功，此时您的包应当位于 $(HOME)/packages 中，否则请
参考错误信息进行修改。如果构建失败，abuild 不会删除中间
阶段产物，您可以进行检查。

请注意，APKBUILD 也不过只是一个 Shell 脚本，您可以使用
任何 Shell 脚本能用的方式调试它，以及 abuild 的 ``-v`` 选项
可以告诉你发生了什么。

## 测试您的包

使用 ``apk add -X ~/packages/testing PKGNAME`` 安装您的包。
``-X`` 选项临时使用一个源，如果需要的话，您也可以将该
目录加入 ``/etc/apk/repository`` 文件中，但写到该文件的路径
应当是绝对路径。

## 将您的包合并到 aports

当您的包准备好面世的时候，是时候将它提交到 aports 了。此处
使用 GitLab 的 MR（Merge Request）进行这项工作。您需要在
[GitLab](https://gitlab.alpinelinux.org/aport) fork 该仓库，
然后将它设置为远程分支：

```
git remote add fork PATH_TO_YOUR_FORK
```

创建新分支，在该分支工作

```
git checkout -b add-PKGNAME
```

您需要使用 git 创建一个提交

```Shell
git commit -a
```

请注意，您的 commit message 应该类似如下：

```
testing/PKGNAME: new aport

LINK TO PROJECT
SIMPLE DESCRIPTION
```

如

```
testing/lua-fn: new aport

https://github.com/ziyao233/lua-fn
Functional programming library for Lua
```

此时您已经做到了，此时您需要将该分支推送到您的
fork，然后提出 Merge Request 并等待合并

## 我的 Merge Request 没有被合并怎么办？

此时您的分支一定落后于 aports，我们需要变基分支

首先，切换从 aports 拉取最新的 master 分支到本地

```Shell
git checkout master
git pull aports master
```

进行变基

```
git checkout add-PKG
git rebase master
```

进行修改，随意产生一个提交并将其挤压进一个提交

```
# do your stuff
git commit -a
git rebase -i HEAD~2
```

在打开的编辑器中将最新的提交改为 squash，下一个
编辑器中修改提交信息

或者直接重做上一个提交

```
git commit -a --amend
```

强制推送提交

```
git push fork add-PKG -f
```

再次检查你的 Merge Request 状态
