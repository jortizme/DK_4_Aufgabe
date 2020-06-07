@echo off
SET TEMPLATE=template_bsr2_rom.vhd
SET ADDR_BITS=14
SET PROJECT=%1

if "%PROJECT%"=="" SET PROJECT=dk

SET INFILE=..\Software\%PROJECT%\Debug\%PROJECT%.hex

echo Executing %0
echo Using hex file %INFILE% as input

SET ENTITY=bsr2_rom
SET MEMORY_S=0x00000000
SET MEMORY_E=0x000037ff
SET OUTFILE=..\Hardware\Speicher\%ENTITY%.vhd

echo Writing %OUTFILE%
REM create_template.py %ADDR_BITS% %TEMPLATE%
Create_Blockram.exe -s %MEMORY_S% -e %MEMORY_E% -fi -n %ENTITY% -t %TEMPLATE% %INFILE% %OUTFILE%

SET ENTITY=bsr2_ram
SET MEMORY_S=0x00004000
SET MEMORY_E=0x00007fff
SET OUTFILE=..\Hardware\Speicher\%ENTITY%.vhd

echo Writing %OUTFILE%
REM create_template.py %ADDR_BITS% %TEMPLATE%
Create_Blockram.exe -s %MEMORY_S% -e %MEMORY_E% -fi -n %ENTITY% -t %TEMPLATE% %INFILE% %OUTFILE%
