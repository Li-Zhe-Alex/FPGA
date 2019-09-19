--------------------------------------------------------------------------------
-- Project     : versuch1
-- Module      : 4-Bit-counter-testbench
-- Filename    : sync_counter_tb.vhdl
-- 
-- Authors     : Li,Zhe
-- Created     : 2017-10-21
-- Last Update : 2017-10-23
--
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sync_counter_tb is
-- leer
end sync_counter_tb;

ARCHITECTURE rtl OF sync_counter_tb IS    

COMPONENT sync_counter
	PORT (
	clock : IN STD_uLOGIC;
	clock_enable : IN STD_uLOGIC;
	q : OUT STD_uLOGIC_VECTOR(3 DOWNTO 0);
	reset : IN STD_uLOGIC
	);
END COMPONENT;

SIGNAL clock : STD_uLOGIC:= '0';
SIGNAL clock_enable: STD_uLOGIC:= '0';
SIGNAL q : STD_uLOGIC_VECTOR(3 DOWNTO 0);
SIGNAL reset : STD_uLOGIC:= '1';
constant T : time := 100 ns;

begin
DUT : sync_counter port map (
clock=>clock,
clock_enable=>clock_enable,
reset=>reset,
q=>q
 );

clk_process:process
begin
   clock  <= '0';
   wait for T/2;
   clock  <= '1';
   wait for T/2;
end process;
Stimulus_process:process
begin
clock_enable <= '0';
reset <= '1';
wait for 135 ns;
clock_enable <= '1';
wait for 870 ns;
reset <= '0';

wait;
end process;
end rtl;