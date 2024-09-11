#ifndef SERIAL_PORT_H
#define SERIAL_PORT_H

#define BUFFER_SIZE 256  // 定义缓冲区大小为256字节
// 设置波特率
void set_baud_rate(struct termios *options, int baud_rate);

// 设置数据位和停止位
void set_data_and_stop_bits(struct termios *options, int data_bits, int stop_bits);

// 设置校验位
void set_parity(struct termios *options, int parity);

// 设置串口参数
void set_serial_port(int fd, int baud_rate, int data_bits, int stop_bits, int parity);

// 发送数据
void send_data(int fd);

// 接收数据
void recv_data(int fd);

#endif // SERIAL_PORT_H


