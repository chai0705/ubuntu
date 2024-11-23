#!/bin/bash

# 获取显示器名称
display_name=$(xrandr | grep " connected" | awk '{ print $1 }')

# 判断是否存在触摸屏设备 ("goodix-ts" 或 "ft5x06")
touch_name=$(xinput list | grep -Ei "goodix-ts|ft5x06" | grep -oP '(?<=↳ ).*(?=\s+id)')
touch_id=$(xinput list | grep -Ei "goodix-ts|ft5x06" | grep -oP '(?<=id=)[0-9]+')

# 如果没有找到显示器，退出
if [ -z "$display_name" ]; then
    echo "没有找到连接的显示器！"
    exit 1
fi

# 提示是否启用触摸屏同步（如果没有找到触摸屏设备则跳过）
if [ -z "$touch_id" ]; then
    echo "警告：未检测到触摸屏设备，触摸屏同步将被跳过。"
    enable_touch=false
else
    enable_touch=true
fi

# 检查是否提供了参数
if [ -z "$1" ]; then
    echo "使用方法: $0 [选项]"
    echo "选项:"
    echo "1 - 正常显示"
    echo "2 - 向左旋转90度"
    echo "3 - 向右旋转90度"
    echo "4 - 旋转180度"
    exit 1
fi

# 判断输入参数
case $1 in
    1)
        # 正常显示
        xrandr --output "$display_name" --rotate normal
        if [ "$enable_touch" = true ]; then
            xinput set-prop "$touch_id" "Coordinate Transformation Matrix" 1 0 0 0 1 0 0 0 1
        fi
        ;;
    2)
        # 向左旋转90度
        xrandr --output "$display_name" --rotate left
        if [ "$enable_touch" = true ]; then
            xinput set-prop "$touch_id" "Coordinate Transformation Matrix" 0 -1 1 1 0 0 0 0 1
        fi
        ;;
    3)
        # 向右旋转90度
        xrandr --output "$display_name" --rotate right
        if [ "$enable_touch" = true ]; then
            xinput set-prop "$touch_id" "Coordinate Transformation Matrix" 0 1 0 -1 0 1 0 0 1
        fi
        ;;
    4)
        # 旋转180度
        xrandr --output "$display_name" --rotate inverted
        if [ "$enable_touch" = true ]; then
            xinput set-prop "$touch_id" "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1
        fi
        ;;
    *)
        echo "无效选项！使用1、2、3或4作为参数。"
        exit 1
        ;;
esac

echo "显示器旋转完成。"
if [ "$enable_touch" = true ]; then
    echo "触摸屏旋转同步完成。"
else
    echo "未同步触摸屏旋转（未检测到触摸屏设备）。"
fi

