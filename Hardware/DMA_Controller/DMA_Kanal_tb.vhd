library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DMA_Kanal_tb is
end entity;

use work.txt_util_pack.all;

architecture testbench of DMA_Kanal_tb is

    constant CLOCK_PERIOD : time     := 20 ns;
    
    signal Source_Addres : std_ulogic_vector(31 downto 0);
    signal Destination_Addres : std_ulogic_vector(31 downto 0);
    signal Betriebsmodus        : std_ulogic_vector(1 downto 0);
    signal Transfer_Anzahl      : std_ulogic_vector(31 downto 0);
    signal TransferModus        : std_ulogic;
    signal ExEreignisEn         : std_ulogic;
    signal Reset                : std_ulogic;
    signal Transfer_Fertig      : std_ulogic;
    signal S_Ready              : std_ulogic;
    signal M_Valid              : std_ulogic;
    signal Kanal_Aktiv          : std_ulogic;
    signal M_STB                : std_ulogic;
    signal M_WE                 : std_ulogic;
    signal M_ADR                : std_ulogic_vector(31 downto 0);
    signal M_SEL                : std_ulogic_vector(3 downto 0);
    signal M_DAT_O              : std_ulogic_vector(31 downto 0);
    signal M_DAT_I              : std_ulogic_vector(31 downto 0);
    signal M_ACK                : std_ulogic;

    type textcase_record is record
        Source_Addres       : std_ulogic_vector(31 downto 0);
        Destination_Addres  : std_ulogic_vector(31 downto 0);
        Betriebsmodus        : std_ulogic_vector(1 downto 0);
        Transfer_Anzahl      : positive;
        TransferModus        : boolean;
        ExEreignisEn         : boolean;
        Final_Sou_Add        : std_ulogic_vector(31 downto 0);
        Final_Dest_Add    : std_ulogic_vector(31 downto 0);
    end record;

    type testcase_vector is array(natural range <>) of textcase_record;

    constant tests : testcase_vector (0 to 8) := (

        0=> (x"FF004500", x"FF342300", "10", 10, false, true, , x"FF342300"),
        1=> (x"FF005600", x"00392300", "10", 15, false, false, , x"00392300" ),
        2=> (x"FF344500", x"FF340000", "10", 20, true, true, , x"FF340000"),
        3=> (x"FFAC4500", x"FF542300", "10", 10, true, false, ,  x"FF542300"),
        4=> (x"FFFD4500", x"FF34FF00", "01", 15, false, true, x"FFFD4500" , ),
        5=> (x"FF00FC00", x"0434AF00", "01", 20, false, false, x"FF00FC00", ),
        6=> (x"FF000000", x"45343400", "01", 10, true, true, x"FF000000", ),
        7=> (x"FF001000", x"59342100", "01", 15, true, false, x"FF001000", ),
        8=> (x"AD004500", x"FD34FA00", "11", 10, false, false, , )         --Muessen wir die falschen Fälle bei Speicher-Speicher auch beruesichtigen?
    );




end architecture;