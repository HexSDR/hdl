
####################################################################################
## Copyright 2018(c) Analog Devices, Inc.
## Auto-generated, do not modify!
####################################################################################

PROJECT_NAME := talise_prod_test

LIB_DEPS += axi_clkgen
LIB_DEPS += axi_sysid
LIB_DEPS += sysid_rom
LIB_DEPS += axi_fan_control
LIB_DEPS += axi_i2s_adi
LIB_DEPS += axi_dmac
LIB_DEPS += xilinx/axi_xcvrlb
LIB_DEPS += xilinx/axi_adcfifo
LIB_DEPS += xilinx/axi_dacfifo
LIB_DEPS += xilinx/axi_adxcvr
LIB_DEPS += xilinx/util_adxcvr
LIB_DEPS += jesd204/axi_jesd204_rx
LIB_DEPS += jesd204/axi_jesd204_tx
LIB_DEPS += jesd204/jesd204_rx
LIB_DEPS += jesd204/jesd204_tx
LIB_DEPS += util_pack/util_cpack2
LIB_DEPS += util_pack/util_upack2
LIB_DEPS += jesd204/ad_ip_jesd204_tpl_adc
LIB_DEPS += jesd204/ad_ip_jesd204_tpl_dac
LIB_DEPS += axi_clock_monitor

hdl_generic_location := $(wildcard ../../../../hdl)
ifndef ADI_HDL_DIR
  ifeq ($(hdl_generic_location),)
    $(error ADI_HDL_DIR is not set! e.g. export ADI_HDL_DIR=/media/data/github/hdl C/../hdl)
  else
    ADI_HDL_DIR := $(hdl_generic_location)
    export ADI_HDL_DIR=$(hdl_generic_location)
  endif
endif

include $(ADI_HDL_DIR)/projects/scripts/project-xilinx.mk
