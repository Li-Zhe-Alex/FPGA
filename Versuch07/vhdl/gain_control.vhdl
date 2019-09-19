--------------------------------------------------------------------------------
-- Project     : versuch7
-- Module      : gain_control
-- Filename    : gain_control.vhdl
-- 
-- Authors     : Li,Zhe
-- Created     : 2017-12-10
-- Last Update : 2017-12-18
--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga_audiofx_pkg.all;

entity gain_control is
  generic (
    SHIFT_FACTOR : natural := 6
    );
  port (
    clock          : in  std_ulogic;
    reset          : in  std_ulogic;
    -- audio signals
    ain_sync       : in  std_ulogic;
    ain_data       : in  std_ulogic;
    aout_sync      : out std_ulogic;
    aout_data      : out std_ulogic;
    -- register interface
    regif_cs       : in  std_ulogic;
    regif_wen      : in  std_ulogic;
    regif_addr     : in  std_ulogic_vector(REGIF_ADDR_WIDTH-1 downto 0);
    regif_data_in  : in  std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0);
    regif_data_out : out std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0)
    );
end entity gain_control;

architecture rtl of gain_control is
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
	end component s2p_unit;
	
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
	end component p2s_unit;
	
signal smp_valid    : std_ulogic;
signal smp_data     : std_ulogic_vector(SAMPLE_WIDTH-1 downto 0);
signal smp_ack      : std_ulogic;

signal gain_factor    : std_ulogic_vector(REGIF_DATA_WIDTH -1 downto 0);
signal gain_factor_next    : std_ulogic_vector(REGIF_DATA_WIDTH -1 downto 0);

signal regif_data_out_next      : std_ulogic_vector(REGIF_DATA_WIDTH -1 downto 0);
signal gain_data      : std_ulogic_vector(SAMPLE_WIDTH -1 downto 0);
signal gain_out_valid    : std_ulogic;
signal gain_out_ack      : std_ulogic;

signal gain_data_multi    : std_ulogic_vector(SAMPLE_WIDTH + REGIF_DATA_WIDTH downto 0);
signal gain_data_extend   : std_ulogic_vector(SAMPLE_WIDTH + REGIF_DATA_WIDTH downto 0);

begin
	register_interface_seq: process(clock, reset)
		begin
			if reset = '0' then
				gain_factor <=(others => '0');
				regif_data_out <= (others => '0');
			elsif rising_edge(clock) then
				gain_factor <= gain_factor_next;
				regif_data_out <= regif_data_out_next;
			end if;
	end process register_interface_seq;
	
	register_interface_komb: process(regif_addr, regif_cs, regif_data_in, regif_wen)
		begin
		if regif_cs = '1' then
			if regif_wen ='1' then
				if regif_addr = "00000000" then
					gain_factor_next <= regif_data_in;
				end if;
			else
				regif_data_out_next <= gain_factor;
			end if;
		else 
			regif_data_out_next <= (others => '0');
			
		end if;
	end process register_interface_komb;

	mult: process(smp_valid, smp_data, gain_factor, gain_out_ack)
	begin
		gain_data_multi <= (others => '0');
		if smp_valid = '1' and gain_out_ack = '1' then
			gain_data_multi <= std_ulogic_vector(signed(smp_data)*signed('0' & gain_factor));
			gain_out_valid <= '1';
			smp_ack <= '1';
		else
			gain_out_valid <= '0';
			smp_ack <= '0';
		end if;
	end process mult;
	
	gain_data_extend <= std_ulogic_vector(shift_right(signed(gain_data_multi), SHIFT_FACTOR));
	gain_data <= gain_data_extend(SAMPLE_WIDTH - 1 downto 0);
	
	s2p: s2p_unit
	port map(
	clock => clock,
	reset => reset,
	ain_sync  => ain_sync,
	ain_data  => ain_data,
	smp_valid => smp_valid,
	smp_ack   => smp_ack,
	smp_data  => smp_data
	);
	
	p2s: p2s_unit
	port map(
	clock => clock,
	reset => reset,
	smp_valid => gain_out_valid,
	smp_ack   => gain_out_ack,
	smp_data  => gain_data,	
	aout_sync  => aout_sync,
	aout_data  => aout_data
	);

end rtl;