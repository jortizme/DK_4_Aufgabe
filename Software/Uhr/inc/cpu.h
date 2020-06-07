#pragma once

#include <stdint.h>

#define IP0_INTR (1<<8)
#define IP2_INTR (1<<10)
#define IP3_INTR (1<<11)
#define IP4_INTR (1<<12)

typedef enum {
	CP0_STATUS = 12,
	CP0_CAUSE = 13,
	CP0_EPC = 14
} CP0_REG_t;

unsigned _mfc0(CP0_REG_t reg);
void     _mtc0(CP0_REG_t reg, uint32_t val);

unsigned _ei();
unsigned _di();

void     cpu_enable_interrupt(uint32_t mask);
void     cpu_disable_interrupt(uint32_t mask);

void     out32(uint32_t addr, uint32_t data);
uint32_t in32(uint32_t addr);

