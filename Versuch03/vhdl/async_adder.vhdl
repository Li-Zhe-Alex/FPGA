--------------------------------------------------------------------------------
-- Project     : versuch3a
-- Module      : async_adder
-- Filename    : async_adder.vhdl
-- 
-- Authors     : Li,Zhe
-- Created     : 2017-10-31
-- Last Update : 2017-10-31
--
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity async_adder is
port(
OpA: in std_logic_vector(3 downto 0);
OpB: in std_logic_vector(3 downto 0);
output: out std_ulogic_vector(4 downto 0)
);
end async_adder;

architecture async of async_adder is
begin

output <= std_ulogic_vector(resize(signed(OpA),5) + resize(signed(OpB),5));

end async;
