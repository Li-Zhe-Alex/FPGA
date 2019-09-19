--------------------------------------------------------------------------------
-- Project     : versuch2
-- Module      : sync_counter_func
-- Filename    : sync_counter_func.vhdl
-- 
-- Authors     : Li,Zhe
-- Created     : 2017-10-25
-- Last Update : 2017-10-26
--
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sync_counter_func is
  port(
    clock   	    : in  std_ulogic;
    clock_enable    : in  std_ulogic;
    reset           : in  std_ulogic;
    q               : out std_ulogic_vector(3 downto 0)
    );
end sync_counter_func;

architecture rtl of sync_counter_func is
signal temp: integer range 0 to 15;
	signal counter : std_ulogic_vector(3 downto 0);

begin

	q <= counter;
	--q <= std_ulogic_vector(to_unsigned(15, 4) - unsigned(counter));     --methode1
	
	Seq : process(clock, reset)
	begin
		if reset = '1' then
			counter <= std_ulogic_vector(to_unsigned(0, 4));
		
                elsif rising_edge(clock) then
			if clock_enable = '1' then
				counter <= std_ulogic_vector(to_unsigned(temp, 4));
                                
			end if;
		end if;

	end process Seq;

	komb : process(counter)
	begin
		if  (temp = 15) then
                        temp <= 0;
                else temp <= ((to_integer(unsigned(counter)) + 1));
                end if;
		
	end process;

end rtl;


	
	-- Seq : process(clock, reset)            --methode2
	-- begin
		-- if reset = '1' then
			-- counter <= std_ulogic_vector(to_unsigned(15, 4));
		
                -- elsif rising_edge(clock) then
			-- if clock_enable = '1' then
				-- counter <= std_ulogic_vector(to_unsigned(temp, 4));
                                
			-- end if;
		-- end if;

	-- end process Seq;

	-- komb : process(counter)
	-- begin
		-- if  (temp = 0) then
                         -- temp <= 15;
                -- else temp <= ((to_integer(unsigned(counter)) - 1));
                -- end if;
		-- --temp <= ((to_integer(unsigned(counter)) - 1));
	-- end process;

-- end rtl;


