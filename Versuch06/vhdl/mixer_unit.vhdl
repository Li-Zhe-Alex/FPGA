--------------------------------------------------------------------------------
-- Project     : versuch6
-- Module      : mixer_unit
-- Filename    : mixer_unit.vhdl
-- 
-- Authors     : Li,Zhe
-- Created     : 2017-11-24
-- Last Update : 2017-11-30
--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga_audiofx_pkg.all;

entity mixer_unit is
  port (
    clock     : in  std_ulogic;
    reset     : in  std_ulogic;
    -- serial audio-data inputs 
    ain_sync  : in  std_ulogic_vector(1 downto 0);
    ain_data  : in  std_ulogic_vector(1 downto 0);
    -- serial audio-data output
    aout_sync : out std_ulogic;
    aout_data : out std_ulogic
    );
end entity mixer_unit;

architecture rtl of mixer_unit is
	component s2p_unit
	port (
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
	end component;
	
	component p2s_unit
	port (
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
	end component;
	
	signal channel_a_smp_valid : std_ulogic;
	signal channel_a_smp_data : std_ulogic_vector(15 downto 0);
	signal channel_a_smp_ack : std_ulogic;
	signal channel_b_smp_valid : std_ulogic;
	signal channel_b_smp_data : std_ulogic_vector(15 downto 0);
	signal channel_b_smp_ack : std_ulogic;
	signal mix_smp_valid : std_ulogic;
	signal mix_smp_data : std_ulogic_vector(sample_width-1 downto 0);
	signal mix_smp_ack : std_ulogic;
	
	begin
	s2p_a: s2p_unit
	port map(
	clock => clock,
	reset => reset,
	ain_sync => ain_sync(0),
	ain_data => ain_data(0),
	smp_valid => channel_a_smp_valid,
	smp_ack   => channel_a_smp_ack,
	smp_data  => channel_a_smp_data
	);
	
	s2p_b: s2p_unit
	port map(
	clock => clock,
	reset => reset,
	ain_sync => ain_sync(1),
	ain_data => ain_data(1),
	smp_valid => channel_b_smp_valid,
	smp_ack   => channel_b_smp_ack,
	smp_data  => channel_b_smp_data
	);
	
	p2s: p2s_unit
	port map(
	clock => clock,
	reset => reset,
	smp_valid => mix_smp_valid,
	smp_ack   => mix_smp_ack,
	smp_data  => mix_smp_data,
	aout_sync => aout_sync,
	aout_data => aout_data
	);
	
	mix: process(channel_a_smp_valid, channel_b_smp_valid, mix_smp_ack, channel_a_smp_data, channel_b_smp_data)
	begin
		channel_a_smp_ack <= '0';
		channel_b_smp_ack <= '0';
		mix_smp_valid         <= '0';
		mix_smp_data        <= (others => '0');
		if channel_a_smp_valid = '1' and channel_b_smp_valid = '1' and mix_smp_ack = '1' then
			channel_a_smp_ack <= '1';
			channel_b_smp_ack <= '1';
			mix_smp_valid     <= '1';
			mix_smp_data <= std_ulogic_vector(signed(channel_a_smp_data)+signed(channel_b_smp_data));
		end if;
	end process;
end rtl;
	