--------------------------------------------------------------------------------------------
--      Institute of Microelectronic Systems
--      Architectures and Systems
--      Leibniz Universitaet Hannover
--------------------------------------------------------------------------------------------
--      lab :         Design Methods for FPGAs
--      file :        i2c_master.vhdl
--      authors :     Jan Duerre
--      last update : 19.08.2014
--      description : This I2C-Master supports different modes:
--                    data mode:
--                      mode = "00": Only Read Bytes
--                      mode = "01": Only Write Bytes
--                      mode = "10": Read Bytes, Repeated Start, Write Bytes
--                      mode = "11": Write Bytes, Repeated Start, Read Bytes
--                    speed modes:
--                      standard:       100 kHz (divider: 500)
--                      fast:           400 kHz (divider: 125)
--------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga_audiofx_pkg.all;

entity i2c_master is
  generic (
    GV_CLOCK_DIVIDER : natural := 125;
    GW_SLAVE_ADDR    : natural := 7;
    GV_MAX_BYTES     : natural := 16
    );
  port (
    clock         : in    std_ulogic;
    reset_n       : in    std_ulogic;
    -- i2c master
    i2c_clk       : out   std_logic;
    i2c_dat       : inout std_logic;
    -- interface
    busy          : out   std_ulogic;
    cs            : in    std_ulogic;
    mode          : in    std_ulogic_vector(1 downto 0);
    slave_addr    : in    std_ulogic_vector(GW_SLAVE_ADDR-1 downto 0);
    bytes_tx      : in    unsigned(to_log2(GV_MAX_BYTES+1)-1 downto 0);
    bytes_rx      : in    unsigned(to_log2(GV_MAX_BYTES+1)-1 downto 0);
    tx_data       : in    std_ulogic_vector(7 downto 0);
    tx_data_valid : in    std_ulogic;
    rx_data       : out   std_ulogic_vector(7 downto 0);
    rx_data_valid : out   std_ulogic;
    rx_data_en    : in    std_ulogic;
    error         : out   std_ulogic
    );
end i2c_master;

architecture rtl of i2c_master is

  -- fifos
  component fifo is
    generic (
      DEPTH     : natural;
      WORDWIDTH : natural
      );
    port (
      clock    : in  std_ulogic;
      reset_n  : in  std_ulogic;
      write_en : in  std_ulogic;
      data_in  : in  std_ulogic_vector(WORDWIDTH-1 downto 0);
      read_en  : in  std_ulogic;
      data_out : out std_ulogic_vector(WORDWIDTH-1 downto 0);
      empty    : out std_ulogic;
      full     : out std_ulogic;
      fill_cnt : out unsigned(to_log2(DEPTH+1)-1 downto 0)
      );
  end component fifo;

  signal rx_fifo_write_en : std_ulogic;
  signal rx_fifo_data_in  : std_ulogic_vector(7 downto 0);
  signal rx_fifo_read_en  : std_ulogic;
  signal rx_fifo_data_out : std_ulogic_vector(7 downto 0);
  signal rx_fifo_empty    : std_ulogic;

  signal tx_fifo_write_en : std_ulogic;
  signal tx_fifo_data_in  : std_ulogic_vector(7 downto 0);
  signal tx_fifo_read_en  : std_ulogic;
  signal tx_fifo_data_out : std_ulogic_vector(7 downto 0);
  signal tx_fifo_empty    : std_ulogic;

  -- clock generation
  component clock_generator is
    generic (
      GV_CLOCK_DIV : natural
      );
    port (
      clock     : in  std_ulogic;
      reset_n   : in  std_ulogic;
      enable    : in  std_ulogic;
      clock_out : out std_ulogic
      );
  end component clock_generator;

  signal i2c_clock_en  : std_ulogic;
  signal i2c_clock     : std_ulogic;
  signal i2c_clock_dly : std_ulogic;

  -- register to save requests
  signal mode_reg, mode_reg_nxt             : std_ulogic_vector(1 downto 0);
  signal slave_addr_reg, slave_addr_reg_nxt : std_ulogic_vector(GW_SLAVE_ADDR-1 downto 0);
  signal bytes_tx_reg, bytes_tx_reg_nxt     : unsigned(to_log2(GV_MAX_BYTES+1)-1 downto 0);
  signal bytes_rx_reg, bytes_rx_reg_nxt     : unsigned(to_log2(GV_MAX_BYTES+1)-1 downto 0);


  -- control fsm
  type state_t is (S_IDLE, S_SYNC, S_I2C_START, S_I2C_SLAVE_ADDR, S_I2C_TX_BYTE, S_I2C_TURN, S_I2C_REPEAT_START, S_I2C_RX_BYTE, S_I2C_RX_ACK, S_I2C_TX_ACK, S_I2C_STOP);
  signal state, state_nxt               : state_t;
  signal follow_state, follow_state_nxt : state_t;

  -- data shift register
  signal i2c_tx_shift_reg, i2c_tx_shift_reg_nxt : std_logic_vector(max(8, GW_SLAVE_ADDR + 1)-1 downto 0);
  signal i2c_rx_shift_reg, i2c_rx_shift_reg_nxt : std_logic_vector(7 downto 0);

  -- counter
  signal tx_byte_cnt, tx_byte_cnt_nxt : unsigned(to_log2(GV_MAX_BYTES+1)-1 downto 0);
  signal rx_byte_cnt, rx_byte_cnt_nxt : unsigned(to_log2(GV_MAX_BYTES+1)-1 downto 0);
  signal bit_cnt, bit_cnt_nxt         : unsigned(to_log2(max(8, GW_SLAVE_ADDR + 1))-1 downto 0);

  -- error flag
  signal error_int, error_int_nxt : std_ulogic;

  signal i2c_clk_wire : std_logic;
  signal i2c_dat_wire : std_logic;

begin

  -- check if slave-address-width is 7 or 10 (as in nxp reference definition)
  assert ((GW_SLAVE_ADDR = 7) or (GW_SLAVE_ADDR = 10)) report "Warning: Most I2C-Interfaces only support 7 or 10 Bit Slave-Addresses!" severity warning;

  -- fifos
  rx_buf_inst : fifo
    generic map (
      DEPTH     => GV_MAX_BYTES,
      WORDWIDTH => 8
      )
    port map (
      clock    => clock,
      reset_n  => reset_n,
      write_en => rx_fifo_write_en,
      data_in  => rx_fifo_data_in,
      read_en  => rx_fifo_read_en,
      data_out => rx_fifo_data_out,
      empty    => rx_fifo_empty,
      full     => open,
      fill_cnt => open
      );

  tx_buf_inst : fifo
    generic map (
      DEPTH     => GV_MAX_BYTES,
      WORDWIDTH => 8
      )
    port map (
      clock    => clock,
      reset_n  => reset_n,
      write_en => tx_fifo_write_en,
      data_in  => tx_fifo_data_in,
      read_en  => tx_fifo_read_en,
      data_out => tx_fifo_data_out,
      empty    => tx_fifo_empty,
      full     => open,
      fill_cnt => open
      );


  -- clock generation
  clk_gen : clock_generator
    generic map (
      GV_CLOCK_DIV => GV_CLOCK_DIVIDER
      )
    port map (
      clock     => clock,
      reset_n   => reset_n,
      enable    => i2c_clock_en,
      clock_out => i2c_clock
      );


  -- ff
  process(clock, reset_n)
  begin
    if reset_n = '0' then
      state            <= S_IDLE;
      follow_state     <= S_IDLE;
      i2c_tx_shift_reg <= (others => '0');
      i2c_rx_shift_reg <= (others => '0');
      mode_reg         <= (others => '0');
      slave_addr_reg   <= (others => '0');
      bytes_tx_reg     <= (others => '0');
      bytes_rx_reg     <= (others => '0');
      tx_byte_cnt      <= (others => '0');
      rx_byte_cnt      <= (others => '0');
      bit_cnt          <= (others => '0');
      error_int        <= '0';
      i2c_clock_dly    <= '0';

    elsif rising_edge(clock) then
      state            <= state_nxt;
      follow_state     <= follow_state_nxt;
      i2c_tx_shift_reg <= i2c_tx_shift_reg_nxt;
      i2c_rx_shift_reg <= i2c_rx_shift_reg_nxt;
      mode_reg         <= mode_reg_nxt;
      slave_addr_reg   <= slave_addr_reg_nxt;
      bytes_tx_reg     <= bytes_tx_reg_nxt;
      bytes_rx_reg     <= bytes_rx_reg_nxt;
      tx_byte_cnt      <= tx_byte_cnt_nxt;
      rx_byte_cnt      <= rx_byte_cnt_nxt;
      bit_cnt          <= bit_cnt_nxt;
      error_int        <= error_int_nxt;
      i2c_clock_dly    <= i2c_clock;

    end if;
  end process;

  -- connect entity to fifos
  tx_fifo_data_in  <= tx_data;
  tx_fifo_write_en <= tx_data_valid;
  rx_data          <= rx_fifo_data_out;
  rx_data_valid    <= not rx_fifo_empty;
  rx_fifo_read_en  <= rx_data_en;

  -- busy signal
  busy <= '0' when state = S_IDLE else
          '1';

  -- i2c lines can only be driven with '0', a logical one is implemented via pull-up -> 'Z'
  i2c_dat <= '0' when i2c_dat_wire <= '0' else
             'Z';
  i2c_clk <= '0' when i2c_clk_wire <= '0' else
             'Z';

  -- logic
  process(state, follow_state, i2c_tx_shift_reg, i2c_rx_shift_reg, mode_reg, slave_addr_reg, bytes_tx_reg, bytes_rx_reg, tx_byte_cnt, rx_byte_cnt, bit_cnt, error_int, cs, mode, slave_addr, bytes_tx, bytes_rx, i2c_clock, i2c_clock_dly, tx_fifo_empty, tx_fifo_data_out, i2c_dat)
  begin
    -- regs
    state_nxt            <= state;
    follow_state_nxt     <= follow_state;
    i2c_tx_shift_reg_nxt <= i2c_tx_shift_reg;
    i2c_rx_shift_reg_nxt <= i2c_rx_shift_reg;
    mode_reg_nxt         <= mode_reg;
    slave_addr_reg_nxt   <= slave_addr_reg;
    bytes_tx_reg_nxt     <= bytes_tx_reg;
    bytes_rx_reg_nxt     <= bytes_rx_reg;
    tx_byte_cnt_nxt      <= tx_byte_cnt;
    rx_byte_cnt_nxt      <= rx_byte_cnt;
    bit_cnt_nxt          <= bit_cnt;

    -- i2c
    i2c_clock_en <= '1';
    i2c_dat_wire <= '1';
    i2c_clk_wire <= '1';

    -- error
    error_int_nxt <= error_int;
    error         <= '0';

    -- fifo
    rx_fifo_write_en <= '0';
    rx_fifo_data_in  <= (others => '0');
    tx_fifo_read_en  <= '0';


    -- fsm
    case state is
      when S_IDLE =>
        -- work request
        if cs = '1' then
                                        -- save relevant information to registers
          mode_reg_nxt       <= mode;
          slave_addr_reg_nxt <= slave_addr;
          bytes_tx_reg_nxt   <= bytes_tx;
          bytes_rx_reg_nxt   <= bytes_rx;

          bit_cnt_nxt <= (others => '0');
                                        -- start with syncing to i2c-clock
          state_nxt   <= S_SYNC;
        end if;

      when S_SYNC =>
        -- falling edge on i2c clock
        if i2c_clock = '0' and i2c_clock_dly = '1' then
          state_nxt <= S_I2C_START;
        end if;

      when S_I2C_START =>
        -- generate start condition
        i2c_dat_wire <= '0';
        i2c_clk_wire <= '1';

        -- falling edge on i2c clock
        if i2c_clock = '0' and i2c_clock_dly = '1' then
                                        -- reset counters
          bit_cnt_nxt     <= (others => '0');
          tx_byte_cnt_nxt <= (others => '0');
          rx_byte_cnt_nxt <= (others => '0');

          state_nxt <= S_I2C_SLAVE_ADDR;

                                        -- next follows RX
          if mode_reg = "00" or mode_reg = "10" then

            i2c_tx_shift_reg_nxt <= std_logic_vector(slave_addr_reg) & '1';
            follow_state_nxt     <= S_I2C_RX_BYTE;

                                        -- next follows TX
          elsif mode_reg = "01" or mode_reg = "11" then

            i2c_tx_shift_reg_nxt <= std_logic_vector(slave_addr_reg) & '0';
            follow_state_nxt     <= S_I2C_TX_BYTE;

          end if;

        end if;

      when S_I2C_SLAVE_ADDR =>
        i2c_clk_wire <= i2c_clock;
        i2c_dat_wire <= i2c_tx_shift_reg(i2c_tx_shift_reg'length-1);

        -- falling edge on i2c clock
        if i2c_clock = '0' and i2c_clock_dly = '1' then
                                        -- shift tx data
          i2c_tx_shift_reg_nxt <= i2c_tx_shift_reg(i2c_tx_shift_reg'length-2 downto 0) & '0';

                                        -- size of slave address reached
          if bit_cnt = GW_SLAVE_ADDR then
                                        -- reset counter
            bit_cnt_nxt <= (others => '0');

            state_nxt <= S_I2C_RX_ACK;

                                        -- fetch byte from fifo when TX is following
            if follow_state = S_I2C_TX_BYTE then
              if tx_fifo_empty = '0' then
                tx_fifo_read_en <= '1';
              end if;
              i2c_tx_shift_reg_nxt(i2c_tx_shift_reg'length-1 downto i2c_tx_shift_reg'length-8) <= std_logic_vector(tx_fifo_data_out);
            end if;

          else
            bit_cnt_nxt <= bit_cnt + 1;

          end if;
        end if;

      when S_I2C_TX_BYTE =>
        i2c_clk_wire <= i2c_clock;
        i2c_dat_wire <= i2c_tx_shift_reg(i2c_tx_shift_reg'length-1);

        -- falling edge on i2c clock
        if i2c_clock = '0' and i2c_clock_dly = '1' then
                                        -- shift
          i2c_tx_shift_reg_nxt <= i2c_tx_shift_reg(i2c_tx_shift_reg'length-2 downto 0) & '0';

                                        -- byte complete
          if bit_cnt = 7 then
                                        -- next byte
            tx_byte_cnt_nxt <= tx_byte_cnt + 1;
                                        -- reset counter
            bit_cnt_nxt     <= (others => '0');
                                        -- await ack
            state_nxt       <= S_I2C_RX_ACK;

                                        -- all bytes transferred
            if tx_byte_cnt = bytes_tx_reg - 1 then
              if mode_reg = "01" or mode_reg = "10" then
                                        -- end transfer after ack
                follow_state_nxt <= S_I2C_STOP;
              elsif mode_reg = "11" then
                                        -- turn to rx
                follow_state_nxt <= S_I2C_TURN;
              end if;
                                        -- not all bytes transferred
            else
                                        -- fetch new byte from fifo
              if tx_fifo_empty = '0' then
                tx_fifo_read_en <= '1';
              end if;
              i2c_tx_shift_reg_nxt(i2c_tx_shift_reg'length-1 downto i2c_tx_shift_reg'length-8) <= std_logic_vector(tx_fifo_data_out);
                                        -- continue after ack
              follow_state_nxt                                                                 <= S_I2C_TX_BYTE;
            end if;

          else
                                        -- continue byte
            bit_cnt_nxt <= bit_cnt + 1;
          end if;
        end if;

      when S_I2C_TURN =>
        -- turn condition
        i2c_clk_wire <= i2c_clock;
        i2c_dat_wire <= '1';

        -- falling edge on clock
        if i2c_clock = '0' and i2c_clock_dly = '1' then
          i2c_clk_wire <= '1';
          i2c_dat_wire <= '0';
          state_nxt    <= S_I2C_REPEAT_START;
        end if;

      when S_I2C_REPEAT_START =>
        -- repeated start condition
        i2c_clk_wire <= '1';
        i2c_dat_wire <= '0';

        -- falling edge on clock
        if i2c_clock = '0' and i2c_clock_dly = '1' then
          state_nxt <= S_I2C_SLAVE_ADDR;

                                        -- next follows TX
          if mode_reg = "10" then

            i2c_tx_shift_reg_nxt <= std_logic_vector(slave_addr_reg) & '0';
            follow_state_nxt     <= S_I2C_TX_BYTE;

                                        -- next follows RX
          elsif mode_reg = "11" then

            i2c_tx_shift_reg_nxt <= std_logic_vector(slave_addr_reg) & '1';
            follow_state_nxt     <= S_I2C_RX_BYTE;

          end if;
        end if;

      when S_I2C_RX_BYTE =>
        i2c_clk_wire <= i2c_clock;
        i2c_dat_wire <= 'Z';

        -- falling edge on i2c clock
        if i2c_clock = '0' and i2c_clock_dly = '1' then
                                        -- shift
          i2c_rx_shift_reg_nxt <= i2c_rx_shift_reg(i2c_rx_shift_reg'length-2 downto 0) & i2c_dat;

                                        -- byte complete
          if bit_cnt = 7 then
                                        -- next byte
            rx_byte_cnt_nxt <= rx_byte_cnt + 1;
                                        -- reset counter
            bit_cnt_nxt     <= (others => '0');
                                        -- send ack
            state_nxt       <= S_I2C_TX_ACK;

                                        -- all bytes transferred (register data)
            if rx_byte_cnt = bytes_rx_reg - 1 then
              if mode_reg = "00" or mode_reg = "11" then
                                        -- stop start after ack-transfer
                follow_state_nxt <= S_I2C_STOP;
              elsif mode_reg = "10" then
                                        -- or turn to TX
                follow_state_nxt <= S_I2C_TURN;
              end if;

                                        -- not all bytes transferred
            else
                                        -- continue receiving register data after ack-transfer
              follow_state_nxt <= S_I2C_RX_BYTE;
            end if;
          else
                                        -- continue byte
            bit_cnt_nxt <= bit_cnt + 1;
          end if;
        end if;

      when S_I2C_RX_ACK =>
        i2c_clk_wire <= i2c_clock;
        i2c_dat_wire <= 'Z';

        -- rising edge on i2c clock: save information
        if i2c_clock = '1' and i2c_clock_dly = '0' then
                                        -- negative ack
          if i2c_dat = '1' then
            error_int_nxt <= '1';
          end if;
        end if;

        -- falling edge on i2c clock: leave state
        if i2c_clock = '0' and i2c_clock_dly = '1' then
                                        -- positive ack
          if error_int = '0' then
                                        -- continue
            state_nxt <= follow_state;

                                        -- negative ack
          else
                                        -- abort
            state_nxt <= S_I2C_STOP;

          end if;
        end if;

      when S_I2C_TX_ACK =>
        i2c_clk_wire <= i2c_clock;
        i2c_dat_wire <= '0';

        -- falling edge on i2c clock
        if i2c_clock = '0' and i2c_clock_dly = '1' then
                                        -- save byte to fifo
          rx_fifo_write_en <= '1';
          rx_fifo_data_in  <= std_ulogic_vector(i2c_rx_shift_reg);
                                        -- continue
          state_nxt        <= follow_state;
        end if;

      when S_I2C_STOP =>
        i2c_clk_wire <= i2c_clock;
        i2c_dat_wire <= '0';

        -- falling edge on clock
        if i2c_clock = '0' and i2c_clock_dly = '1' then
          i2c_clk_wire  <= '1';
          i2c_dat_wire  <= '1';
          error         <= error_int;
          error_int_nxt <= '0';
          state_nxt     <= S_IDLE;
        end if;

    end case;

  end process;


end rtl;




