#include <stdio.h>
#include <string.h>
#include "topeet_beep.h"

int main(int argc, char **argv)
{
    // 如果参数小于2或者包含帮助选项，打印使用帮助
    if ((argc < 2) || (strcmp(argv[1], "-h") == 0))
    {
        usage();
        return 1;
    }
    else if (strcmp(argv[1], "heartbeat") == 0)
    {
        printf("启用蜂鸣器心跳功能\r\n");
        export_pwm();
        heartbeat();
    }
    else
    {
        export_pwm();
        set_beep(argv[1]);
        printf("将蜂鸣器声音设置为%s\r\n",argv[1]);
    }
    return 0;
}