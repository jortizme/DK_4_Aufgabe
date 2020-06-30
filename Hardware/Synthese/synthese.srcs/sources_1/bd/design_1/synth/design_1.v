//Copyright 1986-2017 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2017.4 (win64) Build 2086221 Fri Dec 15 20:55:39 MST 2017
//Date        : Fri Jun 12 15:18:11 2020
//Host        : DESKTOP-SKCALQI running 64-bit major release  (build 9200)
//Command     : generate_target design_1.bd
//Design      : design_1
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "design_1,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=design_1,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=2,numReposBlks=2,numNonXlnxBlks=0,numHierBlks=0,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=1,numPkgbdBlks=0,bdsource=USER,synth_mode=Global}" *) (* HW_HANDOFF = "design_1.hwdef" *) 
module design_1
   (BLUE_0,
    GPIO_0,
    GREEN_0,
    HSYNC_0,
    RED_0,
    RXD_0,
    SDI_RXD_0,
    SDI_TXD_0,
    TXD_0,
    VSYNC_0,
    clk_in1_0);
  output BLUE_0;
  inout [7:0]GPIO_0;
  output GREEN_0;
  output HSYNC_0;
  output RED_0;
  input RXD_0;
  input SDI_RXD_0;
  output SDI_TXD_0;
  output TXD_0;
  output VSYNC_0;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.CLK_IN1_0 CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.CLK_IN1_0, CLK_DOMAIN design_1_clk_in1_0, FREQ_HZ 12000000, PHASE 0.000" *) input clk_in1_0;

  wire Beispielrechner_System_0_BLUE;
  wire Beispielrechner_System_0_GREEN;
  wire Beispielrechner_System_0_HSYNC;
  wire Beispielrechner_System_0_RED;
  wire Beispielrechner_System_0_SDI_TXD;
  wire Beispielrechner_System_0_TXD;
  wire Beispielrechner_System_0_VSYNC;
  wire [7:0]Net;
  wire RXD_0_1;
  wire SDI_RXD_0_1;
  wire clk_in1_0_1;
  wire clk_wiz_0_clk_out1;

  assign BLUE_0 = Beispielrechner_System_0_BLUE;
  assign GREEN_0 = Beispielrechner_System_0_GREEN;
  assign HSYNC_0 = Beispielrechner_System_0_HSYNC;
  assign RED_0 = Beispielrechner_System_0_RED;
  assign RXD_0_1 = RXD_0;
  assign SDI_RXD_0_1 = SDI_RXD_0;
  assign SDI_TXD_0 = Beispielrechner_System_0_SDI_TXD;
  assign TXD_0 = Beispielrechner_System_0_TXD;
  assign VSYNC_0 = Beispielrechner_System_0_VSYNC;
  assign clk_in1_0_1 = clk_in1_0;
  design_1_Beispielrechner_System_0_0 Beispielrechner_System_0
       (.BLUE(Beispielrechner_System_0_BLUE),
        .CLK(clk_wiz_0_clk_out1),
        .GPIO(GPIO_0[7:0]),
        .GREEN(Beispielrechner_System_0_GREEN),
        .HSYNC(Beispielrechner_System_0_HSYNC),
        .RED(Beispielrechner_System_0_RED),
        .RXD(RXD_0_1),
        .SDI_RXD(SDI_RXD_0_1),
        .SDI_TXD(Beispielrechner_System_0_SDI_TXD),
        .TXD(Beispielrechner_System_0_TXD),
        .VSYNC(Beispielrechner_System_0_VSYNC));
  design_1_clk_wiz_0_0 clk_wiz_0
       (.clk_in1(clk_in1_0_1),
        .clk_out1(clk_wiz_0_clk_out1));
endmodule
