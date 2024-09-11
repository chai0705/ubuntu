#!/bin/bash -e

# 检查并尝试获取 root 权限。如果当前用户不是 root，提示并重新执行脚本。
if [[ "${EUID}" != "0" ]]; then
    echo -e "\033[42;36m 该脚本需要 root 权限，请切换为root用户或者使用sudo权限运行 \033[0m"
    exit $?
fi

# 定义目标根文件系统目录和根文件系统镜像文件
TARGET_ROOTFS_DIR=binary/

# 判断 $1 是否为空
if [ -z "$1" ]; then
    # 如果 $1 为空，设置 ROOTFSIMAGE 为 rootfs.img
    ROOTFSIMAGE="rootfs.img"
else
    # 如果 $1 非空，设置 ROOTFSIMAGE 为 ubuntu-$1-rootfs.img
    ROOTFSIMAGE="ubuntu-$1-rootfs.img"
fi

EXTRA_SIZE_MB=300  # 额外添加的空间大小，以MB为单位
IMAGE_SIZE_MB=$(( $(sudo du -sh -m ${TARGET_ROOTFS_DIR} | cut -f1) + ${EXTRA_SIZE_MB} ))  # 计算镜像文件大小

# 修正根文件系统的文件系统类型
function fixup_root()
{
	echo "修正根文件系统类型: $1"

	FS_TYPE=$1
	sed -i "s#\([[:space:]]/[[:space:]]\+\)\w\+#\1${FS_TYPE}#" \
		${TARGET_ROOTFS_DIR}/etc/fstab
}

# 修正特定分区的配置
function fixup_part()
{
	echo "修正分区配置: $@"

	if echo $1 | grep -qE "^/"; then
		DEV=$1
	else
		DEV="PARTLABEL=$1"
	fi

	MOUNT=${2:-/$1}  # 挂载点，默认为分区名
	FS_TYPE=${3:-auto}  # 文件系统类型，默认为auto
	OPT=${4:-defaults}  # 挂载选项，默认为defaults

	# 删除fstab中的旧配置
	sed -i "#[[:space:]]${MOUNT}[[:space:]]#d" ${TARGET_ROOTFS_DIR}/etc/fstab

	# 添加新的fstab配置
	echo -e "${DEV}\t${MOUNT}\t${FS_TYPE}\t${OPT}\t0 2" >> \
		${TARGET_ROOTFS_DIR}/etc/fstab

	# 创建挂载点目录
	mkdir -p ${TARGET_ROOTFS_DIR}/${MOUNT} 
}

# 修正/etc/fstab文件
function fixup_fstab()
{
	echo "修正 /etc/fstab..."

	case "${RK_ROOTFS_TYPE}" in
		ext[234])
			fixup_root ${RK_ROOTFS_TYPE}
			;;
		*)
			fixup_root auto
			;;
	esac

	# 修正额外分区的配置
	for part in ${RK_EXTRA_PARTITIONS}; do
		fixup_part $(echo "${part}" | xargs -d':')
	done
}

# 添加构建信息到/etc/os-release文件中
function add_build_info()
{
	# 删除已有的BUILD_ID字段
	[ -f ${TARGET_ROOTFS_DIR}/etc/os-release ] && \
		sed -i "/^BUILD_ID=/d" ${TARGET_ROOTFS_DIR}/etc/os-release

	# 添加新的BUILD_INFO字段
	echo "添加构建信息到 /etc/os-release..."
	echo "BUILD_INFO=\"$(whoami)@$(hostname) $(date)${@:+ - $@}\"" >> \
		${TARGET_ROOTFS_DIR}/etc/os-release
}

# 创建必要的目录和符号链接
function add_dirs_and_links()
{
	echo "添加目录和符号链接..."

	cd ${TARGET_ROOTFS_DIR}
	mkdir -p mnt/sdcard mnt/usb0  # 创建挂载点目录
	ln -sf media/usb0 udisk  # 创建符号链接
	ln -sf mnt/sdcard sdcard
	ln -sf userdata data
}

# 开始制作根文件系统镜像
echo "制作根文件系统镜像!"

# 如果已有旧的根文件系统镜像文件，则删除
if [ -e ${ROOTFSIMAGE} ]; then
        rm ${ROOTFSIMAGE}
fi

# 添加构建信息
add_build_info 

# 修正 /etc/fstab 文件（如果存在）
[ -f ${TARGET_ROOTFS_DIR}/etc/fstab ] && fixup_fstab

# 添加目录和符号链接
add_dirs_and_links && cd ..

# 创建空白镜像文件
dd if=/dev/zero of=${ROOTFSIMAGE} bs=1M count=0 seek=${IMAGE_SIZE_MB}

# 使用mkfs.ext4命令将内容填充到镜像文件中
sudo mkfs.ext4 -d ${TARGET_ROOTFS_DIR} ${ROOTFSIMAGE}

# 输出根文件系统镜像文件的信息
echo "根文件系统镜像: ${ROOTFSIMAGE}"
