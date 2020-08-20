#pragma once

#include <cpu.h>

// System clock frequency in Hz
#define SYSTEM_FREQUENCY 50000000

// GPIO configuration
#define GPIO_BASE        0x00008100

// UART configuration
#define UART_BASE        0x00008200
#define UART_INTR        IP2_INTR
#define UART_Handler     IP2_Handler

// Timer configuration
#define TIMER_BASE       0x00008300
#define TIMER_INTR       IP3_INTR
#define Timer_Handler    IP3_Handler
#define Timer_us         250

// Display configuration
#define DISPLAY_BASE 0x00010000
#define DISPLAY_WIDTH 80
#define DISPLAY_HEIGHT 30
