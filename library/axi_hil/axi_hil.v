// ***************************************************************************
// ***************************************************************************
// Copyright 2014 - 2019 (c) Analog Devices, Inc. All rights reserved.
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

module axi_hil #(
  parameter     ID = 0
) (  
  output      [31:0]                  dac_1_0_data,
  output      [31:0]                  dac_3_2_data,
  input                               sampling_clk,
  input       [15:0]                  adc_0_data,
  input                               adc_0_valid,
  input       [15:0]                  adc_1_data,
  input                               adc_1_valid,
  input       [15:0]                  adc_2_data,
  input                               adc_2_valid,
  input       [15:0]                  adc_3_data,
  input                               adc_3_valid,

  // ila probes
  // output      [15:0]                  dbg_adc_0_threshold,
  // output      [15:0]                  dbg_dac_0_min_value,
  // output      [15:0]                  dbg_dac_0_max_value,
  // output      [31:0]                  dbg_adc_0_delay_prescaler,
  // output      [31:0]                  dbg_adc_0_delay_cnt,
  // output      [ 0:0]                  dbg_dac_0_bypass_mux,
  // output      [ 0:0]                  dbg_resetn,
  // output      [ 0:0]                  dbg_adc_0_threshold_passed,
  // output      [ 0:0]                  dbg_adc_0_delay_cnt_en,


  //axi interface
  input                               s_axi_aclk,
  input                               s_axi_aresetn,
  input                               s_axi_awvalid,
  input       [ 9:0]                  s_axi_awaddr,
  input       [ 2:0]                  s_axi_awprot,
  output                              s_axi_awready,
  input                               s_axi_wvalid,
  input       [31:0]                  s_axi_wdata,
  input       [ 3:0]                  s_axi_wstrb,
  output                              s_axi_wready,
  output                              s_axi_bvalid,
  output      [ 1:0]                  s_axi_bresp,
  input                               s_axi_bready,
  input                               s_axi_arvalid,
  input       [ 9:0]                  s_axi_araddr,
  input       [ 2:0]                  s_axi_arprot,
  output                              s_axi_arready,
  output                              s_axi_rvalid,
  output      [ 1:0]                  s_axi_rresp,
  output      [31:0]                  s_axi_rdata,
  input                               s_axi_rready
);

  //local parameters
  localparam [31:0] CORE_VERSION            = {16'h0001,     /* MAJOR */
                                                8'h00,       /* MINOR */
                                                8'h00};      /* PATCH */ // 0.0.0
  localparam [31:0] CORE_MAGIC              = 32'h48494C43;    // HILC

  wire          up_wack;
  wire   [31:0] up_rdata;
  wire          up_rack;
  wire          up_rreq_s;
  wire  [7:0]   up_raddr_s;
  wire          up_wreq_s;
  wire  [7:0]   up_waddr_s;
  wire  [31:0]  up_wdata_s;

  wire          up_clk = s_axi_aclk;
  wire          up_rstn = s_axi_aresetn;

  wire            resetn;
  wire            adc_threshold_passed  [3:0];
  wire   [15:0]   dac_data              [3:0];
  wire            dac_bypass_mux        [3:0];
  wire   [15:0]   adc_threshold         [3:0];
  wire   [31:0]   adc_delay_prescaler   [3:0];
  wire   [15:0]   dac_min_value         [3:0];
  wire   [15:0]   dac_max_value         [3:0];
  wire   [31:0]   dac_pulse_prescaler   [3:0];
  reg    [31:0]   adc_delay_cnt         [3:0];
  reg             adc_delay_cnt_en      [3:0];
  reg    [31:0]   dac_pulse_cnt         [3:0];
  reg             dac_pulse_cnt_en      [3:0];
  reg    [15:0]   delay_dac_data        [3:0];
  reg             adc_input_change      [3:0];
  reg             adc_input_change_d1   [3:0];
  reg             adc_input_change_d2   [3:0];
  

  up_axi #(
    .AXI_ADDRESS_WIDTH (10)
  ) i_up_axi (
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

  axi_hil_regmap #(
    .ID (ID),
    .CORE_MAGIC (CORE_MAGIC),
    .CORE_VERSION (CORE_VERSION),
    .ADC_0_THRESHOLD (16'h2000),
    .ADC_1_THRESHOLD (0),
    .ADC_2_THRESHOLD (0),
    .ADC_3_THRESHOLD (0),
    .ADC_0_DELAY_PRESCALER (32'h00B71B00),
    .ADC_1_DELAY_PRESCALER (0),
    .ADC_2_DELAY_PRESCALER (0),
    .ADC_3_DELAY_PRESCALER (0),
    .DAC_0_MIN_VALUE (16'h4639),
    .DAC_1_MIN_VALUE (0),
    .DAC_2_MIN_VALUE (0),
    .DAC_3_MIN_VALUE (0),
    .DAC_0_MAX_VALUE (16'h0000),
    .DAC_1_MAX_VALUE (0),
    .DAC_2_MAX_VALUE (0),
    .DAC_3_MAX_VALUE (0),
    .DAC_0_PULSE_PRESCALER (32'h00B71B00),
    .DAC_1_PULSE_PRESCALER (0),
    .DAC_2_PULSE_PRESCALER (0),
    .DAC_3_PULSE_PRESCALER (0)
  ) i_regmap (
    .ext_clk (sampling_clk),
    .resetn (resetn),
    .dac_0_bypass_mux (dac_bypass_mux[0]),
    .dac_1_bypass_mux (dac_bypass_mux[1]),
    .dac_2_bypass_mux (dac_bypass_mux[2]),
    .dac_3_bypass_mux (dac_bypass_mux[3]),
    .adc_0_threshold (adc_threshold[0]),
    .adc_1_threshold (adc_threshold[1]),
    .adc_2_threshold (adc_threshold[2]),
    .adc_3_threshold (adc_threshold[3]),
    .adc_0_delay_prescaler (adc_delay_prescaler[0]),
    .adc_1_delay_prescaler (adc_delay_prescaler[1]),
    .adc_2_delay_prescaler (adc_delay_prescaler[2]),
    .adc_3_delay_prescaler (adc_delay_prescaler[3]),
    .dac_0_min_value (dac_min_value[0]),
    .dac_1_min_value (dac_min_value[1]),
    .dac_2_min_value (dac_min_value[2]),
    .dac_3_min_value (dac_min_value[3]),
    .dac_0_max_value (dac_max_value[0]),
    .dac_1_max_value (dac_max_value[1]),
    .dac_2_max_value (dac_max_value[2]),
    .dac_3_max_value (dac_max_value[3]),
    .dac_0_pulse_prescaler (dac_pulse_prescaler[0]),
    .dac_1_pulse_prescaler (dac_pulse_prescaler[1]),
    .dac_2_pulse_prescaler (dac_pulse_prescaler[2]),
    .dac_3_pulse_prescaler (dac_pulse_prescaler[3]),
    .up_rstn (up_rstn),
    .up_clk (up_clk),
    .up_wreq (up_wreq_s),
    .up_waddr (up_waddr_s),
    .up_wdata (up_wdata_s),
    .up_wack (up_wack_s),
    .up_rreq (up_rreq_s),
    .up_raddr (up_raddr_s),
    .up_rdata (up_rdata),
    .up_rack (up_rack));

     //comparator logic
  always @(*) begin
    if (adc_0_valid && !adc_0_data[15] && adc_0_data >= adc_threshold[0]) begin
      adc_input_change[0] <= 1'b1;
    end else begin
      adc_input_change[0] <= 1'b0;
    end
    if (adc_1_valid && !adc_1_data[15] && adc_1_data >= adc_threshold[1]) begin
      adc_input_change[1] <= 1'b1;
    end else begin
      adc_input_change[1] <= 1'b0;
    end
    if (adc_2_valid && !adc_2_data[15] && adc_2_data >= adc_threshold[2]) begin
      adc_input_change[2] <= 1'b1;
    end else begin
      adc_input_change[2] <= 1'b0;
    end
    if (adc_3_valid && !adc_3_data[15] && adc_3_data >= adc_threshold[3]) begin
      adc_input_change[3] <= 1'b1;
    end else begin
      adc_input_change[3] <= 1'b0;
    end
  end

  genvar i;
  generate
    for (i=0; i < 4; i=i+1) begin
      assign adc_threshold_passed[i] = !adc_input_change_d2[i] && adc_input_change_d1[i];
      
      always @(posedge sampling_clk) begin
        if (resetn == 1'b0) begin
          adc_input_change_d2[i] <= 1'b0;
          adc_input_change_d1[i] <= 1'b0;
          adc_delay_cnt_en[i] <= 1'b0;
          dac_pulse_cnt_en[i] <= 1'b0;
        end else begin
          adc_input_change_d1[i] <= adc_input_change[i];
          adc_input_change_d2[i] <= adc_input_change_d1[i];
          if (!adc_delay_cnt_en[i] && adc_threshold_passed[i]) begin
            adc_delay_cnt_en[i] <= 1'b1;
          end
          if (adc_delay_cnt[i] == adc_delay_prescaler[i]) begin
            adc_delay_cnt_en[i] <= 1'b0;
            dac_pulse_cnt_en[i] <= 1'b1;
          end
          if (dac_pulse_cnt[i] == dac_pulse_prescaler[i]) begin
            dac_pulse_cnt_en[i] <= 1'b0;
          end
        end
      end

      always @(posedge sampling_clk) begin
        if (resetn == 1'b0) begin
          adc_delay_cnt[i] <= 32'd0;
          dac_pulse_cnt[i] <= 32'd0;
        end else begin
          if (adc_delay_cnt_en[i]) begin
            adc_delay_cnt[i] <= adc_delay_cnt[i] + 1'b1;
            if (adc_delay_cnt[i] == adc_delay_prescaler[i]) begin
              adc_delay_cnt[i] <= 32'd0;
              delay_dac_data[i] <= dac_max_value[i];
            end
          end
          if (dac_pulse_cnt_en[i]) begin
            dac_pulse_cnt[i] <= dac_pulse_cnt[i] + 1'b1;
            if (dac_pulse_cnt[i] == dac_pulse_prescaler[i]) begin
              dac_pulse_cnt[i] <= 32'd0;
              delay_dac_data[i] <= dac_min_value[i];
            end
          end
        end
      end
    end
  endgenerate

  assign dac_data[0] = (dac_bypass_mux[0])? {~adc_0_data[15], adc_0_data[14:0]} : {~delay_dac_data[0][15], delay_dac_data[0][14:0]};
  assign dac_data[1] = (dac_bypass_mux[1])? {~adc_1_data[15], adc_1_data[14:0]} : {~delay_dac_data[1][15], delay_dac_data[1][14:0]};
  assign dac_data[2] = (dac_bypass_mux[2])? {~adc_2_data[15], adc_2_data[14:0]} : {~delay_dac_data[2][15], delay_dac_data[2][14:0]};
  assign dac_data[3] = (dac_bypass_mux[3])? {~adc_3_data[15], adc_3_data[14:0]} : {~delay_dac_data[3][15], delay_dac_data[3][14:0]};

  assign dac_1_0_data = {dac_data[1], dac_data[0]};
  assign dac_3_2_data = {dac_data[3], dac_data[2]};

  // ila probes
  // assign dbg_adc_0_threshold = adc_threshold[0];
  // assign dbg_dac_0_min_value = dac_min_value[0];
  // assign dbg_dac_0_max_value = dac_max_value[0];
  // assign dbg_adc_0_delay_prescaler = adc_delay_prescaler[0];
  // assign dbg_adc_0_delay_cnt = adc_delay_cnt[0];
  // assign dbg_dac_0_bypass_mux = dac_bypass_mux[0];
  // assign dbg_resetn = resetn;
  // assign dbg_adc_0_threshold_passed = adc_threshold_passed[0];
  // assign dbg_adc_0_delay_cnt_en = adc_delay_cnt_en[0];

endmodule
