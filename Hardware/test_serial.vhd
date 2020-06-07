----------------------------------------------------------------------------------
-- Test_Serial package
--   offers non-synthesizable procedures for sending and receiving
--   serial data
-- (c) Bernhard Lang, FH Osnabrueck
----------------------------------------------------------------------------------

library ieee; use ieee.std_logic_1164.all;
package Test_Serial is

  ----------------------------------------------------------------------------------  
  procedure Serial_Receive
  ----------------------------------------------------------------------------------  
    ( -- Parameter
      constant Baudrate:  integer := 9600;
      constant Parity:    boolean := false;
      constant P_even:    boolean := false;
      -- Signale
      signal   RxD:       in  std_logic;        -- serial receive data
      signal   Value:     out std_logic_vector; -- received value
      signal   Start:     out std_logic         -- start bit marker
    );
    
  ----------------------------------------------------------------------------------  
  procedure Serial_Transmit
  ----------------------------------------------------------------------------------  
    ( -- Parameter
      constant Baudrate:  integer := 9600;
      constant Parity:    boolean := false;
      constant P_even:    boolean := false;
      constant Stopbits:  real    := 2.0;
      -- Value
      constant Value:     in  std_logic_vector;
      -- Signale
      signal   TxD:       out std_logic;                    -- serial transmit data
      signal   Start:     out std_logic                     -- start bit marker
    );

end package;

package body Test_Serial is
  ----------------------------------------------------------------------------------  
  procedure Serial_Receive
  ----------------------------------------------------------------------------------  
    ( -- Parameter
      constant Baudrate:  integer := 9600;
      constant Parity:    boolean := false;
      constant P_even:    boolean := false;
      -- Signale
      signal   RxD:       in  std_logic;
      signal   Value:     out std_logic_vector;
      signal   Start:     out std_logic
    ) is
    constant Bitwidth: time := 1 sec / Baudrate;
    variable D: std_logic_vector(Value'range) := (others=>'U');
    variable P: std_logic;
  begin
    P := '0';
    Start <= '0';
    if not (RxD'Event and RxD='0') then
      wait on RxD until RxD='0'; -- Wait for Start Bit
    end if;
    Start <= '1';
    wait for Bitwidth;       -- End of Start Bit
    Start <= '0';
    -- Bits are received right to left
    for i in D'reverse_range loop
      wait for Bitwidth/2;   -- Middle of Data Bit
      D(i) := RxD;
      P := P xor RxD;
      wait for Bitwidth/2;   -- End of Data Bit
    end loop;
    if Parity then
      wait for Bitwidth/2;   -- Middle of Parity Bit
      P := P xor RxD;
      if P_even=false then
        P := not P;
      end if;
      assert P='0' report "Paritätsfehler" severity error;
      wait for Bitwidth/2;   -- End of Parity Bit
    end if;
    Value <= D;
    wait for Bitwidth;    -- End of first Stop Bit
  end procedure;
  
  ----------------------------------------------------------------------------------  
  procedure Serial_Transmit
  ----------------------------------------------------------------------------------  
    ( -- Parameter
      constant Baudrate:  integer := 9600;
      constant Parity:    boolean := false;
      constant P_even:    boolean := false;
      constant Stopbits:  real := 2.0;
      -- Value
      constant Value:     in  std_logic_vector;
      -- Signale
      signal   TxD:       out std_logic;
      signal   Start:     out std_logic
    ) is
    constant Bitwidth: time := 1 sec / Baudrate;
    variable P: std_logic;
  begin
    P := '0';
    Start <= '1';
    TxD   <= '0';
    wait for Bitwidth;      -- Start Bit
    Start <= '0';
    -- Bits are transmitted right to left
    for i in Value'reverse_range loop
      TxD <= Value(i);
      P := P xor Value(i);
      wait for Bitwidth;    -- Data Bit
    end loop;
    if Parity then
      if P_even=false then
        P := not P;
      end if;
      TxD <= P;
      wait for Bitwidth;    -- Parity
    end if;
    TxD <= '1';
    wait for Bitwidth*Stopbits;    -- Stop Bits
  end procedure;
end package body;

----------------------------------------------------------------------------------
-- Testbench for Test_Serial package
----------------------------------------------------------------------------------
library ieee; use ieee.std_logic_1164.all;
use work.Test_Serial.all;
entity test is
end test;
architecture test of test is
  signal RxD:      std_logic := '1';
  signal TxD:      std_logic := '1';
  signal Value:    std_logic_vector(7 downto 0) := (others=>'U');
  signal Start_Rx: std_logic := '0';
  signal Start_Tx: std_logic := '0';
begin
  process -- receive and verify two serial 
  begin
    Serial_Receive (
      Baudrate  => 9600,
      Parity    => false,
      P_even    => false,
      RxD       => RxD,
      Value     => Value,
      Start     => Start_Rx
    );
    assert value=x"55" report "Falschen Wert empfangen" severity error;
    Serial_Receive (
      Baudrate  => 9600,
      Parity    => false,
      P_even    => false,
      RxD       => RxD,
      Value     => Value,
      Start     => Start_Rx
    );
    assert value=x"aa" report "Falschen Wert empfangen" severity error;
    report "Test fertig" severity note;
    wait;
  end process;
  process
  begin
    wait for 100 us;
    Serial_Transmit (
      Baudrate  => 9600,
      Parity  => false,
      P_even    => false,
      Stopbits  => 2.0,
      Value      => x"55",
      TxD       => TxD,
      Start     => Start_Tx
    );
    Serial_Transmit (
      Baudrate  => 9600,
      Parity  => false,
      P_even    => false,
      Stopbits  => 2.0,
      Value      => x"aa",
      TxD       => TxD,
      Start     => Start_Tx
    );
    wait;
  end process;
  RxD <= transport TxD after 250 us;
end test;