--
-- Character Data Format:
--
-- +----------+---------+
-- |  31..8   |   7..0  |
-- +----------+---------+
-- | reserved |  ASCII  |
-- +----------+---------+
--
-- Output Format:
--
-- +--------+-------+------+
-- | 23..16 | 15..8 | 7..0 |
-- +--------+-------+------+
-- |   R    |   B   |  G   |
-- +--------+-------+------+
--
-- Address map:
--
-- 0x00000 - 0x0ffff character memory (max 16384 chars)
-- 0x10000 - 0x1ffff register space
--   0x10000 start register (writing a 1 also clears ready_irq)
--   0x10004 cyclic_mode register
--   0x10008 ready_irq register
--   0x1000C background color register
--   0x10010 foreground color register

package wb_ds_textdisplay_v1_0_pack is

  constant CHAR_WIDTH_PX  : integer :=  8;  -- Width of one character in pixel
  constant CHAR_HEIGHT_PX : integer := 16; -- height of one character in pixel
    
end package;

library ieee;
use ieee.std_logic_1164.all;

entity wb_ds_textdisplay_v1_0 is
  generic(
  
    TEXT_WIDTH_CHARS   : integer;
    TEXT_HEIGHT_CHARS  : integer;
    
    INIT_START         : boolean := false;
    INIT_CYCLIC_MODE   : boolean := false;
    INIT_BACKGROUND    : integer := 16#000000#;
    INIT_FOREGROUND    : integer := 16#FFFFFF#     
  );
  port(
  
    clk       : in  std_ulogic;
    rst       : in  std_ulogic;
    ready_irq : out std_ulogic;
    
    cyc_i     : in  std_ulogic;
    stb_i     : in  std_ulogic;
    we_i      : in  std_ulogic;
    adr_i     : in  std_ulogic_vector(16 downto 0); 
    dat_i     : in  std_ulogic_vector(31 downto 0);
    ack_o     : out std_ulogic;
    dat_o     : out std_ulogic_vector(31 downto 0);
    
    m_valid   : out std_ulogic;
    m_ready   : in  std_ulogic;
    m_user    : out std_ulogic_vector(1 downto 0);  -- pixelmarker
    m_data    : out std_ulogic_vector(23 downto 0)  -- pixel color (xRGB)
    
  );  
end entity;

use work.pixelmarker_pack_v1_1.all;
use work.wb_ds_textdisplay_v1_0_pack.all;

library ieee; 
use ieee.math_real.all;
use ieee.numeric_std.all;

architecture a of wb_ds_textdisplay_v1_0 is

  function to_std_ulogic(b: in boolean) return std_ulogic is
  begin
    if b then
      return '1';
    else
      return '0';
    end if;
  end function;
  
  constant RAM_ADDR_WIDTH : integer := integer(ceil(log2(real(TEXT_WIDTH_CHARS * TEXT_HEIGHT_CHARS))));

  type   state_t is (INIT0, INIT1, INIT2, MEM1_BA, MEM1_IP, MEM2_IP, IP, ZE, BE, ERROR_STATE);
  
  signal start                    : std_ulogic := to_std_ulogic(INIT_START);
  signal cyclic_mode              : std_ulogic := to_std_ulogic(INIT_CYCLIC_MODE);
  signal background               : std_ulogic_vector(23 downto 0) := std_ulogic_vector(to_unsigned(INIT_BACKGROUND, 24));
  signal foreground               : std_ulogic_vector(23 downto 0) := std_ulogic_vector(to_unsigned(INIT_FOREGROUND, 24));
  signal reset_irq                : std_ulogic;
                                  
  signal charmem_en               : std_ulogic := '0';
  signal charmem_addr             : integer range 0 to TEXT_WIDTH_CHARS * TEXT_HEIGHT_CHARS - 1 := 0;  -- next read address in memory
  signal charset_row              : integer range 0 to CHAR_HEIGHT_PX - 1                        := 0;  -- next line of char
  signal charmem_dout             : std_ulogic_vector(7 downto 0);
  signal charset_dout             : std_ulogic_vector(CHAR_WIDTH_PX - 1 downto 0);
                                  
  -- counters                     
  signal text_row                 : integer range 0 to TEXT_HEIGHT_CHARS - 1 := 0;                      
  signal text_col                 : integer range 0 to TEXT_WIDTH_CHARS - 1  := 0;                        
  signal char_row                 : integer range 0 to CHAR_HEIGHT_PX - 1    := 0;                      -- row in the current glyph
  signal char_col                 : integer range 0 to CHAR_WIDTH_PX - 1     := 0;                      -- column in the current char
                                  
  signal bitmap                   : std_ulogic_vector(charset_dout'range); -- bitmap of the current line
                                  
                                  
  signal reg_stb_i                : std_ulogic;
  signal mem_stb_i                : std_ulogic;
  signal mem_dat_o                : std_ulogic_vector(dat_o'range) := (others=>'0');
                                  
  signal state                    : state_t := INIT0;
                        
  signal is_last_char_row         : boolean;
  signal is_last_char_col         : boolean;
  signal is_next_to_last_char_col : boolean;
  signal is_last_text_col         : boolean;
  signal is_next_to_last_text_col : boolean;
  signal is_last_text_row         : boolean;
  
  signal ack_o_internal           : std_ulogic;
  signal ready_irq_internal       : std_ulogic;
  signal charmem_addr_suv         : std_ulogic_vector(RAM_ADDR_WIDTH - 1 downto 0);
  signal char_line_suv            : std_ulogic_vector(3 downto 0);
begin
  ack_o <= ack_o_internal;
  ready_irq <= ready_irq_internal;

  is_last_char_row         <= char_row = CHAR_HEIGHT_PX - 1;
  is_last_char_col         <= char_col = CHAR_WIDTH_PX - 1;
  is_next_to_last_char_col <= char_col = CHAR_WIDTH_PX - 2;
  is_last_text_row         <= text_row = TEXT_HEIGHT_CHARS - 1;
  is_last_text_col         <= text_col = TEXT_WIDTH_CHARS - 1;    
  is_next_to_last_text_col <= text_col = TEXT_WIDTH_CHARS - 2;    
    
  sequential: process
    variable state_next : state_t;
    
    
  begin    
    wait until rising_edge(clk);

    state_next := ERROR_STATE;
        
    case state is
    
      when INIT0 =>
      
        if not start = '1' then 
          state_next := INIT0;
        else
          state_next := INIT1;
          charmem_addr <= 0;
          charset_row  <= 0;
          text_row     <= 0;
          text_col     <= 0;
          char_row     <= 0;
          char_col     <= 0;
        end if;      
      
      when INIT1       => 
      
        state_next   := INIT2;
        
      when INIT2       => 
      
        state_next    := MEM1_BA;
        
        bitmap        <= charset_dout;
        charmem_addr  <= charmem_addr + 1;
        charset_row   <= 0;
        
      when MEM1_BA =>
      
        if not m_ready = '1' then
        
          state_next := MEM1_BA;
          
        else
        
          state_next := MEM2_IP;          
          char_col   <= char_col + 1;
          
        end if;
      
      when MEM1_IP =>
      
        if not m_ready = '1' then
        
          state_next := MEM1_IP;
          
        else
        
          state_next := MEM2_IP;
          char_col   <= char_col + 1;
          
        end if;
        
      when MEM2_IP =>
      
        if not m_ready = '1' then
        
          state_next := MEM2_IP;
          
        else
        
          state_next := IP;
          char_col  <= char_col + 1;
                              
        end if;
        
      when IP =>
      
        if not m_ready = '1' then
        
          state_next := IP;
          
        else
                    
          if not is_next_to_last_text_col and not is_last_text_col then
          
            if is_last_char_col then
            
              state_next := MEM1_IP;
              char_col     <= 0;
              text_col     <= text_col + 1;              
              charmem_addr <= charmem_addr + 1;
              bitmap       <= charset_dout;
             
            else
            
              state_next := IP;
              char_col   <= char_col + 1;
            
            end if;
          
          elsif is_next_to_last_text_col and is_last_char_col and not is_last_char_row then
          
            state_next   := MEM1_IP;
            char_col     <= 0;
            text_col     <= text_col + 1;
            charmem_addr <= charmem_addr + 1 - TEXT_WIDTH_CHARS;
            charset_row  <= charset_row + 1;
            bitmap       <= charset_dout;
          
          elsif is_next_to_last_text_col and is_last_char_col and is_last_char_row then
          
            if not is_last_text_row then
            
              state_next   := MEM1_IP;
              char_col     <= 0;
              text_col     <= text_col + 1;
              charmem_addr <= charmem_addr + 1;
              charset_row  <= 0;                    
              bitmap       <= charset_dout;
              
            elsif is_last_text_row then
            
              state_next   := IP;
              char_col     <= 0;
              text_col     <= text_col + 1;
              
            end if;
          
          elsif is_last_text_col and is_next_to_last_char_col then
          
            if is_last_text_row and is_last_char_row then
            
              state_next := BE;              
              char_col <= char_col + 1;
              
            else
            
              state_next := ZE;
              char_col <= char_col + 1;
            
            end if;
          
          else
          
            state_next := IP;
            char_col <= char_col + 1;
            
          end if;
          
        end if;
        
      when ZE =>
      
        if not m_ready = '1' then
        
          state_next := ZE;
          
        else
        
          state_next   := MEM1_IP;
          char_col     <= 0;          
          charmem_addr <= charmem_addr + 1;
          bitmap       <= charset_dout;
          
          if not is_last_char_row then
                              
            text_col <= 0;
            char_row <= char_row + 1;
            
          elsif is_last_char_row then
          
            text_row <= text_row + 1;
            text_col <= 0;
            char_row <= 0;
          
          end if;          
          
        end if;
        
      when BE          =>
      
        if not m_ready = '1' then
        
          state_next := BE;
          
        else
        
          state_next := INIT0;
          ready_irq_internal <= '1';
          
        end if;
        
      when ERROR_STATE =>
        -- synthesis translate off
        report "wb_ds_textdisplay_v1_0: ERROR_STATE" severity error;
        -- synthesis translate on
        
        state_next := INIT0;
        ready_irq_internal <= '1';
                  
    end case;
          
    if rst = '1' then    
    
      state        <= INIT0;
      text_row     <= 0;                      
      text_col     <= 0;                        
      char_row     <= 0;
      char_col     <= 0;
      charmem_en   <= '0';
      charmem_addr <= 0;
      m_valid      <= '0';
      m_user       <= (others=>'-');
      
    else
      state <= state_next;
      
      case state_next is
        when INIT0       => charmem_en <= '0'; m_valid <= '0'; m_user <= (others=>'-');
        when INIT1       => charmem_en <= '1'; m_valid <= '0'; m_user <= (others=>'-');
        when INIT2       => charmem_en <= '0'; m_valid <= '0'; m_user <= (others=>'-');
        when MEM1_BA     => charmem_en <= '1'; m_valid <= '1'; m_user <= PM_BA;
        when MEM1_IP     => charmem_en <= '1'; m_valid <= '1'; m_user <= PM_IP;
        when MEM2_IP     => charmem_en <= '0'; m_valid <= '1'; m_user <= PM_IP;
        when IP          => charmem_en <= '0'; m_valid <= '1'; m_user <= PM_IP;
        when ZE          => charmem_en <= '0'; m_valid <= '1'; m_user <= PM_ZE;
        when BE          => charmem_en <= '0'; m_valid <= '1'; m_user <= PM_BE;
        when ERROR_STATE => charmem_en <= '0'; m_valid <= '0'; m_user <= (others=>'-');
      end case;
    end if;
    
    -- bus logic
    if rst = '1' then   
    
      ack_o_internal <= '0';      
      start          <= to_std_ulogic(INIT_START);
      cyclic_mode    <= to_std_ulogic(INIT_CYCLIC_MODE);
      background     <= std_ulogic_vector(to_unsigned(INIT_BACKGROUND, 24));
      foreground     <= std_ulogic_vector(to_unsigned(INIT_FOREGROUND, 24));
      ready_irq_internal      <= '0';
      
    else    
    
      ack_o_internal <= cyc_i and stb_i and not ack_o_internal;
      
      if cyclic_mode = '0' then
        start <= '0';
      end if;

      if reg_stb_i = '1' and we_i = '1' then
        case adr_i(15 downto 0) is
          when x"0000" => 
            start       <= dat_i(0);            
            if dat_i(0) = '1' then ready_irq_internal <= '0'; end if;
          when x"0004" => cyclic_mode <= dat_i(0);
          when x"0008" => ready_irq_internal   <= dat_i(0);
          when x"000C" => background  <= dat_i(background'range);
          when x"0010" => foreground  <= dat_i(foreground'range);
          when others  => null;
        end case;
      end if;
      
    end if;
  end process;
    
  combinational: process(cyc_i, stb_i, adr_i, mem_dat_o, start, cyclic_mode, ready_irq_internal, background, foreground, bitmap, char_col)
  begin
  
    -- wishbone read
    mem_stb_i     <= '0';
    reg_stb_i     <= '0';
    dat_o         <= (others=>'-');
    
    if cyc_i = '1' and stb_i = '1' then
          
      if adr_i(16) = '0' then
          mem_stb_i <= '1';
          dat_o <= mem_dat_o;
          
      elsif adr_i(16) = '1' then
          reg_stb_i <= '1';
          
          case adr_i(15 downto 0) is
            when x"0000" => dat_o <= (31 downto 1=>'0', 0=>start);
            when x"0004" => dat_o <= (31 downto 1=>'0', 0=>cyclic_mode);
            when x"0008" => dat_o <= (31 downto 1=>'0', 0=>ready_irq_internal);
            when x"000C" => dat_o <= x"00" & background;
            when x"0010" => dat_o <= x"00" & foreground;
            when others  => null;
          end case;
          
      end if;
    
    end if;
    
    -- output function
    if bitmap(CHAR_WIDTH_PX - char_col - 1) = '1' then
      m_data <= foreground;
    else
      m_data <= background;
    end if;
    
  end process;
                                     
  charmem_addr_suv <= std_ulogic_vector(to_unsigned(charmem_addr, RAM_ADDR_WIDTH));
  
  char_ram : entity work.sdpram_v1_2
    generic map(
      OUTPUT_REGISTERED => true,
      DATA_WIDTH        => 8,
      ADDR_WIDTH        => RAM_ADDR_WIDTH
    )
    port map(
      clk     => clk,
      
      -- read/write port
      a_en    => mem_stb_i,
      a_we    => we_i,
      a_addr  => adr_i(RAM_ADDR_WIDTH + 1 downto 2),
      a_din   => dat_i(7 downto 0),
      a_dout  => mem_dat_o(7 downto 0),
      
      -- read port
      b_en    => charmem_en,
      b_addr  => charmem_addr_suv,
      b_dout  => charmem_dout 
    );
  
  char_line_suv <= std_ulogic_vector(to_unsigned(charset_row, 4));
  
  charset_rom : entity work.charset_v1_0
    port map(
      clk       => clk,
      char_code => charmem_dout(7 downto 0),
      char_line => char_line_suv,
      data      => charset_dout
    );
    
end architecture;