--------------------------------------------------------------------------------
-- Project     : versuch3
-- Module      : sync_adder_tb
-- Filename    : sync_adder_tb.vhdl
-- 
-- Authors     : Li,Zhe
-- Created     : 2017-10-29
-- Last Update : 2017-10-30
--
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sync_adder_tb is
end sync_adder_tb;

ARCHITECTURE rtl OF sync_adder_tb IS    

COMPONENT sync_adder
	PORT (
OpA: in std_logic_vector(3 downto 0);
OpB: in std_logic_vector(3 downto 0);
rst, clk : in std_ulogic;
output: out std_ulogic_vector(4 downto 0)

	);
END COMPONENT;

signal clk:std_ulogic :='0';
signal rst :std_ulogic :='0';
signal OpA:std_logic_vector(3 downto 0);
signal OpB:std_logic_vector(3 downto 0);
signal output:std_ulogic_vector(4 downto 0);
constant T: time:=100 ns;

begin
DUT: sync_adder port map(
clk=>clk,
rst=>rst,
OpA=>OpA,
OpB=>OpB,
output=>output
);

clk_process: process
begin
clk <= '0';
wait for T/2;
clk <='1';
wait for T/2;
end process;

stimulus_process: process
begin
wait for 250 ns;
rst <= '0';
wait for 50 ns;
OPA<="1000";
OPB<="1000";
wait for 500 ns;
OPA<="0101";
OPB<="1010";
wait for 500 ns;
OPA<="0111";
OPB<="0111";
wait for 500 ns;
OPA<="0111";
OPB<="1111";
wait for 500 ns;
OPA<="0111";
OPB<="0111";
wait for 370 ns;
rst  <= '1';
wait;
end process;

end rtl;



