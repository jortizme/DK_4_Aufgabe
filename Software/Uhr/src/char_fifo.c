// ---------------------------------------------------------------------
// CHAR_FIFO
//   A thread safe character fifo.
//   May be used for communication between preemptive concurrent
//    processes (e.g. user program and interrupt handler)
// (c) Bernhard Lang, FH Osnabrueck
// ---------------------------------------------------------------------
#include "char_fifo.h"

//
// initialize a CHAR_FIFO
//
void char_fifo_init(char_fifo_t* fifo, char* buffer, unsigned size)
{
	fifo->read_counter  = 0;
	fifo->write_counter = 0;
	fifo->size          = size;
	fifo->buffer        = buffer;
}

//
// push a value into the CHAR_FIFO
//
int char_fifo_push(char_fifo_t* fifo, int ch)
{
	int D1 = fifo->read_counter - fifo->write_counter - 1;
	if  (D1 < 0) {
		D1 += fifo->size;
	}
	if (D1 > 0) {
		fifo->buffer[fifo->write_counter] = ch;
		fifo->write_counter++;
		if (fifo->write_counter >= fifo->size) {
			fifo->write_counter -= fifo->size;
		}
		return D1 - 1; // return number of free character slots in fifo
	} else {
		return -1;
	}
}

//
// pop a value from the CHAR_FIFO
//
int  char_fifo_pop(char_fifo_t* fifo, char* pval)
{
	int D2 = (fifo->write_counter - fifo->read_counter);
	if  (D2 < 0) {
		D2 += fifo->size;
	}
	if (D2 > 0) {
		*pval = fifo->buffer[fifo->read_counter];
		fifo->read_counter++;
		if (fifo->read_counter >= fifo->size) {
			fifo->read_counter -= fifo->size;
		}
		return D2 - 1; // return number of available characters in fifo
	} else {
		return -1;
	}
}

#if 0
//
// Testprogram for CHAR_FIFO use
//
#include <stdio.h>

int main()
{
	// Define fifo data structures
	char buffer[10];
	CHAR_FIFO my_fifo;

	// initialize fifo
	char_fifo_init(&my_fifo, buffer, sizeof(buffer));

	// fill up fifo
	{
		int i;
		for(i = 0; i < sizeof(buffer) - 1; i++) {
			if (-1 == char_fifo_push(&my_fifo, i)) {
				printf("Error during char_fifo_push(my_fifo,%i)\n", i);
			}
		}
		if (-1 != char_fifo_push(&my_fifo, i)) {
			printf("Error during char_fifo_push(my_fifo,%i)\n", 10);
		}
	}

	// drain fifo
	{
		int i;
		int val;
		for(i = 0; i < sizeof(buffer) - 1; i++) {
			if (i != (val = char_fifo_pop(&my_fifo)) ) {
				printf("Error: char_fifo_pop(my_fifo) returns %i instead of %i\n", val, i);
			}
		}
		if (-1 != (val = char_fifo_pop(&my_fifo)) ) {
			printf("Error: char_fifo_pop(my_fifo) returns %i instead of %i\n", val, -1);
		}
	}

	{
		int val;
		if (-1 != char_fifo_push(&my_fifo, 1)) {
			printf("Error during char_fifo_push(my_fifo,%i)\n", 1);
		}
		if (-1 != char_fifo_push(&my_fifo, 2)) {
			printf("Error during char_fifo_push(my_fifo,%i)\n", 2);
		}
		if (-1 != char_fifo_push(&my_fifo, 3)) {
			printf("Error during char_fifo_push(my_fifo,%i)\n", 3);
		}
		if (1 != (val = char_fifo_pop(&my_fifo)) ) {
			printf("Error: char_fifo_pop(my_fifo) returns %i instead of %i\n", val, 1);
		}
		if (2 != (val = char_fifo_pop(&my_fifo)) ) {
			printf("Error: char_fifo_pop(my_fifo) returns %i instead of %i\n", val, 2);
		}
		if (3 != (val = char_fifo_pop(&my_fifo)) ) {
			printf("Error: char_fifo_pop(my_fifo) returns %i instead of %i\n", val, 3);
		}
	}

	return 0;
}

#endif
