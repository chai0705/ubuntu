#!/bin/bash

# 获取显示器名称
display_name=$(xrandr | grep " connected" | awk '{ print $1 }')

# 判断是否存在 "goodix-ts" 触摸屏设备
touch_name=$(xinput list | grep -i "goodix-ts" | grep -oP '(?<=↳ ).*(?=\s+id)')
touch_id=$(xinput list | grep -i "goodix-ts" | grep -oP '(?<=id=)[0-9]+')

# 如果 "goodix-ts" 没有找到，选择 "ft5x06" 触摸屏设备
if [ -z "$touch_id" ]; then
    touch_name=$(xinput list | grep -i "ft5x06" | grep -oP '(?<=↳ ).*(?=\s+id)')
    touch_id=$(xinput list | grep -i "ft5x06" | grep -oP '(?<=id=)[0-9]+')
fi

# 如果没有找到显示器或触摸屏设备，退出
if [ -z "$display_name" ]; then
    echo "没有找到连接的显示器！"
    exit 1
fi

if [ -z "$touch_id" ]; then
    echo "没有找到触摸屏设备！"
    exit 1
fi

# 显示旋转选项给用户选择
echo "选择旋转角度:"
echo "1. 正常显示"
echo "2. 向左旋转90度"
echo "3. 向右旋转90度"
echo "4. 旋转180度"

read -p "请输入选项 (1-4): " choice

case $choice in
    1)
        # 正常显示
        xrandr --output "$display_name" --rotate normal
        xinput set-prop "$touch_id" "Coordinate Transformation Matrix" 1 0 0 0 1 0 0 0 1
        ;;
    2)
        # 向左旋转90度
        xrandr --output "$display_name" --rotate left
        xinput set-prop "$touch_id" "Coordinate Transformation Matrix" 0 -1 1 1 0 0 0 0 1
        ;;
    3)
        # 向右旋转90度
        xrandr --output "$display_name" --rotate right
        xinput set-prop "$touch_id" "Coordinate Transformation Matrix" 0 1 0 -1 0 1 0 0 1
        ;;
    4)
        # 旋转180度
        xrandr --output "$display_name" --rotate inverted
        xinput set-prop "$touch_id" "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1
        ;;
    *)
        echo "无效选项！"
        exit 1
        ;;
esac

echo "显示器和触摸屏旋转已同步完成。"

