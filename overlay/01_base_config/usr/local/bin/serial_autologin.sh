#!/bin/bash

# 定义服务文件路径
SERVICE_FILE="/usr/lib/systemd/system/serial-getty@.service"

# 自动登录的ExecStart命令
AUTLOGIN_CMD="ExecStart=-/sbin/agetty --autologin root --noclear %I \$TERM"

# 禁用自动登录的默认ExecStart命令
DEFAULT_CMD="ExecStart=-/sbin/agetty -o '-p -- \\\\u' --keep-baud 115200,57600,38400,9600 %I \$TERM"

# 启用自动登录的函数
function enable_autologin() {
    echo "正在启用串口终端自动登录..."
    sudo sed -i "s|^ExecStart=.*|$AUTLOGIN_CMD|" "$SERVICE_FILE"
    sudo systemctl daemon-reload
    echo "自动登录已启用。"
}

# 禁用自动登录的函数，恢复默认设置
function disable_autologin() {
    echo "正在禁用串口终端自动登录..."
    sudo sed -i "s|^ExecStart=.*|$DEFAULT_CMD|" "$SERVICE_FILE"
    sudo systemctl daemon-reload
    echo "自动登录已禁用。"
}

# 检查当前配置状态的函数
function check_status() {
    if grep -q "$AUTLOGIN_CMD" "$SERVICE_FILE"; then
        echo "自动登录当前已启用。"
    elif grep -q "$DEFAULT_CMD" "$SERVICE_FILE"; then
        echo "自动登录当前已禁用。"
    else
        echo "自动登录状态未知。"
    fi
}

# 检查传递的参数，根据参数执行相应操作
if [ "$1" == "enable" ]; then
    enable_autologin
elif [ "$1" == "disable" ]; then
    disable_autologin
elif [ "$1" == "status" ]; then
    check_status
else
    echo "用法: $0 {enable|disable|status}"
    exit 1
fi
