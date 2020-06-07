ROM_BASE = 0x00000000;
RAM_BASE = 0x00004000;
ROM_SIZE = 16K;
RAM_SIZE = 16K;

_sp = RAM_BASE + RAM_SIZE;
_fp = RAM_BASE + RAM_SIZE;
_gp = RAM_BASE;

MEMORY {
	ROM (rx) : ORIGIN = ROM_BASE, LENGTH  = ROM_SIZE,
	RAM (rw) : ORIGIN = RAM_BASE, LENGTH  = RAM_SIZE
}

SECTIONS
{
	/* Read Only (Instructions + Data) */
	.text : {
		*(.boottext)
		*(.text)
		*(.text.*)
		*(.rodata.*)
	} >ROM
  
	/* Initialized Data */
	.data : {
		*(.sdata)
		*(.sdata.*)
		*(.data)
		*(.data.*)
	} >RAM AT >ROM
	
	_data_start     = ADDR(.data);
	_data_start_rom = LOADADDR(.data);
	_data_end       = ADDR(.data) + SIZEOF(.data);
	
	/* Uninitialized Data */
	.bss : {
		*(.bss)
		*(.bss.*)
		*(.sbss)
		*(.sbss.*)
	} >RAM
	
	_bss_start = ADDR(.bss);
	_bss_end   = ADDR(.bss)+SIZEOF(.bss);
}
