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
add wave -hexadecimal /dma_kanal_tb/DUT/Sou_ADR
add wave -hexadecimal /dma_kanal_tb/DUT/Des_ADR
add wave -unsigned /dma_kanal_tb/DUT/Tra_Anzahl
add wave -unsigned /dma_kanal_tb/DUT/BetriebsMod
add wave /dma_kanal_tb/DUT/Tra_Modus
add wave /dma_kanal_tb/DUT/Ex_EreigEn 
add wave /dma_kanal_tb/DUT/Tra_Fertig
add wave /dma_kanal_tb/DUT/S_Ready
add wave /dma_kanal_tb/DUT/M_Valid
add wave /dma_kanal_tb/DUT/Kanal_Aktiv


add wave -divider "Wishbone Bus"
add wave 			  /dma_kanal_tb/DUT/M_STB
add wave 			  /dma_kanal_tb/DUT/M_WE
add wave -hexadecimal /dma_kanal_tb/DUT/M_ADR
add wave -unsigned 	  /dma_kanal_tb/DUT/M_SEL
add wave -hexadecimal /dma_kanal_tb/DUT/M_DAT_O
add wave 			  /dma_kanal_tb/DUT/M_ACK
add wave -hexadecimal /dma_kanal_tb/DUT/M_DAT_I


add wave -divider "Steuerwerk"
add wave 			  /dma_kanal_tb/DUT/Steuerwerk/Zustand
add wave 			  /dma_kanal_tb/DUT/SourceEn
add wave 			  /dma_kanal_tb/DUT/SourceLd
add wave 			  /dma_kanal_tb/DUT/DestEn
add wave 			  /dma_kanal_tb/DUT/DestLd
add wave 			  /dma_kanal_tb/DUT/CntEn
add wave 			  /dma_kanal_tb/DUT/CntLd
add wave 			  /dma_kanal_tb/DUT/DataEn
add wave 			  /dma_kanal_tb/DUT/CntTC

run 150 us
wave zoom full