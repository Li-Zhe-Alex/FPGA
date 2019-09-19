--------------------------------------------------------------------------------
-- Project     : versuch7
-- Module      : fpga_audiofx_top
-- Filename    : fpga_audiofx.vhdl
-- 
-- Authors     : Li,Zhe
-- Created     : 2017-12-15
-- Last Update : 2017-12-18
--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga_audiofx_pkg.all;

entity fpga_audiofx is
  port (
    -- global
    clock_ext_50   : in    std_ulogic;
    reset_n_extern : in    std_ulogic;
    -- audio codec
    wm8731_clk     : out   std_ulogic;
    i2s_sclk       : in    std_ulogic;
    i2s_adc_ws     : in    std_ulogic;
    i2s_adc_sdat   : in    std_ulogic;
    i2s_dac_ws     : in    std_ulogic;
    i2s_dac_sdat   : out   std_ulogic;
    i2c_sdat       : inout std_logic;
    i2c_sclk       : out   std_logic;
    -- uart
    uart_rxd       : in    std_ulogic;
    uart_txd       : out   std_ulogic
    );
end fpga_audiofx;

architecture rtl of fpga_audiofx is

  -- global signals
  component pll is
    port (
      areset : in  std_logic;
      inclk0 : in  std_logic;
      c0     : out std_logic;
      c1     : out std_logic;
      c2     : out std_logic;
      locked : out std_logic
      );
  end component pll;

  signal clock_50       : std_ulogic;
  signal clock_audio_12 : std_ulogic;
  signal reset_extern   : std_ulogic;
  signal reset_n        : std_ulogic;
  signal reset          : std_ulogic;

  -- internal audio connection signals
  component i2s_slave is
    port (
      clock           : in  std_ulogic;
      reset_n         : in  std_ulogic;
      i2s_sclk        : in  std_ulogic;
      i2s_adc_ws      : in  std_ulogic;
      i2s_adc_sdat    : in  std_ulogic;
      i2s_dac_ws      : in  std_ulogic;
      i2s_dac_sdat    : out std_ulogic;
      ain_left_sync   : out std_ulogic;
      ain_left_data   : out std_ulogic;
      ain_right_sync  : out std_ulogic;
      ain_right_data  : out std_ulogic;
      aout_left_sync  : in  std_ulogic;
      aout_left_data  : in  std_ulogic;
      aout_right_sync : in  std_ulogic;
      aout_right_data : in  std_ulogic
      );
  end component i2s_slave;

  signal ain_left_sync : std_ulogic;
  signal ain_left_data : std_ulogic;

  signal ain_right_sync : std_ulogic;
  signal ain_right_data : std_ulogic;

  signal aout_left_sync : std_ulogic;
  signal aout_left_data : std_ulogic;

  signal aout_right_sync : std_ulogic;
  signal aout_right_data : std_ulogic;

  -- connection signals between the WM8731-Configurator and I2C-Master
  component i2c_master is
    port (
      clock         : in    std_ulogic;
      reset_n       : in    std_ulogic;
      i2c_clk       : out   std_logic;
      i2c_dat       : inout std_logic;
      busy          : out   std_ulogic;
      cs            : in    std_ulogic;
      mode          : in    std_ulogic_vector(1 downto 0);
      slave_addr    : in    std_ulogic_vector(6 downto 0);
      bytes_tx      : in    unsigned(4 downto 0);
      bytes_rx      : in    unsigned(4 downto 0);
      tx_data       : in    std_ulogic_vector(7 downto 0);
      tx_data_valid : in    std_ulogic;
      rx_data       : out   std_ulogic_vector(7 downto 0);
      rx_data_valid : out   std_ulogic;
      rx_data_en    : in    std_ulogic;
      error         : out   std_ulogic
      );
  end component i2c_master;

  component wm8731_configurator is
    port(
      clock             : in  std_ulogic;
      reset_n           : in  std_ulogic;
      i2c_busy          : in  std_ulogic;
      i2c_cs            : out std_ulogic;
      i2c_mode          : out std_ulogic_vector(1 downto 0);
      i2c_slave_addr    : out std_ulogic_vector(6 downto 0);
      i2c_bytes_tx      : out unsigned(4 downto 0);
      i2c_bytes_rx      : out unsigned(4 downto 0);
      i2c_tx_data       : out std_ulogic_vector(7 downto 0);
      i2c_tx_data_valid : out std_ulogic;
      i2c_rx_data       : in  std_ulogic_vector(7 downto 0);
      i2c_rx_data_valid : in  std_ulogic;
      i2c_rx_data_en    : out std_ulogic;
      i2c_error         : in  std_ulogic;
      regif_cs          : in  std_ulogic;
      regif_wen         : in  std_ulogic;
      regif_addr        : in  std_ulogic_vector(REGIF_ADDR_WIDTH-1 downto 0);
      regif_data_in     : in  std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0);
      regif_data_out    : out std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0)
      );
  end component wm8731_configurator;

  signal i2c_busy          : std_ulogic;
  signal i2c_cs            : std_ulogic;
  signal i2c_mode          : std_ulogic_vector(1 downto 0);
  signal i2c_slave_addr    : std_ulogic_vector(6 downto 0);
  signal i2c_bytes_tx      : unsigned(4 downto 0);
  signal i2c_bytes_rx      : unsigned(4 downto 0);
  signal i2c_tx_data       : std_ulogic_vector(7 downto 0);
  signal i2c_tx_data_valid : std_ulogic;
  signal i2c_rx_data       : std_ulogic_vector(7 downto 0);
  signal i2c_rx_data_valid : std_ulogic;
  signal i2c_rx_data_en    : std_ulogic;
  signal i2c_error         : std_ulogic;

  -- register-interface signals
  component uart_interface is
    port (
      clock          : in  std_ulogic;
      reset          : in  std_ulogic;
      rxd            : in  std_ulogic;
      txd            : out std_ulogic;
      regif_cs       : out std_ulogic_vector(REGIF_MODULE_RANGE-1 downto 0);
      regif_wen      : out std_ulogic;
      regif_addr     : out std_ulogic_vector(REGIF_ADDR_WIDTH-1 downto 0);
      regif_data_in  : out std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0);
      regif_data_out : in  std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0)
      );
  end component uart_interface;

	component gain_control is
	generic (
    SHIFT_FACTOR : natural := 6
    );
  port (
    clock          : in  std_ulogic;
    reset          : in  std_ulogic;
    -- audio signals
    ain_sync       : in  std_ulogic;
    ain_data       : in  std_ulogic;
    aout_sync      : out std_ulogic;
    aout_data      : out std_ulogic;
    -- register interface
    regif_cs       : in  std_ulogic;
    regif_wen      : in  std_ulogic;
    regif_addr     : in  std_ulogic_vector(REGIF_ADDR_WIDTH-1 downto 0);
    regif_data_in  : in  std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0);
    regif_data_out : out std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0)
    );
end component gain_control;

  signal regif_cs       : std_ulogic_vector(REGIF_MODULE_RANGE-1 downto 0);
  signal regif_wen      : std_ulogic;
  signal regif_addr     : std_ulogic_vector(REGIF_ADDR_WIDTH-1 downto 0);
  signal regif_data_in  : std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0);
  signal regif_data_out : std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0);

	signal regif_data_out_left  : std_ulogic_vector(REGIF_DATA_WIDTH - 1 downto 0);
	signal regif_data_out_right : std_ulogic_vector(REGIF_DATA_WIDTH - 1 downto 0);
  signal regif_dout_ac : std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0);

begin

  -- invert reset-extern signal
  reset_extern <= not reset_n_extern;

  -- pll (clock_50, clock_audio_12, clock_sdram_100)
  pll_inst : pll
    port map(
      areset => reset_extern,
      inclk0 => clock_ext_50,
      c0     => clock_50,
      c1     => clock_audio_12,
      c2     => open,
      locked => reset_n
      );

  -- invert reset-intern signal
  reset      <= not reset_n;
  -- assign 12MHz-clock to WM8731
  wm8731_clk <= clock_audio_12;

  -- wm8731_configurator
  wm8731_configurator_inst : wm8731_configurator
    port map (
      clock             => clock_50,
      reset_n           => reset_n,
      i2c_busy          => i2c_busy,
      i2c_cs            => i2c_cs,
      i2c_mode          => i2c_mode,
      i2c_slave_addr    => i2c_slave_addr,
      i2c_bytes_tx      => i2c_bytes_tx,
      i2c_bytes_rx      => i2c_bytes_rx,
      i2c_tx_data       => i2c_tx_data,
      i2c_tx_data_valid => i2c_tx_data_valid,
      i2c_rx_data       => i2c_rx_data,
      i2c_rx_data_valid => i2c_rx_data_valid,
      i2c_rx_data_en    => i2c_rx_data_en,
      i2c_error         => i2c_error,
      regif_cs          => regif_cs(0),
      regif_wen         => regif_wen,
      regif_addr        => regif_addr,
      regif_data_in     => regif_data_in,
      regif_data_out    => regif_dout_ac
      );

  -- i2c master
  i2c_master_inst : i2c_master
    port map (
      clock         => clock_50,
      reset_n       => reset_n,
      i2c_clk       => i2c_sclk,
      i2c_dat       => i2c_sdat,
      busy          => i2c_busy,
      cs            => i2c_cs,
      mode          => i2c_mode,
      slave_addr    => i2c_slave_addr,
      bytes_tx      => i2c_bytes_tx,
      bytes_rx      => i2c_bytes_rx,
      tx_data       => i2c_tx_data,
      tx_data_valid => i2c_tx_data_valid,
      rx_data       => i2c_rx_data,
      rx_data_valid => i2c_rx_data_valid,
      rx_data_en    => i2c_rx_data_en,
      error         => i2c_error
      );

  -- i2s_slave
  i2s_slave_inst : i2s_slave
    port map (
      clock           => clock_50,
      reset_n         => reset_n,
      i2s_sclk        => i2s_sclk,
      i2s_adc_ws      => i2s_adc_ws,
      i2s_adc_sdat    => i2s_adc_sdat,
      i2s_dac_ws      => i2s_dac_ws,
      i2s_dac_sdat    => i2s_dac_sdat,
      ain_left_sync   => ain_left_sync,
      ain_left_data   => ain_left_data,
      ain_right_sync  => ain_right_sync,
      ain_right_data  => ain_right_data,
      aout_left_sync  => aout_left_sync,
      aout_left_data  => aout_left_sync,
      aout_right_sync => aout_right_sync,
      aout_right_data => aout_right_data
      );

  uart_interface_inst : uart_interface
    port map (
      clock          => clock_50,
      reset          => reset,
      rxd            => uart_rxd,
      txd            => uart_txd,
      regif_cs       => regif_cs,
      regif_wen      => regif_wen,
      regif_addr     => regif_addr,
      regif_data_in  => regif_data_in,
      regif_data_out => regif_data_out
      );

  regif_data_out <= std_ulogic_vector(signed(regif_dout_ac)+signed(regif_data_out_left)+signed(regif_data_out_right));
  
	gain_left: gain_control
	port map(
	clock => clock_50,
	reset => reset,
	ain_sync => ain_left_sync,
	ain_data => ain_left_data,
	aout_sync => aout_left_sync,
	aout_data => aout_left_data,
    regif_cs       => regif_cs(1),    
    regif_wen      => regif_wen,   
    regif_addr     => regif_addr,  
    regif_data_in  => regif_data_in,
    regif_data_out => regif_data_out_left
	);
	
	gain_right: gain_control
	port map(
	clock => clock_50,
	reset => reset,
	ain_sync => ain_right_sync,
	ain_data => ain_right_data,
	aout_sync => aout_right_sync,
	aout_data => aout_right_data,
	regif_cs       => regif_cs(6),  
    regif_wen      => regif_wen, 
    regif_addr     => regif_addr,
    regif_data_in  => regif_data_in,
    regif_data_out => regif_data_out_right
	);

end architecture rtl;
