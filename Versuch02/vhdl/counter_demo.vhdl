--------------------------------------------------------------------------------
-- Project     : versuch2
-- Module      : Top
-- Filename    : counter_demo.vhdl
-- 
-- Authors     : Li,Zhe
-- Created     : 2017-10-25
-- Last Update : 2017-10-26
--
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter_demo is
port (
  clk : in std_ulogic;
  key3 : in std_ulogic;
  hex0: out std_ulogic_vector(6 downto 0);
  hex1: out std_ulogic_vector(6 downto 0)
);
end counter_demo;

architecture rtl of counter_demo is
  COMPONENT sync_counter
	PORT (
	clock : IN STD_uLOGIC;
	clock_enable : IN STD_uLOGIC;
	q : OUT STD_uLOGIC_VECTOR(3 DOWNTO 0);
	reset : IN STD_uLOGIC
	);
  END COMPONENT;
  
  COMPONENT segment_decoder
	PORT (
    data   : in  std_ulogic_vector(3 downto 0);
    hex0_n : out std_ulogic_vector(6 downto 0);
    hex1_n : out std_ulogic_vector(6 downto 0)
	);
  END COMPONENT;
  
  COMPONENT enableGen
	PORT (
    resetValue_in   : in  std_ulogic_vector(25 downto 0);
    clk : IN STD_uLOGIC;
	 nReset : IN STD_uLOGIC;
	 clkEnable_out: OUT STD_uLOGIC
	);
  END COMPONENT;

signal q_wire : std_ulogic_vector(3 downto 0);
signal hex0_wire, hex1_wire :  std_ulogic_vector(6 downto 0);
signal clk_wire, clk_en_wire, reset_wire: std_ulogic ;


begin
sc:sync_counter
port map(
clk_wire, clk_en_wire, q_wire, reset_wire
);
sd:segment_decoder
port map(
q_wire, hex0_wire, hex1_wire
);
en:enableGen
port map(
"10111110101111000010000000",clk_wire, reset_wire, clk_en_wire
);

reset_wire <= not key3; clk_wire <= clk;
hex0 <= hex0_wire; hex1 <= hex1_wire;

end rtl;