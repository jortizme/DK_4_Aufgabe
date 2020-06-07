@echo off

rem HIER MUSS DER NAME DES COM-PORTS angepasst werden.
set COM_PORT=COM7

rem Baudrate
set BAUDRATE=256000

rem Parity (none|odd|even)
set PARITY=none

rem Stopbits (1|1.5|2)
set STOPBITS=1

rem TCP port for GDB connection
set TCP_PORT=10000

rem Verbosity level (off|err|info|debug)
set VERBOSITY=info

rem workaround for GDB delay slot handling
set WORKAROUND=

bsr2-gdb-server.exe -r -v %VERBOSITY% -t %TCP_PORT% -c %COM_PORT% -b %BAUDRATE% -p %PARITY% -s %STOPBITS% %WORKAROUND%
