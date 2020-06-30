vlib work
vlib riviera

vlib riviera/xil_defaultlib
vlib riviera/xpm

vmap xil_defaultlib riviera/xil_defaultlib
vmap xpm riviera/xpm

vlog -work xil_defaultlib  -sv2k12 "+incdir+../../../../synthese.srcs/sources_1/bd/design_1/ipshared/4868" "+incdir+../../../../synthese.srcs/sources_1/bd/design_1/ipshared/4868" \
"C:/Tools/Vivado/2017.4/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \

vcom -work xpm -93 \
"C:/Tools/Vivado/2017.4/data/ip/xpm/xpm_VCOMP.vhd" \

vcom -work xil_defaultlib -93 \
"../../../bd/design_1/ip/design_1_Beispielrechner_System_0_0/sim/design_1_Beispielrechner_System_0_0.vhd" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../../synthese.srcs/sources_1/bd/design_1/ipshared/4868" "+incdir+../../../../synthese.srcs/sources_1/bd/design_1/ipshared/4868" \
"../../../bd/design_1/ip/design_1_clk_wiz_0_0/design_1_clk_wiz_0_0_clk_wiz.v" \
"../../../bd/design_1/ip/design_1_clk_wiz_0_0/design_1_clk_wiz_0_0.v" \
"../../../bd/design_1/sim/design_1.v" \

vlog -work xil_defaultlib \
"glbl.v"

