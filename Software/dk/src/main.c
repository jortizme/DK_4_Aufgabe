#include <gpio.h>
#include <uart.h>
#include <cpu.h>
#include <config.h>
#include <stdio.h>

int main()
{
	UART_Init(UART_BASE, 115200, 8, PARITY_NONE, STOPPBITS_10);

	// TODO: Richtungsregister der GPIO-Komponente konfigurieren

	while(1) {
		int32_t c = inbyte();
		if(-1 != c) {
			if('a' == c)
				c = 'A';
			outbyte(c);
		}

		// TODO: Taster einlesen und gelesenen Wert auf LEDs ausgeben
	}
	return 0;
}

