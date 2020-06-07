#include <string.h> // size_t, memcpy, memset

/* adresses of data segment (defined in linker script) */
extern char _data_start_rom;
extern char _data_start;
extern char _data_end;
extern char _bss_start;
extern char _bss_end;

int main();

void _premain()
{
	/* move initialized data from ROM to RAM */
	if ((&_data_start) != (&_data_start_rom)) {
		memcpy(&_data_start, &_data_start_rom, &_data_end - &_data_start);
	}

	memset(&_bss_start, 0, &_bss_end - &_bss_start);

	main();
	while(1);
}

