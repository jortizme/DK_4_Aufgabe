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
    generic(
        BUSWIDTH : positive;
        WORDWIDTH : positive
    );
    port(
        Takt            : in std_ulogic;

        Sou_ADR         : in std_ulogic_vector(BUSWIDTH - 1 downto 0);
        Des_ADR         : in std_ulogic_vector(BUSWIDTH - 1 downto 0);
        Tra_Anzahl      : in std_ulogic_vector(WORDWIDTH - 1 downto 0);
        BetriebsMod     : in std_ulogic_vector(1 downto 0);
        Tra_Modus       : in std_ulogic;
        Ex_EreigEn      : in std_ulogic;
        Reset           : in std_ulogic;
        Tra_Fertig      : out std_ulogic;

        S_Ready         : in std_ulogic;
        M_Valid         : in std_ulogic;
        Kanal_Aktiv     : out std_ulogic;

        M_STB           : out std_ulogic;
        M_WE            : out std_ulogic;
        M_ADR           : out std_ulogic_vector(BUSWIDTH - 1 downto 0);
        M_SEL           : out std_ulogic_vector(3 downto 0);
        M_DAT_O         : out std_ulogic_vector(WORDWIDTH - 1 downto 0);
        M_DAT_I         : in std_ulogic_vector(WORDWIDTH - 1 downto 0);
        M_ACK           : in std_ulogic
    );

end entity;

architecture rtl of DMA_Kanal is

    -- Typ fuer die Ansteuerung des Multiplexers
    type AdrDemul_type is (S,D,X);
    
    -- Signale zwischen Steuerwerk und Rechenwerk
    signal AdrSel       : AdrDemul_type := X;
    signal SourceEn     : std_ulogic;
    signal SourceLd     : std_ulogic;
    signal DestEn       : std_ulogic;     
    signal DestLd       : std_ulogic;
    signal CntEn        : std_ulogic;
    signal CntLd        : std_ulogic;
    signal DataEn       : std_ulogic;
    signal CntTC        : std_ulogic := '0';

begin

    Rechenwerk: block

        --Interne Signale des Rechenwerks
        signal M_DAT_Out_i   :   std_ulogic_vector(WORDWIDTH - 1 downto 0) := (others => '0');
        signal M_ADR_i       :  std_ulogic_vector(BUSWIDTH - 1 downto 0) := (others => '-');
        signal M_SEL_i       :   std_ulogic_vector(3 downto 0);
        signal Sour_A_Out    :   std_ulogic_vector(BUSWIDTH - 1 downto 0) := (others => '0');
        signal Dest_A_Out    :   std_ulogic_vector(BUSWIDTH - 1 downto 0) := (others => '0');
        signal Sel_Sou_Byte  :   std_ulogic_vector(1 downto 0);
        signal Sel_Dest_Byte :  std_ulogic_vector(1 downto 0);
        signal Sel_SelVektor :  std_ulogic_vector(1 downto 0);
        signal ByteMod_Addr_i  :  std_ulogic_vector(BUSWIDTH - 1 downto 0);
        signal ByteMod_Dat_i :  std_ulogic_vector(WORDWIDTH - 1 downto 0); 
        signal Vergleicher_o :  std_ulogic_vector(BUSWIDTH - 1 downto 0) := (others => '0');
        signal OutputData_i  : std_ulogic_vector(WORDWIDTH - 1 downto 0);

    begin

        Sel_SelVektor <= M_ADR_i(1 downto 0);
        Sel_Sou_Byte  <= Sour_A_Out(1 downto 0);
        Sel_Dest_Byte <= Dest_A_Out(1 downto 0);

        --Wer des internen Signals an Port zuweisen
        process(M_DAT_Out_i)
        begin
            M_DAT_O  <= M_DAT_Out_i;
        end process;

        --Beschreibung:
        SourceAdrRegister: process(Takt)
            variable Adresse :  unsigned(31 downto 0) := (others => '0');
        begin

            if rising_edge(Takt) then 

                if Reset = '1' then
                    Adresse := (others => '0');

                elsif SourceLd = '1' then
                    Adresse := unsigned(Sou_ADR);

                elsif SourceEn = '1' then

                    if Tra_Modus = '0' then
                        Adresse := Adresse  + 4;
                    else
                        Adresse := Adresse  + 1;
                    end if;

                end if;
            
                Sour_A_Out <= std_ulogic_vector(Adresse);
            end if;

        end process;

        --Beschreibung:
        DestAdrRegister: process(Takt)
            variable Adresse :  unsigned(31 downto 0) := (others => '0');
        begin

            if rising_edge(Takt) then 

                if Reset = '1' then
                    Adresse := (others => '0');

                elsif DestLd = '1' then
                    Adresse := unsigned(Des_ADR);

                elsif DestEn = '1' then

                    if Tra_Modus = '0' then
                        Adresse := Adresse  + 4;
                    else
                        Adresse := Adresse  + 1;
                    end if;

                end if;
            
                Dest_A_Out <= std_ulogic_vector(Adresse);
            end if;

        end process;

        --Beschreibung: 
        Addresvergleicher: process(Takt)
            variable Q : std_ulogic_vector(31 downto 0);
            variable Wert : unsigned(1 downto 0) := (others => '-');
        begin

            case(BetriebsMod) is
                when "10" =>    Q := Sour_A_Out;
                when "01" =>    Q := Dest_A_Out;
                when others => null;
            end case;

                Wert := unsigned(Q(1 downto 0));
                
                if rising_edge(Takt) then

                    if Reset = '1' then
                        Vergleicher_o <= (others => '0');
                    
                    elsif Wert = 0 then
                        Vergleicher_o <= Q;
                    end if;

                end if;
            

        end process;

        --Beschreibung:
        Block_A: process(BetriebsMod, AdrSel, Vergleicher_o, M_ADR_i)
        begin 

            if ((BetriebsMod = "10" and AdrSel = S) or (BetriebsMod = "01" and AdrSel = D )) then
                ByteMod_Addr_i <= Vergleicher_o;
            elsif ((BetriebsMod = "10" and AdrSel = D) or (BetriebsMod = "01" and AdrSel = S)) then
                ByteMod_Addr_i <= M_ADR_i;
            else 
                ByteMod_Addr_i <= (others => '0');

            end if;

        end process;

        --Zähler
        Zaehler:process(Takt)
            variable Wert : unsigned(31 downto 0) := (others => '0');
        begin
            if rising_edge(Takt) then
            
                CntTC <= '0';

                if Reset = '1' then
                    Wert := (others => '0');

                elsif CntLd = '1' then
                    Wert := unsigned(Tra_Anzahl) - 1;
                
                elsif CntEn = '1' then 
                    Wert := Wert - 1;
                end if; 

                if Wert = 0 then
					CntTC <= '1';
                end if;
                
            end if;
        end process;

        --Beschreibung:
        AddresMult:process(AdrSel, Sour_A_Out, Dest_A_Out)
        begin
            case (AdrSel) is
                when S => M_ADR_i <= Sour_A_Out;
                when D => M_ADR_i <= Dest_A_Out;
                when others => null;
            end case;
        end process;

        --Beschreibung:
        SelMult:process(Sel_SelVektor)
        begin
            case(Sel_SelVektor) is
                when "00" =>   M_SEL_i <= "0001";  
                when "01" =>   M_SEL_i <= "0010"; 
                when "10" =>   M_SEL_i <= "0100"; 
                when "11" =>   M_SEL_i <= "1000";
                when others => null;
            end case;
        end process;

        --Beschreibung
        ByteMult:process(Sel_Sou_Byte, Sel_Dest_Byte, M_DAT_I)
        variable Byte       :   std_ulogic_vector(7 downto 0) := (others => '0');
        variable Wort       :   std_ulogic_vector(31 downto 0) := (others => '0');

        begin

            Wort := (others => '0');

            case(Sel_Sou_Byte) is
                when "00" =>   Byte := M_DAT_I(7 downto 0);
                when "01" =>   Byte := M_DAT_I(15 downto 8);
                when "10" =>   Byte := M_DAT_I(23 downto 16);
                when "11" =>   Byte := M_DAT_I(31 downto 24);
                when others => null;
            end case;

            case(Sel_Dest_Byte) is
                when "00" =>    Wort(7 downto 0)   := Byte;
                when "01" =>    Wort(15 downto 8)  := Byte;
                when "10" =>    Wort(23 downto 16) := Byte;
                when "11" =>    Wort(31 downto 24) := Byte;
                when others => null;
            end case;

            ByteMod_Dat_i <= Wort;

        end process;

        --Beschreibung
        OutputMult: process(M_ADR_i,ByteMod_Addr_i,M_SEL_i,ByteMod_Dat_i,Tra_Modus)
        
        begin
            case(Tra_Modus) is
                when '0'    =>  M_SEL <= "1111";
                                M_ADR  <= M_ADR_i;
                                OutputData_i <= M_DAT_I;

                when '1'    =>  M_SEL <= M_SEL_i;
                                M_ADR <= ByteMod_Addr_i;
                                OutputData_i <= ByteMod_Dat_i;
                when others => null;
            end case;

        end process;
        
        Output_Data_Reg: process(Takt)
        begin

            if rising_edge(Takt) then
                
                if Reset = '1' then
                    M_DAT_Out_i <= (others => '0');
                    
                elsif DataEn = '1' then
                    M_DAT_Out_i <= OutputData_i;
                end if;
            end if;

        end process;

    end block;

    Steuerwerk: block

    --Typ fuer die Zustandswerte 
    type Zustand_type is (Z_IDLE, Z_WAIT, Z_LESE, Z_WRITE, Z_FERTIG, Z_ERROR);

    --Interne Signale des Steuerwerks
    signal Zustand      : Zustand_type := Z_IDLE;
    signal Folgezustand : Zustand_type;	

    --Interne Signale für die Initialisierung
    signal STB_i            : std_ulogic := '0';
    signal WE_i             : std_ulogic := '0';
    signal Tra_Fertig_i     : std_ulogic := '0';
    signal Kanal_Aktiv_i    : std_ulogic := '0';

    begin

        --Wer des internen Signals an Port zuweisen
        process(STB_i, WE_i, Tra_Fertig_i, Kanal_Aktiv_i)
        begin
            M_STB <= STB_i;
            M_WE <= WE_i;
            Tra_Fertig <= Tra_Fertig_i;
            Kanal_Aktiv <= Kanal_Aktiv_i;
        end process;


    -- Prozess zur Berechnung des Folgezustands und der Mealy-Ausgaenge
    Transition: process(Zustand, M_Valid, Ex_EreigEn, S_Ready, M_ACK, CntTC, BetriebsMod)
    begin

        -- Default-Werte fuer den Folgezustand und die Mealy-Ausgaenge
        SourceEn     <= '0';
        SourceLd     <= '0';
        DestEn       <= '0';     
        DestLd       <= '0';
        CntEn        <= '0';
        CntLd        <= '0';
        DataEn       <= '0';
        Folgezustand <= Z_ERROR;
        
        case( Zustand ) is

            when Z_IDLE =>  
                            if M_Valid = '0' then
                                Folgezustand <= Z_IDLE;

                            elsif M_Valid = '1' then
                                SourceLd <= '1';
                                DestLd <= '1';
                                CntLd  <= '1';
                                Folgezustand <= Z_WAIT;
                            end if; 
            when Z_WAIT =>
                            if Ex_EreigEn = '1' and S_Ready = '0' then
                                Folgezustand <= Z_WAIT;
                    
                            elsif Ex_EreigEn = '0'  or (Ex_EreigEn = '1' and S_Ready = '1') then
                                Folgezustand <= Z_LESE;
                            end if;
            when Z_LESE =>
                            if M_ACK = '0' then
                                Folgezustand <= Z_LESE;

                            elsif M_ACK = '1' then
                                DataEn <= '1';
                                Folgezustand <= Z_WRITE;
                            end if;
            when Z_WRITE =>
                            if M_ACK = '0' then
                                Folgezustand <= Z_WRITE;

                            elsif M_ACK = '1' and CntTC = '1' then
                                Folgezustand <= Z_FERTIG;

                            elsif M_ACK = '1' and CntTC = '0'then
                                CntEn <= '1';
                                case(BetriebsMod) is
                                    when "00" => null;
                                    when "01" => DestEn <= '1';
                                    when "10" => SourceEn <= '1';
                                    when "11" => DestEn <= '1'; SourceEn <= '1';
                                    when others => null;
                                end case;
                                Folgezustand <= Z_WAIT;
                            end if;          
            when Z_FERTIG =>
                            Folgezustand <= Z_IDLE;
            when Z_ERROR => null;

        end case;
    end process;


		-- Register fuer Zustand und Moore-Ausgaenge
		Reg: process(Takt)
		begin
			if rising_edge(Takt) then
            
                Zustand <= Folgezustand;

                case (Folgezustand) is
                    when Z_IDLE =>
                                    STB_i        <='0';
                                    WE_i         <='0';
                                    AdrSel       <= X;
                                    Tra_Fertig_i <='0';
                                    Kanal_Aktiv_i <= '0';
                    when Z_WAIT =>
                                    STB_i        <='0';
                                    WE_i         <='0';
                                    AdrSel       <= X;
                                    Tra_Fertig_i <='0';
                                    Kanal_Aktiv_i <= '1';
                    when Z_LESE =>
                                    STB_i        <='1';
                                    WE_i         <='0';
                                    AdrSel       <= S;
                                    Tra_Fertig_i <='0';
                                    Kanal_Aktiv_i <= '1';
                    when Z_WRITE =>
                                    STB_i        <='1';
                                    WE_i         <='1';
                                    AdrSel       <= D;
                                    Tra_Fertig_i <='0';
                                    Kanal_Aktiv_i <= '1';
                    when Z_FERTIG =>
                                    STB_i        <='0';
                                    WE_i         <='0';
                                    AdrSel       <= X;
                                    Tra_Fertig_i <='1';
                                    Kanal_Aktiv_i <= '1';
                    when Z_ERROR =>
                                    STB_i        <='X';
                                    WE_i         <='X';
                                    AdrSel       <= X;
                                    Tra_Fertig_i <='X';
                                    Kanal_Aktiv_i <= 'X';
                end case;
            end if;
        end process;
    end block;

end architecture ; 


