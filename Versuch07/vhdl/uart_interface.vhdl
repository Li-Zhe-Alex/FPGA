------------------------------------------------
--      Institute of Microelectronic Systems
--      Architectures and Systems
--      Leibniz Universitaet Hannover
------------------------------------------------
--      lab :         Design Methods for FPGAs
--      file :        fpga_audiofx.vhdl
--      authors :     Jan Duerre
--      last update : 04.09.2014
--      description : UART interface wrapper
------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga_audiofx_pkg.all;

entity uart_interface is
  port (
    clock          : in  std_ulogic;
    reset          : in  std_ulogic;
    -- uart signals
    rxd            : in  std_ulogic;
    txd            : out std_ulogic;
    -- regif interface signals
    regif_cs       : out std_ulogic_vector(REGIF_MODULE_RANGE-1 downto 0);
    regif_wen      : out std_ulogic;
    regif_addr     : out std_ulogic_vector(REGIF_ADDR_WIDTH-1 downto 0);
    regif_data_in  : out std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0);
    regif_data_out : in  std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0)
    );
end uart_interface;

architecture rtl of uart_interface is

  component uart_transceiver is
    port (
      clock         : in  std_ulogic;
      reset         : in  std_ulogic;
      rx_data       : out std_ulogic_vector(7 downto 0);
      rx_data_valid : out std_ulogic;
      tx_data       : in  std_ulogic_vector(7 downto 0);
      tx_data_valid : in  std_ulogic;
      tx_data_ack   : out std_ulogic;
      rxd           : in  std_ulogic;
      txd           : out std_ulogic
      );
  end component uart_transceiver;

  component uart_regif_converter is
    port (
      clock          : in  std_ulogic;
      reset          : in  std_ulogic;
      rx_data        : in  std_ulogic_vector(7 downto 0);
      rx_data_valid  : in  std_ulogic;
      tx_data        : out std_ulogic_vector(7 downto 0);
      tx_data_valid  : out std_ulogic;
      tx_data_ack    : in  std_ulogic;
      regif_cs       : out std_ulogic_vector(REGIF_MODULE_RANGE-1 downto 0);
      regif_wen      : out std_ulogic;
      regif_addr     : out std_ulogic_vector(REGIF_ADDR_WIDTH-1 downto 0);
      regif_data_in  : out std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0);
      regif_data_out : in  std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0)
      );
  end component uart_regif_converter;

  -- inter-module signals
  signal rx_data       : std_ulogic_vector(7 downto 0);
  signal rx_data_valid : std_ulogic;
  signal tx_data       : std_ulogic_vector(7 downto 0);
  signal tx_data_valid : std_ulogic;
  signal tx_data_ack   : std_ulogic;

begin

  uart_transceiver_inst : uart_transceiver
    port map (
      clock         => clock,
      reset         => reset,
      rx_data       => rx_data,
      rx_data_valid => rx_data_valid,
      tx_data       => tx_data,
      tx_data_valid => tx_data_valid,
      tx_data_ack   => tx_data_ack,
      rxd           => rxd,
      txd           => txd
      );

  uart_regif_converter_inst : uart_regif_converter
    port map (
      clock          => clock,
      reset          => reset,
      rx_data        => rx_data,
      rx_data_valid  => rx_data_valid,
      tx_data        => tx_data,
      tx_data_valid  => tx_data_valid,
      tx_data_ack    => tx_data_ack,
      regif_cs       => regif_cs,
      regif_wen      => regif_wen,
      regif_addr     => regif_addr,
      regif_data_in  => regif_data_in,
      regif_data_out => regif_data_out
      );

end rtl;


