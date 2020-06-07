-- Wishbone Slave Address Range:
--
-- 0x00000000 - 0xFFFEFFFF memory bus (shared with bsr2_processor_core master interface)
-- 0xFFFF0000              debug control register
-- 0xFFFF0004 - 0xFFFF0FFF reserved
-- 0xFFFF1000 – 0xFFFF1FFF bsr2_processor_core (slave interface)
-- 0xFFFF2000 – 0xFFFFFFFF reserved

-- debug control register:
-- Bit 9..8 : fsm state (00=running, 01=halted, 10=error)
-- Bit 6    : reset bus
-- Bit 5    : reset cpu
-- Bit 4    : reset fsm
-- Bit 1    : resume (self resetting)
-- Bit 0    : halt

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bsr2_processor is
  generic (
    Reset_Vector     : std_logic_vector(31 downto 0) := x"00000000";
    AdEL_Vector      : std_logic_vector(31 downto 0) := x"00000040";
    AdES_Vector      : std_logic_vector(31 downto 0) := x"00000040";
    Sys_Vector       : std_logic_vector(31 downto 0) := x"00000040";
    RI_Vector        : std_logic_vector(31 downto 0) := x"00000040";
    IP0_Vector       : std_logic_vector(31 downto 0) := x"00000040";
    IP2_Vector       : std_logic_vector(31 downto 0) := x"00000080";
    IP3_Vector       : std_logic_vector(31 downto 0) := x"000000C0";
    IP4_Vector       : std_logic_vector(31 downto 0) := x"00000100";
    SYS_FREQUENCY    : integer;
    SDI_BAUDRATE     : integer;
    DELAY_SLOT       : boolean
  );
  port(
    -- Clock and Reset
    CLK_I  : in  std_logic;
	RST_O  : out std_logic;

    -- Wishbone Master Interface
    STB_O  : out std_logic;
    WE_O   : out std_logic;
	WRO_O  : out std_logic;
    ADR_O  : out std_logic_vector(31 downto 0);
    SEL_O  : out std_logic_vector( 3 downto 0);
    ACK_I  : in  std_logic;
    DAT_O  : out std_logic_vector(31 downto 0);
    DAT_I  : in  std_logic_vector(31 downto 0);

    -- Interrupt Requests
    IP2    : in  std_logic;
    IP3    : in  std_logic;
    IP4    : in  std_logic;
    
    -- Serial Debug Interface
    SDI_TXD : out std_logic;
    SDI_RXD : in  std_logic
  );
end entity;

architecture behavioral of bsr2_processor is
  signal SWI_STB_O  : std_logic;
  signal SWI_WE_O   : std_logic;
  signal SWI_ADR_O  : std_ulogic_vector(31 downto 0);
  signal SWI_SEL_O  : std_logic_vector(3 downto 0) := "1111";
  signal SWI_ACK_I  : std_logic;
  signal SWI_DAT_O  : std_ulogic_vector(31 downto 0);
  signal SWI_DAT_I  : std_logic_vector(31 downto 0);

  signal PC_STB_I   : std_logic;
  signal PC_ACK_O   : std_logic;
  signal PC_DAT_O   : std_logic_vector(31 downto 0);

  signal DBG_STB_I  : std_logic;
  signal DBG_ACK_O  : std_logic;
  signal DBG_DAT_O  : std_logic_vector(31 downto 0) := (others=>'0');

  signal S0_STB_I   : std_logic;
  signal S0_ACK_O   : std_logic;
  signal S0_DAT_O   : std_logic_vector(31 downto 0) := (others=>'0');

  signal S1_STB_O   : std_logic;
  signal S1_WE_O    : std_logic;
  signal S1_ADR_O   : std_logic_vector(31 downto 0);
  signal S1_SEL_O   : std_logic_vector(3 downto 0);
  signal S1_ACK_I   : std_logic;
  signal S1_DAT_O   : std_logic_vector(31 downto 0);
  signal S1_DAT_I   : std_logic_vector(31 downto 0);

  signal step_valid : std_logic := '1';
  signal step_ready : std_logic;
  signal trap       : std_logic;
  
  signal halt       : std_logic := '0';
  signal resume     : std_logic := '0';
  signal reset_bus  : std_logic := '0';
  signal reset_cpu  : std_logic := '0';
  signal reset_fsm  : std_logic := '0';
  signal fsm_state  : std_logic_vector(1 downto 0);
begin
	RST_O <= reset_bus;

    swi: entity work.Serial_Wishbone_Interface 
      generic map(
        Frequency => SYS_FREQUENCY,
        Baudrate  => SDI_BAUDRATE
      )
      port map(
        -- serial IO
        RxD       => SDI_RXD,
        TxD       => SDI_TXD,
        -- non-wishbone signals
        interrupt => '0',
        -- wishbone signals
        CLK_I     => CLK_I,
        RST_I     => '0',
        STB_O     => SWI_STB_O,
        WE_O      => SWI_WE_O,
        ACK_I     => SWI_ACK_I,
        ADR_O     => SWI_ADR_O,
        DAT_O     => SWI_DAT_O,
        DAT_I     => std_ulogic_vector(SWI_DAT_I),
        -- reset output
        Reset     => open
      );      

	wb_intercon: process(SWI_STB_O, SWI_ADR_O, DBG_ACK_O, DBG_DAT_O, PC_ACK_O, PC_DAT_O, S0_ACK_O, S0_DAT_O)
		variable dbg_adr    : unsigned(15 downto 0);
	begin
		DBG_STB_I <= '0';
		PC_STB_I  <= '0';
		S0_STB_I  <= '0';		
		SWI_ACK_I <= '0';
		SWI_DAT_I <= x"ffffffff";
	
		if SWI_ADR_O(31 downto 16) = x"ffff" then
			dbg_adr    := unsigned(SWI_ADR_O(15 downto 0));			
		
			--  Memory Range for Debug FSM Control Register
			if    dbg_adr =  16#0000# then 
				DBG_STB_I <= SWI_STB_O;
				SWI_ACK_I <= DBG_ACK_O;
				SWI_DAT_I <= DBG_DAT_O;
			
			-- Memory Range for Processor Core
			elsif dbg_adr >= 16#1000# and dbg_adr <= 16#1123# then 
				PC_STB_I  <= SWI_STB_O;
				SWI_ACK_I <= PC_ACK_O;
				SWI_DAT_I <= PC_DAT_O;				
			
			end if;
		else
			-- Non-Debug wishbone bus access
			S0_STB_I  <= SWI_STB_O;
			SWI_ACK_I <= S0_ACK_O;
			SWI_DAT_I <= S0_DAT_O;
		end if;			
	end process;	
			
    wb_arbiter: entity work.wb_arbiter 
      port map(
        -- Clock and Reset
        CLK_I     => CLK_I,
        RST_I     => reset_bus,

        -- Slave 0 Interface (priority)
        S0_STB_I  => S0_STB_I,
        S0_WE_I   => SWI_WE_O,
		S0_WRO_I  => '1', -- SWI may write to ROM
        S0_SEL_I  => SWI_SEL_O,
        S0_ADR_I  => std_logic_vector(SWI_ADR_O),
        S0_ACK_O  => S0_ACK_O,
        S0_DAT_I  => std_logic_vector(SWI_DAT_O),
        S0_DAT_O  => S0_DAT_O,
        
        -- Slave 1 Interface
        S1_STB_I  => S1_STB_O,
        S1_WE_I   => S1_WE_O,
		S1_WRO_I  => '0', -- Processor must not write to ROM
        S1_SEL_I  => S1_SEL_O,
        S1_ADR_I  => std_logic_vector(S1_ADR_O),
        S1_ACK_O  => S1_ACK_I,
        S1_DAT_I  => std_logic_vector(S1_DAT_O),
        S1_DAT_O  => S1_DAT_I,
        
        -- Master Interface
        M_STB_O   => STB_O,
        M_WE_O    => WE_O,
		M_WRO_O   => WRO_O,
        M_ADR_O   => ADR_O,
        M_SEL_O   => SEL_O,
        M_ACK_I   => ACK_I,
        M_DAT_O   => DAT_O,
        M_DAT_I   => DAT_I
      );

    core: entity work.bsr2_processor_core 
      generic map(
        Reset_Vector => Reset_Vector,
        AdEL_Vector  => AdEL_Vector,
        AdES_Vector  => AdES_Vector,
        Sys_Vector   => Sys_Vector,
        RI_Vector    => RI_Vector,
        IP0_Vector   => IP0_Vector,
        IP2_Vector   => IP2_Vector,
        IP3_Vector   => IP3_Vector,
        IP4_Vector   => IP4_Vector,
        DELAY_SLOT   => DELAY_SLOT
      )
      port map(
        -- Clock and Reset
        CLK_I      => CLK_I,
        RST_I      => reset_cpu,

        -- Wishbone Master Interface
        STB_O      => S1_STB_O,
        WE_O       => S1_WE_O,
        ADR_O      => S1_ADR_O,
        SEL_O      => S1_SEL_O,
        ACK_I      => S1_ACK_I,
        DAT_O      => S1_DAT_O,
        DAT_I      => S1_DAT_I,

        -- Interrupt Requests
        IP2        => IP2,
        IP3        => IP3,
        IP4        => IP4,
        
        -- Wishbone Debug Interface
        DBG_STB_I  => PC_STB_I,
        DBG_WE_I   => SWI_WE_O,
        DBG_ADR_I  => std_logic_vector(SWI_ADR_O),
        DBG_ACK_O  => PC_ACK_O,
        DBG_DAT_I  => std_logic_vector(SWI_DAT_O),
        DBG_DAT_O  => PC_DAT_O,
        step_valid => step_valid,
        step_ready => step_ready,
        trap       => trap
      );
      
    debug_fsm: block
        type state_t is (RUNNING_STATE, HALTED_STATE, ERROR_STATE);
        signal state : state_t := RUNNING_STATE;

    begin
        DBG_ACK_O             <= DBG_STB_I;
        DBG_DAT_O(9 downto 8) <= fsm_state;		
        DBG_DAT_O(6)          <= reset_bus;
        DBG_DAT_O(5)          <= reset_cpu;
        DBG_DAT_O(4)          <= reset_fsm;
        DBG_DAT_O(1)          <= resume;
        DBG_DAT_O(0)          <= halt;
		
		fsm_state <= "00" when state = RUNNING_STATE else
		             "01" when state = HALTED_STATE  else
					 "10" when state = ERROR_STATE   else
					 "11";
    
        reg: process(CLK_I) is
        begin
            if rising_edge(CLK_I) then
				-- always reset resume bit
				resume <= '0';
				
				if DBG_STB_I = '1' and SWI_WE_O = '1' then
					reset_bus <= SWI_DAT_O(6);
					reset_cpu <= SWI_DAT_O(5);
					reset_fsm <= SWI_DAT_O(4);
					resume    <= SWI_DAT_O(1);
					halt      <= SWI_DAT_O(0);
				end if;                     
			end if;
        end process;
        
        fsm: process(CLK_I) is
            variable state_next : state_t;
        begin
            if rising_edge(CLK_I) then            
				state_next := ERROR_STATE;
				
				if reset_fsm = '1' then
					state_next := HALTED_STATE;
				else            
					case state is
						when HALTED_STATE =>
							if    resume = '0' then state_next := HALTED_STATE;
							elsif resume = '1' then state_next := RUNNING_STATE;
							end if;
						when RUNNING_STATE =>
							if    trap = '1' then state_next := HALTED_STATE;
							elsif trap = '0' then
								if    step_ready = '0' then state_next := RUNNING_STATE;
								elsif step_ready = '1' then
									if    halt = '0' then state_next := RUNNING_STATE;
									elsif halt = '1' then state_next := HALTED_STATE;
									end if;
								end if;
							end if;
								
						when ERROR_STATE =>
							-- synthesis translate off
							report "bsr2_processor: ERROR_STATE" severity failure;
							-- synthesis translate on
							null;
					end case;
				
					case state_next is
						when HALTED_STATE  => step_valid <= '0';
						when RUNNING_STATE => step_valid <= '1';
						when ERROR_STATE   => step_valid <= '0';
					end case;					
				end if;
				
				state <= state_next;
            end if;
        end process;
    end block;
    
    
end architecture;


