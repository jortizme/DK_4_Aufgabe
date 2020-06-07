/*
 * axi_ds_textdisplay.c
 *
 *  Created on: 07.04.2017
 *      Author: hoeckmann
 */

#include <display.h>
#include <cpu.h>

typedef struct {
	uint32_t baseaddr;
	uint32_t cursor;
	uint32_t width;
	uint32_t height;
} display_t;

static display_t private_data;

void display_init(uint32_t baseaddr, uint32_t width, uint32_t height)
{
	private_data.baseaddr = baseaddr;
	private_data.cursor   = 0;
	private_data.width    = width;
	private_data.height   = height;
}

void display_set_cursor(uint32_t x, uint32_t y)
{
    private_data.cursor = y * private_data.width + x;
}

void display_puts(const char* s)
{
    while(*s) {
		display_putc(*s);
		s++;
    }
	display_putc('\n');
}

void display_putc(char c)
{
	if('\n' == c) {
		private_data.cursor = (private_data.cursor + private_data.width) - (private_data.cursor % private_data.width);
	} else if('\r' == c) {
		private_data.cursor = private_data.cursor - (private_data.cursor % private_data.width);
	} else {
	    out32(private_data.baseaddr + private_data.cursor * sizeof(unsigned), c);
	    private_data.cursor++;
	}

	if(private_data.cursor >= private_data.height * private_data.width) {
		display_scroll();
		private_data.cursor -= private_data.width;
	}
}

void display_scroll()
{
    int cur = 0;
	for( /* empty */ ; cur < (private_data.height - 1) * private_data.width; cur++) {
	    uint8_t c = in32(private_data.baseaddr + (cur + private_data.width) * sizeof(unsigned));
	    out32(private_data.baseaddr + cur * sizeof(uint32_t), c);
	}

	for( /* empty */ ; cur < private_data.height * private_data.width; cur++) {
        out32(private_data.baseaddr + cur * sizeof(uint32_t), ' ');
	}
}

void display_clear()
{
	uint32_t *p = (uint32_t*)private_data.baseaddr;
	for(uint32_t i = 0; i < private_data.width * private_data.height; i++)
		*(p + i) = ' ';
}
