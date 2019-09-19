--------------------------------------------------------------------------------
-- Project     : versuch3a
-- Module      : testbench
-- Filename    : async_adder_tb.vhdl
-- 
-- Authors     : Li,Zhe
-- Created     : 2017-10-31
-- Last Update : 2017-10-31
--
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity async_adder_tb is
end async_adder_tb;

ARCHITECTURE rtl OF async_adder_tb IS    

COMPONENT async_adder
	PORT (
    OpA: in std_logic_vector(3 downto 0);
    OpB: in std_logic_vector(3 downto 0);

    output: out std_ulogic_vector(4 downto 0)
	);
END COMPONENT;
SIGNAL OpA:  std_logic_vector(3 downto 0);
SIGNAL OpB:  std_logic_vector(3 downto 0);
SIGNAL output:  std_ulogic_vector(4 downto 0);
SIGNAL clk : STD_uLOGIC:= '0';
SIGNAL rst : STD_uLOGIC:= '0';
constant T : time := 100 ns;

begin
DUT : async_adder port map (

OpA=>OpA,
OpB=>OpB,
Output=>Output
 );

Stimulus_process:process
  begin
OpA<="1000";
OpB<="1000";
  wait for 500 ns;
OpA<="0101";
OpB<="1001";
  wait for 500 ns;
OpA<="0111";
OpB<="0111";
  wait for 500 ns;

  end process;
end rtl;

