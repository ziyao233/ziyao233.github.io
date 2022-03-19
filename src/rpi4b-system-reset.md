# 树莓派4B 系统重装  
树莓派4B刚出的时候就入手了一台4GB型号的（现在觉得赚到了！）  

于是~~吃灰派~~树莓派（下文直接写rpi了，呜呜太懒了）就那么
一直在小角落里上着电跑着clash和几个测试用的Web服务...  

大概去年年底的时候，在搜索包的时候发现apt分支变成oldstable了，
也就是——Debian Bullyse代替原来的Buster分支了。Raspbian OS魔改
自Debian，自然也就跟着更新了。于是一直想着什么时候更新一下系
统（包太老了QAQ）今天下午花了大概1h做这件事情，这里记录一下。  

## 写镜像还是apt？  

某位喵喵跟我说Debian可以``sudo apt-get dist-upgrade``，但是
尝试无果ρωρ  

于是没有办法，只能用最原始的方法重新dd镜像了。  

从[这里](https://www.raspberrypi.com/software/operating-systems/)
可以找到所有的Raspbian OS，突然发现竟然有Raspbian OS 64bit了！
（别问喵喵为什么上来就翻列表）  

于是立刻马上直接用64bit系统呀（期待了好久的说）没想到之后给咱
蒙了一大下  

下载然后
```shell
unzip 2022-01-28-raspios-bullseye-arm64-lite.zip
dd if=./2022-01-28-raspios-bullseye-arm64-lite.img of=/dev/sdb status=progress
```
没想到lite版本竟然有2G大小了诶！具体是64bit代码的原因还是其它
什么暂时就不清楚了  

dd的``status=progress``选项比静默要省心得多哦~  

写完镜像，拔卡上电！  

## 没有vim  

上电之后会有提示信息（这个版本的系统似乎会自动扩容根目录），
rpi4如果一直蓝屏的话请检查一下是否是EEPROM的问题，这个解决
方案很多喵也不写了（呜呜还是懒）  

~~默认用户pi raspberry大家都知道吧~~  

于是要把系统配置好 上来第一个大锤就是没有vim 于是只能vi将就  

vi的操作很不一样好吧！！  

## 基本配置  

由于树莓派放在一个小角落，带键盘过去实在是不方便（还是懒）
所以第一件事就是配置静态地址，开启ssh啦  

首先通过``sudo raspi-config``设置主机名（这个小工具很方便的说）
把共享显存调小到16MB（毕竟基本不会外接显示设备）然后在Interface
选项中启动ssh（默认是关闭的应该）  

顺便提一句，如果是作为日常应用的话，各个带WIFI的版本的rpi都
是可以用raspi-config来连接WIFI的  

至于静态地址，需要/etc/dhcpcd.conf文件，配置大概类似：
```
interface eth0
static ip_address=192.168.1.128/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1 114.114.114.114
```
重启系统，这样就可以啦~  

## apt源  

于是现在可以通过ssh连接上rpi啦  

第一件事！补上没有的vim！  

```
sudo apt-get install vim
```  

然后看着KB级的速度就很让人不爽啊喂  

所以我们来换源吧，这里着实蒙了咱一把。像之前一样打开  
清华源官网，找到Raspbian OS，准备复制粘帖URL的时候——  
诶？怎么是[arch=armhf]？  

armhf是32bit的架构代号，可是咱的Raspbian已经是64位了，翻了
一大通也没找到64bit的URL....  

于是只好去搜索啦~最后发现：  
Raspbian OS 64bit用的是Debian源！Debian源！  

似乎是因为Raspbian OS本身就是Debian魔改的吧，既然已经合入  
和主线一样的64bit内核了，基金会大概也没理由自己建仓了。  

所以要用的URL贴在下面啦~把对应文件源内容注释掉就好啦~
```
# /etc/apt/sources.list
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-updates main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-backports main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bullseye-security main contrib non-free

# /etc/apt/sources.list.d/raspi.list
deb http://mirrors.tuna.tsinghua.edu.cn/raspberrypi/ bullseye main
```
这里并没有启用apt的source操作要用的src源哦  

## 软件和硬件的安全  

### 存储卡寿命

rpi用的内存卡寿命真的是很有限的，实践性的做法首先要关掉
swap！  

在/etc/rc.local中加入
```
swapoff -a
```
一定要写在``exit 0``之前哦

重启再``free -h``，swap文件就没啦  

其实可以配置/etc/fstab，把/var/log之类的目录挂载为tmpfs，
今天时间太紧没来得及做QAQ  

### 用户安全  

~~千万不要像咱之前一样把pi用户留着！~~  

因为要做DN42的服务器嘛（是的！），被公开访问就要考虑一下用户安全的问题了哦。  
Raspbian OS的pi用户已经是总所周知了，所以最好就不要日常使用了，那么要新建一个用户：  

```shell
sudo adduser ziyao233
```

这个用户要做日常管理用，所以要启用sudo权限。Raspbian OS中sudoer用户组是有以
任意身份执行任意命令的权限的，所以把新建的用户添加到sudoer组中

```shell
sudo usermod -G -a sudoer
```

对于原始的pi用户，就要删掉什么的啦。

```shell
sudo userdel pi
```  

## 后记  

于是你可以开始折腾啦！aarch64确实会带来很大的性能加成，从而给了rpi4B再搏一搏
的能力~~谁来再跑跑Minecraft试试？~~  

树莓派放着也不必非要吃灰，作为一个低功耗的设备，24h运行作为服务器也是很  
不错的选择。rpi4B支持从外置设备（USB和网络）启动，同时USB3.0也给了连接外置
硬盘更多的可能性：可以让SATA3.0接口的机械硬盘跑出全部性能，完全具有作为文件
存储设备的能力。~~当然像咱一样作为DN42节点也可以啦~~  
