#include "topeet_can.h"
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <linux/can.h>
#include <linux/can/raw.h>
#include <string.h>
#include <net/if.h>
#include <unistd.h>
#include <sys/ioctl.h>

/*
 * 配置CAN套接字的函数
 * 参数：ifname - CAN接口名称
 *      bitrate - 波特率
 * 返回值：成功返回CAN套接字，失败返回-1
 */
int setup_can_socket(const char *ifname, int bitrate) {
    int s;  // 套接字文件描述符
    struct sockaddr_can addr;  // CAN地址结构
    struct ifreq ifr;  // 网络接口请求结构
    char cmd[100];  // 系统命令缓冲区

    // 创建CAN套接字
    s = socket(PF_CAN, SOCK_RAW, CAN_RAW);
    if (s < 0) {
        perror("套接字错误");
        return -1;
    }

    // 关闭CAN设备
    snprintf(cmd, sizeof(cmd), "ip link set %s down", ifname);
    if (system(cmd) < 0) {
        perror("关闭CAN设备错误");
        close(s);
        return -1;
    }

    // 设置CAN设备波特率
    snprintf(cmd, sizeof(cmd), "ip link set %s up type can bitrate %d", ifname, bitrate);
    if (system(cmd) < 0) {
        perror("设置CAN波特率错误");
        close(s);
        return -1;
    }

    // 启动CAN设备
    snprintf(cmd, sizeof(cmd), "ip link set %s up", ifname);
    if (system(cmd) < 0) {
        perror("启动CAN设备错误");
        close(s);
        return -1;
    }

    // 获取指定接口的索引
    strcpy(ifr.ifr_name, ifname);
    if (ioctl(s, SIOCGIFINDEX, &ifr) < 0) {
        perror("获取接口索引错误");
        close(s);
        return -1;
    }

    // 设置CAN地址
    addr.can_family = AF_CAN;
    addr.can_ifindex = ifr.ifr_ifindex;

    // 绑定套接字到CAN接口
    if (bind(s, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("绑定错误");
        close(s);
        return -1;
    }

    return s;
}

/*
 * 发送CAN数据的函数
 * 参数：s - CAN套接字
 */
void send_can_data(int s) {
    struct can_frame frame[3];  // 定义三个CAN帧
    unsigned char data[2] = {0x01, 0x02};  // 数据内容
    int ret;

    // 初始化三个CAN帧
    frame[0].can_id = 0x11;  // 标准帧ID
    frame[0].can_dlc = 2;  // 数据长度码
    strcpy(frame[0].data, data);  // 数据

    frame[1].can_id = 0x11 | CAN_EFF_FLAG;  // 扩展帧ID
    frame[1].can_dlc = 2;
    strcpy(frame[1].data, data);

    frame[2].can_id = 0x11 | CAN_RTR_FLAG;  // 远程请求帧ID
    frame[2].can_dlc = 2;

    // 不断发送三个CAN帧
    while (1) {
        // 发送标准帧
        ret = write(s, &frame[0], sizeof(frame[0]));
        if (ret != sizeof(frame[0])) {
            printf("发送frame[0]错误\n");
            break;
        }

        // 发送扩展帧
        ret = write(s, &frame[1], sizeof(frame[1]));
        if (ret != sizeof(frame[1])) {
            printf("发送frame[1]错误\n");
            break;
        }

        // 发送远程请求帧
        ret = write(s, &frame[2], sizeof(frame[2]));
        if (ret != sizeof(frame[2])) {
            printf("发送frame[2]错误\n");
            break;
        }

        sleep(1);  // 每秒发送一次
    }
}

/*
 * 接收CAN数据的函数
 * 参数：s - CAN套接字
 */
void receive_can_data(int s) {
    struct can_frame frame;  // CAN帧结构
    int ret, n, i, err;
    char buf[BUF_SIZ];  // 数据缓冲区
    FILE *out = stdout;  // 输出文件

    // 不断接收CAN帧
    while (1) {
        ret = read(s, &frame, sizeof(frame));
        if (ret > 0) {
            // 判断是否为扩展帧
            if (frame.can_id & CAN_EFF_FLAG)
                n = snprintf(buf, BUF_SIZ, "<0x%08x>", frame.can_id & CAN_EFF_MASK);
            else
                n = snprintf(buf, BUF_SIZ, "<0x%03x>", frame.can_id & CAN_SFF_MASK);

            n += snprintf(buf + n, BUF_SIZ - n, "[%d]", frame.can_dlc);

            // 读取数据
            for (i = 0; i < frame.can_dlc; i++) {
                n += snprintf(buf + n, BUF_SIZ - n, "%02x", frame.data[i]);
            }

            // 判断是否为远程请求帧
            if (frame.can_id & CAN_RTR_FLAG) {
                snprintf(buf + n, BUF_SIZ - n, "远程请求");
            }

            // 输出接收到的数据
            fprintf(out, "%s\n", buf);

            // 刷新输出缓冲区
            err = fflush(out);
            if (err < 0) {
                printf("刷新错误\n");
            }
        }
    }
}
