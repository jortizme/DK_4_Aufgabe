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

    constant Sou_Adr0   : std_logic_vector(BUSWIDTH - 1 downto 0) := x"FF00453C";
    constant Dest_Adr0  :  std_logic_vector(BUSWIDTH - 1 downto 0) := x"FF3423B0";
    constant Trans_Anz0 : unsigned(WORDWIDTH - 1 downto 0)  := to_unsigned(20,WORDWIDTH);
    constant BetrModus0 : std_logic_vector(1 downto 0) := "10";

    constant Sou_Adr1   : std_logic_vector(BUSWIDTH - 1 downto 0) := x"FF0056A4";
    constant Dest_Adr1  :  std_logic_vector(BUSWIDTH - 1 downto 0) := x"00392338";
    constant Trans_Anz1 : unsigned(WORDWIDTH - 1 downto 0)  := to_unsigned(35, WORDWIDTH);
    constant BetrModus1 : std_logic_vector(1 downto 0) := "01";

    signal   RST           : std_logic := '1';
    signal   Takt          : std_logic;
    signal   Interrupt0    : std_logic;
    signal   Interrupt1    : std_logic;
    signal   S0_Ready       : std_ulogic;
    signal   S1_Ready       : std_ulogic;

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
        Kanal_Enable : in boolean;
        BetrModus    : in unsigned;
        Byte_Trans   : in boolean;
        Freigabe_Int : in boolean;
        ExEreig_En   : in boolean;
        QuitiertInt  : in boolean
    ) return std_logic_vector is
        variable r : std_logic_vector(BUSWIDTH - 1 downto 0);
    begin

        r := (others => '0');

        if Kanal_Enable then 
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
                write_data := cr_value(false, unsigned(BetrModus0), false, true, true, false);
                wishbone_write(x"f", CR0, write_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                wishbone_read(CR0, read_data, Takt, S_STB, S_WE, S_SEL, S_ADR, S_DAT_I, S_ACK, S_DAT_O);
                assert read_data = write_data report "Falsche Wert in CR0 Kanal1 eingestellt" severity failure;
    
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
            Takt            =>  std_ulogic(Takt),
            Reset           =>  std_ulogic(RST),
    
            S_STB           =>  std_ulogic(S_STB),
            S_WE            =>  std_ulogic(S_WE),
            S_ADR           =>  std_ulogic_vector(S_ADR),
            S_SEL           =>  std_ulogic_vector(S_SEL), 
            S_DAT_O         =>  S_DAT_O,
            S_DAT_I         =>  std_ulogic_vector(S_DAT_I),
            S_ACK           =>  S_ACK,
            
            S0_Ready        =>  std_ulogic(S0_Ready),
            S1_Ready        =>  std_ulogic(S1_Ready),
    
            Kanal1_Interrupt => Interrupt0,
            Kanal2_Interrupt => Interrupt1,
    
            M_STB           =>  M_STB,
            M_WE            =>  M_WE,
            M_ADR           =>  M_ADR,
            M_SEL           =>  M_SEL,
            M_DAT_O         =>  M_DAT_O,
            M_DAT_I         =>  std_ulogic_vector(M_DAT_I),
            M_ACK           =>  std_ulogic(M_ACK)
        );

end architecture;
