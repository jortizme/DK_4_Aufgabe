# Benoetigte Dateien uebersetzen
vcom -work work Serieller_Sender.vhd
vcom -work work Serieller_Empfaenger.vhd
vcom -work work UART.vhd
vcom -work work wishbone_test_pack.vhd
vcom -work work txt_util_pack.vhd
vcom -work work UART_tb.vhd

# Simulator starten
vsim -voptargs=+acc -t fs work.uart_tb

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

# Signale hinzufuegen
add wave              /UART_tb/CLK
add wave              /UART_tb/Interrupt

add wave -divider "Wishbone Bus"
add wave              /UART_tb/STB
add wave              /UART_tb/WE
add wave -hexadecimal /UART_tb/ADR
add wave -hexadecimal /UART_tb/DAT
add wave              /UART_tb/ACK
add wave -hexadecimal /UART_tb/UART_DAT

add wave -divider "Interne Signale"
add wave              /uart_tb/uut/Schreibe_Kontroll
add wave -unsigned    /uart_tb/uut/BitBreiteM1
add wave -unsigned    /uart_tb/uut/BitsM1
add wave              /uart_tb/uut/Paritaet_ein
add wave              /uart_tb/uut/Paritaet_gerade
add wave              /uart_tb/uut/Stoppbits
add wave              /uart_tb/uut/Rx_IrEn
add wave              /uart_tb/uut/Tx_IrEn
add wave              /uart_tb/uut/Lese_Status
add wave              /uart_tb/uut/Ueberlauf
add wave              /uart_tb/uut/Empfaenger_Valid
add wave              /uart_tb/uut/Empfaenger_Ready
add wave -hexadecimal /uart_tb/uut/Empfaenger_Data
add wave              /uart_tb/uut/Puffer_Valid
add wave              /uart_tb/uut/Puffer_Ready
add wave -hexadecimal /uart_tb/uut/Puffer_Data
add wave              /uart_tb/uut/Schreibe_Daten
add wave              /uart_tb/uut/Sender_Ready

if {0} {
	add wave -divider "Sender"
	add wave /uart_tb/uut/Sender/BitBreiteM1
	add wave /uart_tb/uut/Sender/Bits
	add wave /uart_tb/uut/Sender/Paritaet_ein
	add wave /uart_tb/uut/Sender/Paritaet_gerade
	add wave /uart_tb/uut/Sender/Stoppbits
	add wave /uart_tb/uut/Sender/S_Valid
	add wave /uart_tb/uut/Sender/S_Ready
	add wave /uart_tb/uut/Sender/S_Data
	add wave /uart_tb/uut/Sender/TxD
	add wave /uart_tb/uut/Sender/TxDSel
	add wave /uart_tb/uut/Sender/ShiftEn
	add wave /uart_tb/uut/Sender/ShiftLd
	add wave /uart_tb/uut/Sender/CntSel
	add wave /uart_tb/uut/Sender/CntEn
	add wave /uart_tb/uut/Sender/CntLd
	add wave /uart_tb/uut/Sender/CntTc
	add wave /uart_tb/uut/Sender/BBSel
	add wave /uart_tb/uut/Sender/BBLd
	add wave /uart_tb/uut/Sender/BBTC
	add wave sim:/uart_tb/uut/Sender/Steuerwerk/Zustand
}

if {0} {
	add wave -divider "Empfaenger"
	add wave -unsigned /uart_tb/uut/Empfaenger/BitBreiteM1
	add wave -unsigned /uart_tb/uut/Empfaenger/Bits
	add wave /uart_tb/uut/Empfaenger/Paritaet_ein
	add wave /uart_tb/uut/Empfaenger/Paritaet_gerade
	add wave /uart_tb/uut/Empfaenger/Stoppbits
	add wave -divider
	add wave /uart_tb/uut/Empfaenger/M_Valid
	add wave /uart_tb/uut/Empfaenger/M_Ready
	add wave /uart_tb/uut/Empfaenger/M_Data
	add wave -divider	
	add wave /uart_tb/uut/Empfaenger/RxD
	add wave -divider
	add wave /uart_tb/uut/Empfaenger/DataLd
	add wave /uart_tb/uut/Empfaenger/DataR
	add wave /uart_tb/uut/Empfaenger/CntSel
	add wave /uart_tb/uut/Empfaenger/CntEn
	add wave /uart_tb/uut/Empfaenger/CntLd
	add wave /uart_tb/uut/Empfaenger/CntTc
	add wave /uart_tb/uut/Empfaenger/BBSel
	add wave /uart_tb/uut/Empfaenger/BBLd
	add wave /uart_tb/uut/Empfaenger/BBTC
	add wave /uart_tb/uut/Empfaenger/P_ok
	add wave -divider
	add wave /uart_tb/uut/Empfaenger/Steuerwerk/Zustand
}

# Simulation ausfuehren
run 180 us

# Alles Anzeigen
wave zoom full

