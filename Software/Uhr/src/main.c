#include <gpio.h>
#include <uart.h>
#include <timer.h>
#include <cpu.h>
#include <config.h>
#include <stdio.h>
#include <systick.h>
#include <display.h>
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
		uint32_t t_start = ((double)SYSTEM_FREQUENCY/1E+6)*Timer_us - 0.5; out32(TIMER_BASE+TIMER_START, t_start);
		// Timer-Interrupt im Coprozessor freigeben
		_mtc0(CP0_STATUS, _mfc0(CP0_STATUS) | TIMER_INTR);
		return;
	// TODO: Code der Funktion einfuegen
}

void Timer_Handler(void) {
	in32(TIMER_BASE+TIMER_STATUS); // Interrupt rücksetzen
	us = us + Timer_us;
	// Vergangene Zeit aufsummieren
	return;
	// TODO: Code der Funktion einfuegen
}

void check_buttons(long p) {
	uint32_t gpio_Pins = in32(GPIO_BASE+GPIO_PINS);
	// set clock via push buttons
	if (gpio_Pins & 0x01) { inc_sec = 1; }
	if (gpio_Pins & 0x02) { inc_min = 1; }
	if (gpio_Pins & 0x04) { inc_hr = 1; }
	// TODO: Code der Funktion einfuegen
}

#define BUFFER_SIZE 40

void show_clock(long p) {
	char buffer[BUFFER_SIZE];
	sprintf(buffer, " %02d:%02d:%02d \r", hr, min, sec);
	printf("%s", buffer); // write time to serial port
	display_set_cursor(0, 0);
	display_puts(buffer); // write time to LCD
	// TODO: Code der Funktion einfuegen

}

void increment_clock(long arg) {
	int changed=0;
	if (++hsec == 2) {
	hsec = 0; inc_sec = 0;
	if (++sec == 60) {
	sec = 0; inc_min = 0;
	if (++min == 60) {
	min = 0; inc_hr = 0;
	if (++hr == 24) { hr = 0; }
	}
	}
	changed = 1;
	}
	if (inc_sec==1) { sec = (sec==59 ? 0 : sec+1); changed = 1; }
	if (inc_min==1) { min = (min==59 ? 0 : min+1); changed = 1; }
	if (inc_hr ==1) { hr = (hr ==23 ? 0 : hr +1); changed = 1; }
	inc_sec = 0; inc_min = 0; inc_hr = 0;
	if (changed) { systick_install_function(&show_clock_entry); }
	// TODO: Code der Funktion einfuegen
}

void check_inbyte(long p) {
	int ch;
	if (-1 != (ch = inbyte())) { // test for serial input
	// set clock via terminal input
	if (ch == 's') { inc_sec = 1; }
	else if (ch == 'm') { inc_min = 1; }
	else if (ch == 'h') { inc_hr = 1; }
	}
	// TODO: Code der Funktion einfuegen
}

int main() {
	// TODO: (Aufgabe 4) Display initialisieren und loeschen
	display_init(DISPLAY_BASE, DISPLAY_WIDTH, DISPLAY_HEIGHT);
	display_clear();
	// Hardware Initialisierung
	UART_Init(UART_BASE, 115200, 8, PARITY_NONE, STOPPBITS_10);
	Timer_Init();
	// Prozesse installieren
	systick_install_function(&increment_clock_entry);
	systick_install_function(&show_clock_entry);
	systick_install_function(&check_buttons_entry);
	systick_install_function(&check_inbyte_entry);
	while(1) {
	uint32_t us_l;
	// vergangene Zeit (in ms) seit letztem Aufruf erfragen
	_di(); us_l = us; us = 0; _ei(); // oder: nur Timer-IR sperren
	// Liste durcharbeiten
	// (Parameter: vergangene Zeit seit letztem Aufruf)
	systick_call(us_l);
	}
	// TODO: Code der Funktion einfuegen
}
