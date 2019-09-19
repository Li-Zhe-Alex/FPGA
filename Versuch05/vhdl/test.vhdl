--------------------------------------------------------------------------------
-- Project     : versuch5
-- Module      : test
-- Filename    : test.vhdl
-- 
-- Authors     : Li,Zhe
-- Created     : 2017-11-16
-- Last Update : 2017-11-19
--
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity test is
generic(
SAMPLE_WIDTH : natural :=15;
QTBITNUM : natural := 6
);
port(
clock   : in  std_ulogic;
reset   : in  std_ulogic;
ain_sync: in  std_ulogic;
ain_data: in  std_ulogic;
aout_sync: out std_ulogic;
aout_data: out std_ulogic
);
end entity test;

architecture rtl of test is
	component s2p_unit is
		port(
		clock     : in  std_ulogic;
		reset     : in  std_ulogic;
    -- serial audio-data signals
		ain_sync  : in  std_ulogic;
		ain_data  : in  std_ulogic;
    -- parallel audio-data signals
		smp_valid : out std_ulogic;
		smp_ack   : in  std_ulogic;
		smp_data  : out std_ulogic_vector(SAMPLE_WIDTH-1 downto 0)
		);
	end component s2p_unit;

	component p2s_unit is
		port(
		clock     : in  std_ulogic;
		reset     : in  std_ulogic;
    -- parallel audio-data signals
		smp_valid : in  std_ulogic;
		smp_ack   : out std_ulogic;
		smp_data  : in  std_ulogic_vector(SAMPLE_WIDTH-1 downto 0);
    -- serial audio-data signals
		aout_sync : out std_ulogic;
		aout_data : out std_ulogic
		);
	end component p2s_unit;

	signal smp_valid : std_ulogic;
	signal smp_ack   : std_ulogic;
	signal smp_data  : std_ulogic_vector(15 downto 0);

begin
	s2p: s2p_unit
		port map(
		clock => clock,
		reset => reset,
		ain_sync => ain_sync,
		ain_data => ain_data,
		smp_valid=> smp_valid,
		smp_ack  => smp_ack,
		smp_data => smp_data
		);
	p2s: p2s_unit
		port map(
		clock => clock,
		reset => reset,
		aout_sync => aout_sync,
		aout_data => aout_data,
		smp_valid=> smp_valid,
		smp_ack  => smp_ack,
		smp_data => smp_data
--		smp_data  => quat_out,
--		smp_data  => multi_out,
		);
		
--		Quantisierung: process(smp_data, quat_in, quat_out)
--		  begin
--		  quat_in <= resize(signed(smp_data), QTBITNUM);
--		  quat_out <= std_ulogic_vector(resize(signed(quat_in), 16));
--		end process;
		--
--		Multiplikation: process(smp_data, multi_out)
--		  begin
--		  multi_out <= std_ulogic_vector(shift_left(signed(smp_data),3)+shift_left(signed(smp_data),1));
--		end process;
end rtl;
