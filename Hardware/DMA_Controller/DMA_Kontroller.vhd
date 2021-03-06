-------------------------------------------------------------------------------
-- DMA-Kontroller
-------------------------------------------------------------------------------
-- Modul Digitale Komponenten
-- Hochschule Osnabrueck
-- Joaquin Ortiz, Filip Mijac
---------------------------------------------------------------------------------------------------
-- Offsets:
-- 0x00 Source Address Kanal_1 Register         (SAR0)      (Write Only)
-- 0x04 Destination Address Kanal_1 Register    (DESTR0)    (Write Only)
-- 0x08 Transfer Antahl Kana_1 Register         (TRAAR0)    (RW)
-- 0x0C Control Register Kanal_1                (CR0)       (RW)
-- 0x10 Source Address Kanal_2 Register         (SAR1)      (Write Only)
-- 0x14 Destination Address Kanal_2 Register    (DESTR1)    (Write Only)
-- 0x18 Transfer Antahl Kana_2 Register         (TRAAR1)    (RW)
-- 0x1C Control Register Kanal_2                (CR1)       (RW)
-- 0x20 Status Register                         (SR)        (Read Only)
---------------------------------------------------------------------------------------------------
-- Control Register (CR0 - CR1):
--  1 .. 0 : Betriebsmodus
--  2      : Byte_Transfer
--  3      : Freigabe Interrupt
--  4      : Externes-Ereignis-Enable
--  8      : Kanal-Enable               (Write-Only)
--  9      : Interrupt-Quittierung      (Write-Only)

---------------------------------------------------------------------------------------------------
-- Status Register (SR):
--  0      : Kanal_1 aktiv
--  1      : Kanal_2 aktiv
--  16     : Interrupt Kanal_1  
--  17     : Interrupt Kanal_2
---------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DMA_Kontroller is 
    generic(
        BUSWIDTH : positive;
        WORDWIDTH : positive
    );
    port(
        Takt            : in std_logic;
        Reset           : in std_logic;

        --Slave interface signals
        S_STB           : in std_logic;
        S_WE            : in std_logic;
        S_ADR           : in std_logic_vector(7 downto 0);
        S_DAT_O         : out std_logic_vector(WORDWIDTH - 1 downto 0);
        S_DAT_I         : in std_logic_vector(WORDWIDTH - 1 downto 0);
        S_ACK           : out std_logic;
        
        --Master interface signals
        M_STB           : out std_logic;
        M_WE            : out std_logic;
        M_ADR           : out std_logic_vector(WORDWIDTH - 1 downto 0);
        M_SEL           : out std_logic_vector(3 downto 0);
        M_DAT_O         : out std_logic_vector(WORDWIDTH - 1 downto 0);
        M_DAT_I         : in std_logic_vector(WORDWIDTH - 1 downto 0);
        M_ACK           : in std_logic;

        --Extern interrupts from peripherals
        S0_Ready         : in std_logic;
        S1_Ready         : in std_logic;

        --Interrupts to CPU
        Kanal1_Interrupt : out std_logic;
        Kanal2_Interrupt : out std_logic
    );
end entity;


architecture rtl of DMA_Kontroller is

    --Signale von Kanal_1
    signal M0_STB           : std_logic;
    signal M0_WE            : std_logic;
    signal M0_ADR           : std_logic_vector(BUSWIDTH - 1 downto 0);
    signal M0_SEL           : std_logic_vector(3 downto 0);
    signal M0_DAT_O         : std_logic_vector(WORDWIDTH - 1 downto 0);
    signal M0_DAT_I         : std_logic_vector(WORDWIDTH - 1 downto 0);
    signal M0_ACK           : std_logic;

    signal TRA0_ANZ_STD      : std_logic_vector(WORDWIDTH - 1 downto 0);
    signal TRA0_Fertig       : std_logic := '0';
    signal Kanal_0_IR        : std_logic := '0';
    signal BetriebMod_0      : std_logic_vector(1 downto 0);
    signal ByteTrans_0       : std_logic;
    signal ExEreigEn_0       : std_logic;
    signal FreigabeIR_0      : std_logic;
    signal Kanal_Aktiv_0     : std_logic;

    --Signale von Kanal_2
    signal M1_STB           : std_logic;
    signal M1_WE            : std_logic;
    signal M1_ADR           : std_logic_vector(BUSWIDTH - 1 downto 0);
    signal M1_SEL           : std_logic_vector(3 downto 0);
    signal M1_DAT_O         : std_logic_vector(WORDWIDTH - 1 downto 0);
    signal M1_DAT_I         : std_logic_vector(WORDWIDTH - 1 downto 0);
    signal M1_ACK           : std_logic;

    signal TRA1_ANZ_STD      : std_logic_vector(WORDWIDTH - 1 downto 0);
    signal TRA1_Fertig       : std_logic := '0';
    signal Kanal_1_IR        : std_logic := '0';
    signal BetriebMod_1      : std_logic_vector(1 downto 0);
    signal ByteTrans_1       : std_logic;
    signal ExEreigEn_1       : std_logic;
    signal FreigabeIR_1      : std_logic;
    signal Kanal_Aktiv_1     : std_logic;

    signal Status    : std_logic_vector(BUSWIDTH - 1 downto 0) := (others=>'0'); 
    signal CR0      : std_logic_vector(BUSWIDTH - 1 downto 0) := (others=>'0');
    signal CR1    : std_logic_vector(BUSWIDTH - 1 downto 0) := (others=>'0');

    --Signale zum Starten der Kanäle und zur Quittierung der entsprechenden Interrupts
    signal M0_Valid : std_logic := '0';
    signal M1_Valid : std_logic := '0';
    signal Quittung_0 : std_logic := '0';
    signal Quittung_1 : std_logic := '0';

    signal Interrupt0_i  : std_logic := '0';
    signal Interrupt1_i  : std_logic := '0';

    --Enable Signale zum Laden der Register
    signal EnSAR0   : std_logic;
    signal EnDEST0   : std_logic;
    signal EnTRAA0   : std_logic;
    signal EnCR0    : std_logic;
    signal EnSAR1   : std_logic;
    signal EnDEST1   : std_logic;
    signal EnTRAA1   : std_logic;
    signal EnCR1    : std_logic;

begin

    S_ACK <= S_STB;

    -- Kontrollregister mit Steuersignalen verbinden
    BetriebMod_0    <= CR0(1 downto 0);  
    ByteTrans_0     <= CR0(2);
    FreigabeIR_0    <= CR0(3);  
    ExEreigEn_0     <= CR0(4);

    BetriebMod_1    <= CR1(1 downto 0);  
    ByteTrans_1     <= CR1(2);
    FreigabeIR_1    <= CR1(3);  
    ExEreigEn_1     <= CR1(4); 

    -- Statusregister mit Statussignalen verbinden
    Status(0) <= Kanal_Aktiv_0;
    Status(1) <= Kanal_Aktiv_1;
    Status(16) <= Kanal_0_IR;
    Status(17) <= Kanal_1_IR;

    Interrupt0_i <= FreigabeIR_0 and Kanal_0_IR;
    Interrupt1_i <= FreigabeIR_1 and Kanal_1_IR;

    --Interne Signale an den Port zuweisen
    IR:process(Interrupt0_i, Interrupt1_i)
    begin
        Kanal1_Interrupt <= Interrupt0_i;
        Kanal2_Interrupt <= Interrupt1_i;
    end process;

    Decoder: process(S_STB, S_ADR, S_WE)
	begin
		-- Default-Werte
		EnSAR0      <= '0';
		EnDEST0     <= '0';
		EnTRAA0     <= '0';
        EnCR0       <= '0';
        EnSAR1      <= '0';
		EnDEST1     <= '0';
		EnTRAA1     <= '0';
        EnCR1       <= '0';
        M0_Valid    <= '0';
        M1_Valid    <= '0';   
        Quittung_0  <= '0';
        Quittung_1  <= '0';

		if S_STB = '1' then
            if S_WE = '1' then
                
                case S_ADR is 
                    when x"00" => EnSAR0 <= '1';
                    when x"04" => EnDEST0 <= '1';
                    when x"08" => EnTRAA0 <= '1';
                    when x"0C" => EnCR0 <= '1';
                                    --Sende das Signal nur wenn der Kanal nicht aktiv ist, und der Interrupt quittiert wurde
                                    if Kanal_0_IR = '0' and Status(0) = '0' and S_DAT_I(8) = '1' then 
                                        M0_Valid <= '1';
                                    end if;
                                    --Sende das Signal nur wenn der Kanal nicht aktiv ist, und der Interrupt nicht quittiert wurde
                                    if Kanal_0_IR = '1' and Status(0) = '0' and S_DAT_I(9) = '1' then 
                                        Quittung_0 <= '1';
                                    end if;

                    when x"10" => EnSAR1 <= '1';
                    when x"14" => EnDEST1 <= '1';
                    when x"18" => EnTRAA1 <= '1';
                    when x"1C" => EnCR1 <= '1';
                                    --Sende das Signal nur wenn der Kanal nicht aktiv ist, und der Interrupt quittiert wurde
                                    if Kanal_1_IR = '0' and Status(1) = '0' and S_DAT_I(8) = '1' then 
                                        M1_Valid <= '1';
                                    end if;
                                    --Sende das Signal nur wenn der Kanal nicht aktiv ist, und der Interrupt nicht quittiert wurde
                                    if Kanal_1_IR = '1' and Status(0) = '0' and S_DAT_I(9) = '1' then 
                                        Quittung_1 <= '1';
                                    end if;
                    when others => null;
                end case;
            end if;
		end if;
    end process;

    Lesedaten_MUX: process(S_ADR, TRA0_ANZ_STD, TRA1_ANZ_STD, CR0, CR1, Status)
	begin
		S_DAT_O <= (others=>'0');
		
		if    S_ADR = x"08" then S_DAT_O(TRA0_ANZ_STD'range)     <= std_logic_vector(TRA0_ANZ_STD);
		elsif S_ADR = x"0C" then S_DAT_O(CR0'range)             <= std_logic_vector(CR0);
        elsif S_ADR = x"18" then S_DAT_O(TRA1_ANZ_STD'range)      <= std_logic_vector(TRA1_ANZ_STD);
        elsif S_ADR = x"1C" then S_DAT_O(CR1'range)              <= std_logic_vector(CR1);
        elsif S_ADR = x"20" then S_DAT_O(Status'range)          <= std_logic_vector(Status);
		end if;		
	end process;

    --Control Register von Kanal_1
    Kontrol_Register0: process(Takt)
    begin
        if rising_edge(Takt) then
            if Reset = '1' then
                CR0 <= x"00000000";
            elsif EnCR0 = '1' then
                CR0  <= S_DAT_I;
            end if;
        end if;
    end process;

    --Dieser RS-Flip-FLop reagiert auf beide Flanken
    RSFlipFlop0: process(Takt)
    variable tmp : std_logic := '0';
    begin
        if(Quittung_0 = '0' and TRA0_Fertig = '0') then
            tmp := tmp;
        elsif (Quittung_0 = '1' and TRA0_Fertig = '1') then
            tmp := 'X';
        elsif (Quittung_0 = '0' and TRA0_Fertig = '1') then
            tmp := '1';
        else
            tmp := '0';
        end if;
        Kanal_0_IR <= tmp;
    end process;

    --Control Register von Kanal_2
    Kontrol_Register1: process(Takt)
    begin
        if rising_edge(Takt) then
            if Reset = '1' then
				CR1 <= x"00000000";
            elsif EnCR1 = '1' then
                CR1 <= S_DAT_I;
            end if;
        end if;
    end process;

    --Dieser RS-Flip-FLop reagiert auf beide Flanken
    RSFlipFlop1: process(Takt)
    variable tmp : std_logic := '0';
    begin
        if(Quittung_1 = '0' and TRA1_Fertig = '0') then
            tmp := tmp;
        elsif (Quittung_1 = '1' and TRA1_Fertig = '1') then
            tmp := 'X';
        elsif (Quittung_1 = '0' and TRA1_Fertig = '1') then
            tmp := '1';
        else
            tmp := '0';
        end if;
        Kanal_1_IR <= tmp;
    end process;

    Kanal1: entity work.DMA_Kanal
    generic map(
        BUSWIDTH        => BUSWIDTH,
        WORDWIDTH       => WORDWIDTH
    )port map(
        Takt           => Takt,

        BetriebsMod     => BetriebMod_0,
        Byte_Trans      => ByteTrans_0 ,
        Ex_EreigEn      => ExEreigEn_0,
        Reset           => Reset,
        Tra_Fertig      => TRA0_Fertig,
        Tra_Anzahl_Stand => TRA0_ANZ_STD,
        Slave_Interface  => S_DAT_I,

        S_Ready         => S0_Ready,
        Sou_W           => EnSAR0,
        Dest_W          => EnDEST0,
        Tra_Anz_W       => EnTRAA0,
        M_Valid         => M0_Valid,
        Kanal_Aktiv     => Kanal_Aktiv_0,

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
        Takt           => Takt,

        BetriebsMod     => BetriebMod_1,
        Byte_Trans      => ByteTrans_1,
        Ex_EreigEn      => ExEreigEn_1,
        Reset           => Reset,
        Tra_Fertig      => TRA1_Fertig,
        Tra_Anzahl_Stand => TRA1_ANZ_STD,
        Slave_Interface  => S_DAT_I,

        S_Ready         => S1_Ready,
        Sou_W           => EnSAR1,
        Dest_W          => EnDEST1,
        Tra_Anz_W       => EnTRAA1,
        M_Valid         => M1_Valid,
        Kanal_Aktiv     => Kanal_Aktiv_1,

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
        S1_SEL_I  => M1_SEL,
        S1_ADR_I  => M1_ADR,
        S1_ACK_O  => M1_ACK,
        S1_DAT_I  => M1_DAT_O,
        S1_DAT_O  => M1_DAT_I,
        
        -- Master Interface
        M_STB_O   => M_STB,
        M_WE_O    => M_WE,
		M_WRO_O   => open,
        M_ADR_O   => M_ADR,
        M_SEL_O   => M_SEL,
        M_ACK_I   => M_ACK,
        M_DAT_O   => M_DAT_O,
        M_DAT_I   => M_DAT_I
    );

end architecture;