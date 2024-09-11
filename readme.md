## 简介

A set of shell scripts that will build GNU/Linux distribution rootfs image
for rockchip platform.

## 适用板卡

- 使用RK3562处理器的iTOP-RK3562板卡
- 使用RK3568处理器的iTOP-RK3568板卡
- 使用RK3588处理器的iTOP-RK3588板卡

## 构建 Ubuntu22.04镜像（仅支持64bit）

- lite：控制台版，无桌面
- xfce：桌面版，使用xfce桌面套件
- gnome：桌面版，使用gnome桌面套件


#### step1.构建基础 Ubuntu 系统。

```
# 运行以下脚本，根据提示选择要构建的版本
./mk-base-ubuntu.sh
```
#### step2.添加 rk overlay 层,并打包ubuntu-rootfs镜像

```
# 运行以下脚本，根据提示选择要构建处理器版本和ubuntu的版本
./mk-ubuntu-rootfs.sh
