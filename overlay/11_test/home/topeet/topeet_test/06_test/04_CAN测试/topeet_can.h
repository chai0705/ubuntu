#ifndef CAN_UTILS_H
#define CAN_UTILS_H

#define BUF_SIZ 255

int setup_can_socket(const char *ifname, int bitrate);  //配置CAN套接字的函数
void send_can_data(int s);  //发送CAN数据的函数
void receive_can_data(int s); // 接收CAN数据的函数

#endif // CAN_UTILS_H

