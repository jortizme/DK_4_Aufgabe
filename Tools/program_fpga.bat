@echo off

echo Executing %0

rem HIER MUSS DER PFAD ZUR VIVADO-INSTALLATION ANGEPASST WERDEN
set XILINX=D:\Xilinx\Vivado\2017.4

set BITFILE=..\Hardware\Synthese\Synthese.runs\impl_1\design_1_wrapper.bit
set VIVADO=%XILINX%\bin\vivado.bat

echo Using bit file %BITFILE%
echo Calling %VIVADO%...

call %VIVADO% -nojournal -nolog -mode batch -source .\program_fpga.tcl -notrace -tclargs .\%BITFILE%

del webtalk*.jou
del webtalk*.log
rmdir .Xil

echo on

