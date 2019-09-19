--------------------------------------------------------------------------------
--      Institute of Microelectronic Systems
--      Architectures and Systems
--      Leibniz Universitaet Hannover
--------------------------------------------------------------------------------
--      lab :           Design Methods for FPGAs
--      file :          segment_decoder_v03.vhdl
--      authors :       Jan Duerre
--      last update :   13.10.2014
--      description :   Displays values from -16 to 15 on three 7-segment-displays
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity segment_decoder is
  port (
    data   : in  std_ulogic_vector(4 downto 0);
    hex0_n : out std_ulogic_vector(6 downto 0);
    hex1_n : out std_ulogic_vector(6 downto 0);
    hex2_n : out std_ulogic_vector(6 downto 0)
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

  signal signed_number : signed(4 downto 0);

  signal hex0 : std_ulogic_vector(6 downto 0);
  signal hex1 : std_ulogic_vector(6 downto 0);
  signal hex2 : std_ulogic_vector(6 downto 0);

begin
  -- cast data
  signed_number <= signed(data);

  -- lower decimal 
  hex0 <= "0111111" when signed_number = 0 or signed_number = 10 or signed_number = -10 else  -- '0'
          "0000110" when signed_number = 1 or signed_number = 11 or signed_number = -1 or signed_number = -11 else  -- '1'
          "1011011" when signed_number = 2 or signed_number = 12 or signed_number = -2 or signed_number = -12 else  -- '2'
          "1001111" when signed_number = 3 or signed_number = 13 or signed_number = -3 or signed_number = -13 else  -- '3'
          "1100110" when signed_number = 4 or signed_number = 14 or signed_number = -4 or signed_number = -14 else  -- '4'
          "1101101" when signed_number = 5 or signed_number = 15 or signed_number = -5 or signed_number = -15 else  -- '5'
          "1111101" when signed_number = 6 or signed_number = -6 or signed_number = -16                       else  -- '6'
          "0000111" when signed_number = 7 or signed_number = -7                                              else  -- '7'
          "1111111" when signed_number = 8 or signed_number = -8                                              else  -- '8'
          "1101111" when signed_number = 9 or signed_number = -9                                              else  -- '9'
          "1111001";                    -- error: display E

  -- upper decimal
  hex1 <= "0000110" when signed_number <=  15 and signed_number >=  10 else -- 1
          "0111111" when signed_number <=   9 and signed_number >=  -9 else -- 0
          "0000110" when signed_number <= -10 and signed_number >= -16 else -- 1
          "1111001";                    -- error: display E

  -- sign
  hex2 <= "0000000" when signed_number >=  0 and signed_number <=  15 else  -- ' '
          "1000000" when signed_number <= -1 and signed_number >= -16 else  -- '-'
          "1111001";                    -- error: display E

  -- invert signals to output
  hex0_n <= not hex0;
  hex1_n <= not hex1;
  hex2_n <= not hex2;

end rtl;
