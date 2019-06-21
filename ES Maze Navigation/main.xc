/*
 * Final Maze Project.xc

 *
 *  Created on: Jun 13, 2019
 *      Author: averysand
 */

//#includes
#include <xs1.h>
#include <stdio.h>
#include <print.h>
#include <string.h>
#include <platform.h>
#include <stdlib.h>
#include <math.h>

#include "mpu6050.h"
#include "i2c.h"
#include "bfs.h"

//Definitions
#define BAUDRATE 9600
#define TICKS_PER_SEC XS1_TIMER_HZ
#define TICKS_PER_US (XS1_TIMER_HZ/1000000)
#define TICKS_PER_MS (XS1_TIMER_HZ/1000)
#define CRLF "\r\n"
#define BOOT_MESSAGE "lua: cannot open init.lua"
#define SEND_WIFI_SETUP_MESSAGE "send_wifi_setup"
#define BUFFER 256
#define MESSAGE_SIZE 128
#define BIN1_ON 0b0010
#define BIN2_ON 0b1000
#define AIN1_ON 0b0100
#define AIN2_ON 0b0001
//#define AIN1_ON 0b0001
//#define AIN2_ON 0b0100
//#define BIN1_ON 0b1000 //For my second robot whose has its bits flipped
//#define BIN2_ON 0b0010
#define STOP 0b0000
#define SIG1 0b0010
#define SIG2 0b0001
#define FULL_DUTY_CYCLE_LEFT 90 //separate duty cycles for fine-tuning each wheel
#define FULL_DUTY_CYCLE_RIGHT 35
#define PWM_FRAME_TICKS TICKS_PER_MS
#define RAD_90_DEGREES (M_PI/2)   //in radians
#define ERROR_MARGIN_TURNS .25 //also in radians
#define WHEEL_ADJUST_RATE 5
#define PAUSE_LENGTH 570

//Ports
in port iEncoders = XS1_PORT_4C; //3rd and 4th bit for SIG1 and SIG2
in port iWiFiTX = XS1_PORT_1H; //receive from WiFi
out port oWiFiRX = XS1_PORT_1F; //send to WiFi
out port oMotorPWMA = XS1_PORT_1P; //left wheel
out port oMotorPWMB = XS1_PORT_1I; //right wheel
out port oMotorControl = XS1_PORT_4D; //heading
out port oSTB = XS1_PORT_1O;
out port oLED1 = XS1_PORT_1A;
out port oLED2 = XS1_PORT_1D;

//Structs
typedef struct {
    char data[MESSAGE_SIZE];
} message_t;

typedef struct {
    int left_duty_cycle;
    int right_duty_cycle;
} motor_cmd_t;

typedef struct {
    float yaw;
    float pitch;
    float roll;
} ypr_t;

//using GY-521 breakout board with 3.3V
struct IMU imu = {{
        on tile[0]:XS1_PORT_1L,                         //scl
        on tile[0]:XS1_PORT_4E,                         //sda
        400},};                                         //clockticks (1000=i2c@100kHz)

in  port butP = XS1_PORT_32A;                           //Button is bit 0, used to stop gracefully

//Functions
void run_wifi_setup();
void output_task(chanend trigger_chan);
void line(const char buffer[]);
void uart_transmit_byte (out port oPort, char value, unsigned int baud_rate);
void uart_transmit_bytes (out port oPort, const char values[], unsigned int baud_rate);
char uart_receive_byte (in port iPort, unsigned int baud_rate);
unsigned int convert_duty_cycle(unsigned int frame_ticks, int duty_cycle);
void motor_control(out port oMotorControl, motor_cmd_t mc);
void encoder_task(in port iEncoder, out port oLed1, out port oLed2, chanend encoder_chan);
void uart_to_console_task(chanend message_chan, chanend motor_chan, chanend encoder_chan, chanend imu_chan, chanend command_chan);
void multi_motor_task(out port oMotorPWM, out port oRightPWM, out port oMotorControl, chanend in_motor_cmd_chan);//DEBUG
void imu_task(chanend imu_out);
void path_to_commands(int path[], char commands[], int num_commands);
void send_commands(char commands[], int num_commmands, chanend command_chan);

//Runs
int main(void){

    /* Run the search */
    const int obstacles[ELEMENT_COUNT] = {
                0, 0, 0, 0, 0,
                0, 1, 1, 1, 0,
                0, 0, 0, 0, 0,
                1, 0, 1, 0, 0,
                0, 0, 1, 0, 0
        };
    int start_rank = RANK(4, 3);
    int goal_rank = RANK(0, 0);
    int path[ELEMENT_COUNT];

    //initialize array
    for (int i = 0; i < ELEMENT_COUNT; i++) {
        path[i] = -1;
    }

    int num_commands = find_shortest_path(start_rank, goal_rank, obstacles, path);
//    for (int i = 0; i < num_commands; i++){
//        printintln(path[i]);
//    }

    char commands[ELEMENT_COUNT];
    path_to_commands(path, commands, num_commands);
    for (int i = 0; i < num_commands; i++){
           printcharln(commands[i]);
        }

    chan message_chan, motor_chan, encoder_chan, imu_chan, command_chan;
    oWiFiRX <: 1;
    iWiFiTX when pinseq(1) :> void;
    oSTB <: 1;

    par{
        imu_task(imu_chan);
        uart_to_console_task(message_chan, motor_chan, encoder_chan, imu_chan, command_chan);
        multi_motor_task(oMotorPWMA, oMotorPWMB, oMotorControl, motor_chan);
        encoder_task(iEncoders, oLED1, oLED2, encoder_chan);
        output_task(message_chan);
        send_commands(commands, num_commands, command_chan);
    }
    return 0;
}

//Sends Commands across Channel, Adding Logic for Timing Pauses Between Commands
void send_commands(char commands[], int num_commands, chanend command_chan){

    delay_seconds(.5); //wait for imu and wifi initialization to complete
    command_chan <: 'x';
    for (int i  = 0; i < num_commands; i++){

        //FORWARD
        if (commands[i] == 'F'){
            command_chan <: 'F';
            delay_milliseconds(PAUSE_LENGTH*1.25);
        }
        //BACKWARD
        else if (commands[i] == 'B'){
            command_chan <: ',';
            delay_milliseconds(PAUSE_LENGTH*2);
            command_chan <: ',';
            delay_milliseconds(PAUSE_LENGTH*2);
        }
        //RIGHT
        else if (commands[i] == 'R'){
            command_chan <: '.';
            delay_milliseconds(PAUSE_LENGTH*1.85);
            command_chan <: 'F';
            delay_milliseconds(PAUSE_LENGTH);
        }
        //LEFT
        else if (commands[i] == 'L'){
            command_chan <: ',';
            delay_milliseconds(PAUSE_LENGTH*2);
            command_chan <: 'F';
            delay_milliseconds(PAUSE_LENGTH);
        }
        //Error, stop car
        else{
            command_chan <: 'x';
        }

        command_chan <: 'x'; //Stop after completing commands
        delay_milliseconds(PAUSE_LENGTH*2); //Pause before next command
    }

}

//Translates Path to Commands in Form {Forward, Backward, Left, Right}
void path_to_commands(int path[], char commands[], int num_commands){

   int previous_spot = 0, next_square = 0;
   int orientation = 0; // North = 0, East = 1, South = 2, West = 3, Default: North

   for (int i = 0; i < num_commands - 1; i++){

       previous_spot = path[i];
       next_square = path[i+1];

       //Pointing North
       if (orientation == 0){
           if (next_square < previous_spot){

               //LEFT
               if (next_square + 1 == previous_spot){
                   commands[i] = 'L';
                   orientation = 3; //Now pointing West
               }
               //FORWARD
               else{
                   commands[i] = 'F';
               }
           }
           else{
               //RIGHT
               if(next_square - 1 == previous_spot){
                   commands[i] = 'R';
                   orientation = 1; //Now pointing East
               }
               //BACKWARD
               else{
                   commands[i] = 'B';
                   orientation = 2; //Now pointing South
               }
           }
       }

       //Pointing East
       else if (orientation == 1){
          if (next_square < previous_spot){

              //BACKWARD
              if (next_square + 1 == previous_spot){
                  commands[i] = 'B';
                  orientation = 3 ; //Now pointing West
              }
              //LEFT
              else{
                  commands[i] = 'L';
                  orientation = 0; //Now Pointing North
              }
          }
          else{
              //FORWARD
              if(next_square - 1 == previous_spot){
                  commands[i] = 'F';
              }
              //RIGHT
              else{
                  commands[i] = 'R';
                  orientation = 2; //Now pointing South
              }
          }
      }

       //Pointing South
       else if (orientation == 2){
          if (next_square < previous_spot){

              //RIGHT
              if (next_square + 1 == previous_spot){
                  commands[i] = 'R';
                  orientation = 3; //Now pointing West
              }
              //BACKWARD
              else{
                  commands[i] = 'B';
                  orientation = 0; //Now pointing North
              }
          }
          else{
              //LEFT
              if(next_square - 1 == previous_spot){
                  commands[i] = 'L';
                  orientation = 1; //Now pointing East
              }
              //FORWARD
              else{
                  commands[i] = 'F';
              }
          }
      }

      //Pointing West
       else {
        if (next_square < previous_spot){

            //FORWARD
            if (next_square + 1 == previous_spot){
                commands[i] = 'F';
            }
            //RIGHT
            else{
                commands[i] = 'R';
                orientation = 0; //Now Pointing North
            }
        }
        else{
            //BACKWARD
            if(next_square - 1 == previous_spot){
                commands[i] = 'B';
                orientation = 1; //Now pointing East
            }
            //LEFT
            else{
                commands[i] = 'L';
                orientation = 2; //Now pointing South
            }
        }
    }

       previous_spot = next_square;
   }
}

void imu_task(chanend imu_out){                        //does all MPU6050 actions
    int packetsize,mpuIntStatus,fifoCount;
    int address;
    unsigned char result[64];                           //holds dmp packet of data
    float qtest;
    float q[4]={0,0,0,0},g[3]={0,0,0},ypr[3]={0,0,0};
    int but_state;
    int fifooverflowcount=0,fifocorrupt=0;
    int GO_FLAG=1;

    printf("Starting MPU6050...\n");
    mpu_init_i2c(imu);
    printf("I2C Initialized...\n");
    address=mpu_read_byte(imu.i2c, MPU6050_RA_WHO_AM_I);
    printf("MPU6050 at i2c address: %.2x\n",address);
    mpu_dmpInitialize(imu);
    mpu_enableDMP(imu,1);   //enable DMP

    mpuIntStatus=mpu_read_byte(imu.i2c,MPU6050_RA_INT_STATUS);
    printf("MPU Interrupt Status:%d\n",mpuIntStatus);
    packetsize=42;                  //size of the fifo buffer
    delay_milliseconds(250);

    //The hardware interrupt line is not used, the FIFO buffer is polled
    while (GO_FLAG){
        mpuIntStatus=mpu_read_byte(imu.i2c,MPU6050_RA_INT_STATUS);
        if (mpuIntStatus >= 2) {
            fifoCount = mpu_read_short(imu.i2c,MPU6050_RA_FIFO_COUNTH);
            if (fifoCount>=1024) {              //fifo overflow
                mpu_resetFifo(imu);
                fifooverflowcount+=1;           //keep track of how often this happens to tweak parameters
                //printf("FIFO Overflow!\n");
            }
            while (fifoCount < packetsize) {    //wait for a full packet in FIFO buffer
                fifoCount = mpu_read_short(imu.i2c,MPU6050_RA_FIFO_COUNTH);
            }
            //printf("fifoCount:%d\n",fifoCount);
            mpu_getFIFOBytes(imu,packetsize,result);    //retrieve the packet from FIFO buffer

            mpu_getQuaternion(result,q);
            qtest=sqrt(q[0]*q[0]+q[1]*q[1]+q[2]*q[2]+q[3]*q[3]);
            if (fabs(qtest-1.0)<0.001){                             //check for fifo corruption - quat should be unit quat
                mpu_getGravity(q,g);
                mpu_getYawPitchRoll(q,g,ypr);

                //Added Struct for Sending YPR Channel Messages
                ypr_t ypr_struct;
                ypr_struct.yaw = ypr[0];
                ypr_struct.pitch = ypr[1];
                ypr_struct.roll = ypr[2];
                imu_out <: ypr_struct;

            } else {
                mpu_resetFifo(imu);     //if a unit quat is not received, assume fifo corruption
                fifocorrupt+=1;
            }
       }
       butP :> but_state;               //check to see if button is pushed to end program, low means pushed
       but_state &=0x1;
       if (but_state==0){
           printf("Exiting...\n");
           GO_FLAG=0;
       }
    }
    mpu_Stop(imu);      //reset hardware gracefully and put into sleep mode
    printf("Fifo Overflows:%d Fifo Corruptions:%d\n",fifooverflowcount,fifocorrupt);
    exit(0);
}

//control motor direction according to duty_cycles
void motor_control(out port oMotorControl, motor_cmd_t mc){

        if (mc.left_duty_cycle == 0 && mc.right_duty_cycle == 0){
            oMotorControl <: STOP;
        }
        else if (mc.left_duty_cycle > 0){
            if (mc.right_duty_cycle > 0){
                oMotorControl <: (BIN1_ON ^ AIN1_ON);
            }
            else{
                oMotorControl <: (BIN1_ON ^ AIN2_ON);
            }

        }
        else{
            if (mc.right_duty_cycle > 0){
                oMotorControl <: (BIN2_ON ^ AIN1_ON);
            }
            else{
                oMotorControl <: (BIN2_ON ^ AIN2_ON);
            }
        }
}

//controls motor based on messages sent along channel
void multi_motor_task(out port oMotorPWMA, out port oMotorPWMB, out port oMotorControl, chanend motor_chan){

    timer tmr, tmrPWMA, tmrPWMB;
    unsigned int left_duty_ticks = 0, right_duty_ticks = 0;
    motor_cmd_t mc;
    unsigned int time = 0, timePWMA, timePWMB = 0;

    //sample timers
    tmrPWMA :> timePWMA;
    tmrPWMB :> timePWMB;
    tmr :> time;

    while(1){
        //send pulse high
        oMotorPWMA <: 1;
        oMotorPWMB <: 1;
        select {
            case motor_chan :> mc:

                //send heading to motor control
                motor_control(oMotorControl, mc);

                //convert duty_cycle percentage to timer ticks
                left_duty_ticks = convert_duty_cycle(PWM_FRAME_TICKS, mc.left_duty_cycle);
                right_duty_ticks = convert_duty_cycle(PWM_FRAME_TICKS, mc.right_duty_cycle);
                continue;

            case tmrPWMA when timerafter(timePWMA + left_duty_ticks) :> void:
                oMotorPWMA <: 0;
                left_duty_ticks += (PWM_FRAME_TICKS + 1);
                continue;
            case tmrPWMB when timerafter(timePWMB + right_duty_ticks) :> void:
                oMotorPWMB <: 0;
                right_duty_ticks += (PWM_FRAME_TICKS + 1);
                continue;
            case tmr when timerafter(time + PWM_FRAME_TICKS) :> void: //delays until end of frame
                //update timers
                tmrPWMA :> timePWMA;
                tmrPWMB :> timePWMB;
                tmr :> time;
                break;
        }
    }
}

//Reads Motor Signal and Lights LEDs based on activity -> oLed1 for oMotorPWMA, oLed2 for oMotorPWMB
void encoder_task(in port iEncoder, out port oLed1, out port oLed2, chanend encoder_chan){

    unsigned int prev_pinseq = 0, curr_pinseq = 0;
    iEncoder :> prev_pinseq;

    while(1){

        iEncoder when pinsneq(prev_pinseq) :> curr_pinseq; //detect change in motor heading

        if ((curr_pinseq & SIG1) == SIG1){ //oMotorPWMA is active high
            oLed1 <: 1;
            encoder_chan <: 1;
        }
        else{
            oLed1 <: 0;
            encoder_chan <: 1;
        }
        if ((curr_pinseq & SIG2) == SIG2){ //oMotorPWMB is active high
            oLed2 <: 1;
            encoder_chan <: 2;
        }
        else{
            oLed2 <: 0;
            encoder_chan <: 2;
        }
        prev_pinseq = curr_pinseq;
    }
}

//Helper Function - Converts duty_cycle Percentage to Timer Ticks Given the Frame Width
unsigned int convert_duty_cycle(unsigned int frame_ticks, int duty_cycle){

    if (duty_cycle < 0){
        duty_cycle *= -1;
    }
    return (frame_ticks * duty_cycle)/100;
}

//Sends Message Across UART Channel with Delay
void line(const char buffer[]){

    timer tmr;
    unsigned int t;
    tmr :> t;
    t += XS1_TIMER_HZ/4;
    tmr when timerafter(t) :> void;

   //format output message to append CRLF for Lua interp
    char message[BUFFER] = "";
    strcpy(message, buffer);
    strcat(message, CRLF);

   //transmit message
   uart_transmit_bytes(oWiFiRX, message, BAUDRATE);
}

//Monitors Channel
void output_task(chanend message_chan){
    message_t received;
    while(1){
        message_chan :> received;
        if (strcmp(received.data, SEND_WIFI_SETUP_MESSAGE) == 0){
            run_wifi_setup();
        }
        else{
            line(received.data);
        }
    }
}


//Receives Messages From command_chan and Monitor imu_chan and enconder_chan
void uart_to_console_task(chanend message_chan, chanend motor_chan, chanend encoder_chan, chanend imu_chan, chanend command_chan){
    unsigned int left_wheel_ticks = 0, right_wheel_ticks = 0, encoder_value = 0, turning = 0, driving = 0;
    char command = 0;
    message_t message;
    motor_cmd_t motor_cmd;
    ypr_t current_ypr;
    float target_yaw_turn = 0, set_point_drive = 0;

    //Setup WiFi
    strcpy(message.data, SEND_WIFI_SETUP_MESSAGE);
    message_chan <: message;

    while(1){
        [[ordered]]
        select {

        case command_chan :> command:

        //Forward 100% Duty Cycle
          if (command == 'F') {
              turning = 0;
              driving = 1;
              set_point_drive = current_ypr.yaw;
              motor_cmd.left_duty_cycle = FULL_DUTY_CYCLE_LEFT;
              motor_cmd.right_duty_cycle = FULL_DUTY_CYCLE_RIGHT;
              motor_chan <: motor_cmd;
              strcpy(message.data, "OK: Forward Full");
              message_chan <: message;
          }

        //Stop Robot
        else if(command == 'x'){
          turning = 0;
          driving = 0;
          motor_cmd.left_duty_cycle = 0;
          motor_cmd.right_duty_cycle = 0;
          motor_chan <: motor_cmd;
          strcpy(message.data, "OK: Stop Robot");
          message_chan <: message;
          }

          //Turn 90 Degrees Left
         else if (command  == ','){
             float starting_yaw = current_ypr.yaw;
             turning = 1;
             driving = 0;

             //wrap around if necessary
             if (starting_yaw - RAD_90_DEGREES < -M_PI){
                target_yaw_turn = M_PI - (RAD_90_DEGREES - (M_PI + starting_yaw)); //Loop to 2pi (360 degrees), subtracting remainder
             }
             else{
                 target_yaw_turn = starting_yaw - RAD_90_DEGREES; //just subtract pi/2 (90 degrees)
             }

             //slow turns for saftey
             motor_cmd.left_duty_cycle = FULL_DUTY_CYCLE_LEFT/5;
             motor_cmd.right_duty_cycle = -FULL_DUTY_CYCLE_RIGHT/5;
             motor_chan <: motor_cmd;
             strcpy(message.data, "OK: Turn Left 90 Degrees");
             message_chan <: message;
         }

         //Turn 90 Degrees Right
         else if (command == '.'){
            turning = 1;
            driving = 0;
            float starting_yaw = current_ypr.yaw;

            //wrap around if necessary
            if (starting_yaw + RAD_90_DEGREES > M_PI){
                target_yaw_turn = -M_PI + (RAD_90_DEGREES - (M_PI - starting_yaw)); //Loop to -2pi (-360 degrees), adding remainder
            }
            else{
                target_yaw_turn = starting_yaw + RAD_90_DEGREES; //just add pi/2 (90 degrees)
            }

            //slow turns for saftey
            motor_cmd.left_duty_cycle = -FULL_DUTY_CYCLE_LEFT/5;
            motor_cmd.right_duty_cycle = FULL_DUTY_CYCLE_RIGHT/5;
            motor_chan <: motor_cmd;
            strcpy(message.data, "OK: Turn Right 90 Degrees");
            message_chan <: message;
        }

        //printcharln(command);
        break;

            //Monitor Imu
           case imu_chan :> current_ypr:

               //stop vehicle if finished turning 90 Degrees
               if (turning){

                   int stop_turning = 0; //bool

                   float min = target_yaw_turn - ERROR_MARGIN_TURNS;
                   float max = target_yaw_turn + ERROR_MARGIN_TURNS;

                   //Check wrap around cases
                   if (max > M_PI){
                       max = -M_PI + (RAD_90_DEGREES - (M_PI - max));
                       if (current_ypr.yaw <= M_PI && current_ypr.yaw >= min){ //current yaw is between min & M_PI
                           stop_turning = 1;
                       }
                       else if (current_ypr.yaw <= max){
                           stop_turning = 1;
                       }
                       else{
                           stop_turning = 0;
                       }
                   }
                   else if (min < -M_PI){
                       min = M_PI - (RAD_90_DEGREES - (M_PI + min));
                       if (current_ypr.yaw >= -M_PI && current_ypr.yaw <= max){
                           stop_turning = 1;
                       }
                       else if (current_ypr.yaw >= min){
                           stop_turning = 1;
                       }
                       else {
                           stop_turning = 0;
                       }
                   }
                   else{
                       if(current_ypr.yaw <= max && current_ypr.yaw >= min){ //default, no wrap around
                           stop_turning = 1;
                       }
                  }

                   if(stop_turning){
                       motor_cmd.left_duty_cycle = 0;
                       motor_cmd.right_duty_cycle = 0;
                       turning = 0;
                       motor_chan <: motor_cmd; //stop immediately
                   }
               }

                //if driving, monitor heading and make adjustments if off
                 if(driving){
                    message_chan <: message;
                     if (set_point_drive > fabs(current_ypr.yaw)){
                        float difference = fabs(set_point_drive - current_ypr.yaw);
                         motor_cmd.right_duty_cycle += (difference * WHEEL_ADJUST_RATE);
                         message_chan <: message;
                    }
                     else if (set_point_drive < fabs(current_ypr.yaw)){
                         float difference = fabs(set_point_drive - current_ypr.yaw);
                         motor_cmd.left_duty_cycle += (difference * WHEEL_ADJUST_RATE);
                         message_chan <: message;
                     }
                     motor_chan <: motor_cmd; //adjust heading immediately
                 }
               break;

            case encoder_chan :> encoder_value:
                if(encoder_value == 1) {
                    left_wheel_ticks++;
                } else {
                    right_wheel_ticks++;
                }
                continue;

        }
    }
}


//Sends Code to Setup WiFi
void run_wifi_setup() {
    line("wifi.setmode(wifi.SOFTAP)");
    line("cfg={}");
    line("cfg.ssid=\"MiniUGAPS\"");
    line("cfg.pwd=\"password123\"");
    line("cfg.ip=\"192.168.0.1\"");
    line("cfg.netmask=\"255.255.255.0\"");
    line("cfg.gateway=\"192.168.0.1\"");
    line("port = 9875");
    line("wifi.ap.setip(cfg)");
    line("wifi.ap.config(cfg)");
    line("tmr.alarm(0,400,0,function() -- run after a delay");
    line("srv=net.createServer(net.TCP, 28800) ");
    line("srv:listen(port,function(conn)");
    line("uart.on(\"data\", 0, function(data)");
    line("conn:send(data)");
    line("end, 0)");
    line("conn:on(\"receive\",function(conn,payload) ");
    line("uart.write(0, payload)");
    line("end)");
    line("conn:on(\"disconnection\",function(c) ");
    line("uart.on(\"data\")");
    line("end)");
    line("end)");
    line("end)");
}

//Read One Byte
char uart_receive_byte(in port iPort, unsigned int baud_rate){

    timer tmr;
    unsigned int time;
    unsigned int bitwidth = XS1_TIMER_HZ / baud_rate;

    iPort when pinseq(0) :> void; //wait for signal low

    tmr :> time;
    time += bitwidth/2; //middle of signal
    tmr when timerafter(time) :> void;

    //receive byte
    char letter = 0;
    for (int j = 0; j < 8; j++){
        time += bitwidth;
        tmr when timerafter(time) :> void;
        iPort :> >> letter;
    }

    //sync stop bit, return received letter
    time += bitwidth;
    tmr when timerafter(time) :> void;
    iPort :> void;
    return letter;
}

//Send One Byte
void uart_transmit_byte(out port oPort, char value, unsigned int baud_rate){

    timer tmr;
    unsigned int t, j;
    const unsigned int bit_time = XS1_TIMER_HZ / baud_rate;
    unsigned int byte = value;

    tmr :> t;

    oPort <: 0;
    t += bit_time;
    tmr when timerafter(t) :> void;

    for (j = 0; j < 8; j++){
        oPort <: (byte & 0x1);
        byte >>= 1;
        t += bit_time;
        tmr when timerafter(t) :> void;
    }

    oPort <: 1;
    t += bit_time;
    tmr when timerafter(t) :> void;
}

//Send Bytes of Data
void uart_transmit_bytes(out port oPort, const char values[], unsigned int baud_rate){
    char letter = 0;
    int index = 0;

    while(values[index] != '\0'){
        letter = values[index];
        uart_transmit_byte(oPort, letter, baud_rate);
        index++;
    }
}
