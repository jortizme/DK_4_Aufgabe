---------------------------------------------------------------------------------------------------
-- Testbench zur Komponente "UART"
-- Bernhard Lang
-- (c) Hochschule Osnabrueck
---------------------------------------------------------------------------------------------------
entity UART_tb is
end entity;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.wishbone_test_pack.all;
use work.txt_util_pack.all;

architecture test of UART_tb is
	constant BAUDRATE      : integer := 256_000;    
	constant DATABITS      : integer := 8;
	constant PARITY_ON     : boolean := true;
	constant PARITY_EVEN   : boolean := true;
	constant STOPPBITS     : real    := 2.5;

	constant OVERSAMPLING  : integer := 16;
	constant SYS_FREQUENCY : integer := OVERSAMPLING * BAUDRATE;
	constant CLK_PERIOD    : time    := (1 sec) / SYS_FREQUENCY;
		
	signal   CLK           : std_logic;
	signal   RST           : std_logic := '1';
	signal   STB           : std_logic;
	signal   WE            : std_logic;
	signal   ADR           : std_logic_vector(3 downto 0);
	signal   SEL           : std_logic_vector(3 downto 0);
	signal   ACK           : std_logic;
	signal   DAT           : std_logic_vector(31 downto 0);
	signal   UART_DAT      : std_logic_vector(31 downto 0);  
	signal   RxD           : std_logic;
	signal   TxD           : std_logic;
	signal   Interrupt     : std_logic;
	
	constant TDR           : std_logic_vector(3 downto 0) := x"0";
	constant RDR           : std_logic_vector(3 downto 0) := x"4";
	constant CR            : std_logic_vector(3 downto 0) := x"8";
	constant SR            : std_logic_vector(3 downto 0) := x"C";
	
	function cr_value(
		baudrate     : in integer;
		databits     : in integer;
		parity_on    : in boolean;
		parity_even  : in boolean;
		stoppbits    : in real;
		enable_rx_ir : in boolean;
		enable_tx_ir : in boolean
	) return std_logic_vector is
		variable r : std_logic_vector(31 downto 0);				
	begin
		r := (others=>'0');
	    r(15 downto  0) := std_logic_vector(to_unsigned(SYS_FREQUENCY / BAUDRATE - 1, 16));
		r(19 downto 16) := std_logic_vector(to_unsigned(DATABITS - 1, 4));
		if parity_on then
			r(20) := '1';			
		end if;
		if parity_even then
			r(21) := '1';			
		end if;
		if    stoppbits = 1.0 then
			r(23 downto 22) := "00";
		elsif stoppbits = 1.5 then
			r(23 downto 22) := "01";
		elsif stoppbits = 2.0 then
			r(23 downto 22) := "10";
		elsif stoppbits = 2.5 then
			r(23 downto 22) := "11";
		else
			r(23 downto 22) := "XX";			
			report "bad value for stoppbits" severity failure;
		end if;
		if enable_rx_ir then
			r(24) := '1';			
		end if;
		if enable_tx_ir then
			r(25) := '1';			
		end if;
		
		return r;
	end function;
begin
  clk_proc: process
    begin
      CLK <= '0';
      wait for CLK_PERIOD / 2;
      CLK <= '1';
      wait for CLK_PERIOD / 2;
    end process;
  
  uut: entity work.UART
    port map(
      CLK_I              => CLK,
	  RST_I              => RST,
      STB_I              => STB,
      WE_I               => WE,
      ADR_I              => ADR,
      ACK_O              => ACK,
      DAT_I              => DAT,
      DAT_O              => UART_DAT,
      RxD                => RxD,
      TxD                => TxD,
      Interrupt          => Interrupt
    );

  -- TxD und RxD zum Test zusammenschalten
  RxD <= TxD;
  
  stim_and_verify: process
    variable write_data : std_logic_vector(31 downto 0);
    variable read_data  : std_logic_vector(31 downto 0);
  begin
    RST <= '1';
    wishbone_init(STB, WE, SEL, ADR, DAT);        
    wait_cycle(2, CLK);
    RST <= '0';
    wait_cycle(2, CLK);

	-- Anfangszustand pruefen
    assert  Interrupt = '0' report "Signal 'Interrupt' sollte '0' sein." severity failure;
    wishbone_read(SR, read_data, CLK, STB, WE, SEL, ADR, DAT, ACK, UART_DAT);
    assert read_data(25) = '0' report "SR: Bit 'Tx_Interrupt' sollte '0' sein." severity failure;
    assert read_data(24) = '0' report "SR: Bit 'Rx_Interrupt' sollte '0' sein." severity failure;
    assert read_data( 2) = '0' report "SR: Bit 'Ueberlauf' sollte '0' sein." severity failure;
    assert read_data( 1) = '1' report "SR: Sender beschaeftigt" severity failure;
    assert read_data( 0) = '0' report "SR: Empfaengspuffer gefuellt" severity failure;

	--------------------------------------------------------------------------------------------
	-- Zeichen Senden und Empfangen
	--------------------------------------------------------------------------------------------
	
	-- Schreiben und Lesen des Kontrollregisters
	write_data := cr_value(BAUDRATE, DATABITS, PARITY_ON, PARITY_EVEN, STOPPBITS, false, false);
    wishbone_write(x"f", CR, write_data, CLK, STB, WE, SEL, ADR, DAT, ACK, UART_DAT);		
    wishbone_read(CR, read_data, CLK, STB, WE, SEL, ADR, DAT, ACK, UART_DAT);
	assert read_data = write_data report "CR: Gelesener Wert ist ungleich dem geschriebenen Wert." severity failure;

	-- Zeichen senden
	write_data := cr_value(BAUDRATE, DATABITS, PARITY_ON, PARITY_EVEN, STOPPBITS, false, true);
    wishbone_write(x"f", CR, write_data, CLK, STB, WE, SEL, ADR, DAT, ACK, UART_DAT);		
    assert  Interrupt = '1' report "Signal 'Interrupt' sollte '1' sein." severity failure;
    wishbone_read(SR, read_data, CLK, STB, WE, SEL, ADR, DAT, ACK, UART_DAT);
    assert read_data(25) = '1' report "SR: Bit 'Tx_IRQ' sollte '1' sein." severity failure;
    assert read_data(24) = '0' report "SR: Bit 'Rx_IRQ' sollte '0' sein." severity failure;
    assert read_data( 2) = '0' report "SR: Bit 'Ueberlauf' sollte '0' sein." severity failure;
    assert read_data( 1) = '1' report "SR: Bit 'Sender_Ready' sollte '1' sein." severity failure;
    assert read_data( 0) = '0' report "SR: Bit 'Ueberlauf' sollte '0' sein." severity failure;        
    write_data := x"000000" & x"aa";
    wishbone_write(x"f", TDR, write_data, CLK, STB, WE, SEL, ADR, DAT, ACK, UART_DAT);
			
	-- Auf Empfangs-Interrupt warten
	write_data := cr_value(BAUDRATE, DATABITS, PARITY_ON, PARITY_EVEN, STOPPBITS, true, false);
    wishbone_write(x"f", CR, write_data, CLK, STB, WE, SEL, ADR, DAT, ACK, UART_DAT);		
	for i in 0 to (DATABITS + 5) * OVERSAMPLING loop
		if Interrupt = '1' then exit; end if;
		wait until falling_edge(CLK);
	end loop;
    assert Interrupt='1' report "Signal 'Interrupt' sollte '1' sein." severity error;   
	
	-- Statusregister lesen
	wishbone_read(SR, read_data, CLK, STB, WE, SEL, ADR, DAT, ACK, UART_DAT);
    assert read_data(24) = '1' report "SR: Bit 'Rx_Interrupt' sollte '1' sein." severity failure;
    assert read_data( 2) = '0' report "SR: Bit 'Ueberlauf' sollte '0' sein." severity failure;
    assert read_data( 0) = '1' report "SR: Bit 'Puffer_Valid' sollte '1' sein." severity failure;        	
	
	-- Zeichen aus dem Puffer lesen
    wishbone_read(RDR, read_data, CLK, STB, WE, SEL, ADR, DAT, ACK, UART_DAT);
    assert read_data = x"000000aa" report "Falsche Daten gelesen" severity failure;
    
	-- Ende des Stoppbits abwarten und Interrupt-Signal pruefen
	wait for OVERSAMPLING * CLK_PERIOD;
    assert  Interrupt = '0' report "Signal 'Interrupt' sollte '0' sein." severity failure;
	
	-- Statusregister pruefen
    wishbone_read(SR, read_data, CLK, STB, WE, SEL, ADR, DAT, ACK, UART_DAT);
    assert read_data(2) = '0' report "SR: Bit 'Ueberlauf' sollte '0' sein." severity failure;
    assert read_data(1) = '1' report "SR: Bit 'Sender_Ready' sollte '1' sein." severity failure;
    assert read_data(0) = '0' report "SR: Bit 'Puffer_Valid' sollte '0' sein." severity failure;        

	--------------------------------------------------------------------------------------------
	-- Ueberlauf provozieren
	--------------------------------------------------------------------------------------------
	
	-- Erstes Zeichen senden
	write_data := cr_value(BAUDRATE, DATABITS, PARITY_ON, PARITY_EVEN, STOPPBITS, false, true);
    wishbone_write(x"f", CR, write_data, CLK, STB, WE, SEL, ADR, DAT, ACK, UART_DAT);		
    assert  Interrupt = '1' report "Signal 'Interrupt' sollte '1' sein." severity failure;
	
    write_data := x"000000" & x"11";
    wishbone_write(x"f", TDR, write_data, CLK, STB, WE, SEL, ADR, DAT, ACK, UART_DAT);	
	
	-- Zweites Zeichen senden
	for i in 0 to (DATABITS + 5) * OVERSAMPLING loop
		if Interrupt = '1' then exit; end if;
		wait until falling_edge(CLK);
	end loop;
    assert Interrupt='1' report "Signal 'Interrupt' sollte '1' sein." severity error;   
	
    write_data := x"000000" & x"22";
    wishbone_write(x"f", TDR, write_data, CLK, STB, WE, SEL, ADR, DAT, ACK, UART_DAT);

	-- Ende der Uebertragung abwarten
	for i in 0 to (DATABITS + 5) * OVERSAMPLING loop
		wait until falling_edge(CLK);
	end loop;
	
	-- Statusregister pruefen
    wishbone_read(SR, read_data, CLK, STB, WE, SEL, ADR, DAT, ACK, UART_DAT);
    assert read_data(2) = '1' report "SR: Bit 'Ueberlauf' sollte '1' sein." severity failure;

	-- timer_status pruefen
    wishbone_read(SR, read_data, CLK, STB, WE, SEL, ADR, DAT, ACK, UART_DAT);
    assert read_data(2) = '0' report "SR: Bit 'Ueberlauf' sollte '0' sein." severity failure;
    
    report "Test fertig";
    wait;
    
  end process;

end architecture;