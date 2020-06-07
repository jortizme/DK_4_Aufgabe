@echo off

rem TCP port for GDB connection
set TCP_PORT=10000

rem Base address of emulated memory (hex)
set MEM_BASE=00000000

rem Size of emulated memory (hex)
set MEM_SIZE=00010000

rem Verbosity level (off|err|info|debug)
set VERBOSITY=info

rem workaround for GDB delay slot handling
set WORKAROUND=

bsr2-gdb-server.exe -e -v %VERBOSITY% -t %TCP_PORT% -m %MEM_BASE% -M %MEM_SIZE% %WORKAROUND%
