library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera;
use altera.altera_primitives_components.all;

entity ff_jk is
  port(
    j    : in  std_ulogic;
    k    : in  std_ulogic;
    clk  : in  std_ulogic;
    ena  : in  std_ulogic;
    clrn : in  std_ulogic;
    prn  : in  std_ulogic;
    q    : out std_ulogic
    );
end ff_jk;

architecture rtl of ff_jk is

  component jkffe
    port(
      j, k, clk, ena, clrn, prn : in  std_logic;
      q                         : out std_logic);
  end component;

  signal j_wire, k_wire, clk_wire, ena_wire, clrn_wire, prn_wire, q_wire : std_logic;

begin

  jkffe_inst : jkffe
    port map(
      j => j_wire, k => k_wire, clk => clk_wire, ena => ena_wire, clrn => clrn_wire, prn => prn_wire, q => q_wire
      );

  j_wire    <= std_logic(j);
  k_wire    <= std_logic(k);
  clk_wire  <= std_logic(clk);
  ena_wire  <= std_logic(ena);
  clrn_wire <= std_logic(clrn);
  prn_wire  <= std_logic(prn);
  q         <= std_ulogic(q_wire);

end rtl;
