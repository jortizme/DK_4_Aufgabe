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

	-- Bus-Signale-Slave-Interface
	signal S_SYS_STB            : std_logic;
	signal S_SYS_WE             : std_logic;
	signal S_SYS_WRO            : std_logic;
	signal S_SYS_ADR            : std_logic_vector(31 downto 0);
	signal S_SYS_SEL            : std_logic_vector( 3 downto 0);
	signal S_SYS_ACK            : std_logic;
	signal S_SYS_DAT_O          : std_logic_vector(31 downto 0);
	signal S_SYS_DAT_I          : std_logic_vector(31 downto 0);

	-- Bus-Signale-Master-Interface-CPU
	signal M_SYS_STB_CPU            : std_logic;
	signal M_SYS_WE_CPU              : std_logic;
	signal M_SYS_WRO_CPU             : std_logic;
	signal M_SYS_ADR_CPU             : std_logic_vector(31 downto 0);
	signal M_SYS_SEL_CPU             : std_logic_vector( 3 downto 0);
	signal M_SYS_ACK_CPU             : std_logic;
	signal M_SYS_DAT_O_CPU           : std_logic_vector(31 downto 0);
	signal M_SYS_DAT_I_CPU           : std_logic_vector(31 downto 0);

	-- Bus-Signale-Master-Interface-DMA-Kontroller
	signal M_SYS_STB_DMA            : std_logic;
	signal M_SYS_WE_DMA              : std_logic;
	signal M_SYS_ADR_DMA             : std_logic_vector(31 downto 0);
	signal M_SYS_SEL_DMA             : std_logic_vector( 3 downto 0);
	signal M_SYS_ACK_DMA             : std_logic;
	signal M_SYS_DAT_O_DMA           : std_logic_vector(31 downto 0);
	signal M_SYS_DAT_I_DMA           : std_logic_vector(31 downto 0);

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
	
	signal VGA_STB		  	  : std_logic;
	signal VGA_ACK		  	  : std_logic;
	signal VGA_DAT_O		  : std_logic_vector(31 downto 0);

	signal DMA_STB			  : std_logic;
	signal DMA_ACK			  : std_logic;
	signal DMA_DAT_O 		  : std_logic_vector(31 downto 0);
	signal IR_Kanal_1         : std_logic;
	signal IR_Kanal_2         : std_logic;	
	signal S0_Ready			  : std_logic;
	signal S1_Ready			  : std_logic;	
	
	
	
begin
	------------------------------------------------------------
	-- Wishbone Interconnect
	------------------------------------------------------------
	intercon_block: block is
	begin
		-- Adress-Decoder
		ROM_STB     <= S_SYS_STB when unsigned(S_SYS_ADR) >= 16#00000000# and
                                    unsigned(S_SYS_ADR) <= 16#00003FFF# else '0';
		RAM_STB     <= S_SYS_STB when unsigned(S_SYS_ADR) >= 16#00004000# and
									unsigned(S_SYS_ADR) <= 16#00007FFF# else '0';
		GPIO_STB    <= S_SYS_STB when unsigned(S_SYS_ADR) >= 16#00008100# and
                                    unsigned(S_SYS_ADR) <= 16#000081FF# else '0';
		UART_STB    <= S_SYS_STB when unsigned(S_SYS_ADR) >= 16#00008200# and
                                    unsigned(S_SYS_ADR) <= 16#0000820F# else '0';
		TIMER_STB   <= S_SYS_STB when unsigned(S_SYS_ADR) >= 16#00008300# and
                            		unsigned(S_SYS_ADR) <= 16#0000830F# else '0';	
		VGA_STB		<= S_SYS_STB when unsigned(S_SYS_ADR) >= 16#00010000# and
									unsigned(S_SYS_ADR) <= 16#0001FFFF# else '0';
		DMA_STB		<= S_SYS_STB when unsigned(S_SYS_ADR) >= 16#00030000# and
                            		unsigned(S_SYS_ADR) <= 16#0003002F# else '0';

		-- Lesedaten-Multiplexer
		S_SYS_DAT_I   <= ROM_DAT_O   when ROM_STB     = '1' else
		               RAM_DAT_O     when RAM_STB     = '1' else
					   GPIO_DAT_O    when GPIO_STB    = '1' else
					   UART_DAT_O    when UART_STB    = '1' else
					   TIMER_DAT_O	 when TIMER_STB   = '1' else
					   VGA_DAT_O	 when VGA_STB     = '1' else
					   DMA_DAT_O     when DMA_STB     = '1' else
					   (others=>'1');

		-- Bestaetigungs-Multiplexer
		S_SYS_ACK     <= ROM_ACK     when ROM_STB     = '1' else
		               RAM_ACK       when RAM_STB     = '1' else
					   GPIO_ACK      when GPIO_STB    = '1' else
					   UART_ACK      when UART_STB    = '1' else
					   TIMER_ACK	 when TIMER_STB   = '1' else
					   VGA_ACK	     when VGA_STB     = '1' else
					   DMA_ACK       when DMA_STB     = '1' else
					   '1';
	end block;

	------------------------------------------------------------
	-- Prozessor
	------------------------------------------------------------

		IP2 <= IR_Kanal_1 or IR_Kanal_2;

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

			CLK_I  => CLK,
			RST_O  => RST,

			-- Wishbone Master Interface-CPU
			STB_O        => M_SYS_STB_CPU,
			WE_O         => M_SYS_WE_CPU ,
			WRO_O        => M_SYS_WRO_CPU,
			ADR_O        => M_SYS_ADR_CPU,
			SEL_O        => M_SYS_SEL_CPU,
			ACK_I        => M_SYS_ACK_CPU,
			DAT_O        => M_SYS_DAT_O_CPU,
			DAT_I        => M_SYS_DAT_I_CPU,

			-- Interrupt Requests
			IP2          => IP2,
			IP3          => IP3,
			IP4          => IP4,

			-- Serial Debug Interface
			SDI_TXD      => SDI_TXD,
			SDI_RXD      => SDI_RXD
		);



	------------------------------------------------------------
	-- DMA_Kontroller
	------------------------------------------------------------

	DUT: entity work.DMA_Kontroller
	generic map(
		BUSWIDTH  => 32,
		WORDWIDTH => 32
	)
	port map(
		Takt            =>  CLK,
		Reset           =>  RST,

		-- Wishbone Slave Interface-DMA
		S_STB           =>  DMA_STB,
		S_WE            =>  S_SYS_WE,
		S_ADR           =>  S_SYS_ADR(7 downto 0),
		S_DAT_O         =>  DMA_DAT_O,
		S_DAT_I         =>  S_SYS_DAT_O,
		S_ACK           =>  DMA_ACK,
		
		-- Wishbone Master Interface-DMA
		M_STB           =>  M_SYS_STB_DMA,
		M_WE            =>  M_SYS_WE_DMA,
		M_ADR           =>  M_SYS_ADR_DMA,
		M_SEL           =>  M_SYS_SEL_DMA,
		M_DAT_O         =>  M_SYS_DAT_O_DMA,
		M_DAT_I         =>  M_SYS_DAT_I_DMA,
		M_ACK           =>  M_SYS_ACK_DMA,

		S0_Ready        =>  S0_Ready,
		S1_Ready        =>  S1_Ready,

		Kanal1_Interrupt => IR_Kanal_1,
		Kanal2_Interrupt => IR_Kanal_2
	);

	------------------------------------------------------------
	--Arbiter für den Master-Zugriff
	------------------------------------------------------------
	Arbiter: entity work.wb_arbiter

    port map(
        -- Clock and Reset
        CLK_I     => CLK,
		RST_I     => RST,

        -- Master CPU Interface (priority)
        S0_STB_I  => M_SYS_STB_CPU,
        S0_WE_I   => M_SYS_WE_CPU,
		S0_WRO_I  => M_SYS_WRO_CPU,
        S0_SEL_I  => M_SYS_SEL_CPU,
        S0_ADR_I  => M_SYS_ADR_CPU,
        S0_ACK_O  => M_SYS_ACK_CPU,
        S0_DAT_I  => M_SYS_DAT_O_CPU,
        S0_DAT_O  => M_SYS_DAT_I_CPU,
        
        -- Master DMA Interface
        S1_STB_I  => M_SYS_STB_DMA,
        S1_WE_I   => M_SYS_WE_DMA,
		S1_WRO_I  => '0',  -- DMA should not write to ROM
        S1_SEL_I  => M_SYS_SEL_DMA,
        S1_ADR_I  => M_SYS_ADR_DMA,
        S1_ACK_O  => M_SYS_ACK_DMA,
        S1_DAT_I  => M_SYS_DAT_O_DMA,
        S1_DAT_O  => M_SYS_DAT_I_DMA,

        -- Slave Interface
        M_STB_O   => S_SYS_STB,
        M_WE_O    => S_SYS_WE,
		M_WRO_O   => S_SYS_WRO,
        M_ADR_O   => S_SYS_ADR,
        M_SEL_O   => S_SYS_ADR,
        M_ACK_I   => S_SYS_ADR,
        M_DAT_O   => S_SYS_DAT_O,
        M_DAT_I   => S_SYS_DAT_I
    );

	------------------------------------------------------------
	-- ROM
	------------------------------------------------------------
	ROM_Block: block
		signal ROM_WE : std_logic;
	begin
		ROM_WE <= S_SYS_WE and S_SYS_WRO;

		ROM_Inst: entity work.bsr2_rom
		port map (
			CLK_I => CLK,
			RST_I => RST,
			STB_I => ROM_STB,
			WE_I  => ROM_WE,
			SEL_I => S_SYS_SEL,
			ADR_I => S_SYS_ADR(13 downto 0),
			DAT_I => S_SYS_DAT_O,
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
		WE_I  => S_SYS_WE ,
		SEL_I => S_SYS_SEL,
		ADR_I => S_SYS_ADR(13 downto 0),
		DAT_I => S_SYS_DAT_O,
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
		WE_I  => S_SYS_WE ,
		ADR_I => S_SYS_ADR(7 downto 0),
		DAT_I => S_SYS_DAT_O,
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
		WE_I      => S_SYS_WE ,
		ADR_I     => S_SYS_ADR(3 downto 0),
		DAT_I     => S_SYS_DAT_O,
		DAT_O     => UART_DAT_O,
		ACK_O     => UART_ACK,
		TX_Interrupt => S1_Ready,
		RX_Interrupt => S0_Ready,
		RxD       => RXD,
		TxD       => TXD
	);
	
	--TIMER
	
	TIMER_Inst: entity work.Timer
		port map(
		  CLK_I      => CLK,
		  RST_I      => RST,
		  STB_I      => TIMER_STB,
		  WE_I       => S_SYS_WE ,
		  ADR_I      => S_SYS_ADR(3 downto 0),
		  DAT_I      => S_SYS_DAT_O,
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
		  WE_I       => S_SYS_WE ,
		  ADR_I      => S_SYS_ADR(15 downto 0),
		  DAT_I      => S_SYS_DAT_O,
		  ACK_O      => VGA_ACK,
		  DAT_O      => VGA_DAT_O,
		
		VSYNC =>VSYNC,
		HSYNC =>HSYNC,
		RED   =>RED,
		GREEN =>GREEN,
		BLUE  =>BLUE
);
end architecture;