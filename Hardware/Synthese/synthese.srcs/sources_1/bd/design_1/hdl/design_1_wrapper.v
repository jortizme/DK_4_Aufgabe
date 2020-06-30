//Copyright 1986-2017 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2017.4 (win64) Build 2086221 Fri Dec 15 20:55:39 MST 2017
//Date        : Fri Jun 12 15:18:11 2020
//Host        : DESKTOP-SKCALQI running 64-bit major release  (build 9200)
//Command     : generate_target design_1_wrapper.bd
//Design      : design_1_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module design_1_wrapper
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
  input clk_in1_0;

  wire BLUE_0;
  wire [7:0]GPIO_0;
  wire GREEN_0;
  wire HSYNC_0;
  wire RED_0;
  wire RXD_0;
  wire SDI_RXD_0;
  wire SDI_TXD_0;
  wire TXD_0;
  wire VSYNC_0;
  wire clk_in1_0;

  design_1 design_1_i
       (.BLUE_0(BLUE_0),
        .GPIO_0(GPIO_0),
        .GREEN_0(GREEN_0),
        .HSYNC_0(HSYNC_0),
        .RED_0(RED_0),
        .RXD_0(RXD_0),
        .SDI_RXD_0(SDI_RXD_0),
        .SDI_TXD_0(SDI_TXD_0),
        .TXD_0(TXD_0),
        .VSYNC_0(VSYNC_0),
        .clk_in1_0(clk_in1_0));
endmodule
