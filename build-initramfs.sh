#!/bin/bash
set -e

echo "📦 准备工作目录..."
WORKDIR=~/qemu-initramfs
INITRAMFS_DIR=$WORKDIR/initramfs
mkdir -p "$INITRAMFS_DIR"

echo "🌐 克隆 BusyBox..."
cd "$WORKDIR"
if [ ! -d busybox ]; then
  git clone https://github.com/mirror/busybox.git
fi

cd busybox
make distclean
make defconfig

echo "⚙️ 修改配置：启用静态构建 + 常用命令..."
# 打开静态链接
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config

# 启用一批核心命令
for CMD in MOUNT LS UNAME CAT ECHO SLEEP DMESG PWD MKDIR RM SH;
do
  sed -i "s/# CONFIG_${CMD} is not set/CONFIG_${CMD}=y/" .config
done

yes "" | make oldconfig

echo "⚙️ 编译 busybox（静态）..."
make -j$(nproc)

echo "📁 准备 initramfs 目录结构..."
cd "$INITRAMFS_DIR"
rm -rf ./*
mkdir -p {bin,sbin,etc,proc,sys,dev,usr/bin,usr/sbin}

# 拷贝 busybox
cp "$WORKDIR/busybox/busybox" bin/
ln -sf busybox bin/sh

cd "$INITRAMFS_DIR/bin"
ln -sf busybox sh
ln -sf busybox ls
ln -sf busybox uname
ln -sf busybox mount

cd $INITRAMFS_DIR

# 创建 init 脚本
cat > init << 'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
echo "✅ Welcome to full-featured initramfs"
/bin/uname -a
exec /bin/sh
EOF

chmod +x init

echo "📦 打包 initramfs.cpio.gz..."
cd "$INITRAMFS_DIR"
find . -print0 | cpio --null -ov --format=newc | gzip -9 > "$WORKDIR/initramfs.cpio.gz"

echo "✅ 构建完成！initramfs 路径：$WORKDIR/initramfs.cpio.gz"
echo
echo "🚀 QEMU 启动示例命令："
echo
echo "qemu-system-x86_64 \\"
echo "  -kernel /path/to/bzImage \\"
echo "  -initrd $WORKDIR/initramfs.cpio.gz \\"
echo "  -append \"console=ttyS0 root=/dev/ram rdinit=/init\" \\"
echo "  -nographic"
echo
echo "👉 请将 /path/to/bzImage 替换为你自己的内核路径"

