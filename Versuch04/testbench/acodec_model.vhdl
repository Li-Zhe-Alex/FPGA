----------------------------------------------------------------------
--      Institute of Microelectronic Systems
--      Architectures and Systems
--      Leibniz Universitaet Hannover
----------------------------------------------------------------------
--      lab :                   Design Methods for FPGAs
--      file :                  acodec_model.vhdl
--      authors :               Jan Duerre
--      last update :   22.09.2015
--      description :   This module provides samples over I2S-protocol,
--                      acting as master. Samples are read from a file. 
--                      The samples are read from file as pairs of 
--                      integer-numbers, alternating for the left and 
--                      the right channel. Correct I2C communication is 
--                      ack'ed but ignored.
----------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity acodec_model is
  generic (
    SAMPLE_WIDTH : natural := 16;
    SAMPLE_RATE  : natural := 44100;
    SAMPLE_FILE  : string  := "audio_samples.txt"
    );
  port (
    -- acodec signals
    i2s_ref_sclk : in    std_ulogic;
    i2s_sclk     : out   std_ulogic;
    i2s_adc_ws   : out   std_ulogic;
    i2s_adc_sdat : out   std_ulogic;
    i2s_dac_ws   : out   std_ulogic;
    i2s_dac_sdat : in    std_ulogic;
    i2c_sdat     : inout std_logic;
    i2c_sclk     : in    std_logic
    );
end acodec_model;

architecture rtl of acodec_model is

  constant WM8731_SLAVE_ADDR : std_ulogic_vector(6 downto 0) := "0011010";
  constant AUDIO_SAMPLE_TIME : time                          := 1 us * 1000000/SAMPLE_RATE;

  signal i2s_adc_sdat_left  : std_ulogic;
  signal i2s_adc_sdat_right : std_ulogic;

  signal i2s_adc_ws_int : std_ulogic := '1';
  signal i2s_dac_ws_int : std_ulogic := '1';

  -- internal data-array for preloaded samples from file
  constant MAX_NUMBER_OF_SAMPLES : natural := 256;
  signal number_of_samples       : natural;

  file sample_f : text open read_mode is SAMPLE_FILE;

  type sample_data_t is array (0 to MAX_NUMBER_OF_SAMPLES-1) of std_ulogic_vector(SAMPLE_WIDTH-1 downto 0);
  signal sample_data_left  : sample_data_t;
  signal sample_data_right : sample_data_t;

begin

  -- preload samples from file
  process
    variable active_line  : line;
    variable neol         : boolean := false;
    variable sample_value : integer := 0;
    variable cnt          : natural := 0;
  begin
    -- preset size
    number_of_samples <= 0;

    -- prefill array with undefined
    sample_data_left  <= (others => (others => 'U'));
    sample_data_right <= (others => (others => 'U'));

    -- read preload file
    while ((not endfile(sample_f)) and (cnt /= MAX_NUMBER_OF_SAMPLES)) loop
      -- read line
      readline(sample_f, active_line);
      -- loop until end of line
      loop
        -- left:
        -- read integer from line
        read(active_line, sample_value, neol);
        -- exit when line has ended
        exit when not neol;
        -- write data to array
        sample_data_left(cnt) <= std_ulogic_vector(to_signed(sample_value, SAMPLE_WIDTH));

        -- right:
        -- read integer from line
        read(active_line, sample_value, neol);
        -- exit when line has ended
        exit when not neol;
        -- write data to array
        sample_data_right(cnt) <= std_ulogic_vector(to_signed(sample_value, SAMPLE_WIDTH));

        -- increment counter
        cnt := cnt + 1;

        -- chancel when sample array is already full
        exit when cnt = MAX_NUMBER_OF_SAMPLES;

      end loop;

    end loop;

    -- update size
    number_of_samples <= cnt;

    -- close file and sleep
    file_close(sample_f);
    wait;

  end process;



  i2s_sclk   <= i2s_ref_sclk;
  i2s_adc_ws <= i2s_adc_ws_int;
  i2s_dac_ws <= i2s_dac_ws_int;

  i2s_adc_sdat <= i2s_adc_sdat_left or i2s_adc_sdat_right;


  -- generate left / right channel signal
  process
  begin

    wait until i2s_ref_sclk = '1';
    wait until i2s_ref_sclk = '0';

    loop
      i2s_adc_ws_int <= '1';
      i2s_dac_ws_int <= '1';
      wait for AUDIO_SAMPLE_TIME/2;
      wait until i2s_ref_sclk = '0';
      i2s_adc_ws_int <= '0';
      i2s_dac_ws_int <= '0';
      wait for AUDIO_SAMPLE_TIME/2;
      wait until i2s_ref_sclk = '0';
    end loop;
  end process;


  -- left channel
  process
    variable sample_ptr : integer := 0;
  begin
    i2s_adc_sdat_left <= '0';

    wait until i2s_ref_sclk = '1';
    wait until i2s_ref_sclk = '0';

    -- loop forever
    loop
      i2s_adc_sdat_left <= '0';

      -- wait for change of channel and synchronize with audio-clock (left channel)
      wait until (i2s_adc_ws_int = '0') and (i2s_ref_sclk = '0');
      -- pass first i2s_ref_sclk
      wait until rising_edge(i2s_ref_sclk);
      wait until falling_edge(i2s_ref_sclk);

      for i in SAMPLE_WIDTH-1 downto 0 loop
        i2s_adc_sdat_left <= std_ulogic(sample_data_left(sample_ptr)(i));
        wait until rising_edge(i2s_ref_sclk);
        wait until falling_edge(i2s_ref_sclk);
      end loop;

      i2s_adc_sdat_left <= '0';

      -- inc data pointer
      if sample_ptr = number_of_samples - 1 then
        sample_ptr := 0;
      else
        sample_ptr := sample_ptr + 1;
      end if;

      -- wait for change of channel (if still in left channel)
      if i2s_adc_ws_int = '0' then
        wait until (i2s_adc_ws_int = '1');
      end if;

    end loop;

  end process;


  -- right channel
  process
    variable sample_ptr : integer := 0;
  begin
    i2s_adc_sdat_right <= '0';

    wait until i2s_ref_sclk = '1';
    wait until i2s_ref_sclk = '0';

    -- start with left channel: wait for that to finish
    wait until (i2s_adc_ws_int = '0');

    -- loop forever
    loop
      i2s_adc_sdat_right <= '0';

      -- wait for change of channel and synchronize with audio-clock (right channel)
      wait until (i2s_adc_ws_int = '1') and (i2s_ref_sclk = '0');
      -- pass first i2s_ref_sclk
      wait until rising_edge(i2s_ref_sclk);
      wait until falling_edge(i2s_ref_sclk);

      for i in SAMPLE_WIDTH-1 downto 0 loop
        i2s_adc_sdat_right <= std_ulogic(sample_data_right(sample_ptr)(i));
        wait until rising_edge(i2s_ref_sclk);
        wait until falling_edge(i2s_ref_sclk);
      end loop;

      i2s_adc_sdat_right <= '0';

      -- inc data pointer
      if sample_ptr = number_of_samples - 1 then
        sample_ptr := 0;
      else
        sample_ptr := sample_ptr + 1;
      end if;

      -- wait for change of channel (if still in right channel)
      if i2s_adc_ws_int = '1' then
        wait until (i2s_adc_ws_int = '0');
      end if;

    end loop;

  end process;


  -- i2c slave: registers can only be written / reading is not supported
  process
    variable slave_addr : std_ulogic_vector(6 downto 0) := (others => '0');
  begin
    i2c_sdat <= 'Z';

    -- loop forever
    loop
      -- start condition
      wait until (falling_edge(i2c_sdat) and (i2c_sclk = '1'));
      -- slave addr
      for i in 6 downto 0 loop
        wait until rising_edge(i2c_sclk);
        slave_addr(i) := i2c_sdat;
        wait for 1 ns;
      end loop;
      -- r/w bit
      wait until rising_edge(i2c_sclk);
      -- correct slave address
      if slave_addr = WM8731_SLAVE_ADDR then
        -- write
        if i2c_sdat = '0' then
                                        -- ack
          wait until falling_edge(i2c_sclk);
          i2c_sdat <= '0';
                                        -- wait one i2c-cycle
          wait until rising_edge(i2c_sclk);
          wait until falling_edge(i2c_sclk);
          i2c_sdat <= 'Z';

                                        -- expecting 16 bit (2 byte)
                                        -- first byte
          for i in 0 to 7 loop
            wait until rising_edge(i2c_sclk);
            wait for 1 ns;
          end loop;
                                        -- ack
          wait until falling_edge(i2c_sclk);
          i2c_sdat <= '0';
                                        -- wait one i2c-cycle
          wait until rising_edge(i2c_sclk);
          wait until falling_edge(i2c_sclk);
          i2c_sdat <= 'Z';

                                        -- second byte
          for i in 0 to 7 loop
            wait until rising_edge(i2c_sclk);
            wait for 1 ns;
          end loop;
                                        -- ack
          wait until falling_edge(i2c_sclk);
          i2c_sdat <= '0';
                                        -- wait one i2c-cycle
          wait until rising_edge(i2c_sclk);
          wait until falling_edge(i2c_sclk);
          i2c_sdat <= 'Z';

                                        -- stop condition
          wait until (rising_edge(i2c_sdat) and (i2c_sclk = '1'));

        -- read
        else
                                        -- don't ack
          wait until falling_edge(i2c_sclk);
          i2c_sdat <= 'Z';
                                        -- wait one i2c-cycle
          wait until rising_edge(i2c_sclk);
          wait until falling_edge(i2c_sclk);
          i2c_sdat <= 'Z';
                                        -- stop condition
          wait until (rising_edge(i2c_sdat) and (i2c_sclk = '1'));
        end if;
      end if;

    end loop;

  end process;


end architecture rtl;
