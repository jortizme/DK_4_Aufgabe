entity Beispielrechner_System_V3_testbench is
end entity;

library ieee; 
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.test_serial.all;
use work.txt_util_pack.all;

architecture test of Beispielrechner_System_V3_testbench is
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
         
	-- Stimulus process
	stim_proc: process
	begin		
		wait for 200 us;
	
		report "Test fuer Aufgabe 1 ('a' senden, 'A' empfangen)";
		Serial_Transmit	(115200, false, false, 1.0, std_logic_vector(to_unsigned(character'pos('a'), 8)), RxD, Tx_Start);		
		report "Gesendet:  'a'";
		Serial_Receive(115200, false, false, TxD, Rx_Value, Rx_Start);
		report "Empfangen: '" & character'val(to_integer(unsigned(Rx_Value))) & "'";		
		assert character'val(to_integer(unsigned(Rx_Value))) = 'A' report "Falscher Wert empfangen" severity failure;
		report "Aufgabe 1 fertig";
	
		report "Test fuer Aufgabe 2 (BTN setzen, LED ablesen)";
		BTN <= "1000";
		wait for 10 us;
		report "BTN : " & str(BTN);
		wait for 30 us;
		report "LED : " & str(LED);
		assert LED = BTN report "Falscher Wert auf LED" severity failure;

		report "Alle Tests beendet";
	wait;
	end process;
end architecture;