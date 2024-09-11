#ifndef BEEP_CONTROL_H
#define BEEP_CONTROL_H

// 函数声明
int usage();
void export_pwm();
int pwm_ctrl(char *arg, char *val);
void heartbeat();
void set_beep(char *val);

#endif // BEEP_CONTROL_H
