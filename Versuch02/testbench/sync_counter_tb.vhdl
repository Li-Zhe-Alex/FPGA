--------------------------------------------------------------------------------
-- Project     : versuch2
-- Module      : sync_counter_tb
-- Filename    : sync_counter_tb.vhdl
-- 
-- Authors     : Li,Zhe
-- Created     : 2017-10-25
-- Last Update : 2017-10-26
--
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sync_counter_tb is
-- leer
end sync_counter_tb;

ARCHITECTURE rtl OF sync_counter_tb IS    
COMPONENT sync_counter_func
port(
    clock   	    : in  std_ulogic;
    clock_enable    : in  std_ulogic;
    reset           : in  std_ulogic;
    q               : out std_ulogic_vector(3 downto 0)
);
end component;

signal clock_wire : STD_uLOGIC:= '0';
signal clock_enable_wire: STD_uLOGIC:= '0';
signal q_wire : STD_uLOGIC_VECTOR(3 DOWNTO 0);
signal reset_wire : STD_uLOGIC:= '1';
constant T : time := 100 ns;

begin
DUT : sync_counter_func port map (
clock => clock_wire,
clock_enable => clock_enable_wire,
reset => reset_wire,
q => q_wire
 );
clk_process:process
  begin
clock_wire<='0';
  wait for T/2;
clock_wire<='1';
  wait for T/2;
  end process;
Stimulus_process:process
  begin
clock_enable_wire<='0';
reset_wire<='0';
  wait for 135 ns;
clock_enable_wire<='1';
  wait for 2070 ns;
reset_wire<='1';
  wait;
end process;
end rtl;
