#include <cpu.h>

void out32(uint32_t addr, uint32_t data)
{
	*((volatile uint32_t*) addr) = data;
}

uint32_t in32(uint32_t addr)
{
	return *((volatile uint32_t*) addr);
}

void __attribute__ ((weak)) IP0_Handler()
{
	return;
}

void __attribute__ ((weak)) IP2_Handler()
{
	return;
}

void __attribute__ ((weak)) IP3_Handler()
{
	return;
}

void __attribute__ ((weak)) IP4_Handler()
{
	return;
}

void cpu_enable_interrupt(uint32_t mask)
{
	uint32_t val = _mfc0(CP0_STATUS);
	_mtc0(CP0_STATUS, val | mask);
}

void cpu_disable_interrupt(uint32_t mask)
{
	uint32_t val = _mfc0(CP0_STATUS);
	_mtc0(CP0_STATUS, val & ~mask);
}

unsigned _mfc0(CP0_REG_t reg)
{
	uint32_t val = 0;

	switch(reg)
	{
	case CP0_STATUS:
		__asm__("mfc0 %0, $12"
				: "=r" (val)
				: /* no inputs */);
		break;
	case CP0_CAUSE:
		__asm__("mfc0 %0, $13"
				: "=r" (val)
				: /* no inputs */);
		break;
	case CP0_EPC:
		__asm__("mfc0 %0, $14"
				: "=r" (val)
				: /* no inputs */);
		break;
	}

	return val;
}

void _mtc0(CP0_REG_t reg, uint32_t val)
{
	switch(reg)
	{
	case CP0_STATUS:
		__asm__("mtc0 %0, $12"
				: /* no outputs */
				: "r" (val));
		break;
	case CP0_CAUSE:
		__asm__("mtc0 %0, $13"
				: /* no outputs */
				: "r" (val));
		break;
	case CP0_EPC:
		__asm__("mtc0 %0, $14"
				: /* no outputs */
				: "r" (val));
		break;
	}
}
