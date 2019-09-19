-----------------------------------------------------------
-- Institute of Microelectronic Systems
-- Architectures and Systems
-- Leibniz Universitaet Hannover
-----------------------------------------------------------
-- lab :         Design Methods for FPGAs
-- file :        uart_tester.vhdl
-- authors :     Jan Duerre
-- last update : 27.11.2015
-- description : This module simulates an uart-sender
-----------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga_audiofx_pkg.all;

library std;
use std.textio.all;

entity uart_tester is
  generic (
    COMMAND_FILE : string := "../testbench/uart_commands.txt"
    );
  port (
    -- global signals
    clock : in  std_ulogic;
    reset : in  std_ulogic;
    -- uart signals
    rxd   : in  std_ulogic;
    txd   : out std_ulogic
    );
end uart_tester;

architecture rtl of uart_tester is

  file infile : text open read_mode is COMMAND_FILE;

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

  signal data_out       : std_ulogic_vector(7 downto 0);
  signal data_out_valid : std_ulogic;
  signal data_out_ack   : std_ulogic;

begin

  uart_transceiver_inst : uart_transceiver
    port map (
      clock         => clock,
      reset         => reset,
      rx_data       => open,
      rx_data_valid => open,
      tx_data       => data_out,
      tx_data_valid => data_out_valid,
      tx_data_ack   => data_out_ack,
      rxd           => rxd,
      txd           => txd
      );

  read_file : process
    variable active_line : line;
    variable char        : character;
    variable read_ok     : boolean;
  begin

    data_out_valid <= '0';

    wait for 200 ns;
    wait until clock = '0';

    --until end of file
    while not endfile(infile) loop
      --read new line
      readline(infile, active_line);

      --start of line
      read_ok := true;
      --until end of line
      while read_ok loop
        --read char
        read(active_line, char, read_ok);

        if read_ok then

                                        --send out
          data_out <= std_ulogic_vector(to_unsigned(character'pos(char), data_out'length));

                                        -- write to uart-module, when ready
          while data_out_ack = '0' loop
            wait for 20 ns;
          end loop;
          data_out_valid <= '1';
          wait for 20 ns;
          data_out_valid <= '0';

        end if;

      end loop;

      --send out CR
      data_out <= x"0D";

      -- write to uart-module, when ready
      while data_out_ack = '0' loop
        wait for 20 ns;
      end loop;
      data_out_valid <= '1';
      wait for 20 ns;
      data_out_valid <= '0';

    end loop;

    wait;

  end process;

end architecture rtl;
