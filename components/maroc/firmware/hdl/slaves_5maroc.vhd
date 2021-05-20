--=============================================================================
--! @file slaves_5maroc.vhd
--=============================================================================
--
--! @brief The ipbus slaves live in this entity
--
--! @author David Cussans January 2012, based on template by Dave Newbold, February 2011
--
-- Changes:
-- March 2012    - changed from single maroc to five marocs. DGC
-- November 2012 - added a mask to allow masking of broken MAROC.
-- May 2013      - reduced size of ADC buffer to 512 words.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use work.ipbus.ALL;
use work.ipbus_decode_top_pc043a.all;

use work.fiveMaroc.all;

Library UNISIM;
use UNISIM.vcomponents.all;

entity slaves_5maroc is port(
	ipb_clk : in STD_LOGIC;
  clk_1x : in STD_LOGIC;
  rst : in STD_LOGIC;
	ipb_in : in ipb_wbus;
	ipb_out : out ipb_rbus;
        clock_status: in std_logic_vector(c_NCLKS+1 downto 0); -- status of clock lines. Connect to IPBus

-- Top level ports from here
        clk_8x_i : in std_logic; -- 8x speed of clk_i
--        clk_8x_i     : in    std_logic;  --! twice speed of fast clock
--        clk_fast_strobe_i : in    std_logic;  --! strobes every other clko_2x_fast cycle. Use for ISERDES
        clk_16x_i     : in    std_logic_vector(c_NCLKS-1 downto 0);  --! 16x speed of clk_1. Use for ISERDES
 
	gpio_o : out STD_LOGIC_VECTOR(5 downto 3);
        gpio_i : in  STD_LOGIC_VECTOR(7 downto 6);
	externalHdmiTrigger_a_i : in STD_LOGIC;
	externalTrigger_o : out STD_LOGIC;
        maroc_input_signals: out maroc_input_signals;
        maroc_output_signals: in maroc_output_signals;
        hdmi_input_signals:  in  hdmi_input_signals;
        hdmi_output_signals: out hdmi_output_signals;
        hdmi_inout_signals_p : inout std_logic_vector(3 downto 0);
        hdmi_inout_signals_n : inout std_logic_vector(3 downto 0)        
	);

end slaves_5maroc;

architecture rtl of slaves_5maroc is

  --constant NSLV: positive := 9 + c_NMAROC;
  --constant NSLV: positive := 10 + (2*c_NMAROC);
  signal ipbw: ipb_wbus_array(N_SLAVES-1 downto 0);
  signal ipbr: ipb_rbus_array(N_SLAVES-1 downto 0);
  signal register_data: std_logic_vector(c_BUSWIDTH-1 downto 0);

  --! MarocSelect chooses which Maroc for slow control ( 7 = all )
  signal s_marocSelect: std_logic_vector(c_BUSWIDTH-1 downto 0);  

  --! MarocMask chooses which Marocs will return data.
  signal s_marocMask: std_logic_vector(c_BUSWIDTH-1 downto 0) := ( others => '1') ;
  
  signal s_marocADCBusy : std_logic_vector(c_NMAROC-1 downto 0) := ( others => '0');
  signal s_marocStartADC , s_marocResetADC : std_logic_vector(c_NMAROC-1 downto 0) := ( others => '0');
  signal s_marocADCBusySummary : std_logic:= '0';
  
  signal s_adcConversionStart  : std_logic;
  signal s_externalTrigger_o : std_logic;
  signal s_triggerNumber : std_logic_vector(c_BUSWIDTH-1 downto 0);
  signal s_timeStamp : std_logic_vector(c_BUSWIDTH-1 downto 0);
  signal s_logic_reset : std_logic := '0';  -- Pulses high for one cycle of ipbus clock
  signal s_pulsed_lines : std_logic_vector(c_BUSWIDTH-1 downto 0) := (others => '0');  -- ! Control lines that pulse high for one IPBus clock cycle
  signal hdmi0_data_in : std_logic_vector(2 downto 0);
  signal s_clock_status : std_logic_vector(c_BUSWIDTH-1 downto 0) := ( others => '0');  
                                        -- Copy of clock_status padded with zeros
  signal  s_external_reset_d1 , s_external_reset_d2 , s_external_reset_pulse : std_logic := '0';

  signal s_fsmStatus : std_logic_vector(1 downto 0);
  
  signal s_strobe : std_logic;
  signal s_lines_to_pulse : std_logic_vector( s_pulsed_lines'range );

  attribute mark_debug : string;
  attribute keep : string;
  attribute mark_debug of s_marocADCBusy , s_marocADCBusySummary , rst , s_marocMask , ipb_in , ipb_out: signal is "true";
  attribute keep of s_marocADCBusy , s_marocADCBusySummary , rst , s_marocMask , ipb_in , ipb_out: signal is "true";


begin

--  Generate HDMI I/O for debugging.
--  hdmi: entity work.generate_hdmi
--    port map (
--    clk_i => ipb_clk,
--    hdmi_input_signals => hdmi_input_signals,
--    hdmi_output_signals => hdmi_output_signals );

  -- connect up the HDMI data lines to buffers, to avoid synthesis problems.
  hdmi0_data0_buf :IBUFGDS
    port map
    (O  => hdmi0_data_in(0),
     I  => hdmi_input_signals.HDMI0_DATA_P(0),
     IB => hdmi_input_signals.HDMI0_DATA_N(0)
     );

  -- Fix Me....
  hdmi0_data_in(2) <= '0';
  --hdmi0_data2_buf :IBUFGDS
  --  port map
  --  (O  => hdmi0_data_in(2),
  --   I  => hdmi_input_signals.HDMI0_DATA_P(2),
  --   IB => hdmi_input_signals.HDMI0_DATA_N(2)
  --   );
          
  fabric: entity work.ipbus_fabric_sel
    generic map(
      NSLV => N_SLAVES,
      SEL_WIDTH => IPBUS_SEL_WIDTH )
    port map(
      sel => ipbus_sel_top_pc043a(ipb_in.ipb_addr),
      ipb_in => ipb_in,
      ipb_out => ipb_out,
      ipb_to_slaves => ipbw,
      ipb_from_slaves => ipbr
    );

  --! Slave 0: firmware ID etc
  slave0: entity work.ipbus_ver
    port map(
      ipbus_in => ipbw(N_SLV_FIRMWAREID),
      ipbus_out => ipbr(N_SLV_FIRMWAREID));

  --! Slave 1: 32b register ( output from FPGA to MAROC)
  slave1: entity work.ipbus_syncreg_v
    generic map(N_STAT => 0)
    port map(
      clk => ipb_clk,

      rst =>  rst,
      ipb_in => ipbw(N_SLV_GPIO),
      ipb_out => ipbr(N_SLV_GPIO),
      slv_clk   => clk_1x,
      q(0) => register_data
      );

  --! Slave 2: 32b register ( maroc select lines)
  slave2: entity work.ipbus_syncreg_v
    generic map(N_STAT => 0)
    port map(
      clk => ipb_clk,
      rst =>  rst,
      ipb_in => ipbw(N_SLV_SELECT),
      ipb_out => ipbr(N_SLV_SELECT),
      slv_clk   => clk_1x,
      q(0) => s_marocSelect
      );
  
  maroc_input_signals.maroc_select <= s_marocSelect( maroc_input_signals.maroc_select'range);

    --! Slave 3: 32b register ( maroc mask lines)
  slave3: entity work.ipbus_syncreg_v
    generic map(N_STAT => 0)
    port map(
      clk => ipb_clk,
      rst =>  rst,
      ipb_in => ipbw(N_SLV_MASK),
      ipb_out => ipbr(N_SLV_MASK),
      slv_clk   => clk_1x,
      q(0) => s_marocMask  
      );

  -- Slave 4: reset signal
  slave4: entity work.ipbus_syncreg_v
    generic map(N_STAT => 1)
    port map(
      clk => ipb_clk,
      rst =>  rst,
      ipb_in => ipbw(N_SLV_CONTROLREG),
      ipb_out => ipbr(N_SLV_CONTROLREG),
      slv_clk   => clk_1x,
      stb(0) => s_strobe,
      q(0)   => s_lines_to_pulse ,
      d(0)   => s_clock_status 
      );

    s_pulsed_lines <= s_lines_to_pulse when (s_strobe='1') else (others=> '0');

  --slave4: entity work.ipbus_pulseout_datain
  --port map (
  --  clk => ipb_clk,
  --  ipbus_in => ipbw(N_SLV_CONTROLREG),
  --  ipbus_out => ipbr(N_SLV_CONTROLREG),
  --  slv_clk   => clk_1x,
  --  q_out => (s_pulsed_lines),
  --  d_in => (s_clock_status)
  --  );

  -- Copy clock_status to s_clock_status and pad with zeros.
  s_clock_status(clock_status'range) <= clock_status;
  s_clock_status(s_clock_status'high downto clock_status'high+1) <= (others => '0');
  

  

--maroc_input_signals.maroc_mask <= s_marocMask( maroc_input_signals.maroc_mask'range);
  
-- Connect up data to MAROC from FPGA
--
  maroc_input_signals.en_otaq_2v5    <= register_data(2);
  
  p_sample_reset: process ( clk_1x )
    begin
      if rising_edge(ipb_clk) then
        s_external_reset_d1 <=  gpio_i(6);
        s_external_reset_d2 <=  s_external_reset_d1;
        s_external_reset_pulse <= s_external_reset_d1 and not s_external_reset_d2;
        s_logic_reset <= s_pulsed_lines(0) or s_external_reset_pulse;
      end if;
    end process p_sample_reset;
      
  -- connect up MAROC "40MHz" clock
  maroc_input_signals.CK_40M <= clk_1x;
  
  --! Slave 5: slow control shift register controller
  slave5: entity work.ipbusMarocShiftReg
    generic map(
      g_NBITS    => 829,  --! Number of bits to shift out to MAROC
      g_NWORDS   => c_NWORDS,    --! Number of words in IPBUS space to store data
      --! Number of bits in clock divider between system clock and clock to shift reg
      g_CLKDIVISION => 4,
      g_ADDRWIDTH => 5 )
    port map(
      -- signals to IPBus
      clk_i => ipb_clk,
      reset_i  => rst,
      ipbus_i  => ipbw(N_SLV_SCSR),
      ipbus_o  => ipbr(N_SLV_SCSR),

      -- Signals to MAROC
      clk_sr_o => maroc_input_signals.ck_sc_2v5,
      d_sr_o   => maroc_input_signals.d_sc_2v5,
      q_sr_i   => maroc_output_signals.q_sc_2v5,
      rst_sr_n_o => maroc_input_signals.rst_sc_2v5_n
      );

  --! Slave 6: "R" register shift register controller
  slave6: entity work.ipbusMarocShiftReg
    generic map(
      g_NBITS    => 128,  --! Number of bits to shift out to MAROC
      g_NWORDS   => c_NWORDS,    --! Number of words in IPBUS space to store data
      --! Number of bits in clock divider between system clock and clock to shift reg
      g_CLKDIVISION => 4,
      g_ADDRWIDTH => 5 )
    port map(

      -- signals to IPBus
      clk_i => ipb_clk,
      reset_i  => rst,
      ipbus_i  => ipbw(N_SLV_RSR),
      ipbus_o  => ipbr(N_SLV_RSR),

      -- Signals to MAROC
      clk_sr_o => maroc_input_signals.ck_r_2v5,
      d_sr_o   => maroc_input_signals.d_r_2v5,
      q_sr_i   => maroc_output_signals.q_r_2v5,
      rst_sr_n_o => maroc_input_signals.rst_r_2v5_n
      );

  --! Slave 7: Trigger generator
  slave7: entity work.ipbusFiveMarocTriggerGenerator
    generic map (
      g_NCLKS => c_NCLKS)
    port map (
      -- signals to IPBus
      clk_1x_i => clk_1x,
      reset_i  => rst,
      ipb_clk_i  => ipb_clk,
      control_ipbus_i  => ipbw(N_SLV_TRIGGERCTRL),
      control_ipbus_o  => ipbr(N_SLV_TRIGGERCTRL),
      data_ipbus_i  => ipbw(N_SLV_TRIGGERDATA),
      data_ipbus_o  => ipbr(N_SLV_TRIGGERDATA),

      logic_reset_i => s_logic_reset,
      
      -- Signals to MAROC and ADC controller
      adcBusy_i            =>  s_marocADCBusySummary,
      adcConversionStart_o => s_adcConversionStart,
      triggerNumber_o => s_triggerNumber ,
      timeStamp_o => s_timeStamp ,

      -- Fast clock and external trigger signals
      clk_16x_i           => clk_16x_i,
      clk_8x_i        => clk_8x_i,
     
      externalHdmiTrigger_a_i  => externalHdmiTrigger_a_i,  -- use this for trigger on HDMI      
      externalGpioTrigger_a_i  => gpio_i(7),  -- use this for trigger on GPIO pins
      externalTrigger_o    => s_externalTrigger_o,

      -- Signals from/to MAROC
      or1_a_i              => maroc_output_signals.OR0_2V5,
      or2_a_i              => maroc_output_signals.OR1_2V5,
      hold1_o              => maroc_input_signals.hold1_2v5,
      hold2_o              => maroc_input_signals.hold2_2v5,

      -- OR1,2 trigger signals to/from neighbouring FPGA
      hdmi_inout_signals_p => hdmi_inout_signals_p,
      hdmi_inout_signals_n => hdmi_inout_signals_n,

      fsmStatus_o          => s_fsmStatus,
      or1_from_neighbour_o => gpio_o(3),
      or1_to_neighbour_o   => gpio_o(4)
      
    );

  externalTrigger_o    <= s_externalTrigger_o;

  --! purpose: combine the busy signal from each MAROC ADC interface
  s_marocADCBusySummary <= (s_marocADCBusy(0) and s_marocMask(0)) or
                           (s_marocADCBusy(1) and s_marocMask(1)) or
                           (s_marocADCBusy(2) and s_marocMask(2)) or
                           (s_marocADCBusy(3) and s_marocMask(3)) or
                           (s_marocADCBusy(4) and s_marocMask(4)) ;

  --! combine the startADC signals coming from ADC controllers onto single signal.
  --! these signals are active low, so use "and" rather than "or"
  maroc_input_signals.START_ADC_2V5_N <= s_marocStartADC(0) and
                                         s_marocStartADC(1) and
                                         s_marocStartADC(2) and
                                         s_marocStartADC(3) and
                                         s_marocStartADC(4) ;

  --! combine the reset-ADC signals coming from ADC controllers onto single signal.
  maroc_input_signals.RST_ADC_2V5_N <= s_marocResetADC(0) and
                                       s_marocResetADC(1) and
                                       s_marocResetADC(2) and
                                       s_marocResetADC(3) and
                                       s_marocResetADC(4) ;
    
  -- Instantiate one ADC controller for each MAROC
  maroc_adc: for iMaroc in 0 to c_NMAROC-1 generate

    --! Slave 8-12: Simple ADC controller
    slave_adc: entity work.ipbusMarocADC
      generic map(
        g_ADDRWIDTH => 9,
        g_IDENT => X"000ADC" & std_logic_vector(to_unsigned(iMaroc,8))
		  )
      port map(

        -- signals to IPBus
        -- CHANGEME - move to separate ADC and IPBus clocks
        clk_i => ipb_clk,
        --clk_i => clk_1x,
        --ipb_clk => ipb_clk,
        reset_i  => rst,
        
        control_ipbus_i  => ipbw( (2*iMaroc) + N_SLV_ADC0CTRL),
        control_ipbus_o  => ipbr( (2*iMaroc) + N_SLV_ADC0CTRL),

        data_ipbus_i     => ipbw( (2*iMaroc) + N_SLV_ADC0DATA),
        data_ipbus_o     => ipbr( (2*iMaroc) + N_SLV_ADC0DATA),

        logic_reset_i => s_logic_reset,

        -- Signals to/from trigger controller
        adcStatus_o          => s_marocADCBusy(iMaroc),
        adcConversionStart_i => s_adcConversionStart and s_marocMask(iMaroc),
        triggerNumber_i => s_triggerNumber ,
        timeStamp_i => s_timeStamp ,
       
        -- Signals to MAROC
        START_ADC_N_O => s_marocStartADC(iMaroc),
        RST_ADC_N_O => s_marocResetADC(iMaroc),
        ADC_DAV_I => maroc_output_signals.ADC_DAV_2V5(iMaroc),
        OUT_ADC_I => maroc_output_signals.OUT_ADC_2V5(iMaroc)
        );
    
    end generate maroc_adc;

  -- Slave 13: MAC host interface
  -- Redundant. Removed.

    -- connect up output from MAROC to GPIO pins...
-- ( connect up 0-2 at top level )
--  gpio_o(3) <= maroc_output_signals.ADC_DAV_2V5(0);
--  gpio_o(4) <= maroc_output_signals.OUT_ADC_2V5(0);
    gpio_o(5) <= s_externalTrigger_o;
--    gpio_o(3) <= s_fsmStatus(0);
--    gpio_o(4) <= s_fsmStatus(1);
--  gpio_o(5) <= s_marocADCBusySummary;
    
  --maroc_input_signals.ctest_2v5      <= gpio_i(6);
    
end rtl;

