--------------------------------------------------------------------------------
-- Project     : versuch3
-- Module      : sync_adder_top
-- Filename    : adder_demo.vhdl
-- 
-- Authors     : Li,Zhe
-- Created     : 2017-10-29
-- Last Update : 2017-10-30
--
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adder_demo is
port (
  clk,key3 : in std_ulogic; 
  SW: in std_logic_vector(7 downto 0);
  hex0: out std_ulogic_vector(6 downto 0);
  hex1: out std_ulogic_vector(6 downto 0);
  hex2: out std_ulogic_vector(6 downto 0)  
);
end adder_demo;

architecture rtl of adder_demo is
  COMPONENT sync_adder
	PORT (
    OpA: in std_logic_vector(3 downto 0);
    OpB: in std_logic_vector(3 downto 0);
    rst, clk : in std_ulogic;
    output: out std_ulogic_vector(4 downto 0)
);

  END COMPONENT;
  
  COMPONENT segment_decoder
	PORT (
    data   : in  std_ulogic_vector(4 downto 0);
    hex0_n : out std_ulogic_vector(6 downto 0);
	hex1_n : out std_ulogic_vector(6 downto 0);
	hex2_n : out std_ulogic_vector(6 downto 0)
	);
  END COMPONENT;
  
signal output_wire:  std_ulogic_vector(4 downto 0) ;


begin

  sa: sync_adder
  port map(
  SW(3 downto 0),
  SW(7 downto 4),  
  key3 , 
  clk,
  output_wire);
  
  sd: segment_decoder
  port map(
  output_wire, hex0, hex1, hex2);
  
end rtl;
  
  