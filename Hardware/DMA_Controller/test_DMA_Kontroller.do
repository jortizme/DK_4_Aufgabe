
# Benoetigte Dateien uebersetzen
vcom -work work DMA_Kanal.vhd 
vcom -work work wb_arbiter.vhd
vcom -work work DMA_Kontroller.vhd
vcom -work work wishbone_test_pack.vhd
vcom -work work txt_util_pack.vhd
vcom -work work DMA_Kontroller_tb.vhd

vsim -t ns -voptargs=+acc work.DMA_Kontroller_tb

configure wave -namecolwidth 173
configure wave -valuecolwidth 106
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ms

# Signale hinzufuegen
add wave        /DMA_Kontroller_tb/Takt
add wave        /DMA_Kontroller_tb/RST
add wave        /DMA_Kontroller_tb/Interrupt0
add wave        /DMA_Kontroller_tb/Interrupt1

add wave -divider "Wishbone-Bus-Slave"
add wave              /DMA_Kontroller_tb/S_STB
add wave              /DMA_Kontroller_tb/S_ACK
add wave              /DMA_Kontroller_tb/S_WE
add wave              /DMA_Kontroller_tb/S_SEL
add wave -hexadecimal /DMA_Kontroller_tb/S_ADR
add wave -hexadecimal /DMA_Kontroller_tb/S_DAT_I
add wave -hexadecimal /DMA_Kontroller_tb/S_DAT_O

#add wave -divider "Interne Signale"
#add wave  -hexadecimal  /DMA_Kontroller_tb/DUT/Status
#add wave  -hexadecimal  /DMA_Kontroller_tb/DUT/Kanal1/Rechenwerk/Sour_A_Out
#add wave  -hexadecimal  /DMA_Kontroller_tb/DUT/Kanal1/Rechenwerk/Dest_A_Out
#add wave  -hexadecimal  /DMA_Kontroller_tb/DUT/TRA0_ANZ_STD
#add wave  -hexadecimal  /DMA_Kontroller_tb/DUT/CR0

#add wave -divider "Decoder Enables"
#add wave  /DMA_Kontroller_tb/DUT/EnSAR0
#add wave  /DMA_Kontroller_tb/DUT/EnDEST0
#add wave  /DMA_Kontroller_tb/DUT/EnTRAA0
#add wave  /DMA_Kontroller_tb/DUT/Kanal1/Tra_Anz_W
#add wave  /DMA_Kontroller_tb/DUT/Kanal1/CntLd
#add wave  /DMA_Kontroller_tb/DUT/EnCR0



run 100 us
wave zoom full