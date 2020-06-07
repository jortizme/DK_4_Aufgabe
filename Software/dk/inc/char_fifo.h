// ---------------------------------------------------------------------------
// Thread safe char fifo, Header
// (c) Bernhard Lang, FH Osnabrueck
// ---------------------------------------------------------------------------
#ifndef _CHAR_FIFO_H_
#define _CHAR_FIFO_H_

typedef struct {
	volatile int read_counter;
	volatile int write_counter;
	unsigned     size;
	char*        buffer;
} char_fifo_t;

void char_fifo_init(char_fifo_t* fifo, char* buffer, unsigned size);
int  char_fifo_push(char_fifo_t* fifo, int ch);
int  char_fifo_pop (char_fifo_t* fifo, char* pval);

#endif
