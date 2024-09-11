#ifndef GPIO_CONTROL_H
#define GPIO_CONTROL_H

// 函数声明
int usage();
int Calculation_gpio(char *param);
int check_format(char **argv);
void export_gpio(char gpio_value[20], char gpio_path[100]);
void gpioin_set(char gpio_path[100]);
void gpioout_set(char gpio_path[100], char **argv);

#endif // GPIO_CONTROL_H
