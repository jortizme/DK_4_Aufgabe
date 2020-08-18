-------------------------------------------------------------------------------
-- DMA-Kanal- Testbench
-------------------------------------------------------------------------------
-- Modul Digitale Komponenten
-- Hochschule Osnabrueck
-- Joaquin Ortiz, Filip Mijac
-------------------------------------------------------------------------------
entity DMA_Kontroller_tb is
end entity;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_test_pack.all;
use work.txt_util_pack.all;

architecture test of DMA_Kontroller_tb is

    constant BUSWIDTH   : positive := 32;
    constant WORDWIDTH  : positive := 32;
    constant CLOCK_PERIOD : time   := 20 ns;
    constant DATA_WORT    : std_logic_vector(WORDWIDTH - 1 downto 0) := x"AABBCCDD";

    constant SAR0   :   std_logic_vector(7 downto 0) := x"00";
    constant DESTR0 :   std_logic_vector(7 downto 0) := x"04";
    constant TRAAR0 :   std_logic_vector(7 downto 0) := x"08";
    constant CR0    :   std_logic_vector(7 downto 0) := x"0C";
    constant SAR1   :   std_logic_vector(7 downto 0) := x"10";
    constant DESTR1 :   std_logic_vector(7 downto 0) := x"14";
    constant TRAAR1 :   std_logic_vector(7 downto 0) := x"18";
    constant CR1    :   std_logic_vector(7 downto 0) := x"1C";
    constant SR     :   std_logic_vector(7 downto 0) := x"20";

    function cr_value(
        BetrModus    : in unsigned;
        Byte_Trans   : in boolean;
        Freigabe_Int : in boolean;
        ExEreig_En   : in boolean;
        KanalEnable  : in boolean;
        QuitiertInt  : in boolean
    ) return std_logic_vector is
        variable r : std_logic_vector(BUSWIDTH - 1 downto 0);
    begin

        r := (others => '0');

        r(1 downto 0) := std_logic_vector(BetrModus);
        if Byte_Trans then
            r(2) := '1';
        end if;
        if Freigabe_Int then
            r(3) := '1';
        end if;
        if ExEreig_En then
            r(4) := '1';
        end if;
        if KanalEnable then
            r(5) := '1';
        end if;
        if QuitiertInt then 
            r(6) := '1';
        end if;

        return r;
    end function;

    function to_std_logic(x: boolean) return std_logic is
        begin
            if x then 
                return '1';
            else 
                return '0';
            end if;
        end function;

    signal   RST           : std_logic := '1';
    signal   Takt          : std_logic  := '0';
    signal   Interrupt0    : std_logic;
    signal   Interrupt1    : std_logic;
    signal   S0_Ready       : std_logic := '0';
    signal   S1_Ready       : std_logic := '0';

	signal   M_STB         : std_logic;
	signal   M_WE          : std_logic;
	signal   M_ADR         : std_logic_vector(BUSWIDTH - 1 downto 0);
	signal   M_SEL         : std_logic_vector(3 downto 0);
    signal   M_ACK         : std_logic  := '0';
	signal   M_DAT_O       : std_logic_vector(31 downto 0);
    signal   M_DAT_I       : std_logic_vector(31 downto 0) := (others => '0');

	signal   S_STB         : std_logic := '0';
	signal   S_WE          : std_logic := '0';
    signal   S_ADR         : std_logic_vector(7 downto 0) := (others => '0');
	signal   S_SEL         : std_logic_vector(3 downto 0) := (others => '0');
    signal   S_ACK         : std_logic;
    signal   S_DAT_O       : std_logic_vector(31 downto 0);
    signal   S_DAT_I       : std_logic_vector(31 downto 0) := (others => '0'); 
    

    type textcase_record is record
        Source_Addres       : std_logic_vector(BUSWIDTH - 1  downto 0);
        Destination_Addres  : std_logic_vector(BUSWIDTH - 1  downto 0);
        Betriebsmodus        : std_logic_vector(1 downto 0); 
        Transfer_Anzahl      : integer;
        Byte_Transfer        : boolean;
        ExEreignisEn         : boolean;
    end record;

    type testcase_vector is array(natural range <>) of textcase_record;

    --Ab dem Test 9 wird immer im Byte-Transfer-Modus eine Peripherie-Adresse verwendet,
    --die nicht durch 4 teilbar ist
    constant tests : testcase_vector (0 to 16) := (
        0=> (x"FF00453C", x"FF3423B0", "10", 10, false, true),
        1=> (x"FF0056A4", x"00392338", "10", 15, false, false),
        2=> (x"FF3445E8", x"FF34000C", "10", 20, true, true),
        3=> (x"FFAC45D0", x"FF542378", "10", 18, true, false),
        4=> (x"FFFD454C", x"FF34FFA4", "01", 30, false, true),
        5=> (x"FF00FC20", x"0434AFF0", "01", 24, false, false),
        6=> (x"FF000038", x"4534345C", "01", 13, true, true),
        7=> (x"FF0010D4", x"593421E8", "01", 35, true, false),
        8=> (x"AD00459C", x"FD34FAF4", "00", 27, false, false),
        9=> (x"FFFD454E", x"593421E8",  "01", 10, true, false),  
        10=> (x"FFFD4547", x"48A7F670", "01", 15, true, true),    
        11=> (x"FFFD4541", x"94FFAB48", "01", 27, true, false),     
        12=> (x"FFAC45DC", x"FF340001", "10", 12, true, true),    
        13=> (x"FF0056A4", x"FF542376", "10", 22, true, false),    
        14=> (x"FFFD4544", x"593421EB", "10", 16, true, true),    
        15=> (x"FFFD4544", x"593421EB", "10", 7, true, true),
        16=> (x"FF00FC20", x"48A7F670", "00", 34, false, false)    
    );

    begin

        stim_and_verify:process

            procedure execute_test(i_a: in integer)is
                variable write_data : std_logic_vector(31 downto 0) := (others => '0');
                variable read_data  : std_logic_vector(31 downto 0) := (others => '0');
                variable i_b : integer := tests'length - i_a - 1;
            begin
        
                --Das System Neu Starten
                M_ACK <= '0';
                S1_Ready <= '0';
                S0_Ready <= '0';
                M_DAT_I  <= (others => '0');
                RST <= '1';
                wishbone_init(S_STB, S_WE, S_SEL, S_ADR, S_DAT_I);        
                wait_cycle(2, Takt);
                RST <= '0';
                M_DAT_I  <= DATA_WORT;
                wait_cycle(2, Takt);
        
                --Source-Adresse von Kanal1 einstellen
                write_data := tests(i_a).Source_Addres;
                wishbone_write(x"f", SAR0, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
        
                --Destination-Adresse von Kanal1 einstellen
                write_data := tests(i_a).Destination_Addres;
                wishbone_write(x"f", DESTR0, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
        
                --Transferanzahl von Kanal1 einstellen
                write_data := std_logic_vector(to_unsigned(tests(i_a).Transfer_Anzahl,WORDWIDTH));
                wishbone_write(x"f", TRAAR0, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                wishbone_read(TRAAR0, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data = write_data report "Falsche Anzahl von Transfers Kanal1 eingestellt" severity failure;
        
                --Einstellung von CR0 von Kanal1 
                write_data := cr_value(unsigned(tests(i_a).Betriebsmodus), tests(i_a).Byte_Transfer, true, tests(i_a).ExEreignisEn, false, false);
                wishbone_write(x"f", CR0, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                wishbone_read(CR0, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data = write_data report "Falsche Wert in CR0 Kanal1 eingestellt" severity failure;
        
                --Source-Adresse von Kanal2 einstellen
                write_data := tests(i_b).Source_Addres;
                wishbone_write(x"f", SAR1, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
        
                --Destination-Adresse von Kanal2 einstellen
                write_data := tests(i_b).Destination_Addres;
                wishbone_write(x"f", DESTR1, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
        
                --Transferanzahl von Kanal2 einstellen
                write_data := std_logic_vector(to_unsigned(tests(i_b).Transfer_Anzahl,WORDWIDTH));
                wishbone_write(x"f", TRAAR1, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                wishbone_read(TRAAR1, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data = write_data report "Falsche Anzahl von Transfers Kanal2 eingestellt" severity failure;
        
                --Einstellung von CR1 von Kanal2 
                write_data := cr_value(unsigned(tests(i_b).Betriebsmodus), tests(i_b).Byte_Transfer, true, tests(i_b).ExEreignisEn, false, false);
                wishbone_write(x"f", CR1, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                wishbone_read(CR1, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data = write_data report "Falsche Wert in CR0 Kanal1 eingestellt" severity failure;
        
                --Aktivieren des Kanals 2
                write_data := cr_value(unsigned(tests(i_b).Betriebsmodus), tests(i_b).Byte_Transfer, true, tests(i_b).ExEreignisEn, true, false);
                wishbone_write(x"f", CR1, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                wishbone_read(CR1, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data = write_data report "Falsche Wert in CR0 Kanal1 eingestellt" severity failure;
        
                --Aktivieren des Kanals 1
                write_data := cr_value(unsigned(tests(i_a).Betriebsmodus), tests(i_a).Byte_Transfer, true, tests(i_a).ExEreignisEn, true, false);
                wishbone_write(x"f", CR0, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                wishbone_read(CR0, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data = write_data report "Falsche Wert in CR0 Kanal1 eingestellt" severity failure;
        
                loop
                    --maybe first WARTE AUD FALLENDE FLANKE
                    M_ACK <= '1';
                    S0_Ready <= to_std_logic(tests(i_a).ExEreignisEn);
                    S1_Ready <= to_std_logic(tests(i_b).ExEreignisEn); 
        
                    wait for (i_a+1)*20 ns;
        
                    M_ACK <= '0';
                    S0_Ready <= S0_Ready xor to_std_logic(tests(i_a).ExEreignisEn);
                    S1_Ready <= S1_Ready xor to_std_logic(tests(i_b).ExEreignisEn);

                    wait for (i_a+1)*20 ns;
        
                    if Interrupt0 = '1' and Interrupt1 = '1' then exit; end if;

                end loop;

                --Absichtlich den Kanal_2 wieder aktivieren ohne den Interrupt zu quittieren
                write_data := cr_value(unsigned(tests(i_b).Betriebsmodus), tests(i_b).Byte_Transfer, true, tests(i_b).ExEreignisEn, true, false);
                wishbone_write(x"f", CR1, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                wishbone_read(SR, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data(1) = '0' report "Kanal_2 muss deaktiviert sein, da Interrupt nicht Quittiert" severity failure;
        
                --Absichtlich den Kanal_1 wieder aktivieren ohne den Interrupt zu quittieren
                write_data := cr_value(unsigned(tests(i_a).Betriebsmodus), tests(i_a).Byte_Transfer, true, tests(i_a).ExEreignisEn, true, false);
                wishbone_write(x"f", CR0, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                wishbone_read(SR, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data(0) = '0' report "Kanal_1 muss deaktiviert sein, da Interrupt nicht Quittiert" severity failure;
        
                --Quittierung des Interrupts_0
                write_data := cr_value(unsigned(tests(i_a).Betriebsmodus), tests(i_a).Byte_Transfer, true, tests(i_a).ExEreignisEn, false, true);
                wishbone_write(x"f", CR0, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert Interrupt0 = '0' report "Interrup0 bereits quittiert, er sollte nicht mehr aktiv sein" severity failure;
                wishbone_read(SR, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data(2) = '0' report "Der Interrupt_0 sollte quittiert sein" severity failure;

                --Quittierung des Interrupts_1
                write_data := cr_value(unsigned(tests(i_b).Betriebsmodus), tests(i_b).Byte_Transfer, true, tests(i_b).ExEreignisEn, false, true);
                wishbone_write(x"f", CR1, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert Interrupt1 = '0' report "Interrup1 bereits quittiert, er sollte nicht mehr aktiv sein" severity failure;
                wishbone_read(SR, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data(3) = '0' report "Der Interrupt_0 sollte quittiert sein" severity failure;
        
            end procedure;

        begin

            for i in tests'range loop 
                execute_test(i);
                report "Test " & str(i) & " durchgefuehrt";
            end loop;
            
            wait;
        end process;

        clk_proc: process
        begin
            Takt <= '0';
            wait for CLOCK_PERIOD / 2;
            Takt <= '1';
            wait for CLOCK_PERIOD / 2;
        end process;

        DUT: entity work.DMA_Kontroller
        generic map(
            BUSWIDTH  => BUSWIDTH,
            WORDWIDTH => WORDWIDTH
        )
        port map(
            Takt            =>  Takt,
            Reset           =>  RST,
    
            S_STB           =>  S_STB,
            S_WE            =>  S_WE,
            S_ADR           =>  S_ADR,
            S_SEL           =>  S_SEL, 
            S_DAT_O         =>  S_DAT_O,
            S_DAT_I         =>  S_DAT_I,
            S_ACK           =>  S_ACK,
            
            S0_Ready        =>  S0_Ready,
            S1_Ready        =>  S1_Ready,
    
            Kanal1_Interrupt => Interrupt0,
            Kanal2_Interrupt => Interrupt1,
    
            M_STB           =>  M_STB,
            M_WE            =>  M_WE,
            M_ADR           =>  M_ADR,
            M_SEL           =>  M_SEL,
            M_DAT_O         =>  M_DAT_O,
            M_DAT_I         =>  M_DAT_I,
            M_ACK           =>  M_ACK
        );

end architecture;
