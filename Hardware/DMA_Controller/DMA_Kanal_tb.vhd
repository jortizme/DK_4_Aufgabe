-------------------------------------------------------------------------------
-- DMA-Kanal- Testbench
-------------------------------------------------------------------------------
-- Modul Digitale Komponenten
-- Hochschule Osnabrueck
-- Joaquin Ortiz, Filip Mijac
-------------------------------------------------------------------------------

-- Gewuenschtes Verhalten, z.B. M_DAT_I <= x"AABBCCDD";

-------------------------------------------------------------------------------
-- Speicher-Speicher 
--      Lesen ->        Sel "1111" 
--      Schreiben ->    Sel "1111" M_DAT_O x"AABBCCDD""   
-------------------------------------------------------------------------------
-- Peripherie-Speicher Byte_Transfer => '0'
--      Lesen ->        Sel "1111" 
--      Schreiben ->    Sel "1111" M_DAT_O x"AABBCCDD""       
-------------------------------------------------------------------------------
-- Speicher-Peripherie- Byte_Transfer => '0'
--      Lesen ->        Sel "1111" 
--      Schreiben ->    Sel "1111" M_DAT_O x"AABBCCDD""    
-------------------------------------------------------------------------------
-- Peripherie-Speicher Byte_Transfer => '1' 1. Moeglichkeit
--      Lesen ->        Sel "0001" 
--      Schreiben ->    Sel "0001" M_DAT_O x"000000DD"     

--      Lesen ->        Sel "0001" 
--      Schreiben ->    Sel "0010" M_DAT_O x"0000DD00" 

--      Lesen ->        Sel "0001" 
--      Schreiben ->    Sel "0100" M_DAT_O x"00DD0000"

--      Lesen ->        Sel "0001" 
--      Schreiben ->    Sel "1000" M_DAT_O x"DD000000"

-- Peripherie-Speicher Byte_Transfer => '1' 2. Moeglichkeit

--      Lesen ->        Sel "0010" 
--      Schreiben ->    Sel "0001" M_DAT_O x"000000CC"     

--      Lesen ->        Sel "0010" 
--      Schreiben ->    Sel "0010" M_DAT_O x"0000CC00" 

--      Lesen ->        Sel "0010" 
--      Schreiben ->    Sel "0100" M_DAT_O x"00CC0000"

--      Lesen ->        Sel "0010" 
--      Schreiben ->    Sel "1000" M_DAT_O x"CC000000"

-- 3. Moeglichkeit ( Lesen -> Sel "0100" ) und 4. Moeglichkeit (Lesen -> Sel "1000" ) werden auch getestet

-------------------------------------------------------------------------------

--      Speicher-Peripherie- Byte_Transfer => '1' 1. Moeglichkeit

--      Lesen ->        Sel "0001" 
--      Schreiben ->    Sel "0001" M_DAT_O x"000000DD"     

--      Lesen ->        Sel "0010" 
--      Schreiben ->    Sel "0001" M_DAT_O x"000000CC"

--      Lesen ->        Sel "0100" 
--      Schreiben ->    Sel "0001" M_DAT_O x"000000BB"

--      Lesen ->        Sel "1000" 
--      Schreiben ->    Sel "0001" M_DAT_O x"000000AA"

--      Speicher-Peripherie- Byte_Transfer => '1' 2. Moeglichkeit

--      Lesen ->        Sel "0001" 
--      Schreiben ->    Sel "0010" M_DAT_O x"0000DD00"    

--      Lesen ->        Sel "0010" 
--      Schreiben ->    Sel "0010" M_DAT_O x"0000CC00"

--      Lesen ->        Sel "0100" 
--      Schreiben ->    Sel "0010" M_DAT_O x"0000BB00"

--      Lesen ->        Sel "1000" 
--      Schreiben ->    Sel "0010" M_DAT_O x"0000AA00"

-- 3. Moeglichkeit ( Schreiben -> Sel "0100" ) und 4. Moeglichkeit ( Schreiben -> Sel "1000" ) werden auch getestet
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DMA_Kanal_tb is
end entity;

use work.txt_util_pack.all;

architecture testbench of DMA_Kanal_tb is

    constant CLOCK_PERIOD : time     := 20 ns;
    constant DATA_WORT    : std_ulogic_vector(31 downto 0) := x"AABBCCDD";
    constant BUSWIDTH   : positive := 32;
    constant WORDWIDTH   : positive := 32;

    --Im Schreibvorgang beim Peripherie-Speicher-Modus die gesendeten Bytes testen
    function testBytePeri_Spei(ByteCnt : integer; 
                                M_Sel_Lese : std_ulogic_vector(3 downto 0); 
                                M_Sel_Schreib : std_ulogic_vector(3 downto 0)) return std_ulogic_vector is
        variable Wort_I : std_ulogic_vector(WORDWIDTH - 1 downto 0) := (others => '0');
        variable Byte : std_ulogic_vector(7 downto 0) := (others => '0');
    begin
        case M_Sel_Lese is
            when "0001" => Byte := x"DD";
            when "0010" => Byte := x"CC";
            when "0100" => Byte := x"BB";
            when "1000" => Byte := x"AA";
            when others => report "Falscher Sel_Vector beim Lesen" severity error;
        end case;

        case ByteCnt is
            when 0 => assert M_Sel_Schreib = "0001" report "Bytezugriff SEL Vector sollte 0001 sein" severity error;
            when 1 => assert M_Sel_Schreib = "0010" report "Bytezugriff SEL Vector sollte 0010 sein" severity error;
            when 2 => assert M_Sel_Schreib = "0100" report "Bytezugriff SEL Vector sollte 0100 sein" severity error;
            when 3 => assert M_Sel_Schreib = "1000" report "Bytezugriff SEL Vector sollte 1000 sein" severity error;
            when others => report "Falsch intern gezaehlt" severity error;
        end case ;

        Wort_I(7+(ByteCnt*8) downto 0 +(ByteCnt*8)) := Byte;

        return Wort_I;
    end function;

    --Im Schreibvorgang beim Speicher-Peripherie-Modus die gesendeten Bytes testen
    function testByteSpei_Peri(ByteCnt : integer; 
                                M_Sel_Schreib : std_ulogic_vector(3 downto 0)) return std_ulogic_vector is
        variable Wort_I : std_ulogic_vector(WORDWIDTH - 1 downto 0) := (others => '0');
        variable Byte : std_ulogic_vector(7 downto 0) := (others => '0');
    begin

        case ByteCnt is
            when 0 =>  Byte := x"DD";
            when 1 =>  Byte := x"CC";
            when 2 =>  Byte := x"BB";
            when 3 =>  Byte := x"AA";
            when others => report "Falsche intern gezaehlt" severity error;
        end case ;

        case M_Sel_Schreib is
            when "0001" => 
                Wort_I(7 downto 0) := Byte;
                assert M_Sel_Schreib = "0001" report "Bytezugriff SEL Vector sollte 0001 sein" severity error;             
            when "0010" => 
                Wort_I(15 downto 8) := Byte;
                assert M_Sel_Schreib = "0010" report "Bytezugriff SEL Vector sollte 0010 sein" severity error;
            when "0100" => 
                Wort_I(23 downto 16) := Byte;
                assert M_Sel_Schreib = "0100" report "Bytezugriff SEL Vector sollte 0100 sein" severity error;
            when "1000" => 
                Wort_I(31 downto 24) := Byte;
                assert M_Sel_Schreib = "1000" report "Bytezugriff SEL Vector sollte 1000 sein" severity error;
            when others => report "Falscher Sel_Vector beim Lesen" severity error;
        end case;

        return Wort_I;
    end function;
    
    -----------------Eingaenge--------------------
    signal Takt                 : std_ulogic;
    signal Source_Addres        : std_ulogic_vector(BUSWIDTH - 1 downto 0);
    signal Destination_Addres   : std_ulogic_vector(BUSWIDTH - 1 downto 0);
    signal Betriebsmodus        : std_ulogic_vector(1 downto 0);
    signal Transfer_Anzahl      : std_ulogic_vector(WORDWIDTH - 1 downto 0);
    signal Byte_Transfer        : std_ulogic;
    signal ExEreignisEn         : std_ulogic;
    signal Reset                : std_ulogic := '0';
    signal S_Ready              : std_ulogic := '0';
    signal M_Valid              : std_ulogic := '0';
    signal M_DAT_I              : std_ulogic_vector(WORDWIDTH - 1 downto 0);
    signal M_ACK                : std_ulogic := '0';


    ------------Ausgaenge---------------------
    signal Transfer_Fertig      : std_ulogic;
    signal Kanal_Aktiv          : std_ulogic;
    signal M_STB                : std_ulogic;
    signal M_WE                 : std_ulogic;
    signal M_ADR                : std_ulogic_vector(BUSWIDTH - 1 downto 0);
    signal M_SEL                : std_ulogic_vector(3 downto 0);
    signal M_DAT_O              : std_ulogic_vector(WORDWIDTH - 1 downto 0);


    type textcase_record is record
        Source_Addres       : std_ulogic_vector(BUSWIDTH - 1  downto 0);
        Destination_Addres  : std_ulogic_vector(BUSWIDTH - 1  downto 0);
        Betriebsmodus        : std_ulogic_vector(1 downto 0); 
        Transfer_Anzahl      : positive;
        Byte_Transfer        : boolean;
        ExEreignisEn         : boolean;
        Final_Sou_Add        : std_ulogic_vector(BUSWIDTH - 1  downto 0);
        Final_Dest_Add    : std_ulogic_vector(BUSWIDTH - 1  downto 0);
    end record;

    type testcase_vector is array(natural range <>) of textcase_record;

--Ab dem Test 9 wird immer im Byte-Transfer-Modus eine Peripherie-Adresse verwendet,
--die nicht durch 4 teilbar ist
    constant tests : testcase_vector (0 to 15) := (
        0=> (x"FF00453C", x"FF3423B0", "10", 10, false, true,  x"FF004560", x"FF3423B0"),
        1=> (x"FF0056A4", x"00392338", "10", 15, false, false, x"FF0056DC", x"00392338"),
        2=> (x"FF3445E8", x"FF34000C", "10", 20, true, true,   x"FF3445F8", x"FF34000C"),
        3=> (x"FFAC45D0", x"FF542378", "10", 18, true, false,  x"FFAC45E0", x"FF542378"),
        4=> (x"FFFD454C", x"FF34FFA4", "01", 30, false, true,  x"FFFD454C", x"FF350018"),
        5=> (x"FF00FC20", x"0434AFF0", "01", 24, false, false, x"FF00FC20", x"0434B04C"),
        6=> (x"FF000038", x"4534345C", "01", 13, true, true,   x"FF000038", x"45343468"),
        7=> (x"FF0010D4", x"593421E8", "01", 35, true, false,  x"FF0010D4", x"59342208"),
        8=> (x"AD00459C", x"FD34FAF4", "11", 27, false, false, x"AD004604", x"FD34FB5C"),
        9=> (x"FFFD454E", x"593421E8",  "01", 10, true, false, x"FFFD454C", x"593421F0"),  
        10=> (x"FFFD4547", x"48A7F670", "01", 15, true, true, x"FFFD4544", x"48A7F67C"),    
        11=> (x"FFFD4541", x"94FFAB48", "01", 27, true, false, x"FFFD4540", x"94FFAB60"),     
        12=> (x"FFAC45DC", x"FF340001", "10", 12, true, true, x"FFAC45E4", x"FF340000"),    
        13=> (x"FF0056A4", x"FF542376", "10", 22, true, false, x"FF0056B8", x"FF542374"),    
        14=> (x"FFFD4544", x"593421EB", "10", 16, true, true, x"FFFD4550", x"593421E8"),    
        15=> (x"FFFD4544", x"593421EB", "10", 7, true, true, x"FFFD4548", x"593421E8")    
    );

    --Fehlerhafte Einstellungen werden ebenfalls getestet
    constant error_tests : testcase_vector (0 to 1) := (
        0=> (x"FFFD454C", x"FF34FFA4", "00", 30, false, true,  x"FFFD454C", x"FF350018"),
        1=> (x"AD00459C", x"FD34FAF4", "11", 27, true, false, x"AD004604", x"FD34FB5C")
    );

begin

    Stimulate:process

        function to_std_ulogic(x: boolean) return std_ulogic is
            begin
                if x then 
                    return '1';
                else 
                    return '0';
                end if;
            end function;
        
        --Simuliert das Verhalten eines gesamten Transfers
        procedure execute_test(i: integer) is
            variable ByteCnt : integer := 0;
            variable M_Sel_LeseVorgang : std_ulogic_vector(3 downto 0) := (others => '0');
            variable Wort_i  : std_ulogic_vector(WORDWIDTH - 1 downto 0) := (others => '0');
        begin

            wait until falling_edge(Takt);
            Source_Addres       <= tests(i).Source_Addres; 
            Destination_Addres  <= tests(i).Destination_Addres; 
            Betriebsmodus       <= tests(i).Betriebsmodus;        
            Transfer_Anzahl     <= std_ulogic_vector(to_unsigned(tests(i).Transfer_Anzahl,WORDWIDTH));      
            Byte_Transfer       <= to_std_ulogic(tests(i).Byte_Transfer);       
            ExEreignisEn        <= to_std_ulogic(tests(i).ExEreignisEn);
            M_DAT_I             <= DATA_WORT;
            M_Valid     <= '1'; 

            loop
				wait until rising_edge(Takt);
				if Kanal_Aktiv = '1' then exit;	end if;
            end loop;

            M_Valid     <= '0';
            
            for j in 1 to tests(i).Transfer_Anzahl  loop

                --Stimulieren
                if tests(i).ExEreignisEn = true then
                    wait for CLOCK_PERIOD * 2;
                    wait until falling_edge(Takt);
                    S_Ready <= '1';
                end if;

                wait for 40 ns;

--------------------- Lesevorgang -----------------------------------
                wait until falling_edge(Takt);
                
                --Verifizieren
                assert M_STB = '1'      report "Bus beim Lesezugriff nicht angesprochen" severity error;
                assert M_WE = '0'       report "Signal WE beim Lesezugriff auf 1 gesetzt" severity error;
                assert Kanal_Aktiv = '1' report "Kanal sollte Aktiv sein"   severity error;
                assert Transfer_Fertig = '0' report "Interrupt sollte noch nicht ausgelöst werden" severity failure;

                case tests(i).Byte_Transfer is
                    
                    when false => assert M_SEL = "1111" report "Beim Wortzugriff sollte der SEL Vector 1111 sein" severity error;

                    when true  =>

                        if tests(i).Betriebsmodus = "10" then
                            case ByteCnt is
                                when 0 => assert M_SEL = "0001" report "Bytezugriff SEL Vector sollte 0001 sein" severity error;
                                when 1 => assert M_SEL = "0010" report "Bytezugriff SEL Vector sollte 0010 sein" severity error;
                                when 2 => assert M_SEL = "0100" report "Bytezugriff SEL Vector sollte 0100 sein" severity error;
                                when 3 => assert M_SEL = "1000" report "Bytezugriff SEL Vector sollte 1000 sein" severity error;
                                when others => report "Falsch gezaehlt intern" severity failure;
                            end case;   

                        elsif tests(i).Betriebsmodus = "01" then

                            case tests(i).Source_Addres(1 downto 0) is
                                when "00" => assert M_SEL = "0001" report "Bytezugriff SEL Vector sollte 0001 sein" severity error;
                                when "01" => assert M_SEL = "0010" report "Bytezugriff SEL Vector sollte 0010 sein" severity error;
                                when "10" => assert M_SEL = "0100" report "Bytezugriff SEL Vector sollte 0100 sein" severity error;
                                when "11" => assert M_SEL = "1000" report "Bytezugriff SEL Vector sollte 1000 sein" severity error;
                                when others => report "Falsche Werte bei den letzten Bits der Sourceadresse" severity failure;
                            end case;

                            M_Sel_LeseVorgang := M_SEL;
                        end if;

                end case;

                if j = tests(i).Transfer_Anzahl then
                    assert M_ADR = tests(i).Final_Sou_Add report "Die letzte SourceAdresse ist falsch" severity failure;
                end if;

                wait until falling_edge(Takt);
                S_Ready <= '0';
                M_DAT_I   <= DATA_WORT;
                
                
                wait for CLOCK_PERIOD * (j+1);
                M_ACK <= '1';   --Stimulieren

                wait for 20 ns;

                M_ACK <= '0';

--------------Schreibvorgang---------------------
                wait until falling_edge(Takt);
                
                --Verifizieren
                assert M_STB = '1'      report "Bus beim Schreibzugriff nicht angesprochen" severity error;
                assert M_WE = '1'       report "Signal WE beim Schreibugriff auf 0 gesetzt" severity error;
                assert Kanal_Aktiv = '1' report "Kanal sollte Aktiv sein"   severity error;
                assert Transfer_Fertig = '0' report "Interrupt sollte noch nicht ausgelöst werden" severity failure;

                case tests(i).Byte_Transfer is
                    
                    when false => 
                        assert M_SEL = "1111" report "Beim Wortzugriff sollte der SEL Vector 1111 sein" severity error;
                        assert M_DAT_O =  x"AABBCCDD" report "Falsches Wort gesendet" severity failure;

                    when true  =>
                    if tests(i).Betriebsmodus = "01" then
                    
                        Wort_i := testBytePeri_Spei( ByteCnt, M_Sel_LeseVorgang, M_SEL );
                        assert M_DAT_O =  Wort_i report "Falsches Byte gesendet" severity failure;

                    elsif tests(i).Betriebsmodus = "10" then
                        
                        Wort_i := testByteSpei_Peri( ByteCnt, M_SEL );
                        assert M_DAT_O =  Wort_i report "Falsches Byte gesendet" severity failure;

                    end if;
                end case;

                if j = tests(i).Transfer_Anzahl then
                    assert M_ADR = tests(i).Final_Dest_Add report "Die letzte Destination-Adresse ist falsch" severity failure;
                end if;
                
                wait until falling_edge(Takt);

                wait for CLOCK_PERIOD * (j+1);
                M_ACK <= '1'; --Stimulieren

                wait until M_STB = '0';

                ByteCnt := ByteCnt + 1;
                if ByteCnt > 3 then ByteCnt := 0; end if;

                wait until falling_edge(Takt);

                M_ACK <= '0';

                if j = tests(i).Transfer_Anzahl then
                    assert Transfer_Fertig = '1' report "Interrupt nicht ausgeloest nach dem letzten Schreibvorgang" severity failure;
                end if;

            end loop;

            wait until falling_edge(Takt);
            assert Kanal_Aktiv = '0' report "Am Ende des Transfers soll der Kanal ausgeschaltet sein" severity error;

        end procedure;

        procedure execute_error_test(i : integer) is
        begin

            wait until falling_edge(Takt);
            Source_Addres       <= error_tests(i).Source_Addres; 
            Destination_Addres  <= error_tests(i).Destination_Addres; 
            Betriebsmodus       <= error_tests(i).Betriebsmodus;        
            Transfer_Anzahl     <= std_ulogic_vector(to_unsigned(error_tests(i).Transfer_Anzahl,WORDWIDTH));      
            Byte_Transfer       <= to_std_ulogic(error_tests(i).Byte_Transfer);       
            ExEreignisEn        <= to_std_ulogic(error_tests(i).ExEreignisEn);
            M_DAT_I             <= DATA_WORT;
            M_Valid     <= '1';

            wait until falling_edge(Takt);

            assert  Kanal_Aktiv = '0' report "Bei fehlerhafet Inputs soll der Kanal inaktiv bleiben" severity error;

            wait for 100 ns;

            assert  Kanal_Aktiv = '0' report "Bei fehlerhafet Inputs soll der Kanal inaktiv bleiben" severity error;

            M_Valid     <= '0';
        end procedure;

    begin 

        for i in tests'range loop 
            execute_test(i);
            report "Test " & str(i) & " durchgefuehrt";
        end loop;

        for j in error_tests'range loop
            execute_error_test(j);
            report "Error-Test " & str(j) & " durchgefuehrt";
        end loop;

        wait;

    end process;

    clocking: process
    begin
        Takt <= '0';
        wait for CLOCK_PERIOD / 2;
        Takt <= '1';
        wait for CLOCK_PERIOD / 2;
    end process;

    DUT: entity work.DMA_Kanal
    generic map(
        BUSWIDTH => BUSWIDTH, 
        WORDWIDTH => WORDWIDTH
    )
    port map(
        Takt            =>  Takt,

        Sou_ADR         =>  Source_Addres,
        Des_ADR         =>  Destination_Addres,
        Tra_Anzahl      =>  Transfer_Anzahl,
        BetriebsMod     =>  Betriebsmodus,
        Byte_Trans      =>  Byte_Transfer,
        Ex_EreigEn      =>  ExEreignisEn,
        Reset           =>  Reset,
        Tra_Fertig      =>  Transfer_Fertig,  

        S_Ready         =>  S_Ready,
        M_Valid         =>  M_Valid,
        Kanal_Aktiv     =>  Kanal_Aktiv,

        M_STB           =>  M_STB,
        M_WE            =>  M_WE,
        M_ADR           =>  M_ADR,
        M_SEL           =>  M_SEL,
        M_DAT_O         =>  M_DAT_O,
        M_DAT_I         =>  M_DAT_I,
        M_ACK           =>  M_ACK
    );

end architecture;