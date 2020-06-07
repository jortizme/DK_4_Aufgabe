library ieee;
use ieee.std_logic_1164.all;

entity mult is
  generic (
    N         : integer := 32; -- bit width of factors (result: 2 * N)
    STAGES    : integer := 0   -- number of pipeline stages
  );
  port (
    clk       : in  std_logic;
    start     : in  std_logic;
    done      : out std_logic;
    signs     : in  std_logic;
    factor_a  : in  std_logic_vector(N - 1 downto 0);
    factor_b  : in  std_logic_vector(N - 1 downto 0);
    product   : out std_logic_vector(2 * N - 1 downto 0)
  );
end entity;

library ieee;
use ieee.numeric_std.all;

architecture arch of mult is
    function compl(x: in std_logic_vector) return std_logic_vector is
    begin
        return std_logic_vector(- signed(x));
    end function;


    signal A_VZ_reg1 : std_logic := '0';
    signal B_VZ_reg1 : std_logic := '0';
    signal A_reg1    : std_logic_vector(N - 1 downto 0) := (others=>'0');
    signal B_reg1    : std_logic_vector(N - 1 downto 0) := (others=>'0');

    type P_reg2_t is array(natural range <>) of std_logic_vector(2 * N - 1 downto 0);
    signal P_reg2    : P_reg2_t(0 to STAGES);
    signal A_VZ_reg2 : std_logic_vector(0 to STAGES);
    signal B_VZ_reg2 : std_logic_vector(0 to STAGES);

    signal done_i    : std_logic := '1';

begin

    done <= done_i;

    sync: process
        variable A_VZ : std_logic;
        variable B_VZ : std_logic;
        variable P_VZ : std_logic;
        variable cnt  : natural range 0 to STAGES + 2;
    begin
        wait until rising_edge(clk);

        if start = '1' then
            cnt := STAGES + 2;
        else
            if cnt > 0 then cnt := cnt - 1; end if;
        end if;

        if cnt = 0 then done_i <= '1'; else done_i <= '0'; end if;

        -- input stage
        A_VZ := factor_a(N - 1) and signs;
        B_VZ := factor_b(N - 1) and signs;

        A_VZ_reg1 <= A_VZ;
        B_VZ_reg1 <= B_VZ;

        if    A_VZ = '0' then
            A_reg1 <= factor_a;
        elsif A_VZ = '1' then
            A_reg1 <= compl(factor_a);
        end if;

        if    B_VZ = '0' then
            B_reg1 <= factor_b;
        elsif B_VZ = '1' then
            B_reg1 <= compl(factor_b);
        end if;

        -- pipeline stages
        for i in 0 to STAGES loop
            if i = 0 then
                A_VZ_reg2(A_VZ_reg2'low) <= A_VZ_reg1;
                B_VZ_reg2(B_VZ_reg2'low) <= B_VZ_reg1;
                P_reg2(P_reg2'low)       <= std_logic_vector(unsigned(A_reg1) * unsigned(B_reg1));
            else
                A_VZ_reg2(i) <= A_VZ_reg2(i - 1);
                B_VZ_reg2(i) <= B_VZ_reg2(i - 1);
                P_reg2(i)    <= P_reg2(i - 1);
            end if;
        end loop;

        P_VZ := A_VZ_reg2(A_VZ_reg2'high) xor B_VZ_reg2(B_VZ_reg2'high);

        -- output stage
        if    P_VZ = '0' then
            product <= P_reg2(STAGES);
        elsif P_VZ = '1' then
            product <= compl(P_reg2(STAGES));
        end if;

    end process;

end architecture;


