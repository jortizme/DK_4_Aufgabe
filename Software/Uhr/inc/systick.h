// -------------------------------------------------------------
// Systick functions header
// (c) Bernhard Lang, HS Osnabrueck
// -------------------------------------------------------------
#ifndef _systick_h_
#define _systick_h_

// 64 Bit counter for the systick microseconds
extern volatile unsigned long microseconds[2];

// Systick Function
typedef void (*SYSTICK_FUNCTION)(long);

// Structure of a list element
typedef volatile struct _systick_list {
	volatile struct _systick_list *next;  // Linked list
	SYSTICK_FUNCTION fkt; // pointer to systick function
	long argument;        // argument to systick function
	long period;          // call period of function
	long period_cnt;      // period counter
	long mode;            // mode bits
} SYSTICK_LIST;

// mode values
#define SYSTICK_MODE_PERIODIC 1
#define SYSTICK_MODE_ONCE     2
#define SYSTICK_MODE_INACTIVE 0

// Head of the list
extern volatile SYSTICK_LIST* systick_list;

// list administration
void systick_init_list_entry (SYSTICK_LIST* new_fkt, SYSTICK_FUNCTION fkt, long argument, long period, long mode);
void systick_install_function(SYSTICK_LIST* new_fkt);
int  systick_remove_function (SYSTICK_LIST* existing_fkt);

// function for busy waiting in main-program.
void poll_us_delay(unsigned long us_delay);

// systick handler
void systick_call(unsigned long us);

#endif
