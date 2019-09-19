--------------------------------------------------------------------------------
-- Project     : versuch1
-- Module      : 4-Bit-counter
-- Filename    : sync_counter.vhdl
-- 
-- Authors     : Li,Zhe
-- Created     : 2017-10-21
-- Last Update : 2017-10-23
--
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sync_counter is
  port(
    clock   : in  std_ulogic;
    clock_enable    : in  std_ulogic;
    reset  : in  std_ulogic;
    q    : out std_ulogic_vector(3 downto 0)
    );
end sync_counter;

architecture rtl of sync_counter is
  component ff_jk
  port(
    j    : in  std_ulogic;
    k    : in  std_ulogic;
    clk  : in  std_ulogic;
    ena  : in  std_ulogic;
    clrn : in  std_ulogic;
    prn  : in  std_ulogic;
    q    : out std_ulogic
    );
  end component;

  signal input_wire, clk_wire, ena_wire, clrn_wire, prn_wire,  q01, q02 : std_ulogic;
  signal q_wire : std_ulogic_vector(3 downto 0);

begin
q01 <= q_wire(0) and q_wire(1);
q02 <= q01 and q_wire(2);
q <= q_wire;
input_wire <= '1';
clk_wire <= clock;
ena_wire <= clock_enable;
clrn_wire <= reset;
prn_wire <= '1';

jk0: ff_jk
port map(
input_wire, input_wire, clk_wire, ena_wire, clrn_wire, prn_wire, q_wire(0)
);
jk1: ff_jk
port map(
q_wire(0), q_wire(0), clk_wire, ena_wire, clrn_wire, prn_wire, q_wire(1)
);
jk2: ff_jk
port map(
q01, q01, clk_wire, ena_wire, clrn_wire, prn_wire, q_wire(2)
);
jk3: ff_jk
port map(
q02, q02, clk_wire, ena_wire, clrn_wire, prn_wire, q_wire(3)
);

end rtl;