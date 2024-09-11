#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include "topeet_gpio.h"

// 打印使用帮助信息
int usage()
{
    printf("Usage: ./topeet_gpio [options] <destination>\r\n");
    printf("Options:\r\n");
    printf("-h 打印帮助信息\r\n");
    printf("-t 计算gpio引脚编号,例如可以输入:./topeet_gpio -t gpio3_b6 来计算gpio3_b6的引脚编号\r\n");
    printf("-c 控制gpio的输入输出方向:\r\n");
    printf("  (1)当gpio设置为输入时,可以查看gpio的电平值:\r\n");
    printf("     例如可以输入./topeet_gpio -c gpio3_b6 in 来将gpio3_b6设置为输入模式，并打印改引脚的值\r\n");
    printf("  (2)当gpio设置为输出时,可以设置该引脚的高低电平:\r\n");
    printf("     例如可以输入./topeet_gpio -c gpio3_b6 out 1 来将gpio3_b6设置为输出模式，并设置为高电平\r\n");
    return 0;
}

// 计算GPIO引脚编号
int Calculation_gpio(char *param)
{
    int value, param_length;
    param_length = strlen(param);

    // 检查参数长度是否符合格式
    if (param_length != 8)
    {
        printf("gpio格式错误,请输入正确的GPIO格式,例如GPIO3_B6或者gpio3_b6\r\n");
        return -1;
    }

    // 第一轮判断，确定第一个数字
    switch(param[4])
    {
        case '0': value = 0; break;
        case '1': value = 32; break;
        case '2': value = 64; break;
        case '3': value = 96; break;
        case '4': value = 128; break;
        default: return -1;
    }

    // 第二轮判断，确定字母
    switch(param[6])
    {
        case 'a': case 'A': value += 0; break;
        case 'b': case 'B': value += 8; break;
        case 'c': case 'C': value += 16; break;
        case 'd': case 'D': value += 24; break;
        default: return -1;
    }

    // 第三轮判断，确定最后一个数字
    switch(param[7])
    {
        case '0': value += 0; break;
        case '1': value += 1; break;
        case '2': value += 2; break;
        case '3': value += 3; break;
        case '4': value += 4; break;
        case '5': value += 5; break;
        case '6': value += 6; break;
        case '7': value += 7; break;
        default: return -1;
    }

    return value;
}

//检查输入参数格式，并计算
int check_format(char **argv)
{
    int value;
    // 判断输入的GPIO格式
    if (strlen(argv[2]) == 8)
        value = Calculation_gpio(argv[2]);
    else if (strlen(argv[2]) == 3)
        value = atoi(argv[2]);
    else
        return -1;
    
    return value;
}

void export_gpio(char gpio_value[20], char gpio_path[100])
{
    int fd;

    // 判断是否存在对应的gpio文件夹，如果存在证明已经导出了，如果不存在就导出
    while (access(gpio_path, F_OK) != 0)
    {
        // 导出gpio
        printf("导出gpio\n");
        fd = open("/sys/class/gpio/export", O_WRONLY);
        if (fd < 0)
        {
            printf("export 文件打开失败\n");
            return;
        }
        write(fd, gpio_value, strlen(gpio_value));
        close(fd);
    }  
}

// 设置GPIO为输入模式并读取当前电平值
void gpioin_set(char gpio_path[100])
{
    char file_path[200];
    int fd;
    char buf[2] = {0};

    // 设置GPIO为输入模式
    sprintf(file_path, "%s/direction", gpio_path);
    fd = open(file_path, O_WRONLY);
    if (fd < 0)
    {
        printf("direction 文件打开失败\n");
        return;
    }
    write(fd, "in", 3);
    close(fd);

    // 读取当前GPIO的电平值
    sprintf(file_path, "%s/value", gpio_path);
    fd = open(file_path, O_RDONLY);
    if (fd < 0)
    {
        printf("value 文件打开失败\n");
        return;
    }
    read(fd, buf, 1); // 从文件中读取1个字节的数据
    if (strcmp(buf, "1") == 0)
    {
        printf("当前GPIO为高电平\n");
    }
    else if (strcmp(buf, "0") == 0)
    {
        printf("当前GPIO为低电平\n");
    }
    close(fd);
}

// 设置GPIO为输出模式并设置电平值
void gpioout_set(char gpio_path[100], char **argv)
{
    char file_path[200];
    int fd;

    // 设置GPIO为输出模式
    sprintf(file_path, "%s/direction", gpio_path);
    fd = open(file_path, O_WRONLY);
    if (fd < 0)
    {
        printf("direction 文件打开失败\n");
        return;
    }
    write(fd, "out", 3);
    close(fd);

    // 如果第5个参数设置为1，表示设置为高电平
    if (strcmp(argv[4], "1") == 0)
    {
        printf("将%s设置为高电平\r\n", argv[2]);
        sprintf(file_path, "%s/value", gpio_path);
        fd = open(file_path, O_WRONLY);
        if (fd < 0)
        {
            printf("value 文件打开失败\n");
            return;
        }
        write(fd, "1", 1);
        close(fd);
    }
    // 如果第5个参数设置为0，表示设置为低电平
    else if (strcmp(argv[4], "0") == 0)
    {
        printf("将%s设置为低电平\r\n", argv[2]);
        sprintf(file_path, "%s/value", gpio_path);
        fd = open(file_path, O_WRONLY);
        if (fd < 0)
        {
            printf("value 文件打开失败\n");
            return;
        }
        write(fd, "0", 1);
        close(fd);
    }
}
