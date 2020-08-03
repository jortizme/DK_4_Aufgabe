if {![file exists work]} { 
	vlib work 
}

vcom DMA_Kanal.vhd 
vcom txt_util_pack.vhd
vcom DMA_Kanal_tb.vhd 

vsim -t ns -voptargs=+acc work.DMA_Kanal_tb

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

add wave /dma_kanal_tb/Takt
add wave -hexadecimal /dma_kanal_tb/DUT/Source_Addres
add wave -hexadecimal /dma_kanal_tb/DUT/Takt/DUT/Destination_Addres
add wave -unsigned /dma_kanal_tb/DUT/Transfer_Anzahl
add wave -unsigned /dma_kanal_tb/DUT/Betriebsmodus
add wave /dma_kanal_tb/DUT/TransferModus
add wave /dma_kanal_tb/DUT/ExEreignisEn
add wave /dma_kanal_tb/DUT/Transfer_Fertig
add wave /dma_kanal_tb/DUT/S_Ready
add wave /dma_kanal_tb/DUT/M_Valid
add wave /dma_kanal_tb/DUT/Kanal_Aktiv
add wave /dma_kanal_tb/DUT/M_STB
add wave /dma_kanal_tb/DUT/M_WE
add wave -hexadecimal /dma_kanal_tb/DUT/M_ADR
add wave -unsigned /dma_kanal_tb/DUT/M_SEL
add wave -hexadecimal /dma_kanal_tb/DUT/M_DAT_O
add wave -hexacedimal /dma_kanal_tb/DUT/M_DAT_I
add wave /dma_kanal_tb/DUT/M_ACK


add wave -divider "SourceAdrRegister"
add wave /dma_kanal_tb/UUT/ShiftEn
add wave /dma_kanal_tb/UUT/SourceEn
add wave /dma_kanal_tb/UUT/SourceEn


add wave -divider "FF"
add wave /serieller_sender_tb/UUT/ShiftLd
add wave /serieller_sender_tb/UUT/Rechenwerk/ParityBit

add wave -divider "Zaehler Bits und Stoppbits"
add wave /serieller_sender_tb/UUT/CntSel
add wave /serieller_sender_tb/UUT/CntLd
add wave /serieller_sender_tb/UUT/CntEn
add wave /serieller_sender_tb/UUT/CntTc

add wave -divider "Zaehler Bitbreite"
add wave /serieller_sender_tb/UUT/BBSel
add wave /serieller_sender_tb/UUT/BBLd
add wave /serieller_sender_tb/UUT/BBTC

add wave -divider "Ausgangsmultiplexer"
add wave /serieller_sender_tb/UUT/TxDSel

add wave -divider
add wave /serieller_sender_tb/UUT/TxD
add wave /serieller_sender_tb/Start
add wave -hexadecimal /serieller_sender_tb/Data
add wave /serieller_sender_tb/UUT/Steuerwerk/Zustand

run 800 us
wave zoom full