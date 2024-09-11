#include <stdio.h>
#include <string.h>
#include "topeet_gpio.h"


int main(int argc, char *argv[])
{
    int value, fd;
    char gpio_value[20];
    char gpio_path[100];

    // 如果参数小于2或者包含帮助选项，打印使用帮助
    if ((argc < 2) || (strcmp(argv[1], "-h") == 0))
    {
        usage();
        return 1;
    }
    // 处理计算GPIO引脚编号的选项
    else if (strcmp(argv[1], "-t") == 0)
    {
        value = Calculation_gpio(argv[2]);
        if (value == -1)
            return -1;
        printf("%s的引脚编号为%d\r\n", argv[2], value);
        return 1;
    }
    // 处理控制GPIO输入输出方向的选项
    else if ((strcmp(argv[1], "-c") == 0) && ((argc == 4) || (argc == 5)))
    {
        value = check_format(argv);
        if(value == -1)
        {
            printf("gpio格式错误,请输入正确的GPIO格式,例如GPIO3_B6或者引脚编号\r\n");
            return -1;
        }

        // 将转换完成的int值再转换为字符串类型，从而可以实现拼接
        sprintf(gpio_value, "%d", value);
        sprintf(gpio_path, "/sys/class/gpio/gpio%s", gpio_value);
        printf("要操作的GPIO标号为 %s\n", gpio_value);

        //导出GPIO
        export_gpio(gpio_value, gpio_path);

        // 输入输出模式设置
        if (strcmp(argv[3], "in") == 0)
        {
            printf("将%s设置为输入模式\r\n", argv[2]);
            gpioin_set(gpio_path);
            return 1;
        }
        else if (strcmp(argv[3], "out") == 0)
        {
            printf("将%s设置为输出模式\r\n", argv[2]);
            gpioout_set(gpio_path, argv);
            return 1;
        }
        printf("请输入正确的参数,第三个参数必须为in或者out中的一个\r\n");
    }
    return 0;
}