-- This model is a simple model for distributed or block RAM
-- If mapping to block RAM is intended, set OUTPUT_REGISTERED to true
-- Port a is read/write, Port b is read only
-- When two read/write ports, use tdpram instead

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sdpram_v1_2 is
generic (
  OUTPUT_REGISTERED : boolean;
  DATA_WIDTH        : integer;
  ADDR_WIDTH        : integer
);
port (
  clk     : in  std_ulogic;
  
  -- read/write port
  a_en    : in  std_ulogic;
  a_we    : in  std_ulogic;
  a_addr  : in  std_ulogic_vector(ADDR_WIDTH-1 downto 0);
  a_din   : in  std_ulogic_vector(DATA_WIDTH-1 downto 0);
  a_dout  : out std_ulogic_vector(DATA_WIDTH-1 downto 0);
  
  -- read port
  b_en    : in  std_ulogic;
  b_addr  : in  std_ulogic_vector(ADDR_WIDTH-1 downto 0);
  b_dout  : out std_ulogic_vector(DATA_WIDTH-1 downto 0)  
);
end entity;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

architecture rtl of sdpram_v1_2 is
  function conv_integer(i: std_ulogic_vector) return integer is
  begin
    return to_integer(unsigned(i));
  end function;

  type mem_type is array ( (2**ADDR_WIDTH)-1 downto 0 ) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal mem : mem_type;
  
  signal a_dout_slv: std_logic_vector(a_dout'range);
  signal b_dout_slv: std_logic_vector(b_dout'range);
begin
  a_dout <= std_ulogic_vector(a_dout_slv);
  b_dout <= std_ulogic_vector(b_dout_slv);  

  GEN_UNREGISTERED_OUTPUT: if OUTPUT_REGISTERED = false generate
    A_OUTPUT: a_dout_slv <= mem(conv_integer(a_addr));  
    B_OUTPUT: b_dout_slv <= mem(conv_integer(b_addr));  

    MEM_PROC: process(clk)
    begin
    
      if rising_edge(clk) then
        if a_en = '1' then
          if a_we='1' then
            mem(conv_integer(a_addr)) <= std_logic_vector(a_din);
          end if;
        end if;        
      end if;
    end process;
  end generate;

  GEN_REGISTERED_OUTPUT: if OUTPUT_REGISTERED = true generate
    MEM_PROC: process(clk)
    begin
      if rising_edge(clk) then
        if a_en = '1' then
          a_dout_slv <= mem(conv_integer(a_addr));

          if a_we='1' then
            mem(conv_integer(a_addr)) <= std_logic_vector(a_din);
          end if;
        end if;
        
        if b_en = '1' then
          b_dout_slv <= mem(conv_integer(b_addr));
        end if;
      end if;
    end process;
  end generate;
end rtl;
