#include <gpio.h>
#include <uart.h>
#include <cpu.h>
#include <config.h>
#include <stdio.h>

int main()
{
	UART_Init(UART_BASE, 115200, 8, PARITY_NONE, STOPPBITS_10);

	out32(GPIO_BASE+GPIO_DIR,0xF0);
	uint32_t input;
	uint32_t output;
	while(1) {

		output = 0;
		int32_t c = inbyte();
		if(-1 != c)
		{
			if('a' == c)
				c = 'A';
			outbyte(c);

		}
		input = in32(GPIO_BASE + GPIO_PINS);
		for (int i =0; i<4;i++)
		{
			if (input & (1<<i))
				output |= (1<<i);
		}

		out32(GPIO_BASE+GPIO_DATA,(output << 4));
	}

	return 0;
}

