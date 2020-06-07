entity Beispielrechner_System_V4_testbench is
end entity;

library ieee; 
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.test_serial.all;
use work.txt_util_pack.all;

architecture test of Beispielrechner_System_V4_testbench is
	constant CLK_PERIOD   : time := 20 ns;
	
	signal CLK            : std_logic;
	signal GPIO           : std_logic_vector(7 downto 0);
	signal TXD            : std_logic;
	signal RXD            : std_logic := '1';
	signal BTN            : std_logic_vector(3 downto 0) := "0000";
	signal LED            : std_logic_vector(3 downto 0);
	signal Tx_Start       : std_logic;
	signal Rx_Start       : std_logic;
	signal Rx_Value       : std_logic_vector(7 downto 0);
begin
	-- GPIO-Signale mit den simulierten Tastern und LEDs verbinden
	LED <= GPIO(7 downto 4);
	GPIO(3 downto 0) <= BTN;

	-- UUT instanziieren
	uut: entity work.Beispielrechner_System 
    generic map (
        SYS_FREQUENCY => 50_000_000,
        SDI_BAUDRATE  => 256_000
    )
    port map(
		CLK       	=> CLK,
		GPIO      	=> GPIO,
		RXD       	=> RXD,
		TXD       	=> TXD,
		SDI_RXD   	=> '0',
		SDI_TXD   	=> open
    );

	-- Takt erzeugen
	clk_proc: process is
	begin
		CLK <= '0';
		wait for CLK_PERIOD / 2;
		CLK <= '1';
		wait for CLK_PERIOD / 2;
	end process;
         
end architecture;