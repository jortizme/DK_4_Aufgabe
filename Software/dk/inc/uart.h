#pragma once

// -------------------------------------------------------------------------------------------------
//  Control Register (CR):
//   15..0  : Bitbreite - 1
//   19..16 : Anzahl Datenbits - 1
//   20     : Paritaet ein
//   21     : Paritaet gerade
//   23..22 : Stoppbits
//            00: 1.0 Stoppbits
//            01: 1.5 Stoppbits
//            10: 2.0 Stoppbits
//            11: 2.5 Stoppbits
//   24     : Freigabe fuer Empfangs-Interrupt
//   25     : Freigabe fuer Sende-Interrupt
// -------------------------------------------------------------------------------------------------
//  Status Register (SR):
//   0      : Daten liegen im Empfangspuffer
//   1      : Sendepuffer ist frei
//   2      : Ueberlauf (wird beim Lesen geloescht)
// -------------------------------------------------------------------------------------------------

#include <stdint.h>

#define UART_TDR 0x0
#define UART_RDR 0x4
#define UART_CR  0x8
#define UART_SR  0xC

#define UART_RX_IRQ (1<<24)
#define UART_TX_IRQ (1<<25)

#define RX_BUFFER_SIZE 40
#define TX_BUFFER_SIZE 40

typedef enum {
	PARITY_NONE = 0b00,
	PARITY_ODD  = 0b10,
	PARITY_EVEN = 0b11,
} parity_t;

typedef enum {
	STOPPBITS_10 = 0b00,
	STOPPBITS_15 = 0b01,
	STOPPBITS_20 = 0b10,
	STOPPBITS_25 = 0b11,
} stoppbits_t;

void UART_Init(uint32_t baseaddr, uint32_t baudrate, uint32_t bits, parity_t parity, stoppbits_t stoppbits);

void outbyte(int c);
int inbyte();
