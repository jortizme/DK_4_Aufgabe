# Benoetigte Dateien uebersetzen
vcom -work work Timer.vhd
vcom -work work wishbone_test_pack.vhd
vcom -work work txt_util_pack.vhd
vcom -work work Timer_tb.vhd

# Simulator starten
vsim -voptargs=+acc Timer_tb

# Breite der Namensspalte
configure wave -namecolwidth 128
# Breite der Wertespalte
configure wave -valuecolwidth 128
# Angezeigte Pfadelemente
configure wave -signalnamewidth 1
# sim: nicht anzeigen
configure wave -datasetprefix 0
# Einheit der Zeitachse
configure wave -timelineunits ns

add wave              sim:/Timer_tb/clk
add wave              sim:/Timer_tb/rst

add wave -divider "Bussignale"
add wave              sim:/Timer_tb/Sys_STB
add wave              sim:/Timer_tb/Sys_WE
add wave -hexadecimal sim:/Timer_tb/Sys_ADR
add wave -unsigned    sim:/Timer_tb/Sys_DAT
add wave              sim:/Timer_tb/Timer_ACK
add wave -unsigned    sim:/Timer_tb/Timer_DAT
add wave              sim:/Timer_tb/Timer_IRQ

add wave -divider "Interne Signale"
add wave -unsigned    sim:/Timer_tb/uut/Schreibe_Value
add wave -unsigned    sim:/Timer_tb/uut/Timer_Value
add wave -unsigned    sim:/Timer_tb/uut/Schreibe_Start
add wave -unsigned    sim:/Timer_tb/uut/Timer_Start
add wave -unsigned    sim:/Timer_tb/uut/TC
add wave -unsigned    sim:/Timer_tb/uut/Lese_Status
add wave -unsigned    sim:/Timer_tb/uut/Timer_Status

run 1500 ns
wave zoom full