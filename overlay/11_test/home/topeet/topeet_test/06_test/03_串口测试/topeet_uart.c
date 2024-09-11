#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <string.h>
#include "topeet_uart.h"

// 设置波特率
void set_baud_rate(struct termios *options, int baud_rate) 
{
    switch (baud_rate) 
    {
        case 9600:
            cfsetispeed(options, B9600);
            cfsetospeed(options, B9600);
            break;
        case 19200:
            cfsetispeed(options, B19200);
            cfsetospeed(options, B19200);
            break;
        case 38400:
            cfsetispeed(options, B38400);
            cfsetospeed(options, B38400);
            break;
        case 57600:
            cfsetispeed(options, B57600);
            cfsetospeed(options, B57600);
            break;
        case 115200:
            cfsetispeed(options, B115200);
            cfsetospeed(options, B115200);
            break;
        default:
            cfsetispeed(options, B115200);
            cfsetospeed(options, B115200);
            break;
    }
}

// 设置数据位和停止位
void set_data_and_stop_bits(struct termios *options, int data_bits, int stop_bits) 
{
    options->c_cflag &= ~CSIZE; // 清除CSIZE位

    switch (data_bits) 
    {
        case 7:
            options->c_cflag |= CS7; // 设置数据位为7位
            break;
        case 8:
            options->c_cflag |= CS8; // 设置数据位为8位
            break;
        default:
            options->c_cflag |= CS8; // 默认设置数据位为8位
            break;
    }

    switch (stop_bits) 
    {
        case 1:
            options->c_cflag &= ~CSTOPB; // 设置停止位为1位
            break;
        case 2:
            options->c_cflag |= CSTOPB; // 设置停止位为2位
            break;
        default:
            options->c_cflag &= ~CSTOPB; // 默认设置停止位为1位
            break;
    }
}

// 设置校验位
void set_parity(struct termios *options, int parity) 
{
    switch (parity) 
    {
        case 'O':  // 奇校验
            options->c_cflag |= PARENB;
            options->c_cflag |= PARODD;
            options->c_iflag |= (INPCK | ISTRIP);
            break;
        case 'E':  // 偶校验
            options->c_cflag |= PARENB;
            options->c_cflag &= ~PARODD;
            options->c_iflag |= (INPCK | ISTRIP);
            break;
        case 'N':  // 无校验
            options->c_cflag &= ~PARENB;
            break;
        default:
            options->c_cflag &= ~PARENB;
            break;
    }
}

// 设置串口参数
void set_serial_port(int fd, int baud_rate, int data_bits, int stop_bits, int parity) 
{
    struct termios options;
    tcgetattr(fd, &options);  // 获取串口的设置选项

    set_baud_rate(&options, baud_rate);
    set_data_and_stop_bits(&options, data_bits, stop_bits);
    set_parity(&options, parity);

    options.c_cflag |= CLOCAL | CREAD;  // 启用本地连接和接收数据
    options.c_cflag &= ~CRTSCTS;  // 关闭硬件流控制
    options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);  // 关闭规范模式、回显和信号处理
    options.c_oflag &= ~OPOST;  // 关闭输出处理
    options.c_iflag &= ~(IXON | IXOFF | IXANY);  // 关闭输入处理
    options.c_cc[VTIME] = 0;  // 设置读取时的超时时间
    options.c_cc[VMIN] = 0;  // 设置读取时的最小字节数

    tcsetattr(fd, TCSANOW, &options); // 应用新的设置到串口上
}

// 发送数据
void send_data(int fd) 
{
    char buffer[BUFFER_SIZE];
    while (1) 
    {
        printf("Enter message: ");
        fgets(buffer, BUFFER_SIZE, stdin);
        write(fd, buffer, strlen(buffer));
    }
}

// 接收数据
void recv_data(int fd) 
{
    char buffer[BUFFER_SIZE];
    while (1) 
    {
        int bytes_read = read(fd, buffer, BUFFER_SIZE);
        if (bytes_read > 0) 
        {
            buffer[bytes_read] = '\0';
            printf("Received message: %s", buffer);
        }
    }
}
