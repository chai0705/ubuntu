#!/bin/bash

# 获取设备的 BOARD 值
BOARD=$(cat /proc/device-tree/compatible | tail -c 7 | head -c 6)

# 根据 BOARD 值执行相应的命令
if [ "$BOARD" == "rk3588" ]; then
    # 针对 rk3588 的命令
    insmod /usr/local/modules/rk3588/8723du.ko
    insmod /usr/local/modules/rk3588/rtk_btusb.ko
    rfkill unblock bluetooth
    hciconfig hci0 up

elif [ "$BOARD" == "rk3568" ]; then
    # 针对 rk3568 的命令
    insmod /usr/local/modules/rk3568/8723du.ko
    insmod /usr/local/modules/rk3568/rtk_btusb.ko
    rfkill unblock bluetooth
    hciconfig hci0 up

elif [ "$BOARD" == "rk3562" ]; then
    # 针对 rk3562 的命令
    insmod /usr/local/modules/rk3562/8723du.ko
    insmod /usr/local/modules/rk3562/rtk_btusb.ko
    rfkill unblock bluetooth
    hciconfig hci0 up

else
    echo "未知的 BOARD 值: $BOARD"
fi

