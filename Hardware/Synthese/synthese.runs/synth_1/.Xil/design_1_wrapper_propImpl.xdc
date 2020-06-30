set_property SRC_FILE_INFO {cfile:c:/DK_Praktikum/Hardware/Synthese/synthese.srcs/sources_1/bd/design_1/ip/design_1_clk_wiz_0_0/design_1_clk_wiz_0_0.xdc rfile:../../../synthese.srcs/sources_1/bd/design_1/ip/design_1_clk_wiz_0_0/design_1_clk_wiz_0_0.xdc id:1 order:EARLY scoped_inst:design_1_i/clk_wiz_0/inst} [current_design]
set_property SRC_FILE_INFO {cfile:C:/DK_Praktikum/Hardware/Beispielrechner_System.xdc rfile:../../../../Beispielrechner_System.xdc id:2} [current_design]
set_property src_info {type:SCOPED_XDC file:1 line:57 export:INPUT save:INPUT read:READ} [current_design]
set_input_jitter [get_clocks -of_objects [get_ports clk_in1]] 0.83333
set_property src_info {type:XDC file:2 line:1 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN L17 IOSTANDARD LVCMOS33 } [get_ports { clk_in1_0 }];
set_property src_info {type:XDC file:2 line:5 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports { SDI_TXD_0 }];
set_property src_info {type:XDC file:2 line:6 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports { SDI_RXD_0 }];
set_property src_info {type:XDC file:2 line:9 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN R3  IOSTANDARD LVCMOS33 } [get_ports { GPIO_0[0] }];
set_property src_info {type:XDC file:2 line:10 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN T3  IOSTANDARD LVCMOS33 } [get_ports { GPIO_0[1] }];
set_property src_info {type:XDC file:2 line:11 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN R2  IOSTANDARD LVCMOS33 } [get_ports { GPIO_0[2] }];
set_property src_info {type:XDC file:2 line:12 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN T1  IOSTANDARD LVCMOS33 } [get_ports { GPIO_0[3] }];
set_property src_info {type:XDC file:2 line:15 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN W5  IOSTANDARD LVCMOS33 } [get_ports { GPIO_0[4] }];
set_property src_info {type:XDC file:2 line:16 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN V4  IOSTANDARD LVCMOS33 } [get_ports { GPIO_0[5] }];
set_property src_info {type:XDC file:2 line:17 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN U4  IOSTANDARD LVCMOS33 } [get_ports { GPIO_0[6] }];
set_property src_info {type:XDC file:2 line:18 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN V5  IOSTANDARD LVCMOS33 } [get_ports { GPIO_0[7] }];
set_property src_info {type:XDC file:2 line:21 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN L3  IOSTANDARD LVCMOS33 } [get_ports { RXD_0 }];
set_property src_info {type:XDC file:2 line:22 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN M3  IOSTANDARD LVCMOS33 } [get_ports { TXD_0 }];
set_property src_info {type:XDC file:2 line:25 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict {PACKAGE_PIN U3 IOSTANDARD LVCMOS33} [get_ports {BLUE_0 }];
set_property src_info {type:XDC file:2 line:26 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict {PACKAGE_PIN U7 IOSTANDARD LVCMOS33} [get_ports {GREEN_0}];
set_property src_info {type:XDC file:2 line:27 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict {PACKAGE_PIN W7 IOSTANDARD LVCMOS33} [get_ports {RED_0 }];
set_property src_info {type:XDC file:2 line:28 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict {PACKAGE_PIN U8 IOSTANDARD LVCMOS33} [get_ports {VSYNC_0}];
set_property src_info {type:XDC file:2 line:29 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict {PACKAGE_PIN V8 IOSTANDARD LVCMOS33} [get_ports {HSYNC_0}];
