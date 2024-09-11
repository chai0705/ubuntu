#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include "topeet_uart.h"

int main(int argc, char *argv[]) 
{
    int fd;
    
    if (argc != 3) 
    {
        printf("Usage: %s [serial device] [send|recv]\n", argv[0]);
        return -1;
    }
    if (strcmp(argv[2], "send") == 0) 
    {
        fd = open(argv[1], O_WRONLY | O_NOCTTY | O_SYNC);
        if (fd < 0) 
        {
            printf("Error opening serial device\n");
            return -1;
        }

        set_serial_port(fd, 115200, 8, 1, 'N'); 
        send_data(fd);  // 调用发送数据函数
    }
    else if (strcmp(argv[2], "recv") == 0) 
    {
        fd = open(argv[1], O_RDONLY | O_NOCTTY | O_SYNC);
        if (fd < 0) 
        {
            printf("Error opening serial device\n");
            return -1;
        }

        set_serial_port(fd, 115200, 8, 1, 'N');
        recv_data(fd);  // 调用接收数据函数
    } 
    else 
    {
        printf("Invalid option\n");
        return -1;
    }

    return 0;
}
