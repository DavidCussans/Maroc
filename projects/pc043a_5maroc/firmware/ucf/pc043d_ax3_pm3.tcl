set_property BITSTREAM.Config.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]

# CHANGE ME - Add constraints for 5 MAROC board.
# 
# 
# For 250MHz bit rate
create_clock -period 4.000 -name fmc_clk [get_ports fmc_clk_p]
create_clock -period 4.000 -name rec_clk [get_ports rec_clk_p]

# For 312.5MHz bit rate
# create_clock -period 3.200 -name fmc_clk [get_ports fmc_clk_p]
# create_clock -period 3.200 -name rec_clk [get_ports rec_clk_p]


set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks fmc_clk] -group [get_clocks -include_generated_clocks rec_clk] -group [get_clocks -include_generated_clocks -of_obj [get_pins -of_obj [get_cells infra/clocks/mmcm] -filter {NAME =~ *CLKOUT*}]]

set_property IOSTANDARD LVDS_25 [get_port {fmc_clk_* rec_clk_* rec_d_* clk_out_* rj45_din_* rj45_dout_* sfp_dout_* gpin_* gpout_*}]
set_property DIFF_TERM TRUE [get_port {fmc_clk_* rec_clk_* rec_d_* rj45_din_* gpin_*}]
set_property PACKAGE_PIN T5 [get_ports {fmc_clk_p}]
set_property PACKAGE_PIN T4 [get_ports {fmc_clk_n}]
set_property PACKAGE_PIN E3 [get_ports {rec_clk_p}]
set_property PACKAGE_PIN D3 [get_ports {rec_clk_n}]
set_property PACKAGE_PIN M6 [get_ports {rec_d_p}]
set_property PACKAGE_PIN N6 [get_ports {rec_d_n}]
set_property PACKAGE_PIN N5 [get_ports {clk_out_p}]
set_property PACKAGE_PIN P5 [get_ports {clk_out_n}]
set_property PACKAGE_PIN K3 [get_ports {rj45_din_p}]
set_property PACKAGE_PIN L3 [get_ports {rj45_din_n}]
set_property PACKAGE_PIN G6 [get_ports {rj45_dout_p}]
set_property PACKAGE_PIN F6 [get_ports {rj45_dout_n}]
set_property PACKAGE_PIN D8 [get_ports {sfp_dout_p}]
set_property PACKAGE_PIN C7 [get_ports {sfp_dout_n}]
set_property PACKAGE_PIN N2 [get_ports {gpin_0_p}] 
set_property PACKAGE_PIN N1 [get_ports {gpin_0_n}] 
#set_property PACKAGE_PIN M4 [get_ports {gpin_1_p}]
#set_property PACKAGE_PIN N4 [get_ports {gpin_1_n}]
set_property PACKAGE_PIN L6 [get_ports {gpout_0_p}] 
set_property PACKAGE_PIN L5 [get_ports {gpout_0_n}] 
set_property PACKAGE_PIN G4 [get_ports {gpout_1_p}] 
set_property PACKAGE_PIN G3 [get_ports {gpout_1_n}] 

false_path {rec_d_* clk_out_* rj45_din_* rj45_dout_* sfp_dout_* gpin_* gpout_*} osc_clk

set_property IOSTANDARD LVCMOS25 [get_port {pll_rstn cdr_lol cdr_los sfp_los sfp_tx_dis sfp_flt uid_scl uid_sda sfp_scl sfp_sda pll_scl pll_sda}]
set_property PACKAGE_PIN R6 [get_ports {cdr_lol}]
set_property PACKAGE_PIN R5 [get_ports {cdr_los}]
set_property PACKAGE_PIN P2 [get_ports {sfp_los}]
set_property PACKAGE_PIN U4 [get_ports {sfp_tx_dis}]
set_property PACKAGE_PIN U3 [get_ports {sfp_flt}]
set_property PACKAGE_PIN N17 [get_ports {uid_scl}]
set_property PACKAGE_PIN P18 [get_ports {uid_sda}]
set_property PACKAGE_PIN M3 [get_ports {sfp_scl}]
set_property PACKAGE_PIN M2 [get_ports {sfp_sda}]
set_property PACKAGE_PIN U1 [get_ports {pll_scl}]
set_property PACKAGE_PIN V1 [get_ports {pll_sda}]
set_property PACKAGE_PIN H1 [get_ports {pll_rstn}]
false_path {pll_rstn cdr_lol cdr_los sfp_los sfp_tx_dis sfp_flt uid_scl uid_sda sfp_scl sfp_sda pll_scl pll_sda} osc_clk