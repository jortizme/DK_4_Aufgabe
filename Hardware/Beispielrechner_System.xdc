set_property -dict { PACKAGE_PIN L17 IOSTANDARD LVCMOS33 } [get_ports { clk_in1_0 }];
create_clock -add -name clk_in1 -period 83.33 -waveform {0 41.66} [get_ports { clk_in1_0 }];

# Serial Debug Interface
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports { SDI_TXD_0 }];
set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports { SDI_RXD_0 }];

# BTN
set_property -dict { PACKAGE_PIN R3  IOSTANDARD LVCMOS33 } [get_ports { GPIO_0[0] }];
set_property -dict { PACKAGE_PIN T3  IOSTANDARD LVCMOS33 } [get_ports { GPIO_0[1] }];
set_property -dict { PACKAGE_PIN R2  IOSTANDARD LVCMOS33 } [get_ports { GPIO_0[2] }];
set_property -dict { PACKAGE_PIN T1  IOSTANDARD LVCMOS33 } [get_ports { GPIO_0[3] }];

# LED
set_property -dict { PACKAGE_PIN W5  IOSTANDARD LVCMOS33 } [get_ports { GPIO_0[4] }];
set_property -dict { PACKAGE_PIN V4  IOSTANDARD LVCMOS33 } [get_ports { GPIO_0[5] }];
set_property -dict { PACKAGE_PIN U4  IOSTANDARD LVCMOS33 } [get_ports { GPIO_0[6] }];
set_property -dict { PACKAGE_PIN V5  IOSTANDARD LVCMOS33 } [get_ports { GPIO_0[7] }];

# UART
set_property -dict { PACKAGE_PIN L3  IOSTANDARD LVCMOS33 } [get_ports { RXD_0 }];
set_property -dict { PACKAGE_PIN M3  IOSTANDARD LVCMOS33 } [get_ports { TXD_0 }];

