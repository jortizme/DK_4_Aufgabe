----------------------------------------------------------------------------------
-- Test_Serial package
--   offers non-synthesizable procedures for sending and receiving
--   serial data
-- (c) Bernhard Lang, FH Osnabrueck
----------------------------------------------------------------------------------

library ieee; use ieee.std_logic_1164.all;
package Test_Serial is

	procedure Serial_Receive
	(
		constant Baudrate : integer;               -- Baudrate in bit/s
		constant Num_Bits : integer;               -- Number of bits per data word
		constant Parity   : boolean;               -- Parity: 0:off / 1:on
		constant P_even   : boolean;               -- Parity: 0:odd / 1:even (if enabled)
		Data              : out std_ulogic_vector; -- received data
		signal   RxD      : in  std_ulogic;        -- serial input
		signal   Start    : out std_ulogic         -- start bit marker
	);
    
	procedure Serial_Transmit
    (
		constant Baudrate : integer;               -- Baudrate in Bit/s
		constant Num_Bits : integer;               -- Number of bits per data word
		constant Parity   : boolean;               -- Parity: 0:off / 1:on
		constant P_even   : boolean;               -- Parity: 0:odd / 1:even (if enabled)
		constant Stopbits : real;                  -- Number of stopbits
		constant Data     : in std_ulogic_vector;  -- data to transmit
		signal   TxD      : out std_ulogic;        -- serial output
		signal   Start    : out std_ulogic         -- start bit marker
	);

	procedure Serial_Receive
	(
		constant Baudrate : integer;               -- Baudrate in bit/s
		constant Num_Bits : integer;               -- Number of bits per data word
		constant Parity   : boolean;               -- Parity: 0:off / 1:on
		constant P_even   : boolean;               -- Parity: 0:odd / 1:even (if enabled)
		Data              : out std_logic_vector;  -- received data
		signal   RxD      : in  std_ulogic;        -- serial input
		signal   Start    : out std_ulogic         -- start bit marker
	);
    
	procedure Serial_Transmit
    (
		constant Baudrate : integer;               -- Baudrate in Bit/s
		constant Num_Bits : integer;               -- Number of bits per data word
		constant Parity   : boolean;               -- Parity: 0:off / 1:on
		constant P_even   : boolean;               -- Parity: 0:odd / 1:even (if enabled)
		constant Stopbits : real;                  -- Number of stopbits
		constant Data     : in std_logic_vector;   -- data to transmit
		signal   TxD      : out std_logic;         -- serial output
		signal   Start    : out std_logic          -- start bit marker
	);

end package;

package body Test_Serial is

	procedure Serial_Receive 
	(
		constant Baudrate : integer;
		constant Num_Bits : integer;
		constant Parity   : boolean;
		constant P_even   : boolean;
		Data              : out std_logic_vector;
		signal   RxD      : in  std_ulogic;
		signal   Start    : out std_ulogic
    ) is
		variable Data_suv : std_ulogic_vector(Data'range);
	begin
		Serial_Receive(Baudrate, Num_Bits, Parity, P_even, Data_suv, RxD, Start);
		Data := std_logic_vector(Data_suv);
	end procedure;

	procedure Serial_Receive 
	(
		constant Baudrate : integer;
		constant Num_Bits : integer;
		constant Parity   : boolean;
		constant P_even   : boolean;
		Data              : out std_ulogic_vector;
		signal   RxD      : in  std_ulogic;
		signal   Start    : out std_ulogic
    ) is
		constant Bitwidth : time := 1 sec / Baudrate;
		variable D        : std_ulogic_vector(Data'range) := (others=>'0');
		variable P        : std_ulogic := '0';
	
	begin
	
	-- detect start bit
	if not (RxD'Event and RxD='0') then
		wait on RxD until RxD='0';     -- begin of start bit
    end if;
	Start <= '1';
    wait for Bitwidth; 	               -- end of start bit
	Start <= '0';
	
    -- receive bits beginning with the least significant bit
    for i in 0 to Num_Bits - 1 loop
		wait for Bitwidth / 2;         -- center of data bit
		D(i) := RxD;
		P := P xor RxD;
		wait for Bitwidth / 2;         -- end of data bit
    end loop;

	-- if enabled, receive and check parity bit
    if Parity then
		wait for Bitwidth / 2;         -- center of parity bit
		P := P xor RxD;
		if P_even = false then
			P := not P;
		end if;
		if P /= '0' then
			D := (others=>'X');
			report "parity check failed" severity error;
		end if;
		wait for Bitwidth / 2;         -- end of parity bit
    end if;
	
	wait for Bitwidth / 2;             -- center of first stop bit
    Data := D;
    end procedure;
  
    procedure Serial_Transmit 
    (
		constant Baudrate : integer;               -- Baudrate in Bit/s
		constant Num_Bits : integer;               -- Number of bits per data word
		constant Parity   : boolean;               -- Parity: 0:off / 1:on
		constant P_even   : boolean;               -- Parity: 0:odd / 1:even (if enabled)
		constant Stopbits : real;                  -- Number of stopbits
		constant Data     : in std_logic_vector;   -- data to transmit
		signal   TxD      : out std_logic;          -- serial output
		signal   Start    : out std_logic           -- start bit marker
    ) is
	begin
		Serial_Transmit(Baudrate, Num_Bits, Parity, P_even, Stopbits, std_ulogic_vector(Data), TxD, Start);
	end procedure;
	
  procedure Serial_Transmit 
  (
		constant Baudrate : integer;               -- Baudrate in Bit/s
		constant Num_Bits : integer;               -- Number of bits per data word
		constant Parity   : boolean;               -- Parity: 0:off / 1:on
		constant P_even   : boolean;               -- Parity: 0:odd / 1:even (if enabled)
		constant Stopbits : real;                  -- Number of stopbits
		constant Data     : in std_ulogic_vector;  -- data to transmit
		signal   TxD      : out std_ulogic;        -- serial output
		signal   Start    : out std_ulogic         -- start bit marker
    ) is
		constant Bitwidth : time := 1 sec / Baudrate;
		variable P        : std_ulogic := '0';
	begin
		Start <= '1';
		TxD   <= '0';
		wait for Bitwidth;             -- end of start bit
		Start <= '0';
		
		-- transmit bits beginning with the least significant bit
		for i in 0 to Num_Bits - 1 loop
			TxD <= Data(i);
			P := P xor Data(i);
			wait for Bitwidth;         -- begin of data bit
		end loop;
		
		-- if enabled, transmit parity bit	
		if Parity then
			if not P_even then
				P := not P;
			end if;
		  
			TxD <= P;
			wait for Bitwidth;         -- end of parity bit
		end if;
		
		-- transmit stop bit(s)
		TxD <= '1';
		wait for Bitwidth * Stopbits;  -- end of stop bit(s)
	
	end procedure;
  
end package body;

