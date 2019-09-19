-----------------------------------------------------------
--      Institute of Microelectronic Systems
--      Architectures and Systems
--      Leibniz Universitaet Hannover
-----------------------------------------------------------
--      lab :         Design Methods for FPGAs
--      file :        p2s_unit.vhdl
--      authors :     Jan Duerre
--      last update : 04.09.2014
--      description : Unit to serialize parallel audio data.
-----------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga_audiofx_pkg.all;

entity p2s_unit is
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
end p2s_unit;

architecture rtl of p2s_unit is

  -- control fsm
  type state_t is (ST_IDLE, ST_DATA);
  signal state     : state_t;
  signal state_nxt : state_t;

  -- register to hold data
  signal sample     : std_ulogic_vector(SAMPLE_WIDTH-2 downto 0);
  signal sample_nxt : std_ulogic_vector(SAMPLE_WIDTH-2 downto 0);

  -- counter
  signal bit_counter     : unsigned(to_log2(SAMPLE_WIDTH-1)-1 downto 0);
  signal bit_counter_nxt : unsigned(to_log2(SAMPLE_WIDTH-1)-1 downto 0);

begin

  ff : process(clock, reset)
  begin
    if reset = '1' then
      state       <= ST_IDLE;
      sample      <= (others => '0');
      bit_counter <= (others => '0');
    elsif rising_edge(clock) then
      state       <= state_nxt;
      sample      <= sample_nxt;
      bit_counter <= bit_counter_nxt;
    end if;
  end process ff;

  output : process(state, sample, bit_counter, smp_data, smp_valid)
  begin
    -- hold register content
    state_nxt       <= state;
    sample_nxt      <= sample;
    bit_counter_nxt <= bit_counter;
    -- hold sync / data line low on default
    aout_sync       <= '0';
    aout_data       <= '0';
    -- always ready for serialization
    smp_ack         <= '1';

    case state is
      when ST_IDLE =>
        -- wait for valid parallel data
        if smp_valid = '1' then
                                        -- reset counter
          bit_counter_nxt <= (others => '0');
                                        -- immediately send out sync and first bit
          aout_sync       <= '1';
          aout_data       <= smp_data(SAMPLE_WIDTH-1);
                                        -- save remaining bits in register
          sample_nxt      <= smp_data(SAMPLE_WIDTH-2 downto 0);
                                        -- next state
          state_nxt       <= ST_DATA;
        end if;

      when ST_DATA =>
        -- during serialization: not ready for new data
        smp_ack    <= '0';
        -- send out data (highest bit of sample-register)
        aout_data  <= sample(sample'length-1);
        -- shift left data register
        sample_nxt <= sample(sample'length-2 downto 0) & '0';

        -- sending out last bit
        if bit_counter = SAMPLE_WIDTH-2 then
                                        -- return to idle state
          state_nxt <= ST_IDLE;
        else
                                        -- continue and count bits
          bit_counter_nxt <= bit_counter + 1;
        end if;
    end case;
  end process output;

end rtl;

