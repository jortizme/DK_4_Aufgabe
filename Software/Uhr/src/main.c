#include <gpio.h>
#include <uart.h>
#include <timer.h>
#include <cpu.h>
#include <config.h>
#include <stdio.h>
#include <systick.h>
// TODO: (Aufgabe 4) Header-Datei fuer Display-Ansteuerung inkludieren

volatile uint32_t us; // us-Zaehler

// Clock command variables:
int inc_sec = 0; // set clock: increment seconds
int inc_min = 0; // set clock: increment minutes
int inc_hr = 0;  // set clock: increment hours

// Clock variables:
int hsec = 0; // halfsecond counter
int sec = 0;  // second counter
int min = 0;  // minute counter
int hr = 0;   // hour counter

// Deklaration der Funktionen
void Timer_Init(void);
void Timer_Handler(void);
void increment_clock(long p);
void show_clock(long p);
void check_buttons(long p);
void check_inbyte(long p);
int main();

// Prozesse definieren
SYSTICK_LIST increment_clock_entry = { .fkt = increment_clock, .argument = 0,
		.period = 500000, .mode = SYSTICK_MODE_PERIODIC };
SYSTICK_LIST check_buttons_entry = { .fkt = check_buttons, .argument = 0,
		.period = 100000, .mode = SYSTICK_MODE_PERIODIC };
SYSTICK_LIST show_clock_entry = { .fkt = show_clock, .argument = 0, .period = 0,
		.mode = SYSTICK_MODE_ONCE };
SYSTICK_LIST check_inbyte_entry = { .fkt = check_inbyte, .argument = 0,
		.period = 80, .mode = SYSTICK_MODE_PERIODIC };

void Timer_Init(void) {
	// TODO: Code der Funktion einfuegen
}

void Timer_Handler(void) {
	// TODO: Code der Funktion einfuegen
}

void check_buttons(long p) {
	// TODO: Code der Funktion einfuegen
}

#define BUFFER_SIZE 40

void show_clock(long p) {
	// TODO: Code der Funktion einfuegen

}

void increment_clock(long arg) {
	// TODO: Code der Funktion einfuegen
}

void check_inbyte(long p) {
	// TODO: Code der Funktion einfuegen
}

int main() {
	// TODO: (Aufgabe 4) Display initialisieren und loeschen

	// TODO: Code der Funktion einfuegen
}
