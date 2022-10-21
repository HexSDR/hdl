 // ***************************************************************************
// ***************************************************************************
// Copyright 2014 - 2017 (c) Analog Devices, Inc. All rights reserved.
//
// In this HDL repository, there are many different and unique modules, consisting
// of various HDL (Verilog or VHDL) components. The individual modules are
// developed independently, and may be accompanied by separate and unique license
// terms.
//
// The user should read each of these license terms, and understand the
// freedoms and responsibilities that he or she has by using this source/core.
//
// This core is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE.
//
// Redistribution and use of source or resulting binaries, with or without modification
// of this file, are permitted under one of the following two license terms:
//
//   1. The GNU General Public License version 2 as published by the
//      Free Software Foundation, which can be found in the top level directory
//      of this repository (LICENSE_GPL2), and also online at:
//      <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
//
// OR
//
//   2. An ADI specific BSD license, which can be found in the top level directory
//      of this repository (LICENSE_ADIBSD), and also on-line at:
//      https://github.com/analogdevicesinc/hdl/blob/master/LICENSE_ADIBSD
//      This will allow to generate bit files and not release the source code,
//      as long as it attaches to an ADI device.
//
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/100ps

module axi_ad3552r_if #(

  parameter   ID = 0
) (

  input           dac_clk,  // 120MHz 

  input  [15:0]   data_in_a,
  input  [15:0]   data_in_b,
  input  [31:0]   dma_data,
  input           valid_in_a,
  input           valid_in_b,
  input           valid_in_dma,

  
  // DAC control signals 

  output          dac_sclk,
  output          dac_csn,
  output          dac_sdio_0,
  output          dac_sdio_1,
  output          dac_sdio_2,
  output          dac_sdio_3,


  // AXI INTERFACE

  input           s_axi_aclk,
  input           s_axi_aresetn,
  input           s_axi_awvalid,
  input   [15:0]  s_axi_awaddr,
  input   [ 2:0]  s_axi_awprot,
  output          s_axi_awready,
  input           s_axi_wvalid,
  input   [31:0]  s_axi_wdata,
  input   [ 3:0]  s_axi_wstrb,
  output          s_axi_wready,
  output          s_axi_bvalid,
  output  [ 1:0]  s_axi_bresp,
  input           s_axi_bready,
  input           s_axi_arvalid,
  input   [15:0]  s_axi_araddr,
  input   [ 2:0]  s_axi_arprot,
  output          s_axi_arready,
  output          s_axi_rvalid,
  output  [ 1:0]  s_axi_rresp,
  output  [31:0]  s_axi_rdata,
  input           s_axi_rready
);


 // internal registers

  reg  [31:0] up_rdata = 'd0;
  reg         up_rack = 'd0;
  reg         up_wack = 'd0;
  reg [31:0]  up_rdata_r;
  reg         up_rack_r;
  reg         up_wack_r;

  // internal signals

  wire        adc_rst_s;
  wire        up_rstn;
  wire        up_clk;
  wire [13:0] up_waddr_s;
  wire [13:0] up_raddr_s;
  wire        adc_clk_s;
  wire        up_wreq_s;
  wire        up_rreq_s;
  wire [13:0] up_addr_s;
  wire [31:0] up_wdata_s;
  wire [31:0] up_rdata_s[0:1];
  wire  [1:0] up_rack_s;
  wire  [1:0] up_wack_s;
  wire [ 3:0] dac_data_sel_s;
  wire        dac_data_valid;
  wire [ 7:0] dac_address;
  wire        sdr_ddr_n;
  wire        write_start;
  wire        write_stop;
  wire [15:0] control_data;
  wire        control_valid;



  assign up_clk = s_axi_aclk;
  assign up_rstn = s_axi_aresetn;

integer j;

always @(*) begin
  up_rdata_r = 'h00;
  up_rack_r = 'h00;
  up_wack_r = 'h00;
  for (j = 0; j <= 8; j=j+1) begin
    up_rack_r = up_rack_r | up_rack_s[j];
    up_wack_r = up_wack_r | up_wack_s[j];
    up_rdata_r = up_rdata_r | up_rdata_s[j];
  end
end

always @(negedge up_rstn or posedge up_clk) begin
  if (up_rstn == 0) begin
    up_rdata <= 'd0;
    up_rack <= 'd0;
    up_wack <= 'd0;
  end else begin
    up_rdata <= up_rdata_r;
    up_rack <= up_rack_r;
    up_wack <= up_wack_r;
  end
end

 // dac mux

always @(posedge dac_clk) begin
  case ({dac_data_sel_s[1],dac_data_sel_s[0]})
    8'h00: begin
       dac_data <= {data_in_a,data_in_b}; 
       dac_data_valid <= valid_in_a & valid_in_b;      
    end
    8'h01: begin 
      dac_data <= {data_in_a,dma_data[31:16]};  
      dac_data_valid <= valid_in_a & valid_in_dma;
    end
    8'h10: begin 
      dac_data <= {,dma_data[15:0],data_in_b};  
      dac_data_valid <= valid_in_b & valid_in_dma;
    end
    8'h11: begin 
      dac_data <= dma_data;
      dac_data_valid <= valid_in_dma;                   
    end
    8'h22: begin 
      dac_data[15:0] <= control_data;
      dac_data_valid <= control_valid;                   
    end
   default: dac_data <= {data_in_a,data_in_b};
  endcase
end

generate
  genvar i;
  for (i = 0; i < 1; i=i+1) begin : ad3552r_channels
    up_dac_channel #(
      .CHANNEL_ID (i),
      .USERPORTS_DISABLE(1)
    ) i_up_dac_channel (
      .dac_clk (dac_clk),
      .dac_rst (dac_rst),
      .dac_dds_scale_1 (),
      .dac_dds_init_1 (),
      .dac_dds_incr_1 (),
      .dac_dds_scale_2 (),
      .dac_dds_init_2 (),
      .dac_dds_incr_2 (),
      .dac_pat_data_1 (),
      .dac_pat_data_2 (),
      .dac_data_sel (dac_data_sel_s[i]),
      .dac_iq_mode (),
      .dac_iqcor_enb (),
      .dac_iqcor_coeff_1 (),
      .dac_iqcor_coeff_2 (),
      .up_usr_datatype_be (),
      .up_usr_datatype_signed (),
      .up_usr_datatype_shift (),
      .up_usr_datatype_total_bits (),
      .up_usr_datatype_bits (),
      .up_usr_interpolation_m (),
      .up_usr_interpolation_n (),
      .dac_usr_datatype_be (1'b0),
      .dac_usr_datatype_signed (1'b1),
      .dac_usr_datatype_shift (8'd0),
      .dac_usr_datatype_total_bits (8'd16),
      .dac_usr_datatype_bits (8'd16),
      .dac_usr_interpolation_m (16'd1),
      .dac_usr_interpolation_n (16'd1),
      .up_rstn (up_rstn),
      .up_clk (up_clk),
      .up_wreq (up_wreq_s),
      .up_waddr (up_waddr_s),
      .up_wdata (up_wdata_s),
      .up_wack (up_wack_s[i]),
      .up_rreq (up_rreq_s),
      .up_raddr (up_raddr_s),
      .up_rdata (up_rdata_s[i]),
      .up_rack (up_rack_s[i]));
  
  end
endgenerate

axi_ad3552r_if(
 .ID(0)
) phy_interface (
.clk_in(dac_clk), 
.data_in(dac_data), 
.dac_data_valid(dac_data_valid),
.address(dac_address),
.sdr_ddr_n(sdr_ddr_n),
.write_start(write_start),
.write_stop(write_stop),
.sclk(dac_sclk),
.csn(dac_csn),
.sdio_0(dac_sdio_0),
.sdio_1(dac_sdio_1),
.sdio_2(dac_sdio_2),
.sdio_3(dac_sdio_3));

up_dac_common #(
  .ID (ID),
  .FPGA_TECHNOLOGY (FPGA_TECHNOLOGY),
  .FPGA_FAMILY (FPGA_FAMILY),
  .SPEED_GRADE (SPEED_GRADE),
  .DEV_PACKAGE (DEV_PACKAGE)
) i_up_dac_common (
  .mmcm_rst (),
  .dac_clk (dac_clk),
  .dac_rst (dac_rst),
  .dac_sync (dac_sync_s),
  .dac_frame (),
  .dac_clksel (),
  .dac_data_control({dac_address,control_data,control_valid}),
  .dac_control({write_start,write_stop,sdr_ddr_n}),
  .dac_par_type (),
  .dac_par_enb (),
  .dac_r1_mode (),
  .dac_datafmt (dac_datafmt_s),
  .dac_datarate (),
  .dac_status (dac_status),
  .dac_status_unf (dac_dunf),
  .dac_clk_ratio (32'd16),
  .up_dac_ce (),
  .up_pps_rcounter (31'd0),
  .up_pps_status (1'd0),
  .up_pps_irq_mask (),
  .up_drp_sel (),
  .up_drp_wr (),
  .up_drp_addr (),
  .up_drp_wdata (),
  .up_drp_rdata (32'd0),
  .up_drp_ready (1'd1),
  .up_drp_locked (1'd1),
  .up_usr_chanmax (NUM_CHANNELS),
  .dac_usr_chanmax (8'd1),
  .up_dac_gpio_in (32'd0),
  .up_dac_gpio_out (),
  .up_rstn (up_rstn),
  .up_clk (up_clk),
  .up_wreq (up_wreq_s),
  .up_waddr (up_waddr_s),
  .up_wdata (up_wdata_s),
  .up_wack (up_wack_s[NUM_CHANNELS]),
  .up_rreq (up_rreq_s),
  .up_raddr (up_raddr_s),
  .up_rdata (up_rdata_s[NUM_CHANNELS]),
  .up_rack (up_rack_s[NUM_CHANNELS]));

// up bus interface

up_axi i_up_axi (
  .up_rstn (up_rstn),
  .up_clk (up_clk),
  .up_axi_awvalid (s_axi_awvalid),
  .up_axi_awaddr (s_axi_awaddr),
  .up_axi_awready (s_axi_awready),
  .up_axi_wvalid (s_axi_wvalid),
  .up_axi_wdata (s_axi_wdata),
  .up_axi_wstrb (s_axi_wstrb),
  .up_axi_wready (s_axi_wready),
  .up_axi_bvalid (s_axi_bvalid),
  .up_axi_bresp (s_axi_bresp),
  .up_axi_bready (s_axi_bready),
  .up_axi_arvalid (s_axi_arvalid),
  .up_axi_araddr (s_axi_araddr),
  .up_axi_arready (s_axi_arready),
  .up_axi_rvalid (s_axi_rvalid),
  .up_axi_rresp (s_axi_rresp),
  .up_axi_rdata (s_axi_rdata),
  .up_axi_rready (s_axi_rready),
  .up_wreq (up_wreq_s),
  .up_waddr (up_waddr_s),
  .up_wdata (up_wdata_s),
  .up_wack (up_wack),
  .up_rreq (up_rreq_s),
  .up_raddr (up_raddr_s),
  .up_rdata (up_rdata),
  .up_rack (up_rack));