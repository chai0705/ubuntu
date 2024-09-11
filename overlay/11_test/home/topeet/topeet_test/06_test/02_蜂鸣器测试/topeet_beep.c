#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include "topeet_beep.h"

//导出 PWM 设备,确保程序可以正常控制蜂鸣器
int usage()
{
    // 打印帮助信息
    printf("Usage: ./topeet_beep <destination>\r\n");
    printf("destination:\r\n");
    printf("-h            打印帮助信息\r\n");
    printf("heartbeat     启用心跳功能,蜂鸣器的声音会由底到高再变低,运行示例:./topeet_beep heartbeat\r\n");
    printf("0-100的数字    固定蜂鸣器声音大小,由0-100声音依次增大,运行示例：./topeet_beep 50\r\n");
    return 0;
}

void export_pwm()
{
    int fd;

    // 判断是否存在对应的pwm文件夹，如果存在证明已经导出了，如果不存在就导出
    while (access("/sys/class/pwm/pwmchip2/pwm0/", F_OK) != 0)
    {
        // 导出pwm
        printf("pwm\n");
        fd = open("/sys/class/pwm/pwmchip2/export", O_WRONLY);
        if (fd < 0)
        {
            printf("export 文件打开失败\n");
            return;
        }
        write(fd, "0", 1);
        close(fd);
    }   
}

// PWM控制函数，arg为控制参数，val为参数值
int pwm_ctrl(char *arg, char *val)
{
    char file_path[100];
    int fd;
    // 拼接文件路径
    sprintf(file_path, "/sys/class/pwm/pwmchip2/pwm0/%s", arg);
    // 打开文件
    fd = open(file_path, O_WRONLY);
    if (fd < 0)
    {
        // 打开文件失败
        printf("打开文件%s失败\n", file_path);
        return -1;
    }
    // 写入参数值
    write(fd, val, strlen(val));
    // 关闭文件
    close(fd);
    return 0;
}

//实现了蜂鸣器的心跳效果,通过循环改变占空比来使蜂鸣器的音量由高到低再变高
void heartbeat()
{
    char buf[100];
    // 配置PWM周期、占空比并使能PWM输出
    pwm_ctrl("period", "366300"); // 设置周期为366300纳秒
    pwm_ctrl("duty_cycle", "0"); // 设置占空比为0纳秒，即0%
    pwm_ctrl("enable", "1"); // 使能PWM输出

    //   循环改变PWM占空比，实现beep呼吸灯效果
    while (1)
    {
        for (int i = 0; i <= 260000; i=i+26000) // 减小PWM占空比，BEEP变暗
        {
            sprintf(buf, "%d", i);
            pwm_ctrl("duty_cycle", buf);
            sleep(1); // 延时500微秒
        }
        for (int i = 260000; i > 0; i=i-26000) // 增加PWM占空比，BEEP变亮
        {
            sprintf(buf, "%d", i);
            pwm_ctrl("duty_cycle", buf);
            sleep(1); // 延时500微秒
        }
    }
}

//设置蜂鸣器的固定音量大小
void set_beep(char *val)
{
    char buf[100];
    int value;
    // 配置PWM周期、占空比并使能PWM输出
    pwm_ctrl("period", "366300"); // 设置周期为366300纳秒
    pwm_ctrl("duty_cycle", "0"); // 设置占空比为0纳秒，即0%
    pwm_ctrl("enable", "1"); // 使能PWM输出 
    value = atoi(val);
    value = 2600*value;
    sprintf(buf, "%d", value);
    pwm_ctrl("duty_cycle", buf);
}