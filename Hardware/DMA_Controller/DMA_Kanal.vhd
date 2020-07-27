-------------------------------------------------------------------------------
-- DMA-Kanal
-------------------------------------------------------------------------------
-- Modul Digitale Komponenten
-- Hochschule Osnabrueck
-- Joaquin Ortiz, Filip Mijac
-------------------------------------------------------------------------------
-- BitBreiteM1 = (Taktfrequenz / Baudrate) - 1
--
-- Bits = AnzahlBits - 1
--
-- Kodierung Stoppbits:
--   00 - 1   Stoppbits
--   01 - 1,5 Stobbits
--   10 - 2   Stoppbits
--   11 - 2,5 Stoppbits
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DMA_Kanal is


    port(
        Takt            : in std_ulogic;

        Sou_ADR         : in std_ulogic_vector(31 downto 0);
        Des_ADR         : in std_ulogic_vector(31 downto 0);
        Tra_Anzahl      : in std_ulogic_vector(31 downto 0);
        BetriebsMod     : in std_ulogic_vector(1 downto 0);
        Tra_Modus       : in std_ulogic;
        Ex_EreigEn      : in std_ulogic;
        KanalEn         : in std_ulogic;
        Tra_Fertig      : out std_ulogic;

        S_Ready         : in std_ulogic;

        M_STB           : out std_ulogic;
        M_WE            : out std_ulogic;
        M_ADR           : out std_ulogic_vector(31 downto 0);
        M_SEL           : out std_ulogic_vector(3 downto 0);
        M_DAT_O         : out std_ulogic_vector(31 downto 0);
        M_DAT_I         : in std_ulogic_vector(31 downto 0);
        M_ACK           : in std_ulogic;
    );

end entity;

architecture rtl of DMA_Kanal is

    -- Typ fuer die Ansteuerung des Multiplexers
    type AdrDemul_type is (S,D,X);
    type SELDemul_type is (d,d,d,d,d,,dsf,); -- Gucken noch welche signale zu demultiplexen sind
    
    -- Signale zwischen Steuerwerk und Rechenwerk
    signal AdrSel       : AdrDemul_type := X;
    signal SELVeksel    : SELDemul_type := X;
    signal SourceEn     : std_ulogic;
    signal SourceLd     : std_ulogic;
    signal DestEn       : std_ulogic;     
    signal DestLd       : std_ulogic;
    signal CntEn        : std_ulogic;
    signal CntLd        : std_ulogic;
    signal DataEn       : std_ulogic;
    signal CntTC           : std_ulogic := '0';

begin

    Rechenwerk: block

        --Interne Signale des Rechenwerks
        signal M_ADR_i : std_ulogic_vector(31 downto 0) := (others => '0');

    begin

        --Wer des internen Signals an Port zuweisen
        process(M_ADR_i)
        begin
            M_ADR <= M_ADR_i;
        end process;


    end block;



    Steuerwerk: block

    --Interne Signale des Steuerwerks
    

    --Interne Signale für die Initialisierung
    signal STB_i            : std_ulogic := '0';
    signal WE_i             : std_ulogic := '0';
    signal Tra_Fertig_i     : std_ulogic := '0';

    begin

        --Wer des internen Signals an Port zuweisen
        process(STB_i, WE_i, Tra_Fertig_i)
        begin
            M_STB <= STB_i;
            M_WE <= WE_i;
            Tra_Fertig <= Tra_Fertig_i;
        end process;

    end block;


end architecture ; -