#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "topeet_can.h"

int main(int argc, char *argv[]) {
    // 检查命令行参数
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <can_interface> <bitrate> <send|recv>\n", argv[0]);
        return -1;
    }

    // 获取CAN接口名称、波特率和操作模式
    const char *ifname = argv[1];
    int bitrate = atoi(argv[2]);
    if (bitrate <= 0) {
        fprintf(stderr, "Invalid bitrate: %s\n", argv[2]);
        return -1;
    }

    const char *mode = argv[3];
    if (strcmp(mode, "send") != 0 && strcmp(mode, "recv") != 0) {
        fprintf(stderr, "Invalid mode: %s. Use 'send' or 'recv'.\n", mode);
        return -1;
    }

    // 配置CAN套接字
    int s = setup_can_socket(ifname, bitrate);
    if (s < 0) {
        return -1;
    }

    // 根据模式选择发送或接收
    if (strcmp(mode, "send") == 0) {
        send_can_data(s);
    } else if (strcmp(mode, "recv") == 0) {
        receive_can_data(s);
    }

    close(s);  // 关闭套接字
    return 0;
}
