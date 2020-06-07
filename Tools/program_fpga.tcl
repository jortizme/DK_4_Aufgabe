set BITFILE [lindex $argv 0]
open_hw
connect_hw_server -url localhost:3121
current_hw_target [get_hw_targets */xilinx_tcf/Digilent/*]
open_hw_target
set_property PROGRAM.FILE "$BITFILE" [lindex [get_hw_devices] 0]
current_hw_device [lindex [get_hw_devices] 0]
program_hw_devices [lindex [get_hw_devices] 0]
close_hw
