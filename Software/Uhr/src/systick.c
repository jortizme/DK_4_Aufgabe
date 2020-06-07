// -------------------------------------------------------------
// SYSTICK functions
// (c) Bernhard Lang, HS Osnabrueck
// -------------------------------------------------------------
#include "systick.h"

// -------------------------------------------------------------
// 64 Bit counter for systick microseconds since startup
// (wraps after 584942.417 years
// -------------------------------------------------------------
volatile unsigned long microseconds[2];

// -------------------------------------------------------------
// Head of the list
// -------------------------------------------------------------
volatile SYSTICK_LIST* systick_list = 0;

// -------------------------------------------------------------
// Initialize a systick function list entry
// -------------------------------------------------------------
void systick_init_list_entry(
	SYSTICK_LIST* new_entry, // list entry
	SYSTICK_FUNCTION fkt,    // systick function pointer
	long argument,           // argument value for systick function
	long period,             // period in us before systick function call
	long mode                // systick function mode: once or periodically
)
{
	new_entry->fkt      = fkt;
	new_entry->argument = argument;
	new_entry->period   = period;
	new_entry->mode     = mode;
}

// -------------------------------------------------------------
// Install a systick function into the list
// -------------------------------------------------------------
void systick_install_function(SYSTICK_LIST* new_entry)
{
	volatile SYSTICK_LIST*volatile* help;
	for (help = &systick_list; *help != 0; help = &((*help)->next) ) {
		if (*help == new_entry) {
			break; // function already installed
		}
	}
	if (*help == 0) {
		new_entry->next       = 0;                 // new end of list
		new_entry->period_cnt = new_entry->period; // set call period
		*help                 = new_entry;         // link behind last element
	}
	return;
}

// -------------------------------------------------------------
// Remove a systick function from the list
// -------------------------------------------------------------
int systick_remove_function(SYSTICK_LIST* existing_entry)
{
	SYSTICK_LIST*volatile* help;
	int removed = 0;
	for ( help = &systick_list; *help != 0; help = &((*help)->next) ) {
		if (*help == existing_entry) { // found entry
			*help = (*help)->next; // remove entry
			removed = 1;
			break;
		}
	}
	return removed;
}

// -----------------------------------------------------------------------------
// SYSTICK call
//   Argument us tells how many microseconds have been elapsed since last call
// -----------------------------------------------------------------------------
void systick_call(unsigned long us)
{
	SYSTICK_LIST*volatile* cur;
	microseconds[0] += us;
	if (++microseconds[0] < us) {
		++microseconds[1];    // increment 64 Bit microseconds
	}
	for ( cur = &systick_list; *cur != 0; cur = ((*cur) == 0 ? cur : & ((*cur)->next)) ) {
		(*cur)->period_cnt = (*cur)->period_cnt - us;
		if ((*cur)->period_cnt <= 0) { // entry is active
			(*cur)->fkt((*cur)->argument); // call systick function
			switch((*cur)->mode) {
				case SYSTICK_MODE_ONCE: // remove entry
					*cur = (*cur)->next;
					break;
				case SYSTICK_MODE_PERIODIC: // reload entry counter
					(*cur)->period_cnt += (*cur)->period;
					break;
			}
		}
	}
	return;
}

// -------------------------------------------------------------
// function for busy waiting. It polls the microseconds counter
// until a delay specified in microseconds has elapsed.
// -------------------------------------------------------------
void poll_us_delay(unsigned long us_delay)
{
	if (us_delay == 0) {
		return;
	}
	unsigned long stop = microseconds[0] + us_delay;
	while (microseconds[0] != stop) {}
	return;
}

#if 0
//-----------------------------------------------------------------
// Test environement for systick functions with interrupt simulation
// May be used on desktop systems during debugging
//-----------------------------------------------------------------

#include <stdio.h>
void fkt_i(long l)
{
	printf("Tick\n");
	return;
}
void fkt_a(long l)
{
	printf("Function a %li\n", l);
	return;
}
void fkt_b(long l)
{
	printf("Function b %li\n", l);
	return;
}

int main()
{
	static SYSTICK_LIST function_i;
	static SYSTICK_LIST function_a;
	static SYSTICK_LIST function_b;
	int i;

	systick_init_list_entry(&function_i, fkt_i, 0, 1000, SYSTICK_MODE_PERIODIC);
	systick_install_function(&function_i);

	for (i = 0; i < 40; i++) {
		systick_call(500);
	}

	systick_init_list_entry(&function_a, fkt_a, 1, 8000, SYSTICK_MODE_PERIODIC);
	systick_install_function(&function_a);

	for (i = 0; i < 40; i++) {
		systick_call(500);
	}

	systick_init_list_entry(&function_b, fkt_b, 2, 5000, SYSTICK_MODE_ONCE);
	systick_install_function(&function_b);

	for (i = 0; i < 40; i++) {
		systick_call(500);
	}

	systick_remove_function(&function_a);

	for (i = 0; i < 40; i++) {
		systick_call(500);
	}
	systick_install_function(&function_b);
	for (i = 0; i < 40; i++) {
		systick_call(500);
	}
	systick_install_function(&function_b);
	for (i = 0; i < 40; i++) {
		systick_call(500);
	}

	return 0;
}

#endif
