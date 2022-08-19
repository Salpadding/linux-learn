# 编译过程


## 环境准备

我的环境是 macos intel 芯片, 本文主要使用docker容器作为编译工具，所以也适用于linux环境
macos 的文件系统默认不区分大小写，建议使用磁盘工具创建一个新的区分大小写的卷，然后把源代码复制到这个卷下面

1. 构建用于编译内核和根文件系统的 docker 镜像

```sh
docker build -t kbuild:2.6.32 .
```

2. 创建容器

```sh
docker run --rm -d --name kbuild -v `pwd`:/root/src sleep infinity
```

3. 安装 qemu, 如已经安装可以跳过

```sh
brew install qemu
```

## 编译 linux 内核

1. 下载 linux-2.6.32.tar.bz2 可以在这里找到 https://mirrors.edge.kernel.org/pub/linux/kernel/v2.6/
2. 解压 tar -xf linux-2.6.32.tar.bz2
3. 打补丁 

```sh
cd liunx-2.6.32 # 进入linux源代码所在目录
cat ../patch/kernel.patch | patch -p1
```

4. 进入容器编译内核

```sh
docker exec -it kbuild /bin/bash
cd /root/src/linux-2.6.32
make mrproper
make ARCH=i386 defconfig
make ARCH=i386 menuconfig # 勾选 kernel hacking -> compile with debug info
make ARCH=i386 -j8 # 我的docker分配了8个cpu核心
```

## 编译 busybox

1. 下载 busybox-1.20.1.tar.gz2 可以在这里找到 https://busybox.net/downloads/
2. 解压 tar -xf busybox-1.20.1.tar.gz2
3. 打补丁

```sh
cd busybox-1.20.1 # 进入源代码目录
cat ../patch/busybox.patch | patch -p1
```

4. 进入容器编译 busybox

```sh

docker exec -it kbuild /bin/bash
cd /root/src

pushd busybox-1.20.1 >/dev/null
make defconfig
make menuconfig # 设置 busybox settings -> build options -> build busybox as a static binary
# 设置 shell -> job control 关闭
make install
popd >/dev/null

# 生成根文件系统
$SHELL ./rootfs.sh
```

## 启动并调试

1. 安装 gdb

```sh
brew install gdb
```

2. 启动内核 等待gdb连接

```sh
$SHELL ./qemu.sh
```

3. gdb 连接到 remote

```sh
cd linux-2.6.32
gdb vmlinux
# 以下是 gdb 中的 command
# 连接远程服务 并且在 head_32.S 中打断点
# 开启文字界面
target remote :1234
b *0x1000000 
tui enable
layout asm
```

## 阅读源代码

建议使用 neovim 阅读源代码，因为 neovim 原声就对 ctags 有着良好的支持

1. 没有安装 ctags 或者 cscope 需要先安装

```sh
brew install --HEAD universal-ctags/universal-ctags/universal-ctags
brew install cscope
```

2. 生成 ctags 和 cscope 

```sh
make ARCH=i386 tags
make ARCH=i386 cscope
```

在 neovim 使用 ctrl + ] 就可以跳到函数里面了


3. 对宏进行展开

例如我想展开 init/main.c 可以这么做:

make ARCH=i386 init/main.i
