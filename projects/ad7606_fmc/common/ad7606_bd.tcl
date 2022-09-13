
# system level parameters

set CRC_EN $ad_project_params(CRC_EN)

puts "build parameters: CRC_EN: $CRC_EN"

# data, read and write lines

create_bd_port -dir O -from 15 -to 0 rx_db_o
create_bd_port -dir I -from 15 -to 0 rx_db_i
create_bd_port -dir O rx_db_t
create_bd_port -dir O rx_rd_n
create_bd_port -dir O rx_wr_n

# control lines

create_bd_port -dir I rx_busy
create_bd_port -dir O rx_cnvst_n
create_bd_port -dir O rx_cs_n
create_bd_port -dir I rx_first_data

# instantiation

ad_ip_instance axi_ad7606 axi_ad7606
ad_ip_parameter axi_ad7606 CONFIG.IF_TYPE 1
if {$CRC_EN == 1} {
  ad_ip_parameter axi_ad7606 CONFIG.ADC_READ_MODE 3
} else {
  ad_ip_parameter axi_ad7606 CONFIG.ADC_READ_MODE 1
}
ad_ip_parameter axi_ad7606 CONFIG.EXTERNAL_CLK 0

ad_ip_instance axi_pwm_gen axi_pwm_gen
ad_ip_parameter axi_pwm_gen CONFIG.ASYNC_CLK_EN 0
ad_ip_parameter axi_pwm_gen CONFIG.N_PWMS 1
ad_ip_parameter axi_pwm_gen CONFIG.PULSE_0_WIDTH 135
ad_ip_parameter axi_pwm_gen CONFIG.PULSE_0_PERIOD 136 

ad_ip_instance axi_dmac axi_ad7606_dma
ad_ip_parameter axi_ad7606_dma CONFIG.DMA_TYPE_SRC 2
ad_ip_parameter axi_ad7606_dma CONFIG.DMA_TYPE_DEST 0
ad_ip_parameter axi_ad7606_dma CONFIG.CYCLIC 0
ad_ip_parameter axi_ad7606_dma CONFIG.DMA_2D_TRANSFER 0
ad_ip_parameter axi_ad7606_dma CONFIG.DMA_DATA_WIDTH_SRC 16
ad_ip_parameter axi_ad7606_dma CONFIG.DMA_DATA_WIDTH_DEST 64

ad_ip_instance util_cpack2 ad7606_adc_pack
if {$CRC_EN == 1} {
  ad_ip_parameter ad7606_adc_pack CONFIG.NUM_OF_CHANNELS 9
} else {
  ad_ip_parameter ad7606_adc_pack CONFIG.NUM_OF_CHANNELS 8
}
ad_ip_parameter ad7606_adc_pack CONFIG.SAMPLE_DATA_WIDTH 16

# interface connections

ad_connect  rx_db_o axi_ad7606/rx_db_o
ad_connect  rx_db_i axi_ad7606/rx_db_i
ad_connect  rx_db_t axi_ad7606/rx_db_t
ad_connect  rx_rd_n axi_ad7606/rx_rd_n
ad_connect  rx_wr_n axi_ad7606/rx_wr_n

ad_connect  rx_cs_n axi_ad7606/rx_cs_n
ad_connect  rx_cnvst_n axi_pwm_gen/pwm_0
ad_connect  rx_busy axi_ad7606/rx_busy
ad_connect  rx_first_data axi_ad7606/first_data

ad_connect  sys_cpu_clk axi_ad7606_dma/s_axi_aclk
ad_connect  sys_cpu_clk axi_ad7606_dma/fifo_wr_clk
ad_connect  sys_cpu_clk axi_pwm_gen/s_axi_aclk
ad_connect  sys_cpu_resetn axi_pwm_gen/s_axi_aresetn

ad_connect  axi_ad7606/adc_clk ad7606_adc_pack/clk
ad_connect  axi_ad7606/adc_reset ad7606_adc_pack/reset
ad_connect  axi_ad7606/adc_valid ad7606_adc_pack/fifo_wr_en
ad_connect  ad7606_adc_pack/packed_fifo_wr axi_ad7606_dma/fifo_wr
ad_connect  ad7606_adc_pack/fifo_wr_overflow axi_ad7606/adc_dovf

if {$CRC_EN == 1} {
  for {set i 0} {$i < 8} {incr i} {
    ad_connect axi_ad7606/adc_data_$i ad7606_adc_pack/fifo_wr_data_$i
    ad_connect axi_ad7606/adc_enable_$i ad7606_adc_pack/enable_$i
  }
  ad_connect axi_ad7606/adc_crc ad7606_adc_pack/fifo_wr_data_8
} else {
  for {set i 0} {$i < 8} {incr i} {
    ad_connect axi_ad7606/adc_data_$i ad7606_adc_pack/fifo_wr_data_$i
    ad_connect axi_ad7606/adc_enable_$i ad7606_adc_pack/enable_$i
  }
}

# interconnect

ad_cpu_interconnect  0x44A00000 axi_ad7606
ad_cpu_interconnect  0x44A30000 axi_ad7606_dma
ad_cpu_interconnect  0x44A60000 axi_pwm_gen

# memory interconnect

ad_mem_hp1_interconnect sys_cpu_clk sys_ps7/S_AXI_HP1
ad_mem_hp1_interconnect sys_cpu_clk axi_ad7606_dma/m_dest_axi
ad_connect sys_cpu_resetn axi_ad7606_dma/m_dest_axi_aresetn

#interrupt

ad_cpu_interrupt ps-13 mb-12 axi_ad7606_dma/irq
