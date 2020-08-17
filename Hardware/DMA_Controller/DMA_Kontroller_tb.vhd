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

    constant Sou_Adr0   : std_logic_vector(BUSWIDTH - 1 downto 0) := x"FF00453C";
    constant Dest_Adr0  :  std_logic_vector(BUSWIDTH - 1 downto 0) := x"FF3423B0";
    constant Trans_Anz0 : unsigned(WORDWIDTH - 1 downto 0)  := to_unsigned(20,WORDWIDTH);
    constant BetrModus0 : std_logic_vector(1 downto 0) := "10";

    constant Sou_Adr1   : std_logic_vector(BUSWIDTH - 1 downto 0) := x"FF0056A4";
    constant Dest_Adr1  :  std_logic_vector(BUSWIDTH - 1 downto 0) := x"00392338";
    constant Trans_Anz1 : unsigned(WORDWIDTH - 1 downto 0)  := to_unsigned(35, WORDWIDTH);
    constant BetrModus1 : std_logic_vector(1 downto 0) := "01";

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
        KanalEnable  : in boolean;
        BetrModus    : in unsigned;
        Byte_Trans   : in boolean;
        Freigabe_Int : in boolean;
        ExEreig_En   : in boolean;
        QuitiertInt  : in boolean
    ) return std_logic_vector is
        variable r : std_logic_vector(BUSWIDTH - 1 downto 0);
    begin

        r := (others => '0');

        if KanalEnable then
            r(0) := '1';
        end if;
        r(2 downto 1) := std_logic_vector(BetrModus);
        if Byte_Trans then
            r(3) := '1';
        end if;
        if Freigabe_Int then
            r(4) := '1';
        end if;
        if ExEreig_En then
            r(5) := '1';
        end if;
        if QuitiertInt then 
            r(6) := '1';
        end if;

        return r;
    end function;

    begin

        stim_and_verify:process
            variable write_data : std_logic_vector(31 downto 0) := (others => '0');
            variable read_data  : std_logic_vector(31 downto 0) := (others => '0');
        begin

            RST <= '1';
            wishbone_init(S_STB, S_WE, S_SEL, S_ADR, S_DAT_I);        
            wait_cycle(2, Takt);
            RST <= '0';
            wait_cycle(2, Takt);
        
-------------------------------------------------------------------------------------------------------------

--Jetzt mit dem Kanal_1 alleine

---------------------------------------------------------------------------------------------------------------


                --Anfangszustand pruefen
                assert Interrupt0 = '0' report "Signal 'Interrupt0' sollte '0' sein." severity failure;
                assert Interrupt1 = '0' report "Signal 'Interrupt1' sollte '0' sein." severity failure;
                wishbone_read(SR, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data(0) = '0' report "Kanal 1 sollte nicht aktiv sein"    severity failure;
                assert read_data(1) = '0' report "Kanal 2 sollte nicht aktiv sein"    severity failure;
                assert read_data(2) = '0' report "Bit 'Kanal1_Interrupt' sollte '0' sein"    severity failure;
                assert read_data(3) = '0' report "Bit 'Kanal2_Interrupt' sollte '0' sein"    severity failure;
    
                --Verifizieren des Wertes von CR0
                wishbone_read(CR0, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data = x"00000000" report "CR0 sollte auf 0 gesetzt sein" severity failure;

                --Source-Adresse von Kanal1 einstellen
                write_data := Sou_Adr0;
                wishbone_write(x"f", SAR0, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
    
                --Destination-Adresse von Kanal1 einstellen
                write_data := Dest_Adr0;
                wishbone_write(x"f", DESTR0, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
    

                --Transferanzahl von Kanal1 einstellen
                write_data := std_logic_vector(Trans_Anz0);
                wishbone_write(x"f", TRAAR0, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                wishbone_read(TRAAR0, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data = write_data report "Falsche Anzahl von Transfers Kanal1 eingestellt" severity failure;
    
                --Einstellung von CR0 von Kanal1 
                write_data := cr_value(false, unsigned(BetrModus0), false, true, false, false);
                wishbone_write(x"f", CR0, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                wishbone_read(CR0, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data = write_data report "Falsche Wert in CR0 Kanal1 eingestellt" severity failure;

                --Aktivieren des Kanals 1
                write_data := cr_value(true, unsigned(BetrModus0), false, true, false, false);
                wishbone_write(x"f", CR0, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                wishbone_read(CR0, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data = write_data report "Falsche Wert in CR0 Kanal1 eingestellt" severity failure;


                --So klappt wenn ExEreigEn deaktiviert ist
                loop
                    assert M_STB = '1' report "Der Kanal greift nicht auf den Bus zu" severity failure;
                    wait until falling_edge(Takt);
                    M_DAT_I <= DATA_WORT;
                    M_ACK <= '1';
                    wait until falling_edge(Takt);
                    M_DAT_I <= (others => '0');
                    M_ACK <= '0';
                    assert M_STB = '1' report "Der Kanal greift nicht auf den Bus zu" severity failure;
                    wait until falling_edge(Takt);
                    M_ACK <= '1';
                    wait for 40 ns;
                    if Interrupt0 = '1' then M_ACK <= '0'; exit; end if;
                    M_ACK <= '0';

                end loop;

                --Pruefen ob der Interrupt_0 im Status register sichtbar ist
                wishbone_read(SR, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data(0) = '0' report "Kanal_1 muss deaktiviert sein" severity failure;
                assert read_data(1) = '0' report "Kanal_2 muss deaktiviert sein" severity failure;
                assert read_data(2) = '1' report "Der Interrupt_0 ist im Status-Register nicht sichtbar" severity failure;
                assert read_data(3) = '0' report "Der Interrupt_1 sollte deaktiviert sein" severity failure;

                --Absichtlich den Kanal wieder aktivieren ohne den Interrupt zu quittieren
                write_data := cr_value(true, unsigned(BetrModus0), false, true, false, false);
                wishbone_write(x"f", CR0, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                wishbone_read(SR, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data(0) = '0' report "Kanal_1 muss deaktiviert sein, da Interrupt nicht Quittiert" severity failure;

                --Quittierung des Interrupts_0
                write_data := cr_value(false, unsigned(BetrModus0), false, true, false, true);
                wishbone_write(x"f", CR0, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert Interrupt0 = '0' report "Interrup0 bereits quittiert, er sollte nicht mehr aktiv sein" severity failure;
                wishbone_read(SR, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data(2) = '0' report "Der Interrupt_0 sollte quittiert sein" severity failure;

-------------------------------------------------------------------------------------------------------------

--Jetzt mit dem Kanal_2 alleine

---------------------------------------------------------------------------------------------------------------

                --Anfangszustand pruefen
                assert Interrupt0 = '0' report "Signal 'Interrupt0' sollte '0' sein." severity failure;
                assert Interrupt1 = '0' report "Signal 'Interrupt1' sollte '0' sein." severity failure;
                wishbone_read(SR, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data(0) = '0' report "Kanal 1 sollte nicht aktiv sein"    severity failure;
                assert read_data(1) = '0' report "Kanal 2 sollte nicht aktiv sein"    severity failure;
                assert read_data(2) = '0' report "Bit 'Kanal1_Interrupt' sollte '0' sein"    severity failure;
                assert read_data(3) = '0' report "Bit 'Kanal2_Interrupt' sollte '0' sein"    severity failure;
    
                --Verifizieren des Wertes von CR1
                wishbone_read(CR1, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data = x"00000000" report "CR0 sollte auf 0 gesetzt sein" severity failure;

                --Source-Adresse von Kanal1 einstellen
                write_data := Sou_Adr1;
                wishbone_write(x"f", SAR1, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
    
                --Destination-Adresse von Kanal1 einstellen
                write_data := Dest_Adr1;
                wishbone_write(x"f", DESTR1, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
    
                --Transferanzahl von Kanal2 einstellen
                write_data := std_logic_vector(Trans_Anz1);
                wishbone_write(x"f", TRAAR1, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                wishbone_read(TRAAR1, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data = write_data report "Falsche Anzahl von Transfers Kanal2 eingestellt" severity failure;
    
                --Einstellung von CR1 von Kanal1 
                write_data := cr_value(false, unsigned(BetrModus1), true, true, true, false);
                wishbone_write(x"f", CR1, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                wishbone_read(CR1, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data = write_data report "Falsche Wert in CR0 Kanal1 eingestellt" severity failure;

                --Aktivieren des Kanals 1
                write_data := cr_value(true, unsigned(BetrModus1), true, true, true, false);
                wishbone_write(x"f", CR1, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                wishbone_read(CR1, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data = write_data report "Falsche Wert in CR0 Kanal1 eingestellt" severity failure;


                --So klappt wenn ExEreigEn aktiviert ist
                loop
                    wait until falling_edge(Takt);
                    M_ACK <= '0';
                    S1_Ready <= '1';
                    wait until falling_edge(Takt);
                    assert M_STB = '1' report "Der Kanal greift nicht auf den Bus zu" severity failure;
                    S1_Ready <= '0';
                    wait until falling_edge(Takt);
                    M_DAT_I <= DATA_WORT;
                    M_ACK <= '1';
                    wait until falling_edge(Takt);
                    M_DAT_I <= (others => '0');
                    M_ACK <= '0';
                    assert M_STB = '1' report "Der Kanal greift nicht auf den Bus zu" severity failure;
                    wait until falling_edge(Takt);
                    M_ACK <= '1';
                    wait for 40 ns;
                    if Interrupt1 = '1' then M_ACK <= '0'; exit; end if;
                end loop;

                --Pruefen ob der Interrupt_0 im Status register sichtbar ist
                wishbone_read(SR, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data(0) = '0' report "Kanal_1 muss deaktiviert sein" severity failure;
                assert read_data(1) = '0' report "Kanal_2 muss deaktiviert sein" severity failure;
                assert read_data(2) = '0' report "Der Interrupt_0 sollte deaktiviert sein" severity failure;
                assert read_data(3) = '1' report "Der Interrupt_1 ist im Status-Register nicht sichtbar" severity failure;

                --Absichtlich den Kanal wieder aktivieren ohne den Interrupt zu quittieren
                write_data := cr_value(true, unsigned(BetrModus1), true, true, true, false);
                wishbone_write(x"f", CR1, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                wishbone_read(SR, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data(1) = '0' report "Kanal_2 muss deaktiviert sein, da Interrupt nicht Quittiert" severity failure;

                --Quittierung des Interrupts_1
                write_data := cr_value(false, unsigned(BetrModus1), true, true, true, true);
                wishbone_write(x"f", CR1, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert Interrupt1 = '0' report "Interrup1 bereits quittiert, er sollte nicht mehr aktiv sein" severity failure;
                wishbone_read(SR, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data(3) = '0' report "Der Interrupt_0 sollte quittiert sein" severity failure;


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
