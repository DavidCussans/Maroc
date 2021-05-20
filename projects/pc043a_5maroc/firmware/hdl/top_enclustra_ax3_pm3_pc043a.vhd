-- Top-level design for ipbus demo
--
-- This version is for Enclustra AX3 module, using the RGMII PHY on the PM3 baseboard
--
-- You must edit this file to set the IP and MAC addresses
--
-- Dave Newbold, 4/10/16

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use work.ipbus.ALL;
use work.fiveMaroc.all;

entity top is port(
		osc_clk: in std_logic;
		leds: out std_logic_vector(3 downto 0); -- Enclustra status LEDs
		phy_rstn: out std_logic; -- PHY reset
          rgmii_txd: out std_logic_vector(3 downto 0);
          rgmii_tx_ctl: out std_logic;
          rgmii_txc: out std_logic;
          rgmii_rxd: in std_logic_vector(3 downto 0);
          rgmii_rx_ctl: in std_logic;
          rgmii_rxc: in std_logic;

       -- cfg: in std_logic_vector(3 downto 0); 
        -- Connections to MAROC
        CK_40M_P: out STD_LOGIC;
        CK_40M_N: out STD_LOGIC;
        -- CK_40M_OUT_2V5: in STD_LOGIC; -- not currently used
        HOLD2_2V5: out STD_LOGIC;
        HOLD1_2V5: out STD_LOGIC;
        OR1_2V5: in STD_LOGIC_VECTOR(c_NMAROC-1 downto 0);
        OR0_2V5: in STD_LOGIC_VECTOR(c_NMAROC-1 downto 0);
        -- bodge for now, just to get code to build
--        OR1_2V5: in STD_LOGIC_VECTOR(g_NMAROC-2 downto 0);
--        OR0_2V5: in STD_LOGIC_VECTOR(g_NMAROC-2 downto 0);
        EN_OTAQ_2V5: out STD_LOGIC;
        CTEST_2V5: out STD_LOGIC;
        ADC_DAV_2V5: in STD_LOGIC_VECTOR(c_NMAROC-1 downto 0);
        OUT_ADC_2V5: in STD_LOGIC_VECTOR(c_NMAROC-1 downto 0);
        START_ADC_2V5_N: out STD_LOGIC;
        RST_ADC_2V5_N: out STD_LOGIC;
        RST_SC_2V5_N: out STD_LOGIC;
        Q_SC_2V5: in STD_LOGIC;
        D_SC_2V5: out STD_LOGIC;
        RST_R_2V5_N: out STD_LOGIC;
        Q_R_2V5: in STD_LOGIC;
        D_R_2V5: out STD_LOGIC;
        CK_R_2V5: out STD_LOGIC;
        CK_SC_2V5: out STD_LOGIC;
        -- lines to select marocs for setup and control
        MAROC_SELECT_2V5: out STD_LOGIC_VECTOR(2 downto 0);
        -- HDMI signals for Clock and trigger I/O
        -- For tests declare all as output
        HDMI0_CLK_P: in std_logic;      -- Need an input clock of 40MHz on J28
        HDMI0_CLK_N: in std_logic;
        HDMI0_DATA_P: in std_logic_vector(2 downto 0);
        HDMI0_DATA_N: in std_logic_vector(2 downto 0);
        --HDMI1_CLK_P: in std_logic;
        --HDMI1_CLK_N: in std_logic;        
        --HDMI1_DATA_P: in std_logic_vector(2 downto 0);
        --HDMI1_DATA_N: in std_logic_vector(2 downto 0);
        --HDMI1_CLK_P: inout std_logic;
        --HDMI1_CLK_N: inout std_logic;        
        --HDMI1_DATA_P: inout std_logic_vector(2 downto 0);
        --HDMI1_DATA_N: inout std_logic_vector(2 downto 0);
        HDMI1_SIGNALS_P : inout std_logic_vector(3 downto 0);
        HDMI1_SIGNALS_N : inout std_logic_vector(3 downto 0)
        
        -- GPIO header for debugging:
        -- GPIO_HDR_O: out STD_LOGIC_VECTOR(5 downto 0); -- CHANGEME - No GPIO on Enclustra
        -- GPIO_HDR_I: in STD_LOGIC_VECTOR(7 downto 6)   -- CHANGEME - No GPIO on Enclustra


	);

end top;

architecture rtl of top is

    -- CHANGEME: dummy signals for non-existent GPIO. (Move to unused pins on FMC)
    signal GPIO_HDR_O: STD_LOGIC_VECTOR(5 downto 0)  := (others=>'0'); -- CHANGEME - No GPIO on Enclustra
    signal GPIO_HDR_I: STD_LOGIC_VECTOR(7 downto 6)  := (others=>'0');   -- CHANGEME - No GPIO on Enclustra

    
	signal clk_ipb, rst_ipb, nuke, soft_rst, phy_rst_e, clk125: std_logic;
	signal userled: std_logic;
	signal mac_addr: std_logic_vector(47 downto 0);
	signal ip_addr: std_logic_vector(31 downto 0);
	signal ipb_out: ipb_wbus;
	signal ipb_in: ipb_rbus;
	signal inf_leds: std_logic_vector(1 downto 0);

    attribute keep : string;
    attribute keep of nuke , clk_ipb: signal is "true"; -- Bodge to keep un-used net 
	
begin

-- Infrastructure

	infra: entity work.enclustra_ax3_pm3_infra
		port map(
			osc_clk => osc_clk,
			clk_ipb_o => clk_ipb,
			rst_ipb_o => rst_ipb,
			clk125_o => clk125,
			rst125_o => phy_rst_e,
			nuke => nuke,
			soft_rst => soft_rst,
			leds => inf_leds,
			rgmii_txd => rgmii_txd,
			rgmii_tx_ctl => rgmii_tx_ctl,
			rgmii_txc => rgmii_txc,
			rgmii_rxd => rgmii_rxd,
			rgmii_rx_ctl => rgmii_rx_ctl,
			rgmii_rxc => rgmii_rxc,
			mac_addr => mac_addr,
			ip_addr => ip_addr,
			ipb_in => ipb_in,
			ipb_out => ipb_out
		);
		
	leds <= not ('0' & userled & inf_leds);
	phy_rstn <= not phy_rst_e;
		
	mac_addr <= X"020ddba11640"; -- Careful here, arbitrary addresses do not always work
	ip_addr <= X"c0a8c840"; -- 192.168.200.64

-- ipbus slaves live in the entity below, and can expose top-level ports
-- The ipbus fabric is instantiated within.

	slaves: entity work.payload
		port map(
			ipb_clk => clk_ipb,
			ipb_rst => rst_ipb,
			ipb_in => ipb_out,
			ipb_out => ipb_in,
			nuke => nuke,
			soft_rst => soft_rst,
			userled => userled,
			clk125 => clk125,
		
      		sysclk => osc_clk,
        	leds => open,

        	-- Connections to MAROC
        	CK_40M_P => CK_40M_P,
        	CK_40M_N => CK_40M_N,
           	-- CK_40M_OUT_2V5: in STD_LOGIC; -- not currently used
        	HOLD2_2V5 => HOLD2_2V5,
        	HOLD1_2V5 => HOLD1_2V5,
        	OR1_2V5 => OR1_2V5,
        	OR0_2V5 => OR0_2V5,
			EN_OTAQ_2V5 => EN_OTAQ_2V5, 
			CTEST_2V5 => CTEST_2V5, 
			ADC_DAV_2V5 => ADC_DAV_2V5, 
			OUT_ADC_2V5 => OUT_ADC_2V5, 
			START_ADC_2V5_N => START_ADC_2V5_N, 
			RST_ADC_2V5_N => RST_ADC_2V5_N, 
			RST_SC_2V5_N => RST_SC_2V5_N, 
			Q_SC_2V5 => Q_SC_2V5, 
			D_SC_2V5 => D_SC_2V5, 
			RST_R_2V5_N => RST_R_2V5_N, 
			Q_R_2V5 => Q_R_2V5, 
			D_R_2V5 => D_R_2V5, 
			CK_R_2V5 => CK_R_2V5, 
			CK_SC_2V5 => CK_SC_2V5, 
        -- lines to select marocs for setup and control
			MAROC_SELECT_2V5 => MAROC_SELECT_2V5,
        -- HDMI signals for Clock and trigger I/O
        -- For tests declare all as output
			HDMI0_CLK_P => HDMI0_CLK_P, 
			HDMI0_CLK_N => HDMI0_CLK_N, 
			HDMI0_DATA_P => HDMI0_DATA_P, 
			HDMI0_DATA_N => HDMI0_DATA_N, 
        --HDMI1_CLK_P: in std_logic;
        --HDMI1_CLK_N: in std_logic;        
        --HDMI1_DATA_P: in std_logic_vector(2 downto 0);
        --HDMI1_DATA_N: in std_logic_vector(2 downto 0);
        --HDMI1_CLK_P: inout std_logic;
        --HDMI1_CLK_N: inout std_logic;        
        --HDMI1_DATA_P: inout std_logic_vector(2 downto 0);
        --HDMI1_DATA_N: inout std_logic_vector(2 downto 0);
			HDMI1_SIGNALS_P => HDMI1_SIGNALS_P , 
			HDMI1_SIGNALS_N => HDMI1_SIGNALS_N, 
		
		  	GPIO_HDR_O => GPIO_HDR_O,
            GPIO_HDR_I => GPIO_HDR_I
        
			
		);

end rtl;
