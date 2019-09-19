-----------------------------------------------------------
--      Institute of Microelectronic Systems
--      Architectures and Systems
--      Leibniz Universitaet Hannover
-----------------------------------------------------------
--      lab :         Design Methods for FPGAs
--      file :        s2p_unit.vhdl
--      authors :     
--      last update : 
--      description : 
-----------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga_audiofx_pkg.all;

entity s2p_unit is
generic(SAMPLE_WIDTH : natural := 16
);
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
end entity s2p_unit;

architecture rtl of s2p_unit is
signal cnt_reset :std_ulogic;
signal nload :std_ulogic;
signal bit_counter      :unsigned(3 downto 0);
signal bit_counter_next :unsigned(3 downto 0);

signal din_en          : std_ulogic;
signal dout_en         : std_ulogic;

type state_t is (idel, get_data, wait_ack);
signal state : state_t;
signal state_next : state_t;

signal shift_r      :std_ulogic_vector(SAMPLE_WIDTH-1 downto 0);
signal shift_next :std_ulogic_vector(SAMPLE_WIDTH-1 downto 0);

begin
	bit_counter_seq: process(clock, reset)
	begin
		if reset = '1' then
		bit_counter <= "0000";
		elsif rising_edge(clock) then
		bit_counter <= bit_counter_next;
		end if;
	end process bit_counter_seq;
	
	bit_counter_komb: process(bit_counter, cnt_reset)
	begin
		if cnt_reset = '1' then
		bit_counter <= "0000";
		nload <= '0';
		elsif bit_counter = "1110" then
		bit_counter_next <= bit_counter;
		nload <= '1';
		else
		bit_counter_next <= bit_counter + 1 ;
		nload <= '0';
		end if;
	end process bit_counter_komb;
	
	FSM_seq: process(clock, reset)
	begin
		if reset = '1' then
		state <= idel;
		elsif rising_edge(clock) then
		state <= state_next;
		end if;
	end process FSM_seq;
	
	FSM_komb: process(state, ain_sync, smp_ack, nload)
	begin
	state_next <= state;
	cnt_reset <= '0';
	din_en    <= '0';
	dout_en   <= '0';
	smp_valid <= '0';
	
	case state is
		
		when idel =>
			if ain_sync = '1' then
			state_next <= get_data;
			cnt_reset <= '1';
			din_en    <= '1';
			dout_en   <= '0';
			smp_valid <= '0';
			elsif ain_sync = '0' then
			state_next <= idel;
			
			din_en    <= '0';
			dout_en   <= '0';
			smp_valid <= '0';
			end if;
			
		when get_data =>
			if nload = '1' then
			state_next <= wait_ack;
			cnt_reset <= '0';
			din_en    <= '1';
			dout_en   <= '0';
			smp_valid <= '0';
			elsif nload = '0' then
			state_next <= get_data;
			cnt_reset <= '0';
			din_en    <= '1';
			dout_en   <= '0';
			smp_valid <= '0';
			end if;
		
		when wait_ack =>
			if ain_sync = '1' then
			state_next <= get_data;
			cnt_reset <= '1';
			din_en    <= '1';
			dout_en   <= '1';
			smp_valid <= '1';
			elsif ain_sync = '0' and smp_ack = '1' then
			state_next <= idel;
			cnt_reset <= '0';
			din_en    <= '0';
			dout_en   <= '1';
			smp_valid <= '1';
			elsif ain_sync = '0' and smp_ack = '0' then
			state_next <= wait_ack;
			cnt_reset <= '0';
			din_en    <= '0';
			dout_en   <= '1';
			smp_valid <= '1';
			end if;
		end case;
	end process FSM_komb;
	
	pdata_seq: process(clock, reset)
	begin
		if reset = '1' then
		shift_r <= (others => '0');
		elsif rising_edge(clock) then
		shift_r <= shift_next;
		end if;
	end process pdata_seq;
	
	pdata_komb :process(din_en, dout_en, ain_data, shift_r)
	begin
		if din_en = '1' and dout_en = '0' then
		shift_next(15 downto 1) <= shift_r(14 downto 0);
		shift_next(0) <= ain_data;
		smp_data <= (others => '0');
		elsif din_en = '0' and dout_en = '1' then
		shift_next <= shift_r;
		smp_data <= shift_r;
		elsif din_en = '1' and dout_en = '1' then
		shift_next(15 downto 1) <= shift_r(14 downto 0);
		shift_next(0)           <= ain_data;
		smp_data                  <= shift_r;
		else
		shift_next <= shift_r;
		smp_data <= (others => '0');
		end if;
	end process pdata_komb;
	
end rtl;
	
	
		
		
		
	