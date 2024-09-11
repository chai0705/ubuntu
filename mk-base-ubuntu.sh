#!/bin/bash -e
# 使用 -e 参数，确保脚本在遇到错误时自动退出

# 确保脚本在错误时退出
set -e -o pipefail

# 检查并尝试获取 root 权限。如果当前用户不是 root，提示并重新执行脚本。
if [[ "${EUID}" != "0" ]]; then
    echo -e "\033[42;36m 该脚本需要 root 权限，请切换为root用户或者使用sudo权限运行 \033[0m"
    exit $?
fi

# 定义日志文件路径
LOGFILE="/var/log/script.log"

# 将所有输出重定向到日志文件，并同时输出到终端
exec > >(tee -i $LOGFILE) 2>&1

# 定义一个函数，用于修复 dpkg 信息目录
repair_dpkg() {
    mv /var/lib/dpkg/info/ /var/lib/dpkg/info_old/
    mkdir /var/lib/dpkg/info/
    apt-get update
    mv /var/lib/dpkg/info_old/* /var/lib/dpkg/info/
}

# 定义一个函数，用于挂载必要的文件系统
mnt() {
    echo "MOUNTING"
    mount -t proc /proc ${1}proc
    mount -t sysfs /sys ${1}sys
    mount -o bind /dev ${1}dev
    mount -o bind /dev/pts ${1}dev/pts
}

# 定义一个函数，用于解除挂载文件系统
umnt() {
    echo "UNMOUNTING"
    umount ${1}proc || true
    umount ${1}sys || true
    umount ${1}dev/pts || true
    umount ${1}dev || true
}

# 定义一个清理函数，在脚本遇到错误时自动执行
finish() {
    umnt $TARGET_ROOTFS_DIR/
    echo -e "脚本执行失败。详情请查看 $LOGFILE。"
    exit 1
}
# 设置 trap，当脚本发生错误时，自动执行 finish 函数
trap finish ERR

# 定义一个函数，用于处理用户输入以选择目标系统版本
select_target() {
    while true; do
        echo "---------------------------------------------------------"
        echo "please enter TARGET version number:"
        echo "请输入要构建的根文件系统版本:"
        echo "[0] 退出菜单"
        echo "[1] gnome"
        echo "[2] xfce"
        echo "[3] lite"
        echo "---------------------------------------------------------"
        read input
        case $input in
            0) exit;;
            1) TARGET=gnome; break;;
            2) TARGET=xfce; break;;
            3) TARGET=lite; break;;
            *) echo -e "\033[47;36m 输入错误，请重试。 \033[0m";;
        esac
    done
    echo -e "\033[47;36m 设置 TARGET=$TARGET...... \033[0m"
}

# 如果 TARGET 变量未定义，调用 select_target 函数让用户选择
[ -z "$TARGET" ] && select_target

# 设置默认架构为 arm64
ARCH="arm64" && echo -e "\033[47;36m 设置默认 ARCH=arm64...... \033[0m"

# 设置目标根文件系统目录
TARGET_ROOTFS_DIR="binary"

# 删除已有的目标根文件系统目录，避免冲突
rm -rf $TARGET_ROOTFS_DIR/

# 如果目标根文件系统目录不存在，则创建它
if [ ! -d $TARGET_ROOTFS_DIR ]; then
    mkdir -p $TARGET_ROOTFS_DIR

    # 如果 ubuntu-base 压缩包不存在，则下载相应的版本
    if [ ! -e ubuntu-base-20.04.5-base-$ARCH.tar.gz ]; then
        echo -e "\033[47;36m 下载 ubuntu-base-20.04.5-base-$ARCH.tar.gz \033[0m"
        wget -c http://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release/ubuntu-base-20.04.5-base-$ARCH.tar.gz
    fi

    # 解压下载的 ubuntu-base 压缩包到目标目录
    tar -xzf ubuntu-base-20.04.5-base-$ARCH.tar.gz -C $TARGET_ROOTFS_DIR/

    # 复制当前系统的 DNS 解析配置到目标根文件系统中
    cp -b /etc/resolv.conf $TARGET_ROOTFS_DIR/etc/resolv.conf
	
    # 修改目标根文件系统的 apt 软件源
    cat <<-EOF > "$TARGET_ROOTFS_DIR"/etc/apt/sources.list
        deb http://mirrors.ustc.edu.cn/ubuntu-ports/ focal main multiverse restricted universe
        deb http://mirrors.ustc.edu.cn/ubuntu-ports/ focal-backports main multiverse restricted universe
        deb http://mirrors.ustc.edu.cn/ubuntu-ports/ focal-proposed main multiverse restricted universe
        deb http://mirrors.ustc.edu.cn/ubuntu-ports/ focal-security main multiverse restricted universe
        deb http://mirrors.ustc.edu.cn/ubuntu-ports/ focal-updates main multiverse restricted universe
        deb-src http://mirrors.ustc.edu.cn/ubuntu-ports/ focal main multiverse restricted universe
        deb-src http://mirrors.ustc.edu.cn/ubuntu-ports/ focal-backports main multiverse restricted universe
        deb-src http://mirrors.ustc.edu.cn/ubuntu-ports/ focal-proposed main multiverse restricted universe
        deb-src http://mirrors.ustc.edu.cn/ubuntu-ports/ focal-security main multiverse restricted universe
        deb-src http://mirrors.ustc.edu.cn/ubuntu-ports/ focal-updates main multiverse restricted universe
	EOF

    # 根据系统架构，复制相应的 qemu 可执行文件，以便在 chroot 环境中运行
    cp -b /usr/bin/qemu-aarch64-static $TARGET_ROOTFS_DIR/usr/bin/
fi

echo -e "\033[47;36m 切换到根目录...... \033[0m"

# 挂载根文件系统以便后续的 chroot 操作
mnt $TARGET_ROOTFS_DIR/

# 通过 chroot 进入目标根文件系统并执行一系列命令
cat <<EOF | chroot $TARGET_ROOTFS_DIR/

export DEBIAN_FRONTEND=noninteractive  # 设置为非交互模式，以避免安装过程中要求用户输入
export APT_INSTALL="apt-get install -fy --allow-downgrades"  # 定义安装命令的快捷方式
export LC_ALL=C.UTF-8  # 设置系统语言环境为 C.UTF-8

# 更新和升级系统包
apt-get -y update
apt-get -f -y upgrade

# 根据 TARGET 变量安装不同的桌面环境或软件包
case "$TARGET" in
    gnome)
        apt install -y ubuntu-desktop-minimal rsyslog sudo dialog apt-utils ntp evtest onboard
        repair_dpkg
        ;;
    xfce)
        apt install -y xubuntu-core onboard rsyslog sudo dialog apt-utils ntp evtest udev
        repair_dpkg
        ;;
    lite)
        apt install -y rsyslog sudo dialog apt-utils ntp evtest acpid
        ;;
esac

# 安装基本的网络、开发和系统工具
\${APT_INSTALL} net-tools openssh-server ifupdown alsa-utils ntp network-manager gdb inetutils-ping libssl-dev \
    vsftpd tcpdump can-utils i2c-tools strace vim iperf3 ethtool netplan.io toilet htop pciutils usbutils curl \
    whiptail gnupg bc xinput gdisk parted gcc sox libsox-fmt-all gpiod libgpiod-dev python3-pip python3-libgpiod \
    guvcview nfs-kernel-server

\${APT_INSTALL} ttf-wqy-zenhei xfonts-intl-chinese  # 安装中文字体

# 安装中文支持包，设置系统语言为简体中文
if [[ "$TARGET" == "gnome" ||  "$TARGET" == "xfce" ]]; then
    apt purge ibus firefox -y  # 卸载 ibus 和 Firefox

    echo -e "\033[47;36m 安装中文字体...... \033[0m"
    \${APT_INSTALL} language-pack-zh-hans fonts-noto-cjk-extra gnome-user-docs-zh-hans language-pack-gnome-zh-hans

    # 设置 fcitx 为默认的输入法
    \${APT_INSTALL} fcitx fcitx-table fcitx-googlepinyin fcitx-pinyin fcitx-config-gtk
    sed -i 's/default/fcitx/g' /etc/X11/xinit/xinputrc

    \${APT_INSTALL} ipython3 jupyter  # 安装 IPython 和 Jupyter

    # 取消对 zh_CN.UTF-8 的注释，使其可生成
    sed -i 's/^# *\(zh_CN.UTF-8\)/\1/' /etc/locale.gen
    echo "LANG=zh_CN.UTF-8" >> /etc/default/locale

    # 生成 zh_CN.UTF-8 本地化环境
    locale-gen zh_CN.UTF-8

    # 设置环境变量
    echo "LC_ALL=zh_CN.UTF-8" >> /etc/environment    
    echo "LANG=zh_CN.UTF-8" >> /etc/environment
    echo "LANGUAGE=zh_CN:zh:en_US:en" >> /etc/environment

    echo "export LC_ALL=zh_CN.UTF-8" >> /etc/profile.d/zh_CN.sh
    echo "export LANG=zh_CN.UTF-8" >> /etc/profile.d/zh_CN.sh
    echo "export LANGUAGE=zh_CN:zh:en_US:en" >> /etc/profile.d/zh_CN.sh

    \${APT_INSTALL} $(check-language-support)  # 安装语言支持包
fi

# 为 GNOME 或 XFCE 桌面环境安装额外的多媒体工具
if [[ "$TARGET" == "gnome" || "$TARGET" == "xfce" ]]; then
    \${APT_INSTALL} mpv acpid gnome-sound-recorder
elif [ "$TARGET" == "lite" ]; then
    \${APT_INSTALL}  
fi

# 安装 Python 库和工具
pip3 install python-periphery Adafruit-Blinka -i https://mirrors.aliyun.com/pypi/simple/

HOST=topeet  # 设置主机名

# 创建新用户 'topeet' 并设置密码
useradd -G sudo -m -s /bin/bash topeet
passwd topeet <<IEOF
topeet
topeet
IEOF

# 将用户 'topeet' 添加到视频和音频组
gpasswd -a topeet video
gpasswd -a topeet audio

# 设置 root 用户密码
passwd root <<IEOF
topeet
topeet
IEOF

# 允许 root 用户登录
sed -i '/pam_securetty.so/s/^/# /g' /etc/pam.d/login

# 设置主机名为 'topeet'
echo topeet > /etc/hostname

# 设置系统时区为上海
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 解决 90 秒延迟问题
for service in NetworkManager systemd-networkd; do
    systemctl mask ${service}-wait-online.service
done

# 禁用有线和无线的 wpa_supplicant 服务
systemctl mask wpa_supplicant-wired@
systemctl mask wpa_supplicant-nl80211@
systemctl mask wpa_supplicant@

# 减少 systemd 的日志输出
sed -i 's/#LogLevel=info/LogLevel=warning/' \
  /etc/systemd/system.conf

sed -i 's/#LogTarget=journal-or-kmsg/LogTarget=journal/' \
  /etc/systemd/system.conf

# 确保 sudoers 文件中包含对 sudo 组的配置
SUDOEXISTS="$(awk '$1 == "%sudo" { print $1 }' /etc/sudoers)"
if [ -z "$SUDOEXISTS" ]; then
    # 如果没有 sudo 组的配置，则添加
    echo "# Members of the sudo group may gain root privileges" >> /etc/sudoers
    echo "%sudo	ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi

# 确保 sudo 组的 NOPASSWD 配置已设置
sed -i -e '
/\%sudo/ c \
%sudo    ALL=(ALL) NOPASSWD: ALL
' /etc/sudoers

# 清理 apt 缓存并同步磁盘
apt-get clean
rm -rf /var/lib/apt/lists/*
sync

EOF

# 解除挂载根文件系统
umnt $TARGET_ROOTFS_DIR/

# 获取当前日期，并将根文件系统打包成 tar.xz 文件
DATE=$(date +%Y%m%d)
echo -e "\033[47;36m 运行 tar 打包 ubuntu-base-$TARGET-$ARCH-$DATE.tar.xz \033[0m"
XZ_OPT=-T0 tar -cpJf ubuntu-base-$TARGET-$ARCH-$DATE.tar.xz $TARGET_ROOTFS_DIR
