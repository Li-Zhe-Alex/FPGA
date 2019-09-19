-----------------------------------------------------------
--      Institute of Microelectronic Systems
--      Architectures and Systems
--      Leibniz Universitaet Hannover
-----------------------------------------------------------
--      lab :         Design Methods for FPGAs
--      file :        fpga_audiofx_pkg.vhdl
--      authors :     Jan Duerre
--      last update : 04.09.2014
--      description : Package with constants and functions
-----------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fpga_audiofx_pkg is

  -- audio sample bit width
  constant SAMPLE_WIDTH : natural := 16;

  -- register interface
  constant REGIF_MODULE_RANGE : natural := 32;
  constant REGIF_ADDR_WIDTH   : natural := 8;
  constant REGIF_DATA_WIDTH   : natural := 8;

  -- functions
  function to_log2 (constant input : natural) return natural;
  function max(a, b                : integer) return integer;
  function max(a, b                : unsigned) return unsigned;
  function min(a, b                : integer) return integer;
  function min(a, b                : unsigned) return unsigned;

end;

package body fpga_audiofx_pkg is

  -- functions
  -- constant integer log to base 2
  function to_log2 (constant input : natural) return natural is
    variable temp : natural := 2;
    variable res  : natural := 1;
  begin

    if temp < input then
      while temp < input loop
        temp := temp * 2;
        res  := res + 1;
      end loop;
    end if;

    return res;
  end function;

  -- min / max
  function max(a, b : integer) return integer is
  begin
    if a > b then
      return a;
    else
      return b;
    end if;
  end function;

  function max(a, b : unsigned) return unsigned is
  begin
    if a > b then
      return a;
    else
      return b;
    end if;
  end function;

  function min(a, b : integer) return integer is
  begin
    if a < b then
      return a;
    else
      return b;
    end if;
  end function;

  function min(a, b : unsigned) return unsigned is
  begin
    if a < b then
      return a;
    else
      return b;
    end if;
  end function;

end fpga_audiofx_pkg;
