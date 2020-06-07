library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Display is
	generic (
		CLKDIV  : integer   :=   1;
		HS_POL  : std_logic := '0';
		VS_POL  : std_logic := '0';
		HACT_PX : integer   := 640;
		HFP_PX  : integer   :=  16;
		HS_PX   : integer   :=  96;
		HBP_PX  : integer   :=  48;
		VACT_PX : integer   := 480;
		VFP_PX  : integer   :=  11;
		VS_PX   : integer   :=   2;
		VBP_PX  : integer   :=  31
	);
	port (
		CLK_I : IN  STD_LOGIC;
		RST_I : IN  STD_LOGIC;
		STB_I : IN  STD_LOGIC;
		WE_I  : IN  STD_LOGIC;
		ADR_I : IN  STD_LOGIC_VECTOR(15 DOWNTO 0); 
		DAT_I : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		ACK_O : OUT STD_LOGIC;
		DAT_O : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		
		VSYNC : OUT STD_LOGIC;
		HSYNC : OUT STD_LOGIC;
		RED   : OUT STD_LOGIC;
		GREEN : OUT STD_LOGIC;
		BLUE  : OUT STD_LOGIC
);
end entity;

architecture rtl of Display is

    constant TEXT_WIDTH_CHARS   : integer := 80;
    constant TEXT_HEIGHT_CHARS  : integer := 30;    
    constant INIT_START         : boolean := true;
    constant INIT_CYCLIC_MODE   : boolean := true;
    constant BACKGROUND         : std_logic_vector(2 downto 0) := "001";
    constant FOREGROUND         : std_logic_vector(2 downto 0) := "111";
	
    signal td_valid     : std_ulogic;
    signal td_ready     : std_ulogic;
    signal td_user      : std_ulogic_vector(1 downto 0);
    signal td_data      : std_ulogic_vector(23 downto 0);
	
    signal vid_data     : std_ulogic_vector(0 downto 0);
    signal vid_active   : std_ulogic;
    signal vid_VSYNC    : std_ulogic;
    signal vid_HSYNC    : std_ulogic;	

	signal TD_ADR       : std_ulogic_vector(16 downto 0);
	signal TD_DAT       : std_ulogic_vector(31 downto 0);
begin    
	TD_ADR <= '0' & std_ulogic_vector(ADR_I);
	DAT_O  <= std_logic_vector(TD_DAT);

	textdisplay_inst: entity work.wb_ds_textdisplay_v1_0
	generic map(    
		TEXT_WIDTH_CHARS   => TEXT_WIDTH_CHARS,
		TEXT_HEIGHT_CHARS  => TEXT_HEIGHT_CHARS,      
		INIT_START         => INIT_START,
		INIT_CYCLIC_MODE   => INIT_CYCLIC_MODE,
		INIT_BACKGROUND    => 16#000000#,
		INIT_FOREGROUND    => 16#FFFFFF#
	)
	port map(    
		clk       => clk_i,
		rst       => rst_i,
		ready_irq => open,

		cyc_i     => '1',
		stb_i     => STB_I,
		we_i      => WE_I,
		adr_i     => TD_ADR,
		dat_i     => std_ulogic_vector(DAT_I),
		ack_o     => ACK_O,
		dat_o     => TD_DAT,

		m_valid   => td_valid,
		m_ready   => td_ready,
		m_user    => td_user,
		m_data    => td_data
	);  
	
	video_out_inst: entity work.ds_video_out_v1_0 
	generic map(
		DATA_WIDTH   => 1
	)
	port map (
		clk          => clk_i,
		rst          => rst_i,

		enable       => '1',
		clkdiv       => to_unsigned(CLKDIV, 4),

		hs_pol       => HS_POL,
		vs_pol       => VS_POL,

		hact_px      => to_unsigned(HACT_PX, 13),
		hfp_px       => to_unsigned(HFP_PX,   8),
		hs_px        => to_unsigned(HS_PX,    8),
		hbp_px       => to_unsigned(HBP_PX,   8),

		vact_px      => to_unsigned(VACT_PX, 13),
		vfp_px       => to_unsigned(VFP_PX,   8),
		vs_px        => to_unsigned(VS_PX,    8),
		vbp_px       => to_unsigned(VBP_PX,   8),

		s_valid      => td_valid,
		s_user       => td_user,
		s_data       => td_data(0 downto 0),
		s_ready      => td_ready,

		vid_vs       => vid_VSYNC,
		vid_hs       => vid_HSYNC,
		vid_active   => vid_active,
		vid_data     => vid_data
	);
	
	process(clk_i)
	begin
		if rising_edge(clk_i) then
			VSYNC <= vid_VSYNC;
			HSYNC <= vid_HSYNC;

			if vid_active = '1' then
				if vid_data(0) = '1' then
					RED   <= FOREGROUND(2);
					GREEN <= FOREGROUND(1);
					BLUE  <= FOREGROUND(0);
				else
					RED   <= BACKGROUND(2);
					GREEN <= BACKGROUND(1);
					BLUE  <= BACKGROUND(0);
				end if;
			else
				RED   <= '0';
				GREEN <= '0';
				BLUE  <= '0';			
			end if;
		end if;
	end process;

end architecture;
