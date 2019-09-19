----------------------------------------------------------------------------
--      Institute of Microelectronic Systems
--      Architectures and Systems
--      Leibniz Universitaet Hannover
----------------------------------------------------------------------------
--      lab :           Design Methods for FPGAs
--      file :          segment_decoder_v01.vhdl
--      authors :       Jan Duerre
--      last update :   09.09.2014
--      description :   Displays values from 0 to 15 on two 7-segment-displays
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity segment_decoder is
  port (
    data   : in  std_ulogic_vector(3 downto 0);
    hex0_n : out std_ulogic_vector(6 downto 0);
    hex1_n : out std_ulogic_vector(6 downto 0)
    );
end segment_decoder;

architecture rtl of segment_decoder is

  -- +-----+
  -- |  0  |
  -- | 5 1 |
  -- |  6  |
  -- | 4 2 |
  -- |  3  |
  -- +-----+

  signal hex0 : std_ulogic_vector(6 downto 0);
  signal hex1 : std_ulogic_vector(6 downto 0);

begin

  -- lower decimal 
  process(data)
  begin
    case data is
      when "0000" => hex0 <= "0111111";  -- 0
      when "0001" => hex0 <= "0000110";  -- 1
      when "0010" => hex0 <= "1011011";  -- 2
      when "0011" => hex0 <= "1001111";  -- 3
      when "0100" => hex0 <= "1100110";  -- 4
      when "0101" => hex0 <= "1101101";  -- 5
      when "0110" => hex0 <= "1111101";  -- 6
      when "0111" => hex0 <= "0000111";  -- 7
      when "1000" => hex0 <= "1111111";  -- 8
      when "1001" => hex0 <= "1101111";  -- 9
      when "1010" => hex0 <= "0111111";  -- 10
      when "1011" => hex0 <= "0000110";  -- 11
      when "1100" => hex0 <= "1011011";  -- 12
      when "1101" => hex0 <= "1001111";  -- 13
      when "1110" => hex0 <= "1100110";  -- 14
      when "1111" => hex0 <= "1101101";  -- 15
      when others => hex0 <= "1111001";  -- error: display E
    end case;
  end process;

  -- upper decimal 
  process(data)
  begin
    case data is
      when "0000" => hex1 <= "0111111";  -- 0
      when "0001" => hex1 <= "0111111";  -- 1
      when "0010" => hex1 <= "0111111";  -- 2
      when "0011" => hex1 <= "0111111";  -- 3
      when "0100" => hex1 <= "0111111";  -- 4
      when "0101" => hex1 <= "0111111";  -- 5
      when "0110" => hex1 <= "0111111";  -- 6
      when "0111" => hex1 <= "0111111";  -- 7
      when "1000" => hex1 <= "0111111";  -- 8
      when "1001" => hex1 <= "0111111";  -- 9
      when "1010" => hex1 <= "0000110";  -- 10
      when "1011" => hex1 <= "0000110";  -- 11
      when "1100" => hex1 <= "0000110";  -- 12
      when "1101" => hex1 <= "0000110";  -- 13
      when "1110" => hex1 <= "0000110";  -- 14
      when "1111" => hex1 <= "0000110";  -- 15
      when others => hex1 <= "1111001";  -- error: display E
    end case;
  end process;

  -- invert signals to output
  hex0_n <= not hex0;
  hex1_n <= not hex1;

end rtl;
