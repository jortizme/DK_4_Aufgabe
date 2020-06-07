----------------------------------------------------------------------------
-- Wishbone Interface with Serial Interface
-- For short command descriptions see DF_Wishbone_Interface
-- (c) Bernhard Lang, Hochschule Osnabrueck
----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
package Serial_Wishbone_Interface_pack is
  component Serial_Wishbone_Interface is
    generic (
      constant Frequency: integer:= 50_000_000;
      constant Baudrate:  integer:= 115_200
    );
    port(
      -- serial IO
      RxD      : in  std_ulogic;
      TxD      : out std_ulogic;
      -- non-wishbone signals
      interrupt: in  std_ulogic;
      -- wishbone signals
      CLK_I    : in  std_ulogic;
      RST_I    : in  std_ulogic;
      STB_O    : out std_ulogic;
      WE_O     : out std_ulogic;
      ACK_I    : in  std_ulogic;
      ADR_O    : out std_ulogic_vector(31 downto 0);
      DAT_O    : out std_ulogic_vector(31 downto 0);
      DAT_I    : in  std_ulogic_vector(31 downto 0);
      -- reset output
      Reset    : out std_ulogic
    );
  end component;
end package Serial_Wishbone_Interface_pack;

library IEEE;
use IEEE.std_logic_1164.all;
entity Serial_Wishbone_Interface is
  generic (
    constant Frequency: integer:= 50_000_000;
    constant Baudrate:  integer:= 115_200
  );
  port(
    -- serial IO
    RxD      : in  std_ulogic;
    TxD      : out std_ulogic;
    -- non-wishbone signals
    interrupt: in  std_ulogic;
    -- wishbone signals
    CLK_I    : in  std_ulogic;
    RST_I    : in  std_ulogic;
    STB_O    : out std_ulogic;
    WE_O     : out std_ulogic;
    ACK_I    : in  std_ulogic;
    ADR_O    : out std_ulogic_vector(31 downto 0);
    DAT_O    : out std_ulogic_vector(31 downto 0);
    DAT_I    : in  std_ulogic_vector(31 downto 0);
    -- reset output
    Reset    : out std_ulogic
  );
end Serial_Wishbone_Interface;

library IEEE;
use IEEE.numeric_std.all;
architecture arch of Serial_Wishbone_Interface is
  
  function ComputeSerialBitWidth(Frequency:NATURAL; Baudrate:NATURAL) return NATURAL is
    variable Div:   NATURAL;
    variable Rest:  NATURAL;
  begin
    Div  := Frequency/Baudrate;
    Rest := Frequency mod Baudrate;
    if Rest > (Baudrate/2) then
      Div := Div+1;
    end if;
    return Div;
  end;
  function UNSIGNED_NUM_BITS (ARG: NATURAL) return NATURAL is
    variable NBITS: NATURAL;
    variable N: NATURAL;
  begin
    N := ARG;
    NBITS := 1;
    while N > 1 loop
      NBITS := NBITS+1;
      N := N / 2;
    end loop;
    return NBITS;
  end UNSIGNED_NUM_BITS;

  constant NATURAL_Bit_Width : NATURAL := ComputeSerialBitWidth(Frequency,Baudrate);
  constant BwSize            : NATURAL := UNSIGNED_NUM_BITS(NATURAL_Bit_Width);
  constant Bit_Width         : std_ulogic_vector(BwSize-1 downto 0) := std_ulogic_vector(to_unsigned(NATURAL_Bit_Width,BwSize));
  constant Parity_on         : std_ulogic := '0';
  constant Parity_even       : std_ulogic := '0';

  signal TxD_ValidIn_0       : std_ulogic;
  signal TxD_DataIn_0        : std_ulogic_vector(7 downto 0);
  signal TxD_WaitIn_0        : std_ulogic;
    
  signal TxD_ValidIn_1       : std_ulogic;
  signal TxD_DataIn_1        : std_ulogic_vector(7 downto 0);
  signal TxD_WaitIn_1        : std_ulogic;
    
  signal RxD_ValidOut        : std_ulogic;
  signal RxD_DataOut         : std_ulogic_vector(7 downto 0);
  signal RxD_WaitOut         : std_ulogic;
  
begin
  
  Serial_input: entity work.DF_Serial_in_v1_0
    generic map(
      BwSize   => BwSize,
      DataSize => 8
    )
    port map(
      -- commons
      Clock       => CLK_I,
      Reset       => RST_I,
      -- serial input
      Serial_in   => RxD,
      -- configuration inputs
      Bit_Width   => Bit_Width,
      Parity_on   => Parity_on,
      Parity_even => Parity_even,
      -- Dataflow Output
      ValidOut    => RxD_ValidOut,
      DataOut     => RxD_DataOut
    );
  Wishbone_Interface: entity work.DF_Wishbone_Interface
    port map (
      -- Dataflow input
      ValidIn    => RxD_ValidOut,
      DataIn     => RxD_DataOut,
      WaitIn     => RxD_WaitOut,
      -- Dataflow output
      ValidOut   => TxD_ValidIn_0,
      LastOut    => open,
      DataOut    => TxD_DataIn_0,
      WaitOut    => TxD_WaitIn_0,
      -- non-wishbone signals
      interrupt  => interrupt,
      -- wishbone signals
      CLK_I      => CLK_I,
      RST_I      => RST_I,
      STB_O      => STB_O,
      WE_O       => WE_O,
      ACK_I      => ACK_I,
      ADR_O      => ADR_O,
      DAT_O      => DAT_O,
      DAT_I      => DAT_I,
      Reset      => Reset
    );
  
  DataSync: process(CLK_I) is
  begin
	if rising_edge(CLK_I) then
		if RST_I = '1' then
			TxD_ValidIn_1 <= '0';
			TxD_DataIn_1  <= (others=>'0');
		else
			if TxD_WaitIn_1 = '0' then
				TxD_ValidIn_1 <= TxD_ValidIn_0;
				TxD_DataIn_1  <= TxD_DataIn_0;
			end if;
		end if;
	end if;
  end process;
  
  TxD_WaitIn_0 <= TxD_WaitIn_1 and TxD_ValidIn_1;
	
  Serial_output: entity work.DF_Serial_out_v1_0
    generic map (
      BwSize   => BwSize,
      DataSize => 8
    )
    port map (
      -- commons
      Clock       => CLK_I,
      Reset       => RST_I,
      -- Dataflow Input
      ValidIn     => TxD_ValidIn_1,
      DataIn      => TxD_DataIn_1,
      WaitIn      => TxD_WaitIn_1,
      -- configuration inputs
      Bit_Width   => Bit_Width,
      Parity_on   => Parity_on,
      Parity_even => Parity_even,
      -- serial output
      Serial_out => TxD
    );

end arch;