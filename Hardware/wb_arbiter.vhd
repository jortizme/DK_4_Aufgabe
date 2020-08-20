library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wb_arbiter is
  port(
    -- Clock and Reset
    CLK_I  : in  std_logic;
    RST_I  : in  std_logic;

    -- Slave 0 Interface (priority)
    S0_STB_I  : in  std_logic;
    S0_WE_I   : in  std_logic;
	S0_WRO_I  : in  std_logic;
    S0_SEL_I  : in  std_logic_vector( 3 downto 0);
    S0_ADR_I  : in  std_logic_vector(31 downto 0);
    S0_ACK_O  : out std_logic;
    S0_DAT_I  : in  std_logic_vector(31 downto 0);
    S0_DAT_O  : out std_logic_vector(31 downto 0);
	
    -- Slave 1 Interface
    S1_STB_I  : in  std_logic;
    S1_WE_I   : in  std_logic;
	S1_WRO_I  : in  std_logic;
    S1_SEL_I  : in  std_logic_vector( 3 downto 0);
    S1_ADR_I  : in  std_logic_vector(31 downto 0);
    S1_ACK_O  : out std_logic;
    S1_DAT_I  : in  std_logic_vector(31 downto 0);
    S1_DAT_O  : out std_logic_vector(31 downto 0);
	
    -- Master Interface
    M_STB_O  : out std_logic;
    M_WE_O   : out std_logic;
    M_WRO_O  : out std_logic;
    M_ADR_O  : out std_logic_vector(31 downto 0);
    M_SEL_O  : out std_logic_vector( 3 downto 0);
    M_ACK_I  : in  std_logic;
    M_DAT_O  : out std_logic_vector(31 downto 0);
    M_DAT_I  : in  std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of wb_arbiter is
	signal sel : integer range 0 to 1;
	type state_t is (DEFAULT_STATE, S0_STATE, S1_STATE, ERROR_STATE);
	
	signal state      : state_t := DEFAULT_STATE;
	signal state_next : state_t;
begin
	S0_DAT_O <= M_DAT_I;
	S1_DAT_O <= M_DAT_I;							
	
	mux: process(sel, S0_STB_I, S0_WE_I, S0_WRO_I, S0_SEL_I, S0_ADR_I, S0_DAT_I, S1_STB_I, S1_WE_I, S1_WRO_I, S1_SEL_I, S1_ADR_I, S1_DAT_I, M_ACK_I) is
	begin
		case sel is
			when 0 =>
				M_STB_O  <= S0_STB_I;
				M_WE_O   <= S0_WE_I;
				M_WRO_O  <= S0_WRO_I;
				M_SEL_O  <= S0_SEL_I;
				M_ADR_O  <= S0_ADR_I;
				M_DAT_O  <= S0_DAT_I;
				
				S0_ACK_O <= M_ACK_I;							
				S1_ACK_O <= '0';
				
			when 1 =>
				M_STB_O  <= S1_STB_I;
				M_WE_O   <= S1_WE_I;
				M_WRO_O  <= S1_WRO_I;
				M_SEL_O  <= S1_SEL_I;
				M_ADR_O  <= S1_ADR_I;
				M_DAT_O  <= S1_DAT_I;
				
				S1_ACK_O <= M_ACK_I;
				S0_ACK_O <= '0';			
				
		end case;
	end process;
	
	state_logic: process(state, S0_STB_I, S1_STB_I, M_ACK_I) is
	begin
		state_next <= ERROR_STATE;
		sel <= 0;
	
		case state is
			when DEFAULT_STATE =>
				if    S0_STB_I = '0' and S1_STB_I = '0' then state_next <= DEFAULT_STATE; sel <= 0;				
				elsif S0_STB_I = '1' then
					if    M_ACK_I  = '0' then state_next <= S0_STATE;      sel <= 0;
					elsif M_ACK_I  = '1' then state_next <= DEFAULT_STATE; sel <= 0;
					end if;
				
				elsif S0_STB_I = '0' and S1_STB_I = '1' then 
					if    M_ACK_I  = '0' then state_next <= S1_STATE;      sel <= 1;
					elsif M_ACK_I  = '1' then state_next <= DEFAULT_STATE; sel <= 1;				
					end if;
				end if;
				
			when S0_STATE =>
				if    M_ACK_I = '0' then state_next <= S0_STATE;      sel <= 0;
				elsif M_ACK_I = '1' then state_next <= DEFAULT_STATE; sel <= 0;
				end if;
				
			when S1_STATE =>
				if    M_ACK_I = '0' then state_next <= S1_STATE;      sel <= 1;
				elsif M_ACK_I = '1' then state_next <= DEFAULT_STATE; sel <= 1;
				end if;
				
			when ERROR_STATE =>
				-- synthesis translate off
				report "wb_arbiter: ERROR_STATE" severity failure;
				-- synthesis translate on
				null;
		end case;
	end process;
	
	state_reg: process(CLK_I) is
	begin
		if rising_edge(CLK_I) then
			if RST_I = '1' then
				state <= DEFAULT_STATE;
			else
				state <= state_next;
			end if;
		end if;
	end process;
end architecture;
