-------------------------------------------------------------------------------
-- DMA-Kontroller
-------------------------------------------------------------------------------
-- Modul Digitale Komponenten
-- Hochschule Osnabrueck
-- Joaquin Ortiz, Filip Mijac
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DMA_Kontroller is 
    generic(
        BUSWIDTH : positive;
        WORDWIDTH : positive
    );
    port(
        Takt            : in std_ulogic;
        Reset           : in std_ulogic;

        S_STB           : in std_ulogic;
        S_WE            : in std_ulogic;
        S_ADR           : in std_ulogic_vector(7 downto 0);
        S_SEL           : in std_ulogic_vector(3 downto 0);
        S_DAT_O         : out std_ulogic_vector(WORDWIDTH - 1 downto 0);
        S_DAT_I         : in std_ulogic_vector(WORDWIDTH - 1 downto 0);
        S_ACK           : out std_ulogic;
        

        S0_Ready         : in std_ulogic;
        S1_Ready         : in std_ulogic;

        Kanal1_Interrupt : out std_ulogic;
        Kanal2_Interrupt : out std_ulogic;

        M_STB           : out std_ulogic;
        M_WE            : out std_ulogic;
        M_ADR           : out std_ulogic_vector(7 downto 0);
        M_SEL           : out std_ulogic_vector(3 downto 0);
        M_DAT_O         : out std_ulogic_vector(WORDWIDTH - 1 downto 0);
        M_DAT_I         : in std_ulogic_vector(WORDWIDTH - 1 downto 0);
        M_ACK           : in std_ulogic;
    );
end entity;


architecture rtl of DMA_Kontroller is

    signal M0_STB           : std_ulogic;
    signal M0_WE            : std_ulogic;
    signal M0_ADR           : std_ulogic_vector(BUSWIDTH - 1 downto 0);
    signal M0_SEL           : std_ulogic_vector(3 downto 0);
    signal M0_DAT_O         : std_ulogic_vector(WORDWIDTH - 1 downto 0);
    signal M0_DAT_I         : std_ulogic_vector(WORDWIDTH - 1 downto 0);
    signal M0_ACK           : std_ulogic;

    signal TRA0_ANZ_STD      : std_ulogic_vector(WORDWIDTH - 1 downto 0);
    signal M0_Valid          : std_ulogic := '0';
    signal TRA0_Fertig       : std_ulogic := '0';

    signal M1_STB           : std_ulogic;
    signal M1_WE            : std_ulogic;
    signal M1_ADR           : std_ulogic_vector(BUSWIDTH - 1 downto 0);
    signal M1_SEL           : std_ulogic_vector(3 downto 0);
    signal M1_DAT_O         : std_ulogic_vector(WORDWIDTH - 1 downto 0);
    signal M1_DAT_I         : std_ulogic_vector(WORDWIDTH - 1 downto 0);
    signal M1_ACK           : std_ulogic;

    signal TRA1_ANZ_STD      : std_ulogic_vector(WORDWIDTH - 1 downto 0);
    signal M1_Valid          : std_ulogic := '0';
    signal TRA1_Fertig       : std_ulogic := '0';

    signal Status    : std_logic_vector(31 downto 0) := (others=>'0');
    signal SAR0      : std_logic_vector(31 downto 0) := (others=>'0');
    signal DESTR0    : std_logic_vector(31 downto 0) := (others=>'0');
    signal TRAA0        : std_logic_vector(31 downto 0) := (others=>'0');
    signal CR0      : std_logic_vector(31 downto 0) := (others=>'0');
    signal SAR1      : std_logic_vector(31 downto 0) := (others=>'0');
    signal DESTR1    : std_logic_vector(31 downto 0) := (others=>'0');
    signal TRAA1  : std_logic_vector(31 downto 0) := (others=>'0');
    signal CR1    : std_logic_vector(31 downto 0) := (others=>'0');
    signal EnSAR0   : std_ulogic;
    signal EnDEST0   : std_ulogic;
    signal EnTRAA0   : std_ulogic;
    signal EnCR0    : std_ulogic;
    signal EnSAR1   : std_ulogic;
    signal EnDEST1   : std_ulogic;
    signal EnTRAA1   : std_ulogic;
    signal EnCR1    : std_ulogic;

    signal Interupt0_i : std_ulogic;
    signal Interrupt1_i : std_ulogic;

begin

    S_ACK <= S_STB;

    Kanal1_Interrupt <= CR0(4) and TRA0_Fertig;
    Kanal2_Interrupt <= CR1(4) and TRA1_Fertig;

    Status(2) <= Kanal1_Interrupt;
    Status(3) <= Kanal2_Interrupt;

    process (CR0, CR1)
    begin
        if CR0(0) = '1' then
            M0_Valid <= '1';
            CR0(0) <= '0';
        elsif CR1(0) = '1' then
            M1_Valid <= '1';
            CR1(0) <= '0';
        end if;
    end process;

    Decoder: process(S_STB, S_ADR, S_WE)
	begin
		-- Default-Werte
		EnSAR0 <= '0';
		EnDEST0    <= '0';
		EnTRAA0      <= '0';
        EnCR1       <= '0';
        EnSAR1 <= '0';
		EnDEST1    <= '0';
		EnTRAA1      <= '0';
		EnCR1       <= '0';

		if S_STB = '1' then
            if S_WE = '1' then
                
                case S_ADR is 
                    when x"00" => EnSAR0 <= '1';
                    when x"04" => EnDEST0 <= '1';
                    when x"08" => EnTRAA0 <= '1';
                    when x"0C" => EnCR1 <= '1';
                    when x"10" => EnSAR1 <= '1';
                    when x"14" => EnDEST1 <= '1';
                    when x"18" => EnTRAA1 <= '1';
                    when x"1C" => EnCR1 <= '1';
                    when others => null;

  ----ZUnaechst NOCH NICHTS BEI WE = 0              
			elsif S_WE = '0' then
				if    S_ADR = x"4" then Puffer_Ready      <= '1';
				elsif S_ADR = x"C" then Lese_Status       <= '1';
				end if;
			end if;		
		end if;
    end process;

    Lesedaten_MUX: process(S_ADR, TRA0_ANZ_STD, TRA1_ANZ_STD, CR0, CR1, Status)
	begin
		S_DAT_O <= (others=>'0');
		
		if    ADR_I = x"08" then S_DAT_O(TRA0_ANZ_STD'range) <= TRA0_ANZ_STD;
		elsif ADR_I = x"0C" then S_DAT_O(CR0'range)    <= CR0;
        elsif ADR_I = x"18" then S_DAT_O(TRA1_ANZ_STD'range)      <= TRA1_ANZ_STD;
        elsif ADR_I = x"1C" then S_DAT_O(CR1'range)      <= CR1;
        elsif ADR_I = x"20" then S_DAT_O(Status'range)      <= Status;
		end if;		
	end process;

    
    SAR0: process(Takt)
    begin
        if rising_edge(Takt) then
            if Reset = '1' then
				SAR0 <= x"00000000";
			elsif EnSAR0 = '1' then
				SAR0 <= S_DAT_I;
        end if;
    end process;

    DESTR0: process(Takt)
    begin
        if rising_edge(Takt) then
            if Reset = '1' then
				DESTR0 <= x"00000000";
			elsif EnDEST0 = '1' then
				DESTR0 <= S_DAT_I;
        end if;
    end process;

    TRAA0: process(Takt)
    begin
        if rising_edge(Takt) then
            if Reset = '1' then
				TRAA0 <= x"00000000";
			elsif EnTRAA0 = '1' then
				TRAA0 <= S_DAT_I;
        end if;
    end process;

    CR0: process(Takt)
    begin
        if rising_edge(Takt) then

            M0_Valid <= '0';
            if Reset = '1' then
				CR0 <= x"00000000";
			elsif EnCR0 = '1' then
                CR0 <= S_DAT_I;
        end if;
    end process;

    SAR1: process(Takt)
    begin
        if rising_edge(Takt) then
            if Reset = '1' then
				SAR1 <= x"00000000";
			elsif EnSAR1 = '1' then
				SAR1 <= S_DAT_I;
        end if;
    end process;

    DESTR1: process(Takt)
    begin
        if rising_edge(Takt) then
            if Reset = '1' then
				DESTR1 <= x"00000000";
			elsif EnDEST1 = '1' then
				DESTR1 <= S_DAT_I;
        end if;
    end process;

    TRAA1: process(Takt)
    begin
        if rising_edge(Takt) then
            if Reset = '1' then
				TRAA1 <= x"00000000";
			elsif EnTRAA1 = '1' then
				TRAA1 <= S_DAT_I;
        end if;
    end process;

    CR1: process(Takt)
    begin
        if rising_edge(Takt) then
            M1_Valid <= '0';

            if Reset = '1' then
				CR1 <= x"00000000";
			elsif EnCR1 = '1' then
                CR1 <= S_DAT_I;
        end if;
    end process;

    Kanal1: entity work.DMA_Kanal
    generic map(
        BUSWIDTH        => BUSWIDTH,
        WORDWIDTH       => WORDWIDTH
    )port map(
        Takt           => Takt

        Sou_ADR         => SAR0,
        Des_ADR         => DESTR0,
        Tra_Anzahl      => TRAA0,
        BetriebsMod     => CR0(2 downto 1),
        Byte_Trans      => CR0(3),
        Ex_EreigEn      => CR0(5),
        Reset           => Reset,
        Tra_Fertig      => TRA0_Fertig,
        Tra_Anzahl_Stand => TRA0_ANZ_STD,

        S_Ready         => S0_Ready,
        M_Valid         => M0_Valid,
        Kanal_Aktiv     => not Status(0),

        M_STB           => M0_STB,
        M_WE            => M0_WE,
        M_ADR           => M0_ADR,
        M_SEL           => M0_SEL,
        M_DAT_O         => M0_DAT_O,
        M_DAT_I         => M0_DAT_I, 
        M_ACK           => M0_ACK
    );

    Kanal2: entity work.DMA_Kanal
    generic map(
        BUSWIDTH        => BUSWIDTH,
        WORDWIDTH       => WORDWIDTH
    )port map(
        Takt           => Takt

        Sou_ADR         => SAR1,
        Des_ADR         => DESTR1,
        Tra_Anzahl      => TRAA1,
        BetriebsMod     => CR1(2 downto 1),
        Byte_Trans      => CR1(3),
        Ex_EreigEn      => CR1(5),
        Reset           => Reset,
        Tra_Fertig      => TRA1_Fertig,
        Tra_Anzahl_Stand => TRA1_ANZ_STD,

        S_Ready         => S1_Ready,
        M_Valid         => M1_Valid,
        Kanal_Aktiv     => not Status(1),

        M_STB           => M1_STB,
        M_WE            => M1_WE,
        M_ADR           => M1_ADR,
        M_SEL           => M1_SEL,
        M_DAT_O         => M1_DAT_O,
        M_DAT_I         => M1_DAT_I, 
        M_ACK           => M1_ACK
    );

    Arbiter: entity work.wb_arbiter

    port map(
        -- Clock and Reset
        CLK_I     => Takt,
        RST_I     => Reset,

        -- Slave 0 Interface (priority)
        S0_STB_I  => M0_STB,
        S0_WE_I   => M0_WE,
		S0_WRO_I  => '0', -- Kanal0 must not write to ROM
        S0_SEL_I  => M0_SEL,
        S0_ADR_I  => M0_ADR,
        S0_ACK_O  => M0_ACK,
        S0_DAT_I  => M0_DAT_O,
        S0_DAT_O  => M0_DAT_I,
        
        -- Slave 1 Interface
        S1_STB_I  => M1_STB,
        S1_WE_I   => M1_WE,
		S1_WRO_I  => '0', -- Kanal1 must not write to ROM
        S1_SEL_I  => M0_SEL,
        S1_ADR_I  => M0_ADR,
        S1_ACK_O  => M0_ACK,
        S1_DAT_I  => M0_DAT_O,
        S1_DAT_O  => M0_DAT_I,
        
        -- Master Interface
        M_STB_O   => M_STB,
        M_WE_O    => M_WE,
		M_WRO_O   => '0',
        M_ADR_O   => M_ADR,
        M_SEL_O   => M_SEL,
        M_ACK_I   => M_ACK,
        M_DAT_O   => M_DAT_O,
        M_DAT_I   => M_DAT_I


    );

end architecture;