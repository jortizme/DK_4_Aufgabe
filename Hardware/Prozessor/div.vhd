library ieee;
use ieee.std_logic_1164.all;

entity div is
  generic (
    N         : integer := 32 -- bit width
  );
  port (
    clk       : in  std_logic;
    start     : in  std_logic;
    done      : out std_logic;
    signs     : in  std_logic;
    dividend  : in  std_logic_vector(N - 1 downto 0);
    divisor   : in  std_logic_vector(N - 1 downto 0);
    quotient  : out std_logic_vector(N - 1 downto 0);
    remainder : out std_logic_vector(N - 1 downto 0)
  );
end entity;

library ieee;
use ieee.numeric_std.all;

architecture arch of div is
    function compl(x: in std_logic_vector) return std_logic_vector is
    begin
        return std_logic_vector(- signed(x));
    end function;

    signal dividend_reg     : std_logic_vector(N - 1 downto 0);
    signal divisor_reg      : std_logic_vector(N - 1 downto 0);
    signal dividend_vz_reg  : std_logic;
    signal divisor_vz_reg   : std_logic;
    signal start_division   : std_logic := '0';
    signal division_gueltig : std_logic := '0';
    signal done_i           : std_logic := '0';

    signal remainder_abs    : std_logic_vector(N - 1 downto 0);
    signal quotient_abs     : std_logic_vector(N - 1 downto 0);
    
begin
    done <= done_i;

    sync: process
        variable dividend_vz : std_logic;
        variable divisor_vz  : std_logic;
    begin
        wait until rising_edge(clk);

        -- input stage
        dividend_vz := dividend(N - 1) and signs;
        divisor_vz  := divisor (N - 1) and signs;

        if start = '1' then
            dividend_vz_reg <= dividend_vz;
            divisor_vz_reg  <= divisor_vz;
            
            if    dividend_vz = '0' then
                dividend_reg <= dividend;
            else
                dividend_reg <= compl(dividend);
            end if;

            if    divisor_vz = '0' then
                divisor_reg <= divisor;
            else
                divisor_reg <= compl(divisor);
            end if;
        end if;
        
        start_division <= start;
        
        -- output stage
        done_i <= division_gueltig;
        if dividend_vz_reg = '0' then
            remainder <= remainder_abs;
        else
            remainder <= compl(remainder_abs);
        end if;
        
        if dividend_vz_reg = divisor_vz_reg then
            quotient <= quotient_abs;
        else
            quotient <= compl(quotient_abs);
        end if;
    end process;

    division: block
        signal Init   : std_logic;
        signal Fertig : std_logic;
    begin
        Rechenwerk: block
            signal W : unsigned(2 * N - 1 downto 0);
            signal V : unsigned(N - 1 downto 0);
            signal R : unsigned(N downto 0);
            signal Qi: std_logic;
        begin
            --
            -- MUX und Reg1
            process (clk)
            begin
                if rising_edge(clk) then
                    W <= (2 * N - 1 downto 0 => 'X');
                    if    Init='1' then W <= unsigned((2 * N -1 downto n => '0') & dividend_reg);
                    elsif Init='0' then W <= R(N - 1 downto 0) & W(n-2 downto 0) & '0';
                    end if;
                end if;
            end process;
            --
            -- Reg2, Reg3 (einfach mal zwei Register in einem Prozess)
            process (clk)
            begin
                if rising_edge(clk) then
                    if Init='1' then
                        V <= unsigned(divisor_reg);
                    end if;
                    remainder_abs <= std_logic_vector(R(N - 1 downto 0));
                end if;
            end process;
            --
            -- Sub und MUX
            process (W(2 * N -1 downto n-1), V)
                variable S : unsigned(N downto 0);
            begin
                R <= (N downto 0 => 'X'); -- Default-Wert für R
                S := (W(2 * N -1 downto n-1)) - ("0" & V); -- Summe und Carry berechnen
                Qi <= not S(N); -- Quotientenziffer Qi
                if    S(N)='0' then R <= S;                   -- MUX Eingang für Qi=1
                elsif S(N)='1' then R <= W(2 * N -1 downto n-1); -- MUX Eingang für Qi=0
                end if;
            end process;
            --
            -- SR (Schieberegister)
            process (clk)
                variable Q: std_logic_vector(n-1 downto 0);
            begin
                if rising_edge(clk) then
                    Q := Q(n-2 downto 0) & Qi;
                    quotient_abs <= Q;
                end if;
            end process;
            --
            -- Cnt (Zähler der Bits)
            process (clk)
                variable Q: integer range 0 to n-1;
            begin
                if rising_edge(clk) then
                    Fertig <= '0';
                    if    Init='1' then
                        Q := n-1;
                    elsif Init='0' then
                        if Q>0 then Q := Q-1; end if;
                        if Q=0 then Fertig <= '1'; end if;
                    end if;
                end if;
            end process;
        end block;
        --
        --
        Steuerwerk: block
            type Zustandswerte is (Warten, Div, OK, Err);
            signal Zustand, Folgezustand : Zustandswerte;
        begin
          --
          -- Berechnung Folgezustand und Mealy-Ausgang (Kombinatorik)
          process (Zustand, Start_Division, Fertig)
            begin
              Folgezustand <= Err;
                Init <= '0';
                case Zustand is
                    when Warten =>  
                        if Start_Division='0'    then Folgezustand <= Warten;
                        elsif Start_Division='1' then Folgezustand <= Div; Init <= '1';
                        end if;
                    when Div =>  
                        if Fertig='0' then Folgezustand <= Div;
                        elsif Fertig='1' then Folgezustand <= OK;
                        end if;
                    when OK =>  
                        if    Start_Division='0' then Folgezustand <= Warten;
                        elsif Start_Division='1' then Folgezustand <= Div; Init <= '1';
                        end if; 
                    when Err =>  
                        null; 
                end case;
            end process;
            --
            -- Berechung Zustand und Moore-Ausgänge (Synchron)
            process (clk)
            begin
              if rising_edge(clk) then
                Zustand <= Folgezustand;
                    case Folgezustand is
                    when Warten => Division_Gueltig <='0';
                    when Div    => Division_Gueltig <='0';
                    when OK     => Division_Gueltig <='1';
                    when Err    => Division_Gueltig <='X';
                    end case;
                end if;
            end process;
            --
        end block;
    end block;

end architecture;


