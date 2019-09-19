---------------------------------------------------------------------
--      Institute of Microelectronic Systems
--      Architectures and Systems
--      Leibniz Universitaet Hannover
---------------------------------------------------------------------
--      lab :         Design Methods for FPGAs
--      file :        i2s_slave.vhdl
--      authors :     Jan Duerre
--      last update : 22.09.2015
--      description : This module implements a Slave-Receiver for the 
--                    Inter-IC Sound Bus for Stereo-Signals.
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga_audiofx_pkg.all;

entity i2s_slave is
  port (
    clock           : in  std_ulogic;
    reset_n         : in  std_ulogic;
    -- i2s signals
    i2s_sclk        : in  std_ulogic;
    i2s_adc_ws      : in  std_ulogic;
    i2s_adc_sdat    : in  std_ulogic;
    i2s_dac_ws      : in  std_ulogic;
    i2s_dac_sdat    : out std_ulogic;
    -- internal audio sample
    ain_left_sync   : out std_ulogic;
    ain_left_data   : out std_ulogic;
    ain_right_sync  : out std_ulogic;
    ain_right_data  : out std_ulogic;
    aout_left_sync  : in  std_ulogic;
    aout_left_data  : in  std_ulogic;
    aout_right_sync : in  std_ulogic;
    aout_right_data : in  std_ulogic
    );
end i2s_slave;

architecture rtl of i2s_slave is

  -- shift regs for signal detection
  signal i2s_sclk_sreg     : std_ulogic_vector(2 downto 0);
  signal i2s_sclk_sreg_nxt : std_ulogic_vector(2 downto 0);

  signal i2s_adc_ws_sreg     : std_ulogic_vector(1 downto 0);
  signal i2s_adc_ws_sreg_nxt : std_ulogic_vector(1 downto 0);

  signal i2s_dac_ws_sreg     : std_ulogic_vector(1 downto 0);
  signal i2s_dac_ws_sreg_nxt : std_ulogic_vector(1 downto 0);

  signal i2s_adc_sdat_reg     : std_ulogic;
  signal i2s_adc_sdat_reg_nxt : std_ulogic;

  -- data registers
  signal audio_data_in_lr     : std_ulogic;
  signal audio_data_in_lr_nxt : std_ulogic;
  signal ain_lr               : std_ulogic;
  signal ain_lr_nxt           : std_ulogic;

  signal audio_data_in_left      : std_ulogic_vector(SAMPLE_WIDTH-1 downto 0);
  signal audio_data_in_left_nxt  : std_ulogic_vector(SAMPLE_WIDTH-1 downto 0);
  signal audio_data_in_right     : std_ulogic_vector(SAMPLE_WIDTH-1 downto 0);
  signal audio_data_in_right_nxt : std_ulogic_vector(SAMPLE_WIDTH-1 downto 0);
  signal audio_data_in_sreg      : std_ulogic_vector(SAMPLE_WIDTH-1 downto 0);
  signal audio_data_in_sreg_nxt  : std_ulogic_vector(SAMPLE_WIDTH-1 downto 0);


  signal audio_data_out_lr     : std_ulogic;
  signal audio_data_out_lr_nxt : std_ulogic;

  signal audio_data_out_left_valid      : std_ulogic;
  signal audio_data_out_left_valid_nxt  : std_ulogic;
  signal audio_data_out_right_valid     : std_ulogic;
  signal audio_data_out_right_valid_nxt : std_ulogic;
  signal audio_data_out_left            : std_ulogic_vector(SAMPLE_WIDTH-1 downto 0);
  signal audio_data_out_left_nxt        : std_ulogic_vector(SAMPLE_WIDTH-1 downto 0);
  signal audio_data_out_right           : std_ulogic_vector(SAMPLE_WIDTH-1 downto 0);
  signal audio_data_out_right_nxt       : std_ulogic_vector(SAMPLE_WIDTH-1 downto 0);
  signal audio_data_out_sreg            : std_ulogic_vector(SAMPLE_WIDTH-1 downto 0);
  signal audio_data_out_sreg_nxt        : std_ulogic_vector(SAMPLE_WIDTH-1 downto 0);

  -- bit counter
  signal audio_data_in_cnt_left      : unsigned(to_log2(SAMPLE_WIDTH+2)-1 downto 0);
  signal audio_data_in_cnt_left_nxt  : unsigned(to_log2(SAMPLE_WIDTH+2)-1 downto 0);
  signal audio_data_in_cnt_right     : unsigned(to_log2(SAMPLE_WIDTH+2)-1 downto 0);
  signal audio_data_in_cnt_right_nxt : unsigned(to_log2(SAMPLE_WIDTH+2)-1 downto 0);

  signal audio_data_out_cnt     : unsigned(to_log2(SAMPLE_WIDTH+2)-1 downto 0);
  signal audio_data_out_cnt_nxt : unsigned(to_log2(SAMPLE_WIDTH+2)-1 downto 0);

  signal ain_cnt     : unsigned(to_log2(SAMPLE_WIDTH+1)-1 downto 0);
  signal ain_cnt_nxt : unsigned(to_log2(SAMPLE_WIDTH+1)-1 downto 0);

  signal aout_cnt_left      : unsigned(to_log2(SAMPLE_WIDTH+1)-1 downto 0);
  signal aout_cnt_left_nxt  : unsigned(to_log2(SAMPLE_WIDTH+1)-1 downto 0);
  signal aout_cnt_right     : unsigned(to_log2(SAMPLE_WIDTH+1)-1 downto 0);
  signal aout_cnt_right_nxt : unsigned(to_log2(SAMPLE_WIDTH+1)-1 downto 0);


  -- FSM adc (audio in)
  type fsm_ain_t is (S_WAIT_FOR_EDGE_LR, S_WAIT_1BCLK_RISE, S_WAIT_1BCLK_FALL);
  signal state_ain, state_ain_nxt : fsm_ain_t;

  -- FSM dac (audio out)
  type fsm_aout_t is (S_WAIT_FOR_EDGE_LR, S_WAIT_1BCLK_RISE, S_WAIT_1BCLK_FALL);
  signal state_aout, state_aout_nxt : fsm_aout_t;


begin

  -- FFs
  process(clock, reset_n)
  begin
    if reset_n = '0' then
      i2s_sclk_sreg   <= (others => '0');
      i2s_adc_ws_sreg <= (others => '1');
      i2s_dac_ws_sreg <= (others => '1');

      i2s_adc_sdat_reg <= '0';

      audio_data_in_lr    <= '0';
      audio_data_in_left  <= (others => '0');
      audio_data_in_right <= (others => '0');
      audio_data_in_sreg  <= (others => '0');

      audio_data_out_lr    <= '0';
      audio_data_out_left  <= (others => '0');
      audio_data_out_right <= (others => '0');
      audio_data_out_sreg  <= (others => '0');

      audio_data_in_cnt_left  <= to_unsigned(SAMPLE_WIDTH+1, audio_data_in_cnt_left'length);
      audio_data_in_cnt_right <= to_unsigned(SAMPLE_WIDTH+1, audio_data_in_cnt_right'length);
      audio_data_out_cnt      <= to_unsigned(SAMPLE_WIDTH+1, audio_data_out_cnt'length);

      ain_cnt        <= to_unsigned(SAMPLE_WIDTH, ain_cnt'length);
      aout_cnt_left  <= to_unsigned(SAMPLE_WIDTH-1, aout_cnt_left'length);
      aout_cnt_right <= to_unsigned(SAMPLE_WIDTH-1, aout_cnt_right'length);
      ain_lr         <= '0';

      state_ain  <= S_WAIT_FOR_EDGE_LR;
      state_aout <= S_WAIT_FOR_EDGE_LR;

    elsif rising_edge(clock) then
      i2s_sclk_sreg   <= i2s_sclk_sreg_nxt;
      i2s_adc_ws_sreg <= i2s_adc_ws_sreg_nxt;
      i2s_dac_ws_sreg <= i2s_dac_ws_sreg_nxt;

      i2s_adc_sdat_reg <= i2s_adc_sdat_reg_nxt;

      audio_data_in_lr    <= audio_data_in_lr_nxt;
      audio_data_in_left  <= audio_data_in_left_nxt;
      audio_data_in_right <= audio_data_in_right_nxt;
      audio_data_in_sreg  <= audio_data_in_sreg_nxt;

      audio_data_out_lr    <= audio_data_out_lr_nxt;
      audio_data_out_left  <= audio_data_out_left_nxt;
      audio_data_out_right <= audio_data_out_right_nxt;
      audio_data_out_sreg  <= audio_data_out_sreg_nxt;

      audio_data_in_cnt_left  <= audio_data_in_cnt_left_nxt;
      audio_data_in_cnt_right <= audio_data_in_cnt_right_nxt;
      audio_data_out_cnt      <= audio_data_out_cnt_nxt;

      ain_cnt        <= ain_cnt_nxt;
      aout_cnt_left  <= aout_cnt_left_nxt;
      aout_cnt_right <= aout_cnt_right_nxt;
      ain_lr         <= ain_lr_nxt;

      state_ain  <= state_ain_nxt;
      state_aout <= state_aout_nxt;

    end if;
  end process;


  -- shift regs for edge detection
  i2s_sclk_sreg_nxt   <= i2s_sclk & i2s_sclk_sreg(2 downto 1);
  i2s_adc_ws_sreg_nxt <= i2s_adc_ws & i2s_adc_ws_sreg(1);
  i2s_dac_ws_sreg_nxt <= i2s_dac_ws & i2s_dac_ws_sreg(1);

  -- connect adc data in to register, to have access to past data
  i2s_adc_sdat_reg_nxt <= i2s_adc_sdat;

  -- FSM Audio In
  process (state_ain, audio_data_in_lr, audio_data_in_left, audio_data_in_right, audio_data_in_cnt_left, audio_data_in_cnt_right, ain_cnt, ain_lr, i2s_adc_ws, i2s_adc_ws_sreg, i2s_sclk_sreg, i2s_adc_sdat, audio_data_in_sreg, i2s_adc_sdat_reg)
  begin

    state_ain_nxt <= state_ain;

    audio_data_in_lr_nxt    <= audio_data_in_lr;
    audio_data_in_left_nxt  <= audio_data_in_left;
    audio_data_in_right_nxt <= audio_data_in_right;
    audio_data_in_sreg_nxt  <= audio_data_in_sreg;

    audio_data_in_cnt_left_nxt  <= audio_data_in_cnt_left;
    audio_data_in_cnt_right_nxt <= audio_data_in_cnt_right;

    ain_cnt_nxt <= ain_cnt;
    ain_lr_nxt  <= ain_lr;

    ain_left_sync  <= '0';
    ain_left_data  <= '0';
    ain_right_sync <= '0';
    ain_right_data <= '0';

    -- serialization
    if ain_cnt /= SAMPLE_WIDTH then
      -- sync signal
      if ain_cnt = 0 then
        -- left / right
        if ain_lr = '0' then
          ain_left_sync <= '1';
        else
          ain_right_sync <= '1';
        end if;
      end if;

      -- serial data signal
      if ain_lr = '0' then
        -- left
        ain_left_data <= audio_data_in_sreg(SAMPLE_WIDTH-1);
      else
        -- right
        ain_right_data <= audio_data_in_sreg(SAMPLE_WIDTH-1);
      end if;

      -- shift data
      audio_data_in_sreg_nxt <= audio_data_in_sreg(SAMPLE_WIDTH-2 downto 0) & '0';
      -- count
      ain_cnt_nxt            <= ain_cnt + 1;

    end if;


    -- i2s rx
    -- rising edge on sclk: shift in data
    if i2s_sclk_sreg(2 downto 1) = "10" then
      -- left
      if audio_data_in_lr = '0' then
        audio_data_in_left_nxt <= audio_data_in_left(SAMPLE_WIDTH-2 downto 0) & i2s_adc_sdat_reg;
      -- right
      else
        audio_data_in_right_nxt <= audio_data_in_right(SAMPLE_WIDTH-2 downto 0) & i2s_adc_sdat_reg;
      end if;
    end if;

    -- rising edge on sclk: count data
    if i2s_sclk_sreg(2 downto 1) = "10" then
      -- left
      if audio_data_in_lr = '0' then
        if audio_data_in_cnt_left <= SAMPLE_WIDTH then
          audio_data_in_cnt_left_nxt <= audio_data_in_cnt_left + 1;
        end if;
      else
        -- right
        if audio_data_in_cnt_right <= SAMPLE_WIDTH then
          audio_data_in_cnt_right_nxt <= audio_data_in_cnt_right + 1;
        end if;
      end if;
    end if;

    -- finished rx : start serialization
    if audio_data_in_cnt_left = SAMPLE_WIDTH then
      ain_cnt_nxt                <= (others => '0');
      ain_lr_nxt                 <= audio_data_in_lr;
      audio_data_in_sreg_nxt     <= audio_data_in_left;
      audio_data_in_cnt_left_nxt <= audio_data_in_cnt_left + 1;
    end if;

    if audio_data_in_cnt_right = SAMPLE_WIDTH then
      ain_cnt_nxt                 <= (others => '0');
      ain_lr_nxt                  <= audio_data_in_lr;
      audio_data_in_sreg_nxt      <= audio_data_in_right;
      audio_data_in_cnt_right_nxt <= audio_data_in_cnt_right + 1;
    end if;


    -- mini-fsm to control flow
    case state_ain is
      when S_WAIT_FOR_EDGE_LR =>
        -- on falling or rising edge on word select
        if i2s_adc_ws_sreg = "01" or i2s_adc_ws_sreg = "10" then
                                        -- await first cycle 
          state_ain_nxt <= S_WAIT_1BCLK_RISE;
        end if;

      when S_WAIT_1BCLK_RISE =>
        -- rising edge on sclk
        if i2s_sclk_sreg(2 downto 1) = "10" then
                                        -- await first cycle 
          state_ain_nxt <= S_WAIT_1BCLK_FALL;
        end if;

      when S_WAIT_1BCLK_FALL =>
        -- falling edge on sclk
        if i2s_sclk_sreg(2 downto 1) = "01" then
                                        -- start recording data
          if i2s_adc_ws = '0' then
            audio_data_in_cnt_left_nxt <= (others => '0');
          else
            audio_data_in_cnt_right_nxt <= (others => '0');
          end if;
                                        -- save channel
          audio_data_in_lr_nxt <= i2s_adc_ws;
                                        -- wait for next edge
          state_ain_nxt        <= S_WAIT_FOR_EDGE_LR;
        end if;

    end case;

  end process;


  -- FSM Audio Out
  process (state_aout, aout_cnt_left, aout_cnt_right, aout_left_sync, aout_left_data, aout_right_sync, aout_right_data, audio_data_out_left, audio_data_out_right, audio_data_out_sreg, audio_data_out_lr, audio_data_out_cnt, i2s_dac_ws, i2s_dac_ws_sreg, i2s_sclk_sreg)
  begin

    state_aout_nxt <= state_aout;

    audio_data_out_lr_nxt    <= audio_data_out_lr;
    audio_data_out_left_nxt  <= audio_data_out_left;
    audio_data_out_right_nxt <= audio_data_out_right;
    audio_data_out_sreg_nxt  <= audio_data_out_sreg;

    audio_data_out_cnt_nxt <= audio_data_out_cnt;

    aout_cnt_left_nxt  <= aout_cnt_left;
    aout_cnt_right_nxt <= aout_cnt_right;

    i2s_dac_sdat <= '0';


    -- parallelization
    if aout_left_sync = '1' then
      audio_data_out_left_nxt <= audio_data_out_left(SAMPLE_WIDTH-2 downto 0) & aout_left_data;
      aout_cnt_left_nxt       <= (others => '0');
    end if;

    if aout_right_sync = '1' then
      audio_data_out_right_nxt <= audio_data_out_right(SAMPLE_WIDTH-2 downto 0) & aout_right_data;
      aout_cnt_right_nxt       <= (others => '0');
    end if;

    -- shift in
    -- left
    if aout_cnt_left /= SAMPLE_WIDTH - 1 then
      audio_data_out_left_nxt <= audio_data_out_left(SAMPLE_WIDTH-2 downto 0) & aout_left_data;
      -- count
      aout_cnt_left_nxt       <= aout_cnt_left + 1;
    end if;

    -- right
    if aout_cnt_right /= SAMPLE_WIDTH - 1 then
      audio_data_out_right_nxt <= audio_data_out_right(SAMPLE_WIDTH-2 downto 0) & aout_right_data;
      -- count
      aout_cnt_right_nxt       <= aout_cnt_right + 1;
    end if;


    -- i2s tx
    i2s_dac_sdat <= audio_data_out_sreg(SAMPLE_WIDTH-1);

    if audio_data_out_cnt <= SAMPLE_WIDTH then
      -- rising edge on delayed sclk: shift
      if i2s_sclk_sreg(1 downto 0) = "10" then
        -- left
        if audio_data_out_lr = '0' then
          audio_data_out_sreg_nxt <= audio_data_out_sreg(SAMPLE_WIDTH-2 downto 0) & '0';
        -- right
        else
          audio_data_out_sreg_nxt <= audio_data_out_sreg(SAMPLE_WIDTH-2 downto 0) & '0';
        end if;
      end if;

      -- rising edge on sclk: count
      if i2s_sclk_sreg(2 downto 1) = "10" then
        -- count
        audio_data_out_cnt_nxt <= audio_data_out_cnt + 1;
      end if;
    end if;


    -- mini-fsm to control flow
    case state_aout is
      when S_WAIT_FOR_EDGE_LR =>
        -- on rising or falling edge on ws
        if i2s_dac_ws_sreg = "10" or i2s_dac_ws_sreg = "01" then
          state_aout_nxt <= S_WAIT_1BCLK_RISE;
        end if;

      when S_WAIT_1BCLK_RISE =>
        -- rising edge on sclk
        if i2s_sclk_sreg(2 downto 1) = "10" then
          state_aout_nxt <= S_WAIT_1BCLK_FALL;

          if i2s_dac_ws = '0' then
            audio_data_out_sreg_nxt <= audio_data_out_left;
                                        -- reset register
            if aout_cnt_left = SAMPLE_WIDTH - 1 and aout_left_sync = '0' then
              audio_data_out_left_nxt <= (others => '0');
            end if;
          else
            audio_data_out_sreg_nxt <= audio_data_out_right;
                                        -- reset register
            if aout_cnt_right = SAMPLE_WIDTH - 1 and aout_right_sync = '0' then
              audio_data_out_right_nxt <= (others => '0');
            end if;
          end if;

        end if;

      when S_WAIT_1BCLK_FALL =>
        -- falling edge on sclk
        if i2s_sclk_sreg(2 downto 1) = "01" then
          audio_data_out_lr_nxt  <= i2s_dac_ws;
          state_aout_nxt         <= S_WAIT_FOR_EDGE_LR;
          audio_data_out_cnt_nxt <= (others => '0');
        end if;

    end case;

  end process;

end architecture rtl;
