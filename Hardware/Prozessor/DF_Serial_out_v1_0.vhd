------------------------------------------------------------------------------
-- Dataflow serial output
-- (c) Prof. B.Lang, FH Osnabrück
------------------------------------------------------------------------------

library IEEE; use IEEE.std_logic_1164.all;
entity DF_Serial_out_v1_0 is
  generic(
    BwSize:   integer := 4;  -- width of bit_width counter
    DataSize: integer := 8   -- width data value
  );
  port(
    -- commons
    Clock    : in  std_ulogic;     -- input clock
    Reset    : in  std_ulogic;     -- synchronous reset
    -- Dataflow Input
    ValidIn  : in  std_ulogic;     -- valid control input for DataIn
    DataIn   : in  std_ulogic_vector (DataSize-1 downto 0); -- Data input
    WaitIn   : out std_ulogic;     -- wait request to input
    -- configuration inputs
    Bit_Width   : std_ulogic_vector(BwSize-1 downto 0); -- width of a bit in clock cycles
    Parity_on   : in std_ulogic;     -- parity on/off
    Parity_even : in std_ulogic;     -- even (1) or odd (0) parity
    -- serial output
    Serial_out : out std_ulogic
  );
end entity;

library IEEE; use IEEE.numeric_std.all;
architecture arch of DF_Serial_out_v1_0 is
  signal Load:     std_ulogic;
  signal EnableSR: std_ulogic;
  signal Serial_out_i: std_ulogic := '1';
begin
  Serial_out <= Serial_out_i;

  ------------------------------------------------------------
  control_path: block
  ------------------------------------------------------------
    function Number_of_bits(v:integer) return integer is
      variable value : integer := v;
      variable bits  : integer := 1;
    begin
      if value>1 then
        while value>1 loop
          value := value / 2;
          bits  := bits + 1;
        end loop;
      end if;
      return bits;
    end Number_of_bits;
    signal TC:   std_ulogic := '1';
    signal Zero: std_ulogic := '1';
  begin
    -- Modulo counter to divide the clock down to the baudrate
    Modulo_counter: process(Clock)
      variable value: unsigned(Bit_Width'range):=(others=>'0');
    begin
      if rising_edge(Clock) then
        if Reset = '1' then
          value := unsigned(Bit_Width);
        else          
          if value=0 then
            value := unsigned(Bit_Width);
            TC <= '1';
          else
            value := value-1;
            TC <= '0';
          end if;
        end if;
      end if;
    end process;
    -- counter to count the bits of the serial output
    counter:  process(Clock)
      variable value: unsigned(Number_of_bits(DataSize+3)-1 downto 0):=(others=>'0');
    begin
      if rising_edge(Clock) then
        if Reset='1' then
          value := (others => '0');
          Zero <= '1';
        else
          if Load='1' then
            value := to_unsigned(DataSize+3,value'LENGTH);
            Zero <= '0';
          elsif value>1 and TC='1' then
            value := value-1;
            Zero <= '0';
          elsif value=1 and TC='1' then
            value := value-1;
            Zero <= '1';
          end if;
        end if;
      end if;
    end process;
    -- Load signal for counter and shift register
    Load <= ValidIn and Zero;
    -- Dataflow Input Wait
    WaitIn <= not Zero;
    -- shift Register enable
    EnableSR <= TC;
  end block;
  
  ------------------------------------------------------------
  data_path: block
  ------------------------------------------------------------
    signal Parity_value: std_ulogic;
  begin
    -- shift register
    Shift_Register: process (Clock)
      variable value: std_ulogic_vector((DataSize+3)-1 downto 0):=(others=>'1');
    begin
      if rising_edge(Clock) then
        if Reset='1' then
          value := (others => '1');
          Serial_Out_i <= value(0);
        else
          if Load='1' then
            value := Parity_value & DataIn & "01";
          elsif EnableSR='1' then
            value := '1' & value(value'high downto 1);
          end if;
          Serial_Out_i <= value(0);
        end if;
      end if;
    end process;
    -- parity computations
    Parity: process(DataIn,Parity_on,Parity_even)
      variable p: std_ulogic;
    begin
      if Parity_on='0' then
        Parity_value <= '1';
      else
        if Parity_even='0' then
          p:='1'; -- odd parity
        else
          p:='0'; -- even parity
        end if;
        for i in DataIn'range loop
          p := p xor DataIn(i);
        end loop;
        Parity_value <= p;
      end if;
    end process;
  end block;
end architecture;
