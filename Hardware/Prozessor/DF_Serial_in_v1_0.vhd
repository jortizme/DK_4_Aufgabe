------------------------------------------------------------------------------
-- Dataflow serial input
-- (c) Prof. B.Lang, FH Osnabrück
------------------------------------------------------------------------------

library IEEE; use IEEE.std_logic_1164.all;
entity DF_Serial_in_v1_0 is
  generic(
    BwSize:   integer := 4;  -- width of bit_width counter
    DataSize: integer := 8   -- width data value
  );
  port(
    -- commons
    Clock    : in  std_ulogic;     -- input clock
    Reset    : in  std_ulogic;     -- synchronous reset
    -- serial input
    Serial_in : in std_ulogic;
    -- configuration inputs
    Bit_Width   : std_ulogic_vector(BwSize-1 downto 0); -- width of a bit in clock cycles
    Parity_on   : in std_ulogic;     -- parity on/off
    Parity_even : in std_ulogic;     -- even (1) or odd (0) parity
    -- Dataflow Output
    ValidOut  : out std_ulogic;     -- valid control output for DataOut
    DataOut   : out std_ulogic_vector (DataSize-1 downto 0) -- Data output
  );
end entity;

library IEEE; use IEEE.numeric_std.all;
architecture arch of DF_Serial_in_v1_0 is
  signal si1:        std_ulogic := '1';
  signal si2:        std_ulogic := '1';
  signal cntval:     unsigned(Bit_Width'range) := (others=>'0');
  signal Load:       std_ulogic;
  signal EnableSR:   std_ulogic;
  signal Bit0:       std_ulogic := '1';
  signal Data:       std_ulogic_vector (DataSize-1 downto 0) := (others=>'-');
  signal Parity_Bit: std_ulogic;
  signal P_ok:       std_ulogic;
begin
  -- delay FlipFlops for Serial_in-Signal
  FFs: process(Clock)
  begin
    if rising_edge(Clock) then
      if Reset='1' then
        si1 <= '1';
        si2 <= '1';
      else
        si1 <= Serial_in;
        si2 <= si1;
      end if;
    end if;
  end process;
  -- Modulo counter to divide the clock down to the baudrate
  Modulo_counter: process(Clock)
  begin
    if rising_edge(Clock) then
      if Reset='1' then
        cntval <= unsigned(Bit_Width);
      else
        if (cntval=0) or (si1/=si2) then
          cntval <= unsigned(Bit_Width);
        else
          cntval <= cntval-1;
        end if;
      end if;
    end if;
  end process;
  -- compare counter to half bit width
  EnableSR <= '1' when cntval = ('0' & unsigned(Bit_Width(Bit_Width'high downto 1))) else
              '0';
  -- shift register
  Shift_Register: process (Clock)
    variable value: std_ulogic_vector((DataSize+2)-1 downto 0):=(others=>'1');
  begin
    if rising_edge(Clock) then
      if Reset='1' then
        value := (others => '1');
        Bit0 <= '1';
        Data <= (others=>'-');
        Parity_Bit <= '0';
      else
        if Load='1' then
          value := (others => '1');
        elsif EnableSR='1' then
          value := si2 & value(value'high downto 1);
        end if;
        Bit0 <= value(0);
        Data <= value(DataSize downto 1);
        Parity_Bit <= value(DataSize+1);
      end if;
    end if;
  end process;
  Load <= not Bit0;
  -- parity computing
  Parity: process(Data,Parity_Bit,Parity_on,Parity_even)
    variable p: std_ulogic;
  begin
    if Parity_on='0' then
      P_ok <= '1';
    else
      if Parity_even='0' then
        p:='1'; -- odd parity
      else
        p:='0'; -- even parity
      end if;
      for i in Data'range loop
        p := p xor Data(i);
      end loop;
      if Parity_Bit=p then P_ok <= '1';
      else                 P_ok <= '0';
      end if;
    end if;
  end process;
  -- Dataflow output (WaitOut cannot be considered)
  ValidOut <= Load and P_ok;
  DataOut  <= Data;
end architecture;