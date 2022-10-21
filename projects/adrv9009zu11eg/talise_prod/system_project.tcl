
set abs_path [pwd]

if [info exists ::env(ADI_HDL_DIR)] {
  set ad_hdl_dir $::env(ADI_HDL_DIR)
} else {
	set ad_hdl_dir  "$abs_path/../../../hdl"
}

if [info exists ::env(ADI_GHDL_DIR)] {
  set ad_ghdl_dir $::env(ADI_GHDL_DIR)
} else {
	set ad_ghdl_dir  "$abs_path/../../../ghdl"
}

source $ad_hdl_dir/scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_project_xilinx.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl

set p_device "xczu11eg-ffvf1517-2-e"
set sys_zynq 2

adi_project talise_prod_test 0 [list \
  RX_JESD_M       8 \
  RX_JESD_L       4 \
  RX_JESD_S       1 \
  TX_JESD_M       8 \
  TX_JESD_L       8 \
  TX_JESD_S       1 \
  RX_OS_JESD_M    4 \
  RX_OS_JESD_L    4 \
  RX_OS_JESD_S    1 \
]

adi_project_files talise_prod_test [list \
  "system_top.v" \
  "$ad_hdl_dir/projects/adrv9009zu11eg/common/adrv9009zu11eg_spi.v" \
  "$ad_hdl_dir/projects/adrv9009zu11eg/common/adrv9009zu11eg_constr.xdc"\
  "$ad_hdl_dir/projects/adrv9009zu11eg/common/adrv2crr_fmc_constr.xdc"\
  "prod_constr.xdc"\
  "$ad_hdl_dir/library/common/ad_iobuf.v"
  ]

adi_project_run talise_prod_test
