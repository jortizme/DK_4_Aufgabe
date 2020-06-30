library ieee;
use ieee.std_logic_1164.all;

entity Beispielrechner_System is
generic (
	SYS_FREQUENCY  : integer := 50_000_000;
	SDI_BAUDRATE   : integer := 256_000;
	DELAY_SLOT     : boolean := false
	
);
port (
	CLK            : in    std_logic;
	
	-- GPIO
	GPIO           : inout std_logic_vector(7 downto 0);
	
	-- UART
	RXD            : in    std_logic;
	TXD            : out   std_logic;
	
	-- VGA Ausgabe
	
	VSYNC : out std_logic;
	HSYNC : out std_logic;
	RED : out std_logic;
	GREEN : out std_logic; 
	BLUE  : out std_logic;


	-- Serial Debug Interface
	SDI_TXD        : out  std_logic;
	SDI_RXD        : in   std_logic
);
end entity;

library ieee;
use ieee.numeric_std.all;

architecture arch of Beispielrechner_System is

	signal RST                : std_logic;

	-- Interrupts
	signal IP2                : std_logic := '0';
	signal IP3                : std_logic := '0';
	signal IP4                : std_logic := '0';

	-- Bus-Signale
	signal SYS_STB            : std_logic;
	signal SYS_WE             : std_logic;
	signal SYS_WRO            : std_logic;
	signal SYS_ADR            : std_logic_vector(31 downto 0);
	signal SYS_SEL            : std_logic_vector( 3 downto 0);
	signal SYS_ACK            : std_logic;
	signal SYS_DAT_O          : std_logic_vector(31 downto 0);
	signal SYS_DAT_I          : std_logic_vector(31 downto 0);

	signal ROM_STB            : std_logic;
	signal ROM_WE             : std_logic;
	signal ROM_ACK            : std_logic;
	signal ROM_DAT_O          : std_logic_vector(31 downto 0);

	signal RAM_STB            : std_logic;
	signal RAM_ACK            : std_logic;
	signal RAM_DAT_O          : std_logic_vector(31 downto 0);

	signal GPIO_STB           : std_logic;
	signal GPIO_ACK           : std_logic;
	signal GPIO_DAT_O         : std_logic_vector(31 downto 0);

	signal UART_STB           : std_logic;
	signal UART_ACK           : std_logic;
	signal UART_DAT_O         : std_logic_vector(31 downto 0);

	signal TIMER_STB		  : std_logic;
	signal TIMER_ACK		  : std_logic;
	signal TIMER_DAT_O		  : std_logic_vector(31 downto 0);
	
	signal VGA_STB		  : std_logic;
	signal VGA_ACK		  : std_logic;
	signal VGA_DAT_O		: std_logic_vector(31 downto 0);
	
	
	
begin
	------------------------------------------------------------
	-- Wishbone Interconnect
	------------------------------------------------------------
	intercon_block: block is
	begin
		-- Adress-Decoder
		ROM_STB     <= sys_STB when unsigned(SYS_ADR) >= 16#00000000# and
                                    unsigned(SYS_ADR) <= 16#00003FFF# else '0';
		RAM_STB     <= sys_STB when unsigned(SYS_ADR) >= 16#00004000# and
                                    unsigned(SYS_ADR) <= 16#00007FFF# else '0';
		GPIO_STB    <= sys_STB when unsigned(SYS_ADR) >= 16#00008100# and
                                    unsigned(SYS_ADR) <= 16#000081FF# else '0';
		UART_STB    <= sys_STB when unsigned(SYS_ADR) >= 16#00008200# and
                                    unsigned(SYS_ADR) <= 16#0000820F# else '0';
		TIMER_STB   <= sys_STB when unsigned(SYS_ADR) >= 16#00008300# and
                            		unsigned(SYS_ADR) <= 16#0000830F# else '0';	
		VGA_STB		<= sys_STB when unsigned(SYS_ADR) >= 16#00010000# and
                            		unsigned(SYS_ADR) <= 16#0001FFFF# else '0';	

		-- Lesedaten-Multiplexer
		SYS_DAT_I   <= ROM_DAT_O     when ROM_STB     = '1' else
		               RAM_DAT_O     when RAM_STB     = '1' else
					   GPIO_DAT_O    when GPIO_STB    = '1' else
					   UART_DAT_O    when UART_STB    = '1' else
					   TIMER_DAT_O	 when TIMER_STB   = '1' else
					   VGA_DAT_O	 when VGA_STB   = '1' else
					   -- TODO: Dekodierung fuer weitere Komponenten ergaenzen (Uebung 4)
					   (others=>'1');

		-- Bestaetigungs-Multiplexer
		SYS_ACK     <= ROM_ACK       when ROM_STB     = '1' else
		               RAM_ACK       when RAM_STB     = '1' else
					   GPIO_ACK      when GPIO_STB    = '1' else
					   UART_ACK      when UART_STB    = '1' else
					   TIMER_ACK	 when TIMER_STB   = '1' else
					   VGA_ACK	 when VGA_STB   = '1' else
					   -- TODO: Signale weiterer Komponenten ergaenzen (Uebung 4)
					   '1';
	end block;

	------------------------------------------------------------
	-- Prozessor
	------------------------------------------------------------
	CPU_Inst: entity work.bsr2_processor
	generic map (
		Reset_Vector   => x"00000000",
		AdEL_Vector    => x"00000010",
		AdES_Vector    => x"00000010",
		Sys_Vector     => x"00000010",
		RI_Vector      => x"00000010",
		IP0_Vector     => x"00000010",
		IP2_Vector     => x"00000020",
		IP3_Vector     => x"00000030",
		IP4_Vector     => x"00000040",
		SYS_FREQUENCY  => SYS_FREQUENCY,
		SDI_BAUDRATE   => SDI_BAUDRATE,
		DELAY_SLOT     => DELAY_SLOT
	) port map (
		-- Clock and Reset
		CLK_I        => CLK,
		RST_O        => RST,

		-- Wishbone Master Interface
		STB_O        => SYS_STB,
		WE_O         => SYS_WE,
		WRO_O        => SYS_WRO,
		ADR_O        => SYS_ADR,
		SEL_O        => SYS_SEL,
		ACK_I        => SYS_ACK,
		DAT_O        => SYS_DAT_O,
		DAT_I        => SYS_DAT_I,

		-- Interrupt Requests
		IP2          => IP2,
		IP3          => IP3,
		IP4          => IP4,

		-- Serial Debug Interface
		SDI_TXD      => SDI_TXD,
		SDI_RXD      => SDI_RXD
	);

	------------------------------------------------------------
	-- ROM
	------------------------------------------------------------
	ROM_Block: block
		signal ROM_WE : std_logic;
	begin
		ROM_WE <= SYS_WE and SYS_WRO;

		ROM_Inst: entity work.bsr2_rom
		port map (
			CLK_I => CLK,
			RST_I => RST,
			STB_I => ROM_STB,
			WE_I  => ROM_WE,
			SEL_I => SYS_SEL,
			ADR_I => SYS_ADR(13 downto 0),
			DAT_I => SYS_DAT_O,
			DAT_O => ROM_DAT_O,
			ACK_O => ROM_ACK
		);
	end block;

	------------------------------------------------------------
	-- RAM
	------------------------------------------------------------
	RAM_Inst: entity work.bsr2_ram
	port map (
		CLK_I => CLK,
		RST_I => RST,
		STB_I => RAM_STB,
		WE_I  => SYS_WE,
		SEL_I => SYS_SEL,
		ADR_I => SYS_ADR(13 downto 0),
		DAT_I => SYS_DAT_O,
		DAT_O => RAM_DAT_O,
		ACK_O => RAM_ACK
	);

	------------------------------------------------------------
	-- GPIO
	------------------------------------------------------------
	GPIO_Inst: entity work.GPIO
	generic map (
		NUM_PORTS => GPIO'length
	) port map (
		CLK_I => CLK,
		RST_I => RST,
		STB_I => GPIO_STB,
		WE_I  => SYS_WE,
		ADR_I => SYS_ADR(7 downto 0),
		DAT_I => SYS_DAT_O,
		DAT_O => GPIO_DAT_O,
		ACK_O => GPIO_ACK,
		Pins  => GPIO
	);

	------------------------------------------------------------
	-- UART
	------------------------------------------------------------
	UART_Inst: entity work.UART
	port map (
		CLK_I     => CLK,
		RST_I     => RST,
		STB_I     => UART_STB,
		WE_I      => SYS_WE,
		ADR_I     => SYS_ADR(3 downto 0),
		DAT_I     => SYS_DAT_O,
		DAT_O     => UART_DAT_O,
		ACK_O     => UART_ACK,
		Interrupt => IP2,
		RxD       => RXD,
		TxD       => TXD
	);
	
	--TIMER
	
	TIMER_Inst: entity work.Timer
		port map(
		  CLK_I      => CLK,
		  RST_I      => RST,
		  STB_I      => TIMER_STB,
		  WE_I       => SYS_WE,
		  ADR_I      => SYS_ADR(3 downto 0),
		  DAT_I      => SYS_DAT_O,
		  ACK_O      => TIMER_ACK,
		  DAT_O      => TIMER_DAT_O,
		  Timer_IRQ  => IP3
		);
	

-- Display
Display: entity work.Display
generic map (
		CLKDIV  =>      1,
		HS_POL  => '0',
		VS_POL  => '0',
		HACT_PX => 640,
		HFP_PX =>  16,
		HS_PX   => 96,
		HBP_PX  =>  48,
		VACT_PX => 480,
		VFP_PX  =>  11,
		VS_PX   =>   2,
		VBP_PX  =>  31
	)
	port map (
		 CLK_I      => CLK,
		  RST_I      => RST,
		  STB_I      => VGA_STB,
		  WE_I       => SYS_WE,
		  ADR_I      => SYS_ADR(15 downto 0),
		  DAT_I      => SYS_DAT_O,
		  ACK_O      => VGA_ACK,
		  DAT_O      => VGA_DAT_O,
		
		VSYNC =>VSYNC,
		HSYNC =>HSYNC,
		RED   =>RED,
		GREEN =>GREEN,
		BLUE  =>BLUE
);
end architecture;