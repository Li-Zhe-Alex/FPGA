--------------------------------------------------------------------------------
-- Project     : versuch8
-- Module      : delay_unit
-- Filename    : delay_unit.vhdl
-- 
-- Authors     : Li,Zhe
-- Created     : 2018-01-09
-- Last Update : 2018-01-18
--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga_audiofx_pkg.all;

entity delay_unit is
  generic (
    BASE_ADDR_0        : natural := 16#00000000#;
    BASE_ADDR_1        : natural := 16#01000000#;
    BUFFER_SIZE        : natural := 16#01000000#;
    DELAY_SHIFT_FACTOR : natural := 10;
	OUTPORTS           : natural := 5
    );
  port (
    clock               : in  std_ulogic;
    reset               : in  std_ulogic;
    -- audio signals
    ain_sync_0          : in  std_ulogic;
    ain_data_0          : in  std_ulogic;
    ain_sync_1          : in  std_ulogic;
    ain_data_1          : in  std_ulogic;
    aout_sync_0         : out std_ulogic_vector(OUTPORTS-1 downto 0);
    aout_data_0         : out std_ulogic_vector(OUTPORTS-1 downto 0);
    aout_sync_1         : out std_ulogic_vector(OUTPORTS-1 downto 0);
    aout_data_1         : out std_ulogic_vector(OUTPORTS-1 downto 0);
    -- register interface
    regif_cs            : in  std_ulogic;
    regif_wen           : in  std_ulogic;
    regif_addr          : in  std_ulogic_vector(REGIF_ADDR_WIDTH-1 downto 0);
    regif_data_in       : in  std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0);
    regif_data_out      : out std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0);
    -- sdram interface
    sdram_select        : out std_ulogic;
    sdram_write_en      : out std_ulogic;
    sdram_address       : out std_ulogic_vector(25 downto 0);
    sdram_data_in       : in  std_ulogic_vector(15 downto 0);
    sdram_data_out      : out std_ulogic_vector(15 downto 0);
    sdram_request_en    : out std_ulogic;
    sdram_req_slot_free : in  std_ulogic;
    sdram_data_avail    : in  std_ulogic
    );
end entity delay_unit;

architecture rtl of delay_unit is
	constant OUTPUT_DELAY_0_RANGE : std_ulogic_vector(7 downto 0) := std_ulogic_vector(to_unsigned(2 + OUTPORTS - 1, 8));
	constant OUTPUT_DELAY_1_RANGE : std_ulogic_vector(7 downto 0) := std_ulogic_vector(to_unsigned(2 + 2*OUTPORTS - 1, 8));
	
	type delay_array is array(OUTPORTS -1 downto 0) of std_ulogic_vector(7 downto 0);  --Aufgabe 2
	signal output_delay_0, output_delay_0_next : delay_array;
	signal output_delay_1, output_delay_1_next : delay_array;
	signal control_0, control_0_next           : std_ulogic_vector(7 downto 0);
	signal control_1, control_1_next           : std_ulogic_vector(7 downto 0);
	signal regif_data_out_next                 : std_ulogic_vector(7 downto 0);
	
	signal write_pointer_0, write_pointer_0_next : unsigned(25 downto 0); --Aufgabe 5
	signal write_pointer_1, write_pointer_1_next : unsigned(25 downto 0);
	type read_array is array (OUTPORTS - 1 downto 0) of unsigned(25 downto 0);
	signal read_pointer_0, read_pointer_0_next   : read_array;
	signal read_pointer_1, read_pointer_1_next   : read_array;
	signal inc_write_pointer_0                   : std_ulogic := '0';
	signal inc_write_pointer_1                   : std_ulogic := '0';
	
	signal max_write_pointer_0, max_write_pointer_0_next : unsigned(25 downto 0); --Aufgabe 7
	signal max_write_pointer_1, max_write_pointer_1_next : unsigned(25 downto 0);
	signal enough_samples_0                              : std_logic_vector(OUTPORTS - 1 downto 0);
	signal enough_samples_1                              : std_logic_vector(OUTPORTS - 1 downto 0);
	
	signal smp_valid_in_0  : std_ulogic; --Aufgabe 9
	signal smp_ack_in_0    : std_ulogic;
	signal smp_data_in_0   : std_ulogic_vector(SAMPLE_WIDTH - 1 downto 0);
	signal smp_valid_in_1  : std_ulogic;
	signal smp_ack_in_1    : std_ulogic;
	signal smp_data_in_1   : std_ulogic_vector(SAMPLE_WIDTH - 1 downto 0);
	signal smp_valid_out_0 : std_ulogic_vector(OUTPORTS - 1 downto 0);
	signal smp_ack_out_0   : std_ulogic_vector(OUTPORTS - 1 downto 0);
	signal smp_valid_out_1 : std_ulogic_vector(OUTPORTS - 1 downto 0);
	signal smp_ack_out_1   : std_ulogic_vector(OUTPORTS - 1 downto 0);
	type smp_data_out_array is array (OUTPORTS - 1 downto 0) of std_ulogic_vector(SAMPLE_WIDTH - 1 downto 0);
	signal smp_data_out_0  : smp_data_out_array;
	signal smp_data_out_1  : smp_data_out_array;
	
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
			smp_data  : out std_ulogic_vector(SAMPLE_WIDTH - 1 downto 0)
		);
	end component;

	component p2s_unit is
		port(
			clock     : in  std_ulogic;
			reset     : in  std_ulogic;
			-- parallel audio-data signals
			smp_valid : in  std_ulogic;
			smp_ack   : out std_ulogic;
			smp_data  : in  std_ulogic_vector(SAMPLE_WIDTH - 1 downto 0);
			-- serial audio-data signals
			aout_sync : out std_ulogic;
			aout_data : out std_ulogic
		);
	end component;
	
	signal port_cnt, port_cnt_next : unsigned(to_log2(OUTPORTS - 1) + 1 downto 0); --Aufgabe 10
	signal inc_port_cnt : std_ulogic;
	signal rst_port_cnt : std_ulogic;

	type states is (idle, write_data_0, request_data_0, wait_data_0, write_data_1, request_data_1, wait_data_1);
	signal state, state_next : states;
	
begin

  -- check valid generic-configuration
  assert ((OUTPORTS >= 1) and (OUTPORTS <= 7)) report "[Delay Unit] Illegal number of outports!" severity failure;
  assert (BASE_ADDR_0 /= BASE_ADDR_1) report "[Delay Unit] Buffer Base Addresses can't be identical!" severity failure;
  assert (BASE_ADDR_0 > BASE_ADDR_1) or ((BASE_ADDR_0 + BUFFER_SIZE - 1) < BASE_ADDR_1) report "[Delay Unit] Buffer Ranges do not match!" severity failure;
  assert (BASE_ADDR_0 < BASE_ADDR_1) or ((BASE_ADDR_1 + BUFFER_SIZE - 1) < BASE_ADDR_0) report "[Delay Unit] Buffer Ranges do not match!" severity failure;

	register_interface_seq: process(clock, reset)
	begin
		if reset ='1' then
			output_delay_0 <= (others => (others =>'0'));
			output_delay_1 <= (others => (others =>'0'));
			control_0      <= (others =>'0');
			control_1      <= (others =>'0');
			regif_data_out      <= (others => '0');
			read_pointer_0      <= (others => (others => '0'));
			read_pointer_1      <= (others => (others => '0'));
			write_pointer_0     <= to_unsigned(BASE_ADDR_0, 26);
			write_pointer_1     <= to_unsigned(BASE_ADDR_1, 26);
			max_write_pointer_0 <= (others => '0');
			max_write_pointer_1 <= (others => '0');
			port_cnt            <= (others => '0');
			state               <= idle;
		else
			output_delay_0 <= output_delay_0_next;
			output_delay_1 <= output_delay_1_next;
			control_0      <= control_0_next;
			control_1      <= control_1_next;
			regif_data_out      <= regif_data_out_next;
			read_pointer_0      <= read_pointer_0_next;
			read_pointer_1      <= read_pointer_1_next;
			write_pointer_0     <= write_pointer_0_next;
			write_pointer_1     <= write_pointer_1_next;
			max_write_pointer_0 <= max_write_pointer_0_next;
			max_write_pointer_1 <= max_write_pointer_1_next;
			port_cnt            <= port_cnt_next;
			state               <= state_next;
		end if;
	end process register_interface_seq;
	
	register_interface_komb: process(regif_addr, regif_cs, regif_data_in, regif_wen, control_0, control_1, output_delay_0, output_delay_1)
	begin
		regif_data_out_next <= (others => '0'); --initialize
		control_0_next      <= control_0;
		control_1_next      <= control_1;
		output_delay_0_next <= output_delay_0;
		output_delay_1_next <= output_delay_1;

		if regif_cs = '1' then
			if regif_wen = '1' then
				if regif_addr = "00000000" then
					control_0_next <= regif_data_in;
				elsif regif_addr = "00000001" then
					control_1_next <= regif_data_in;
				elsif regif_addr >= "00000010" and regif_addr <= OUTPUT_DELAY_0_RANGE then -- 1
					output_delay_0_next(to_integer(unsigned(regif_addr) - to_unsigned(2, 8))) <= regif_data_in;

				elsif regif_addr > OUTPUT_DELAY_0_RANGE and regif_addr <= OUTPUT_DELAY_1_RANGE then -- 2
					output_delay_1_next(to_integer(unsigned(regif_addr) - to_unsigned(2 + OUTPORTS, 8))) <= regif_data_in;
				end if;
			else                        --read
			if regif_addr = "00000000" then
					regif_data_out_next <= control_0;

				elsif regif_addr = "00000001" then
					regif_data_out_next <= control_1;

				elsif regif_addr >= "00000010" and regif_addr <= OUTPUT_DELAY_0_RANGE then
					regif_data_out_next <= output_delay_0(to_integer(unsigned(regif_addr) - to_unsigned(2, 8)));

				elsif regif_addr > OUTPUT_DELAY_0_RANGE and regif_addr <= OUTPUT_DELAY_1_RANGE then
					regif_data_out_next <= output_delay_1(to_integer(unsigned(regif_addr) - to_unsigned(2 + OUTPORTS, 8)));

				end if;
			end if;
		else
			regif_data_out_next <= (others => '0');
		end if;
	end process register_interface_komb;
	


	point_control_komb : process(write_pointer_0, write_pointer_1, inc_write_pointer_0, inc_write_pointer_1, output_delay_0, output_delay_1)
	begin
		write_pointer_0_next <= write_pointer_0; --initialize
		write_pointer_1_next <= write_pointer_1;
		
		if inc_write_pointer_0 = '1' then
			if write_pointer_0 = BASE_ADDR_0 + BUFFER_SIZE - 1 then
				write_pointer_0_next <= to_unsigned(BASE_ADDR_0, 26);
			else 
				write_pointer_0_next <= write_pointer_0 + 1 ; 
			end if;
		end if;
		if inc_write_pointer_1 = '1' then
			if write_pointer_1 = BASE_ADDR_1 + BUFFER_SIZE -1 then
				write_pointer_1_next <= to_unsigned(BASE_ADDR_1, 26);
			else 
				write_pointer_1_next <= write_pointer_1 + 1 ; 
			end if;
		end if;
		for i in 0 to OUTPORTS-1 loop
			if write_pointer_0 - BASE_ADDR_0 >= shift_left(resize(unsigned(output_delay_0(i)), DELAY_SHIFT_FACTOR + 8), DELAY_SHIFT_FACTOR) then
				read_pointer_0_next(i) <= write_pointer_0 - shift_left(resize(unsigned(output_delay_0(i)), DELAY_SHIFT_FACTOR + 8), DELAY_SHIFT_FACTOR); --Beispiel A
			else
				read_pointer_0_next(i) <= write_pointer_0 + BUFFER_SIZE - shift_left(resize(unsigned(output_delay_0(i)), DELAY_SHIFT_FACTOR + 8), DELAY_SHIFT_FACTOR); --Beispiel B
			end if;

			if write_pointer_1 - BASE_ADDR_1 >= shift_left(resize(unsigned(output_delay_1(i)), DELAY_SHIFT_FACTOR + 8), DELAY_SHIFT_FACTOR) then
				read_pointer_1_next(i) <= write_pointer_1 - shift_left(resize(unsigned(output_delay_1(i)), DELAY_SHIFT_FACTOR + 8), DELAY_SHIFT_FACTOR);
			else
				read_pointer_1_next(i) <= write_pointer_1 + BUFFER_SIZE - shift_left(resize(unsigned(output_delay_1(i)), DELAY_SHIFT_FACTOR + 8), DELAY_SHIFT_FACTOR);
			end if;
		end loop;
	end process point_control_komb;
	
	buffer_status : process(max_write_pointer_0, max_write_pointer_1, write_pointer_0, write_pointer_1, output_delay_0, output_delay_1) --Aufgabe 7
	begin
		enough_samples_0         <= (others => '0'); --initialize
		enough_samples_1         <= (others => '0');
		max_write_pointer_0_next <= max_write_pointer_0;
		max_write_pointer_1_next <= max_write_pointer_1;

		if max_write_pointer_0 < write_pointer_0 then
			max_write_pointer_0_next <= write_pointer_0;
		end if;

		if max_write_pointer_1 < write_pointer_1 then
			max_write_pointer_1_next <= write_pointer_1;
		end if;

		for i in 0 to OUTPORTS - 1 loop
			if max_write_pointer_0 >= BASE_ADDR_0 + shift_left(resize(unsigned(output_delay_0(i)), DELAY_SHIFT_FACTOR + 8), DELAY_SHIFT_FACTOR)  then
				enough_samples_0(i) <= '1';
			end if;
			if max_write_pointer_1 >= BASE_ADDR_1 + shift_left(resize(unsigned(output_delay_1(i)), DELAY_SHIFT_FACTOR + 8), DELAY_SHIFT_FACTOR)  then
				enough_samples_1(i) <= '1';
			end if;
		end loop;

	end process;
	
	s2p_0 : s2p_unit
		port map(
			clock     => clock,
			reset     => reset,
			-- serial audio-data signals
			ain_sync  => ain_sync_0,
			ain_data  => ain_data_0,
			-- parallel audio-data signals
			smp_valid => smp_valid_in_0,
			smp_ack   => smp_ack_in_0,
			smp_data  => smp_data_in_0
		);

	s2p_1 : s2p_unit
		port map(
			clock     => clock,
			reset     => reset,
			-- serial audio-data signals
			ain_sync  => ain_sync_1,
			ain_data  => ain_data_1,
			-- parallel audio-data signals
			smp_valid => smp_valid_in_1,
			smp_ack   => smp_ack_in_1,
			smp_data  => smp_data_in_1
		);

	p2s_inst : for i in 0 to OUTPORTS - 1 generate
		p2s_0 : p2s_unit
			port map(
				clock     => clock,
				reset     => reset,
				smp_valid => smp_valid_out_0(i),
				smp_ack   => smp_ack_out_0(i),
				smp_data  => smp_data_out_0(i),
				aout_sync => aout_sync_0(i),
				aout_data => aout_data_0(i)
			);

		p2s_1 : p2s_unit
			port map(
				clock     => clock,
				reset     => reset,
				smp_valid => smp_valid_out_1(i),
				smp_ack   => smp_ack_out_1(i),
				smp_data  => smp_data_out_1(i),
				aout_sync => aout_sync_1(i),
				aout_data => aout_data_1(i)
			);
	end generate;
		
		port_counter : process(port_cnt, rst_port_cnt, inc_port_cnt)
	begin
		port_cnt_next <= port_cnt;

		if rst_port_cnt = '1' then
			port_cnt_next <= (others => '0');
		elsif inc_port_cnt = '1' then
			port_cnt_next <= port_cnt + 1;
		end if;
	end process;
	
end architecture rtl;
