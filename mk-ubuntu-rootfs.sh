#!/bin/bash -e

# 使用 -e 参数，确保脚本在遇到错误时自动退出
set -e -o pipefail

# 检查并尝试获取 root 权限。如果当前用户不是 root，提示并重新执行脚本。
if [[ "${EUID}" != "0" ]]; then
    echo -e "\033[42;36m 该脚本需要 root 权限，正在尝试使用 sudo 重新运行 \033[0m"
    exit $?
fi

# 定义日志文件路径并将所有输出同时重定向到日志文件和终端
LOGFILE="/var/log/script.log"
exec > >(tee -i "$LOGFILE") 2>&1

# 选择 SOC 的函数，用于选择要构建的 SOC（系统芯片）
select_soc() {
    while true; do
        echo -e "\033[42;36m --------------------------------------------------------- \033[0m"
        echo -e "\033[42;36m 请输入要构建CPU的序号: \033[0m"
        echo -e "\033[42;36m [0] 退出 \033[0m"
        echo -e "\033[42;36m [1] rk3562 \033[0m"
        echo -e "\033[42;36m [2] rk3568 \033[0m"
        echo -e "\033[42;36m [3] rk3588/rk3588s \033[0m"
        echo -e "\033[42;36m --------------------------------------------------------- \033[0m"
        read -p "选择: " input

        case $input in
            0) exit;;  # 退出
            1) SOC=rk3562; break;;  # 选择rk3562
            2) SOC=rk3568; break;;  # 选择rk3568
            3) SOC=rk3588; break;;  # 选择rk3588
            *) echo -e "\033[42;36m 无效输入，请重试。 \033[0m";;  # 输入错误提示
        esac
    done
    echo -e "\033[42;36m 设置 SOC=$SOC...... \033[0m"
    
    # 设置默认架构为 arm64
    ARCH="arm64" && echo -e "\033[42;36m 设置默认 ARCH=arm64...... \033[0m"
}

# 选择 TARGET 版本的函数，用于选择要构建的根文件系统版本
select_target() {
    while true; do
        echo -e "\033[42;36m --------------------------------------------------------- \033[0m"
        echo -e "\033[42;36m 请输入要构建的根文件系统版本: \033[0m"
        echo -e "\033[42;36m [0] 退出 \033[0m"
        echo -e "\033[42;36m [1] gnome \033[0m"
        echo -e "\033[42;36m [2] xfce \033[0m"
        echo -e "\033[42;36m [3] lite \033[0m"
        echo -e "\033[42;36m --------------------------------------------------------- \033[0m"
        read -p "选择: " input

        case $input in
            0) exit;;  # 退出
            1) TARGET=gnome; break;;  # 选择gnome
            2) TARGET=xfce; break;;  # 选择xfce
            3) TARGET=lite; break;;  # 选择lite
            *) echo -e "\033[42;36m 无效输入，请重试。 \033[0m";;  # 输入错误提示
        esac
    done
    echo -e "\033[42;36m 设置 TARGET=$TARGET...... \033[0m"
}

# 安装与 SOC 相关的软件包，根据选择的SOC类型安装不同的驱动包
install_packages() {
    case $SOC in
        rk3562)
            MALI=bifrost-g52-g13p0
            ISP=rkaiq_rk3562
            BOARD_NAME="iTOP-RK3562"
            ;;
        rk3568)
            MALI=bifrost-g52-g13p0
            ISP=rkaiq_rk3568
            BOARD_NAME="iTOP-RK3568"
            ;;
        rk3588)
            MALI=valhall-g610-g13p0
            ISP=rkaiq_rk3588
            BOARD_NAME="iTOP-RK3588"
            ;;
    esac
}

# 定义一个重试命令的函数，如果命令执行失败，将重试最多3次
retry_command() {
    local retries=3
    local count=0
    until "$@"; do
        exit_code=$?
        count=$((count + 1))
        if [ $count -lt $retries ]; then
            echo -e "\033[42;36m 命令失败，正在重试 ($count/$retries)... \033[0m"
            sleep 1
        else
            echo -e "\033[42;36m 命令执行失败，退出。 \033[0m"
            return $exit_code
        fi
    done
    return 0
}

# 定义一个函数，用于挂载必要的文件系统到目标根文件系统
mnt() {
    echo -e "\033[42;36m 挂载文件系统... \033[0m"
    mount -t proc /proc ${1}proc
    mount -t sysfs /sys ${1}sys
    mount -o bind /dev ${1}dev
    mount -o bind /dev/pts ${1}dev/pts
}

# 定义一个函数，用于解除挂载文件系统
umnt() {
    echo -e "\033[42;36m 解除挂载文件系统... \033[0m"
    umount ${1}proc || true
    umount ${1}sys || true
    umount ${1}dev/pts || true
    umount ${1}dev || true
}

# 检查并选择 SOC 和 TARGET，如果没有定义则调用选择函数
[ -z "$SOC" ] && select_soc
[ -z "$TARGET" ] && select_target

TARGET_ROOTFS_DIR=binary

# 设置默认版本，如果没有定义 VERSION 则默认设置为 "release"
[ -z "$VERSION" ] && VERSION="release"
echo -e "\033[42;36m 正在构建 $VERSION 版本 \033[0m"

# 检查是否存在 Ubuntu 基础镜像，如果不存在则运行 mk-base-ubuntu.sh 构建基础系统
if [ ! -e ubuntu-base-"$TARGET"-$ARCH-*.tar.xz ]; then
    echo -e "\033[42;36m 未存在基础包，运行 mk-base-ubuntu.sh 构建基本系统 \033[0m"
    source mk-base-ubuntu.sh
fi

# 定义一个清理函数，在脚本遇到错误时自动执行
finish() {
    umnt $TARGET_ROOTFS_DIR/
    echo -e "\033[42;36m 脚本执行失败。详情请查看 $LOGFILE。 \033[0m"
    exit 1
}
trap finish ERR  # 捕捉错误并调用 finish 函数

# 解压基础镜像
echo -e "\033[42;36m 解压基础镜像 \033[0m"
rm -rf $TARGET_ROOTFS_DIR  # 删除目标目录
tar -xf ubuntu-base-$TARGET-$ARCH-*.tar.xz  # 解压基础镜像

# 创建 packages 目录并复制内容到目标根文件系统
mkdir -p $TARGET_ROOTFS_DIR/packages
retry_command cp -rpf packages/$ARCH/* $TARGET_ROOTFS_DIR/packages

# 调用 install_packages 函数并复制相关软件包
install_packages
mkdir -p $TARGET_ROOTFS_DIR/packages/install_packages
retry_command cp -rpf packages/$ARCH/libmali/libmali-*$MALI*-x11*.deb $TARGET_ROOTFS_DIR/packages/install_packages
retry_command cp -rpf packages/$ARCH/${ISP:0:5}/camera_engine_$ISP*.deb $TARGET_ROOTFS_DIR/packages/install_packages

# 处理内核文件，如果存在内核相关的 deb 包，将其复制到目标根文件系统
if [ -e ../linux-headers* ]; then
    Image_Deb=$(basename ../linux-headers*)
    mkdir -p $TARGET_ROOTFS_DIR/boot/kerneldeb
    touch $TARGET_ROOTFS_DIR/boot/build-host
    retry_command cp -vrpf ../${Image_Deb} $TARGET_ROOTFS_DIR/boot/kerneldeb
    retry_command cp -vrpf ../${Image_Deb/headers/image} $TARGET_ROOTFS_DIR/boot/kerneldeb
fi

# 复制 overlay文件夹的内容到目标根文件系统
retry_command cp -rpf overlay/*/* $TARGET_ROOTFS_DIR/

# 复制 qemu 可执行文件并挂载根文件系统
echo -e "\033[42;36m 切换到根目录...... \033[0m"
cp /usr/bin/qemu-aarch64-static $TARGET_ROOTFS_DIR/usr/bin/
mnt $TARGET_ROOTFS_DIR/

# 获取目标根文件系统的所有者 ID，用于后续修复权限
ID=$(stat --format %u $TARGET_ROOTFS_DIR)

# 进入 chroot 环境并执行安装和配置
cat << EOF | chroot $TARGET_ROOTFS_DIR
    # 为 root 用户设置终端颜色，以便文件类型等有颜色显示
    echo "alias ls='ls --color=auto'" >> /root/.bashrc
    echo "export LS_COLORS='rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:'" >>  /root/.bashrc

    # 为 topeet 用户设置终端颜色
    echo "alias ls='ls --color=auto'" >> /home/topeet/.bashrc
    echo "export LS_COLORS='rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:'" >>  /home/topeet/.bashrc

    # 设置终端自动登录
    serial_autologin.sh enable

    # 设置SSH 允许root登录
    sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

    # 修复文件所有者为 root
    if [ "$ID" -ne 0 ];then
        find / -user $ID -exec chown -h 0:0 {} \;
    fi

    # 修复用户目录的权限，确保用户目录的所有者和组正确
    for u in \$(ls /home/); do
        chown -h -R \$u:\$u /home/\$u
    done

    # 设置语言环境为 UTF-8
    export LC_ALL=C.UTF-8

    # 更新并升级系统包
    apt-get update && apt-get upgrade -y

    # 修复权限问题，确保某些系统文件的正确权限
    chmod o+x /usr/lib/dbus-1.0/dbus-daemon-launch-helper
    chmod +x /etc/rc.local

    # 设置非交互模式安装软件包，防止出现交互提示
    export DEBIAN_FRONTEND=noninteractive
    export APT_INSTALL="apt-get install -fy --allow-downgrades"
    
    \${APT_INSTALL} u-boot-tools edid-decode logrotate nfs-kernel-server
    if [[ "$TARGET" == "gnome" ]]; then
        \${APT_INSTALL} gdisk blueman
	apt purge -y gnome-initial-setup
    elif [[ "$TARGET" == "xfce" ]]; then
        apt-get remove -y gnome-bluetooth
        \${APT_INSTALL} bluez bluez-tools blueman
    elif [ "$TARGET" == "lite" ];then
        \${APT_INSTALL} bluez bluez-tools blueman
    fi

    # 将 topeet 用户加入一些常用的系统组，确保能够访问特定资源
    usermod -aG adm,dialout,cdrom,audio,dip,video,plugdev,bluetooth,pulse-access,sudo,systemd-journal,netdev,staff topeet

    # 安装在 packages 目录中的驱动包和内核包
    \${APT_INSTALL} /packages/install_packages/*.deb
    \${APT_INSTALL} /boot/kerneldeb/* || true

    # 选择对应soc的xml文件
    cp /etc/iqfiles/$SOC/* /etc/iqfiles/
    rm -rf /etc/iqfiles/rk3568 /etc/iqfiles/rk3588 /etc/iqfiles/rk3562

    # 电源管理相关设置，安装电源管理工具
    echo -e "\033[42;36m ----- power management ----- \033[0m"
    \${APT_INSTALL} pm-utils triggerhappy bsdmainutils
    cp /etc/Powermanager/triggerhappy.service  /lib/systemd/system/triggerhappy.service
    sed -i "s/#HandlePowerKey=.*/HandlePowerKey=ignore/" /etc/systemd/logind.conf

    # 安装 RGA 驱动
    echo -e "\033[42;36m ----------- RGA  ----------- \033[0m"
    \${APT_INSTALL} /packages/rga2/*.deb

    # 配置视频相关的工具和插件，安装 MPP（多媒体处理）和 GStreamer 插件
    echo -e "\033[42;36m ------ Setup Video---------- \033[0m"
    \${APT_INSTALL} /packages/mpp/*
    \${APT_INSTALL} /packages/gst-rkmpp/*.deb
    \${APT_INSTALL} /packages/gstreamer/*.deb

    # 安装和配置摄像头相关的工具
    echo -e "\033[42;36m ----- Install Camera ----- - \033[0m"
    \${APT_INSTALL} cheese v4l-utils
    \${APT_INSTALL} /packages/libv4l/*.deb

    # 安装 Xserver 相关的软件包，配置图形界面
    case "$TARGET" in
        gnome)
            echo -e "\033[42;36m ----- Install Xserver------- \033[0m"
            \${APT_INSTALL} /packages/xserver/xserver-xorg-*.deb
            apt-mark hold xserver-xorg-core xserver-xorg-legacy
            ;;
        xfce)
            echo -e "\033[42;36m ----- Install Xserver------- \033[0m"
            \${APT_INSTALL} /packages/xserver/*.deb
            apt-mark hold xserver-common xserver-xorg-core xserver-xorg-legacy
            ;;
    esac

    # 更新 Chromium 浏览器
    echo -e "\033[42;36m ------ update chromium ----- \033[0m"
    ln -s /usr/lib/aarch64-linux-gnu/libmali_hook.so.1.9.0 /usr/lib/aarch64-linux-gnu/libmali-hook.so.1
    \${APT_INSTALL} libc++-dev libc++1
    if [ ! -f "/packages/chromium/chromium-x11_91.0.4472.164_arm64.deb" ]; then
        cat "/packages/chromium/chromium-x11_91.0.4472.164_arm64_part_aa" \
            "/packages/chromium/chromium-x11_91.0.4472.164_arm64_part_ab" \
            > "/packages/chromium/chromium-x11_91.0.4472.164_arm64.deb" 
    fi
    \${APT_INSTALL} /packages/chromium/*.deb

    # 安装 libdrm 和其他相关的软件包
    echo -e "\033[42;36m ------- Install libdrm ------ \033[0m"
    \${APT_INSTALL} /packages/libdrm/*.deb

    # 安装 libdrm-cursor
    echo -e "\033[42;36m ------ libdrm-cursor -------- \033[0m"
    \${APT_INSTALL} /packages/libdrm-cursor/*.deb

    # 安装 glmark2 用于图形性能测试
    echo -e "\033[42;36m ------ Install glmark2 ------ \033[0m"
    \${APT_INSTALL} glmark2-es2

    # 安装 rknpu 库，用于处理 Rockchip NPU（神经网络处理器）任务
    echo -e "\033[42;36m ------- move rknpu2 --------- \033[0m"
    mv /packages/rknpu2/*.tar /
    tar xvf /rknpu2.tar -C /
    rm -rf /rknpu2.tar

    # 安装 Rockchip 工具包
    echo -e "\033[42;36m ----- Install rktoolkit ----- \033[0m"
    \${APT_INSTALL} /packages/rktoolkit/*.deb

    # 安装 ffmpeg，用于音频和视频处理
    if [[ "$TARGET" == "gnome" ||  "$TARGET" == "xfce" ]];then
        echo -e "\033[42;36m ------ Install ffmpeg ------- \033[0m"
        \${APT_INSTALL} ffmpeg
    fi

    # 安装 mpv 播放器
    echo -e "\033[42;36m ------- Install mpv --------- \033[0m"
    apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install -y /packages/mpv/*.deb

    # 自动删除不再需要的软件包
    apt autoremove -y

    # 将所有可升级的软件包设置为 hold 状态，防止自动升级
    apt list --upgradable | cut -d/ -f1 | xargs apt-mark hold

    # 禁用不需要的网络服务，减少启动时间
    systemctl mask systemd-networkd-wait-online.service
    systemctl mask NetworkManager-wait-online.service
    systemctl disable hostapd

    # 判断并执行相应的自动登录配置
    if [[ "$TARGET" == "xfce" ]]; then
        echo "配置 Xfce 的 LightDM 自动登录..."
        echo -e "\n[SeatDefaults]\nautologin-user=topeet\nautologin-user-timeout=0" >> /etc/lightdm/lightdm.conf
        echo -e "\033[42;36m Xfce 的 LightDM 自动登录配置完成 \033[0m"
    elif [[ "$TARGET" == "gnome" ]]; then
        echo "配置 GNOME 的 GDM3 自动登录..."
        sudo sed -i 's/#  AutomaticLoginEnable = true/AutomaticLoginEnable = true/' /etc/gdm3/custom.conf
        sudo sed -i 's/#  AutomaticLogin = user1/AutomaticLogin = topeet/' /etc/gdm3/custom.conf

        # 确保 WaylandEnable 被设置为 false，禁用 Wayland
        sudo sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf      
        echo "GNOME 的 GDM3 自动登录配置完成。"
        echo -e "\033[42;36m GNOME 的 GDM3 自动登录配置完成 \033[0m"
    fi

    # 为 X 预加载 libdrm-cursor 库
    sed -i "1aexport LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libdrm-cursor.so.1" /usr/bin/X
    cd /usr/lib/aarch64-linux-gnu/dri/
    cp kms_swrast_dri.so swrast_dri.so rockchip_dri.so /
    rm /usr/lib/aarch64-linux-gnu/dri/*.so
    mv /*.so /usr/lib/aarch64-linux-gnu/dri/
    rm /etc/profile.d/qt.sh

    # 删除不必要的目录和文件，保持系统清洁
    rm -rf /home/$(whoami)
    rm -rf /var/lib/apt/lists/*
    rm -rf /var/cache/
    rm -rf /packages/
    rm -rf /boot/*
EOF


# 解除挂载根文件系统
umnt $TARGET_ROOTFS_DIR/

# 调用 mk-image.sh 脚本生成镜像
./mk-image.sh $TARGET

# 打包成压缩包的形式
#echo -e "\033[42;36m ------- 压缩成xz包 ------ \033[0m"
#XZ_OPT=-T0 tar -cpJf ubuntu-focal-$TARGET-arm64.tar.xz binary
