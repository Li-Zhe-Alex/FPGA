-----------------------------------------------------------
--      Institute of Microelectronic Systems
--      Architectures and Systems
--      Leibniz Universitaet Hannover
-----------------------------------------------------------
--      lab :         Design Methods for FPGAs
--      file :        uart_regif_converter.vhdl
--      authors :     Ingo Schmaedecke / Jan Duerre
--      last update : 04.09.2014
--      description : UART-Regif Converter
-----------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga_audiofx_pkg.all;

entity uart_regif_converter is
  port (
    clock          : in  std_ulogic;
    reset          : in  std_ulogic;
    -- interface from uart-transceiver
    rx_data        : in  std_ulogic_vector(7 downto 0);
    rx_data_valid  : in  std_ulogic;
    tx_data        : out std_ulogic_vector(7 downto 0);
    tx_data_valid  : out std_ulogic;
    tx_data_ack    : in  std_ulogic;
    -- regif signals
    regif_cs       : out std_ulogic_vector(REGIF_MODULE_RANGE-1 downto 0);
    regif_wen      : out std_ulogic;
    regif_addr     : out std_ulogic_vector(REGIF_ADDR_WIDTH-1 downto 0);
    regif_data_in  : out std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0);
    regif_data_out : in  std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0)
    );
end uart_regif_converter;

architecture rtl of uart_regif_converter is

  --scanner signals
  type sc_state_t is (SC_IDLE,
                      FIRST_NIBBLE_0, FIRST_NIBBLE_U, FIRST_NIBBLE_C, FIRST_NIBBLE_2,
                      SECOND_NIBBLE_U, SECOND_NIBBLE_C, SECOND_NIBBLE_2,
                      THIRD_NIBBLE,
                      SEND_NUMBER,
                      CHAR_AFTER_VALUE
                      );
  signal sc_state     : sc_state_t;
  signal sc_state_nxt : sc_state_t;

  signal char     : std_ulogic_vector(7 downto 0);
  signal char_nxt : std_ulogic_vector(7 downto 0);

  signal nibble_reg1     : std_ulogic_vector(3 downto 0);
  signal nibble_reg1_nxt : std_ulogic_vector(3 downto 0);
  signal nibble_reg2     : std_ulogic_vector(3 downto 0);
  signal nibble_reg2_nxt : std_ulogic_vector(3 downto 0);
  signal nibble_reg3     : std_ulogic_vector(3 downto 0);
  signal nibble_reg3_nxt : std_ulogic_vector(3 downto 0);

  signal nibble_value1     : std_ulogic_vector(3 downto 0);
  signal nibble_value1_nxt : std_ulogic_vector(3 downto 0);
  signal nibble_value2     : std_ulogic_vector(3 downto 0);
  signal nibble_value2_nxt : std_ulogic_vector(3 downto 0);
  signal nibble_value3     : std_ulogic_vector(3 downto 0);
  signal nibble_value3_nxt : std_ulogic_vector(3 downto 0);

  signal sc_value     : std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0);
  signal sc_value_nxt : std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0);

  signal sc_valid     : std_ulogic;
  signal sc_valid_nxt : std_ulogic;
  signal m_char       : std_ulogic;
  signal m_char_nxt   : std_ulogic;
  signal r_char       : std_ulogic;
  signal r_char_nxt   : std_ulogic;
  signal eq_char      : std_ulogic;
  signal eq_char_nxt  : std_ulogic;
  signal qu_char      : std_ulogic;
  signal qu_char_nxt  : std_ulogic;
  signal re_char      : std_ulogic;
  signal re_char_nxt  : std_ulogic;

  --parser signals
  type ps_state_t is (PS_IDLE, M_STATE, M_VAL, R_STATE, R_VAL, QU_STATE, EQ_STATE, EQ_VAL);
  signal ps_state     : ps_state_t;
  signal ps_state_nxt : ps_state_t;

  signal ps_alland_char               : std_ulogic;
  signal ps_regif_data_out_valid      : std_ulogic;
  signal ps_regif_data_out_valid_nxt  : std_ulogic;
  signal ps_regif_data_out_valid_nxt2 : std_ulogic;
  signal ps_module_id                 : std_ulogic_vector(to_log2(REGIF_MODULE_RANGE)-1 downto 0);
  signal ps_module_id_nxt             : std_ulogic_vector(to_log2(REGIF_MODULE_RANGE)-1 downto 0);

  signal ps_regif_cs          : std_ulogic_vector(REGIF_MODULE_RANGE-1 downto 0);
  signal ps_regif_cs_nxt      : std_ulogic_vector(REGIF_MODULE_RANGE-1 downto 0);
  signal ps_regif_wen         : std_ulogic;
  signal ps_regif_wen_nxt     : std_ulogic;
  signal ps_regif_addr        : std_ulogic_vector(REGIF_ADDR_WIDTH-1 downto 0);
  signal ps_regif_addr_nxt    : std_ulogic_vector(REGIF_ADDR_WIDTH-1 downto 0);
  signal ps_regif_data_in     : std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0);
  signal ps_regif_data_in_nxt : std_ulogic_vector(REGIF_DATA_WIDTH-1 downto 0);

  --code generator signals
  type cg_state_t is (CG_IDLE, WAIT_ACK1, WAIT_ACK2, SEND_RE);
  signal cg_state     : cg_state_t;
  signal cg_state_nxt : cg_state_t;

  signal char2     : std_ulogic_vector(7 downto 0);
  signal char2_nxt : std_ulogic_vector(7 downto 0);
  signal char3     : std_ulogic_vector(7 downto 0);
  signal char3_nxt : std_ulogic_vector(7 downto 0);
  signal char4     : std_ulogic_vector(7 downto 0);
  signal char4_nxt : std_ulogic_vector(7 downto 0);

  signal tx_data_valid_nxt : std_ulogic;
  signal tx_data_reg       : std_ulogic_vector(7 downto 0);
  signal tx_data_reg_nxt   : std_ulogic_vector(7 downto 0);

  signal rx_data_lo : unsigned(3 downto 0);
  signal rx_data_hi : unsigned(3 downto 0);

begin

  rx_data_lo <= unsigned(rx_data(3 downto 0));
  rx_data_hi <= unsigned(rx_data(7 downto 4));

  -- parser signals assignments
  regif_cs       <= ps_regif_cs;
  regif_wen      <= ps_regif_wen;
  regif_addr     <= ps_regif_addr;
  regif_data_in  <= ps_regif_data_in;
  ps_alland_char <= m_char or r_char or eq_char or qu_char or re_char;

  -- code generator signals
  tx_data <= tx_data_reg;

  ff : process (clock, reset)
  begin
    if reset = '1' then
      sc_valid      <= '0';
      m_char        <= '0';
      r_char        <= '0';
      eq_char       <= '0';
      qu_char       <= '0';
      re_char       <= '0';
      sc_value      <= (others => '0');
      char          <= (others => '0');
      nibble_reg1   <= (others => '0');
      nibble_reg2   <= (others => '0');
      nibble_reg3   <= (others => '0');
      nibble_value1 <= (others => '0');
      nibble_value2 <= (others => '0');
      nibble_value3 <= (others => '0');
      sc_value      <= (others => '0');
      sc_state      <= SC_IDLE;

      ps_state                    <= PS_IDLE;
      ps_regif_data_out_valid_nxt <= '0';
      ps_regif_data_out_valid     <= '0';
      ps_regif_wen                <= '0';
      ps_regif_cs                 <= (others => '0');
      ps_module_id                <= (others => '0');
      ps_regif_addr               <= (others => '0');
      ps_regif_data_in            <= (others => '0');

      cg_state      <= CG_IDLE;
      char2         <= (others => '0');
      char3         <= (others => '0');
      char4         <= (others => '0');
      tx_data_valid <= '0';
      tx_data_reg   <= (others => '0');

    elsif rising_edge(clock) then
      sc_valid      <= sc_valid_nxt;
      m_char        <= m_char_nxt;
      r_char        <= r_char_nxt;
      eq_char       <= eq_char_nxt;
      qu_char       <= qu_char_nxt;
      re_char       <= re_char_nxt;
      sc_value      <= sc_value_nxt;
      char          <= char_nxt;
      nibble_reg1   <= nibble_reg1_nxt;
      nibble_reg2   <= nibble_reg2_nxt;
      nibble_reg3   <= nibble_reg3_nxt;
      nibble_value1 <= nibble_value1_nxt;
      nibble_value2 <= nibble_value2_nxt;
      nibble_value3 <= nibble_value3_nxt;
      sc_state      <= sc_state_nxt;

      ps_state                    <= ps_state_nxt;
      ps_regif_data_out_valid_nxt <= ps_regif_data_out_valid_nxt2;
      ps_regif_data_out_valid     <= ps_regif_data_out_valid_nxt;
      ps_regif_wen                <= ps_regif_wen_nxt;
      ps_regif_cs                 <= ps_regif_cs_nxt;
      ps_module_id                <= ps_module_id_nxt;
      ps_regif_addr               <= ps_regif_addr_nxt;
      ps_regif_data_in            <= ps_regif_data_in_nxt;

      cg_state      <= cg_state_nxt;
      char2         <= char2_nxt;
      char3         <= char3_nxt;
      char4         <= char4_nxt;
      tx_data_valid <= tx_data_valid_nxt;
      tx_data_reg   <= tx_data_reg_nxt;
    end if;
  end process ff;




  -- analyse rx_data for its meaning
  -- separate between command characters (M, R, =, ?, CR) and digits (0,1,...,9)
  -- sequences of digits (1, 2 or 3)  are interpreted as an 8bit decimal value,
  -- which is limited to a range of 0 to 255
  scanner_fsm : process (char, char_nxt, nibble_reg1, nibble_reg2, nibble_reg3, nibble_value1, nibble_value2, nibble_value3, sc_state, sc_value, rx_data_valid, rx_data, rx_data_lo, rx_data_hi)
  begin
    sc_valid_nxt      <= '0';
    m_char_nxt        <= '0';
    r_char_nxt        <= '0';
    eq_char_nxt       <= '0';
    qu_char_nxt       <= '0';
    re_char_nxt       <= '0';
    nibble_reg1_nxt   <= nibble_reg1;
    nibble_reg2_nxt   <= nibble_reg2;
    nibble_reg3_nxt   <= nibble_reg3;
    nibble_value1_nxt <= nibble_value1;
    nibble_value2_nxt <= nibble_value2;
    nibble_value3_nxt <= nibble_value3;
    char_nxt          <= char;
    sc_value_nxt      <= sc_value;
    sc_state_nxt      <= SC_IDLE;

    case sc_state is
      when SC_IDLE =>
        -- when a new uart data is available
        if rx_data_valid = '1' then

          if rx_data = x"4D" then       -- M
            m_char_nxt   <= '1';
            sc_valid_nxt <= '1';

          elsif rx_data = x"52" then    -- R
            r_char_nxt   <= '1';
            sc_valid_nxt <= '1';

          elsif rx_data = x"3D" then    -- =
            eq_char_nxt  <= '1';
            sc_valid_nxt <= '1';

          elsif rx_data = x"3F" then    -- ?
            qu_char_nxt  <= '1';
            sc_valid_nxt <= '1';

          elsif rx_data = x"0D" then    -- CR
            re_char_nxt  <= '1';
            sc_valid_nxt <= '1';

          elsif rx_data_hi = x"3" and rx_data_lo < x"A" then  -- rx_data is a digit
            if rx_data_lo = x"0" then
              nibble_reg1_nxt <= std_ulogic_vector(rx_data_lo);
              sc_state_nxt    <= FIRST_NIBBLE_0;

            elsif rx_data_lo < x"2" then
              nibble_reg1_nxt <= std_ulogic_vector(rx_data_lo);
              sc_state_nxt    <= FIRST_NIBBLE_U;

            elsif rx_data_lo = x"2" then
              nibble_reg1_nxt <= std_ulogic_vector(rx_data_lo);
              sc_state_nxt    <= FIRST_NIBBLE_C;

            elsif rx_data_lo < x"A" then
              nibble_reg1_nxt <= std_ulogic_vector(rx_data_lo);
              sc_state_nxt    <= FIRST_NIBBLE_2;

            end if;
          end if;
        end if;

      when FIRST_NIBBLE_0 =>
        if rx_data_valid = '1' then
          if rx_data = x"52" or rx_data = x"3D" or rx_data = x"0D" or rx_data = x"3F" then
            char_nxt          <= rx_data;
            nibble_value1_nxt <= (others => '0');
            nibble_value2_nxt <= (others => '0');
            nibble_value3_nxt <= nibble_reg1;
            sc_state_nxt      <= SEND_NUMBER;

          else
            if rx_data_hi = x"3" then
              if rx_data_lo = x"0" then
                nibble_reg1_nxt <= std_ulogic_vector(rx_data_lo);
                sc_state_nxt    <= FIRST_NIBBLE_0;

              elsif rx_data_lo < x"2" then
                nibble_reg1_nxt <= std_ulogic_vector(rx_data_lo);
                sc_state_nxt    <= FIRST_NIBBLE_U;

              elsif rx_data_lo = x"2" then
                nibble_reg1_nxt <= std_ulogic_vector(rx_data_lo);
                sc_state_nxt    <= FIRST_NIBBLE_C;

              elsif rx_data_lo < x"A" then
                nibble_reg1_nxt <= std_ulogic_vector(rx_data_lo);
                sc_state_nxt    <= FIRST_NIBBLE_2;

              end if;
            else
              sc_state_nxt <= SC_IDLE;

            end if;
          end if;
        else
          sc_state_nxt <= FIRST_NIBBLE_0;

        end if;

      when FIRST_NIBBLE_U =>
        if rx_data_valid = '1' then
          if rx_data = x"52" or rx_data = x"3D" or rx_data = x"0D" or rx_data = x"3F" then
            char_nxt          <= rx_data;
            nibble_value1_nxt <= (others => '0');
            nibble_value2_nxt <= (others => '0');
            nibble_value3_nxt <= nibble_reg1;
            sc_state_nxt      <= SEND_NUMBER;

          else
            if rx_data_hi = x"3" and rx_data_lo < x"A" then
              nibble_reg2_nxt <= std_ulogic_vector(rx_data_lo);
              sc_state_nxt    <= SECOND_NIBBLE_U;

            else
              sc_state_nxt <= SC_IDLE;

            end if;
          end if;
        else
          sc_state_nxt <= FIRST_NIBBLE_U;

        end if;

      when FIRST_NIBBLE_C =>
        if rx_data_valid = '1' then
          if rx_data = x"52" or rx_data = x"3D" or rx_data = x"0D" or rx_data = x"3F" then
            char_nxt          <= rx_data;
            nibble_value1_nxt <= (others => '0');
            nibble_value2_nxt <= (others => '0');
            nibble_value3_nxt <= nibble_reg1;
            sc_state_nxt      <= SEND_NUMBER;

          else
            if rx_data_hi = x"3" then
              if rx_data_lo < x"5" then
                nibble_reg2_nxt <= std_ulogic_vector(rx_data_lo);
                sc_state_nxt    <= SECOND_NIBBLE_U;

              elsif rx_data_lo = x"5" then
                nibble_reg2_nxt <= std_ulogic_vector(rx_data_lo);
                sc_state_nxt    <= SECOND_NIBBLE_C;

              elsif rx_data_lo < x"A" then
                nibble_reg2_nxt <= std_ulogic_vector(rx_data_lo);
                sc_state_nxt    <= SECOND_NIBBLE_2;

              else
                sc_state_nxt <= SC_IDLE;

              end if;
            else
              sc_state_nxt <= SC_IDLE;

            end if;
          end if;
        else
          sc_state_nxt <= FIRST_NIBBLE_C;

        end if;

      when FIRST_NIBBLE_2 =>
        if rx_data_valid = '1' then
          if rx_data = x"52" or rx_data = x"3D" or rx_data = x"0D" or rx_data = x"3F" then
            char_nxt          <= rx_data;
            nibble_value1_nxt <= (others => '0');
            nibble_value2_nxt <= (others => '0');
            nibble_value3_nxt <= nibble_reg1;
            sc_state_nxt      <= SEND_NUMBER;

          else
            if rx_data_hi = x"3" and rx_data_lo < x"A" then
              nibble_reg2_nxt <= std_ulogic_vector(rx_data_lo);
              sc_state_nxt    <= SECOND_NIBBLE_2;

            else
              sc_state_nxt <= SC_IDLE;

            end if;
          end if;
        else
          sc_state_nxt <= FIRST_NIBBLE_2;

        end if;

      when SECOND_NIBBLE_U =>
        if rx_data_valid = '1' then
          if rx_data = x"52" or rx_data = x"3D" or rx_data = x"0D" or rx_data = x"3F" then
            char_nxt          <= rx_data;
            nibble_value1_nxt <= (others => '0');
            nibble_value2_nxt <= nibble_reg1;
            nibble_value3_nxt <= nibble_reg2;
            sc_state_nxt      <= SEND_NUMBER;

          else
            if rx_data_hi = x"3" and unsigned(rx_data_lo) < x"A" then
              nibble_reg3_nxt <= std_ulogic_vector(rx_data_lo);
              sc_state_nxt    <= THIRD_NIBBLE;

            else
              sc_state_nxt <= SC_IDLE;

            end if;
          end if;
        else
          sc_state_nxt <= SECOND_NIBBLE_U;

        end if;

      when SECOND_NIBBLE_C =>
        if rx_data_valid = '1' then
          if rx_data = x"52" or rx_data = x"3D" or rx_data = x"0D" or rx_data = x"3F" then
            char_nxt          <= rx_data;
            nibble_value1_nxt <= (others => '0');
            nibble_value2_nxt <= nibble_reg1;
            nibble_value3_nxt <= nibble_reg2;
            sc_state_nxt      <= SEND_NUMBER;

          else
            if rx_data_hi = x"3" and rx_data_lo < x"6" then
              nibble_reg3_nxt <= std_ulogic_vector(rx_data_lo);
              sc_state_nxt    <= THIRD_NIBBLE;

            else
              sc_state_nxt <= SC_IDLE;

            end if;
          end if;
        else
          sc_state_nxt <= SECOND_NIBBLE_C;

        end if;

      when SECOND_NIBBLE_2 =>
        if rx_data_valid = '1' then
          if rx_data = x"52" or rx_data = x"3D" or rx_data = x"0D" or rx_data = x"3F" then
            char_nxt          <= rx_data;
            nibble_value1_nxt <= (others => '0');
            nibble_value2_nxt <= nibble_reg1;
            nibble_value3_nxt <= nibble_reg2;
            sc_state_nxt      <= SEND_NUMBER;

          else
            sc_state_nxt <= SC_IDLE;

          end if;
        else
          sc_state_nxt <= SECOND_NIBBLE_2;

        end if;

      when THIRD_NIBBLE =>
        if rx_data_valid = '1' then
          if rx_data = x"52" or rx_data = x"3D" or rx_data = x"0D" or rx_data = x"3F" then
            char_nxt          <= rx_data;
            nibble_value1_nxt <= nibble_reg1;
            nibble_value2_nxt <= nibble_reg2;
            nibble_value3_nxt <= nibble_reg3;
            sc_state_nxt      <= SEND_NUMBER;

          else
            sc_state_nxt <= SC_IDLE;

          end if;
        else
          sc_state_nxt <= THIRD_NIBBLE;

        end if;

      when SEND_NUMBER =>
        sc_value_nxt <= std_ulogic_vector(to_unsigned(100 * to_integer(unsigned(nibble_value1)), sc_value_nxt'length) +
                                          to_unsigned(10 * to_integer(unsigned(nibble_value2)), sc_value_nxt'length) +
                                          unsigned(nibble_value3));
        sc_valid_nxt <= '1';
        sc_state_nxt <= CHAR_AFTER_VALUE;

      when CHAR_AFTER_VALUE =>
        if char_nxt = x"52" then
          r_char_nxt   <= '1';
          sc_valid_nxt <= '1';

        elsif char_nxt = x"3D" then
          eq_char_nxt  <= '1';
          sc_valid_nxt <= '1';

        elsif char_nxt = x"3F" then
          qu_char_nxt  <= '1';
          sc_valid_nxt <= '1';

        else
          re_char_nxt  <= '1';
          sc_valid_nxt <= '1';

        end if;

        sc_state_nxt <= SC_IDLE;

    end case;

  end process scanner_fsm;

  -- check the sequence of incoming characters and values
  -- only valid sequences result in regif transactions 
  -- required sequence for regif write: "M", value, "R", value, "=", value, "CR"
  -- required sequence for regif read:  "M", value, "R", value, "?", "CR"
  parser_fsm : process (eq_char, m_char, qu_char, re_char, r_char, ps_alland_char, ps_module_id, ps_regif_addr, ps_regif_data_in, ps_regif_wen, ps_state, sc_valid, sc_value)
  begin

    -- default assignments
    ps_regif_wen_nxt             <= ps_regif_wen;
    ps_module_id_nxt             <= ps_module_id;
    ps_regif_addr_nxt            <= ps_regif_addr;
    ps_regif_data_in_nxt         <= ps_regif_data_in;
    ps_state_nxt                 <= ps_state;
    ps_regif_cs_nxt              <= (others => '0');
    ps_regif_data_out_valid_nxt2 <= '0';

    if sc_valid = '1' then
      case ps_state is

        when PS_IDLE =>
          if m_char = '1' then
            ps_state_nxt <= M_STATE;
          end if;

        when M_STATE =>
          if ps_alland_char = '0' then
            ps_module_id_nxt <= std_ulogic_vector(resize(unsigned(sc_value), ps_module_id_nxt'length));
            ps_state_nxt     <= M_VAL;
          else
            ps_state_nxt <= PS_IDLE;
          end if;

        when M_VAL =>
          if r_char = '1' then
            ps_state_nxt <= R_STATE;
          else
            ps_state_nxt <= PS_IDLE;
          end if;

        when R_STATE =>
          if ps_alland_char = '0' then
            ps_regif_addr_nxt <= sc_value;
            ps_state_nxt      <= R_VAL;
          else
            ps_state_nxt <= PS_IDLE;
          end if;

        when R_VAL =>
          if qu_char = '1' then
            ps_regif_data_in_nxt(REGIF_DATA_WIDTH/2-1 downto 0) <= (others => '0');
            ps_state_nxt                                        <= QU_STATE;
          elsif eq_char = '1' then
            ps_state_nxt <= EQ_STATE;
          else
            ps_state_nxt <= PS_IDLE;
          end if;

        when EQ_STATE =>
          if ps_alland_char = '0' then
            ps_regif_data_in_nxt(REGIF_DATA_WIDTH-1 downto 0) <= sc_value;
            ps_state_nxt                                      <= EQ_VAL;
          else
            ps_state_nxt <= PS_IDLE;
          end if;

        when EQ_VAL =>
          if re_char = '1' then
            ps_regif_cs_nxt(to_integer(unsigned(ps_module_id))) <= '1';
            ps_regif_wen_nxt                                    <= '1';
            ps_state_nxt                                        <= PS_IDLE;
          else
            ps_state_nxt <= PS_IDLE;
          end if;

        when QU_STATE =>
          if re_char = '1' then
            ps_regif_cs_nxt(to_integer(unsigned(ps_module_id))) <= '1';
            ps_regif_wen_nxt                                    <= '0';
            ps_regif_data_out_valid_nxt2                        <= '1';
          end if;

          ps_state_nxt <= PS_IDLE;

      end case;

    end if;

  end process parser_fsm;

  -- received data of regif bus are divided into 4 hex digits and are send to uart_interface
  code_generator_fsm : process (cg_state, char2, char3, char4, ps_regif_data_out_valid, regif_data_out, tx_data_reg, tx_data_ack)
  begin
    char2_nxt         <= char2;
    char3_nxt         <= char3;
    char4_nxt         <= char4;
    tx_data_valid_nxt <= '0';
    tx_data_reg_nxt   <= tx_data_reg;
    cg_state_nxt      <= cg_state;

    case cg_state is
      when CG_IDLE =>
        if ps_regif_data_out_valid = '1' then
          if regif_data_out(REGIF_DATA_WIDTH-1 downto REGIF_DATA_WIDTH/2) < x"A" then
            tx_data_reg_nxt <= x"3" & regif_data_out(REGIF_DATA_WIDTH-1 downto REGIF_DATA_WIDTH/2);
          else
            tx_data_reg_nxt <= x"4" & std_ulogic_vector(unsigned(regif_data_out(REGIF_DATA_WIDTH-1 downto REGIF_DATA_WIDTH/2))-x"9");
          end if;

          if regif_data_out(REGIF_DATA_WIDTH/2-1 downto 0) < x"A" then
            char2_nxt <= x"3" & regif_data_out(REGIF_DATA_WIDTH/2-1 downto 0);
          else
            char2_nxt <= x"4" & std_ulogic_vector(unsigned(regif_data_out(REGIF_DATA_WIDTH/2-1 downto 0))-x"9");
          end if;

          tx_data_valid_nxt <= '1';
          cg_state_nxt      <= WAIT_ACK1;

        end if;

      when WAIT_ACK1 =>
        if tx_data_ack = '1' then
          tx_data_reg_nxt   <= char2;
          tx_data_valid_nxt <= '1';
          cg_state_nxt      <= WAIT_ACK2;
        end if;

      when WAIT_ACK2 =>
        if tx_data_ack = '1' then
          tx_data_reg_nxt   <= x"0D";
          tx_data_valid_nxt <= '1';
          cg_state_nxt      <= SEND_RE;
        end if;

      when SEND_RE =>
        if tx_data_ack = '1' then
          cg_state_nxt <= CG_IDLE;
        end if;

    end case;

  end process code_generator_fsm;

end architecture rtl;
