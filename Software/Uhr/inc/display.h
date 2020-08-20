#pragma once

#include <stdint.h>
#include <display.h>
void display_init(uint32_t baseaddr, uint32_t width, uint32_t height);
void display_set_cursor(uint32_t x, uint32_t y);
void display_puts(const char * s);
void display_putc(char c);
void display_scroll();
void display_clear();
