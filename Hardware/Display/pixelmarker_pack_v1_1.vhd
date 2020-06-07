-----------------------------------------------------------------------------------------------
-- pixelmarker_pack
--      definiert die Marklierung der Pixel und stellt Hilfsfunktionen dafür
--      bereit
--
--   Pixel-Markierungen fuer PM (BA, IP, ZE, BE):
--        BA IP IP IP IP IP IP ZE
--        IP IP IP IP IP IP IP ZE
--        IP IP IP IP IP IP IP ZE
--        IP IP IP IP IP IP IP BE
--
--   Pixel-Markierungen fuer AXIS (SOF, IP, EOL)
--        SOF IP IP IP IP IP IP EOL
--        IP  IP IP IP IP IP IP EOL
--        IP  IP IP IP IP IP IP EOL
--        IP  IP IP IP IP IP IP EOF
--
-- (c) Rainer Höckmann, Bernhard Lang
-- HS Osnabrueck
------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pixelmarker_pack_v1_1 is
    subtype pm_t is std_ulogic_vector(1 downto 0);
    subtype pm_string_t is string (1 to 2);
    subtype axis_string_t is string (1 to 3);
    constant PM_BA: std_ulogic_vector(1 downto 0) := "11";
    constant PM_IP: std_ulogic_vector(1 downto 0) := "00";
    constant PM_ZE: std_ulogic_vector(1 downto 0) := "01";
    constant PM_BE: std_ulogic_vector(1 downto 0) := "10";
    function pm_string(pm: std_ulogic_vector(1 downto 0)) return string;
    function axis_string(tuser: std_ulogic; tlast: std_ulogic) return string;
end package;

package body pixelmarker_pack_v1_1 is
    function pm_string(pm: std_ulogic_vector(1 downto 0)) return string is
    begin
      case pm is
        when PM_BA => return "BA";
        when PM_IP => return "IP";
        when PM_ZE => return "ZE";
        when PM_BE => return "BE";
        when others => return "??";
      end case;
    end;
    function axis_string(tuser: std_ulogic; tlast: std_ulogic) return string is
    begin
      if    tuser = '1' and tlast = '0' then
        return "SOF";
      elsif tuser = '0' and tlast = '0' then
        return "   ";
      elsif tuser = '0' and tlast = '1' then
        return "EOL";
      else
        return "???";
      end if;
    end;
end package body;