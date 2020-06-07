#include <uart.h>
#include <config.h>
#include <cpu.h>

// ---------------------------------------------------------------------------
// Low level interrupt driven IO-functions with fifo buffering
// (c) Bernhard Lang, FH Osnabrueck
// ---------------------------------------------------------------------------

#include "uart.h"
#include "char_fifo.h"

char rx_buffer[RX_BUFFER_SIZE];
char tx_buffer[TX_BUFFER_SIZE];

char_fifo_t tx_fifo;
char_fifo_t rx_fifo;
static unsigned uart_baseaddr;

void UART_Init(uint32_t baseaddr, uint32_t baudrate, uint32_t bits, parity_t parity, stoppbits_t stoppbits)
{
	uart_baseaddr = baseaddr;

	// init rx fifo
	char_fifo_init(&rx_fifo, rx_buffer, sizeof(rx_buffer));

	// init tx fifo
	char_fifo_init(&tx_fifo, tx_buffer, sizeof(tx_buffer));

	out32(uart_baseaddr + UART_CR, UART_RX_IRQ | (stoppbits << 22) | (parity << 20) | ((bits - 1) << 16) | (SYSTEM_FREQUENCY / baudrate - 1));

	// enable interrupt for UART
	cpu_enable_interrupt(UART_INTR);
}

// UART Interrupt Handler
void UART_Handler()
{
	uint32_t status = in32(uart_baseaddr + UART_SR);

	if(status & UART_RX_IRQ) {

		// read Rx data from receiver and push into rx fifo
		// fifo overflow is currently not checked
		char_fifo_push(&rx_fifo, in32(uart_baseaddr + UART_RDR));

	}

	if(status & UART_TX_IRQ) {

		char ch;
		// pop value from tx fifo
		if (char_fifo_pop(&tx_fifo, &ch) < 0) {
			// if no Tx data available disable Tx interrupt
			out32(uart_baseaddr + UART_CR, in32(uart_baseaddr + UART_CR) & ~UART_TX_IRQ);
		} else                               {
			// else write Tx data into transmitter
			out32(uart_baseaddr + UART_TDR, ch);
		}

	}
}

// Low level function to read a byte from console
int inbyte()
{
	char ch;
	// pop from rx_fifo
	if (-1 == char_fifo_pop(&rx_fifo, &ch)) {
		return -1;
	} else                                   {
		return ch;
	}
}

// Low level function to write a byte to console
void outbyte(int c)
{
	while (char_fifo_push(&tx_fifo, c)<0) {} // push to tx_fifo

	//enable_ir(TX_INTR);
	// enable Tx interrupt
	out32(uart_baseaddr + UART_CR, in32(uart_baseaddr + UART_CR) | UART_TX_IRQ);
}
