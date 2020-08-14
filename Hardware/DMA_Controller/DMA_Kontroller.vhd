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
  --  signal M0_Valid          : std_ulogic := '0';
    signal TRA0_Fertig       : std_ulogic := '0';
    signal RS0               : std_ulogic := '0';

    signal M1_STB           : std_ulogic;
    signal M1_WE            : std_ulogic;
    signal M1_ADR           : std_ulogic_vector(BUSWIDTH - 1 downto 0);
    signal M1_SEL           : std_ulogic_vector(3 downto 0);
    signal M1_DAT_O         : std_ulogic_vector(WORDWIDTH - 1 downto 0);
    signal M1_DAT_I         : std_ulogic_vector(WORDWIDTH - 1 downto 0);
    signal M1_ACK           : std_ulogic;

    signal TRA1_ANZ_STD      : std_ulogic_vector(WORDWIDTH - 1 downto 0);
 --   signal M1_Valid          : std_ulogic := '0';
    signal TRA1_Fertig       : std_ulogic := '0';
    signal RS1               : std_ulogic := '0';

    signal Status    : std_logic_vector(BUSWIDTH - 1 downto 0) := (others=>'0');
    signal CR0      : std_logic_vector(BUSWIDTH - 1 downto 0) := (others=>'0');
    signal CR1    : std_logic_vector(BUSWIDTH - 1 downto 0) := (others=>'0');

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

    Kanal1_Interrupt <= CR0(4) and RS0;
    Kanal2_Interrupt <= CR1(4) and RS1;

    Status(2) <= Kanal1_Interrupt;
    Status(3) <= Kanal2_Interrupt;

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
                end case;

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

    CR0: process(Takt)
    begin
        if rising_edge(Takt) then

            M0_Valid <= '0';
            CR0(0) <= '0';
            CR0(6) <= '0';

            if Reset = '1' then
				CR0 <= x"00000000";
            elsif EnCR0 = '1' then
                if S_DAT_I(0) = '1' and RS0 = '1' then -- um zu versichern, dass der Interrupt quittiert wurde
                CR0(0) <= '0';
            end if;
            
                CR0 <= S_DAT_I;
            end if;
        end if;
    end process;

-- ACHTUNG: Diese RS-Flip-FLop reagiert auf die beiden Flanken
    RS0: process(Takt)
    variable tmp : std_ulogic := '0';
    begin

        if(CR0(6) = '0' and TRA0_Fertig = '0') then
            tmp := tmp;
        elsif (CR0(6) = '1' and TRA0_Fertig = '1') then
            tmp := 'X';
        elsif (CR0(6) = '0' and TRA0_Fertig = '1') then
            tmp := '1';
        else
            tmp := '0';
        end if;

            RS0 <= tmp;
    end process;

    CR1: process(Takt)
    begin
        if rising_edge(Takt) then

            M1_Valid <= '0';
            CR1(0) <= '0';
            CR1(6) <= '0';

            if Reset = '1' then
				CR1 <= x"00000000";
            elsif EnCR1 = '1' then

                if S_DAT_I(0) = '1' and RS0 = '1' then -- um zu versichern, dass der Interrupt quittiert wurde
                    CR1(0) <= '0';
                end if;

                CR1 <= S_DAT_I;
            end if;
        end if;
    end process;

-- ACHTUNG: Diese RS-Flip-FLop reagiert auf die beiden Flanken
    RS1: process(Takt)
    variable tmp : std_ulogic := '0';
    begin

        if(CR1(6) = '0' and TRA1_Fertig = '0') then
            tmp := tmp;
        elsif (CR1(6) = '1' and TRA1_Fertig = '1') then
            tmp := 'X';
        elsif (CR1(6) = '0' and TRA1_Fertig = '1') then
            tmp := '1';
        else
            tmp := '0';
        end if;

            RS1 <= tmp;
    end process;

    Kanal1: entity work.DMA_Kanal
    generic map(
        BUSWIDTH        => BUSWIDTH,
        WORDWIDTH       => WORDWIDTH
    )port map(
        Takt           => Takt

        BetriebsMod     => CR0(2 downto 1),
        Byte_Trans      => CR0(3),
        Ex_EreigEn      => CR0(5),
        Reset           => Reset,
        Tra_Fertig      => TRA0_Fertig,
        Tra_Anzahl_Stand => TRA0_ANZ_STD,

        S_Ready         => S0_Ready,
        Sou_W           => EnSAR0,
        Dest_W          => EnDEST0,
        Tra_Anz_W       => EnTRAA0,
        M_Valid         => CR0(0),
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

        BetriebsMod     => CR1(2 downto 1),
        Byte_Trans      => CR1(3),
        Ex_EreigEn      => CR1(5),
        Reset           => Reset,
        Tra_Fertig      => TRA1_Fertig,
        Tra_Anzahl_Stand => TRA1_ANZ_STD,

        S_Ready         => S1_Ready,
        Sou_W           => EnSAR1,
        Dest_W          => EnDEST1,
        Tra_Anz_W       => EnTRAA1,
        M_Valid         => CR1(0),
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