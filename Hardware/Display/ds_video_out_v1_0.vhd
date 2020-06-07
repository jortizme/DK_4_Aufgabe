library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ds_video_out_v1_0 is
  generic (
    DATA_WIDTH   : integer := 24
  );
  port (
    clk          : in  std_ulogic;
    rst          : in  std_ulogic;

    enable       : in  std_ulogic;
    clkdiv       : in  unsigned( 3 downto 0);

    hs_pol       : in  std_ulogic;
    vs_pol       : in  std_ulogic;

    hact_px      : in  unsigned(12 downto 0);
    hfp_px       : in  unsigned( 7 downto 0);
    hs_px        : in  unsigned( 7 downto 0);
    hbp_px       : in  unsigned( 7 downto 0);

    vact_px      : in  unsigned(12 downto 0);
    vfp_px       : in  unsigned( 7 downto 0);
    vs_px        : in  unsigned( 7 downto 0);
    vbp_px       : in  unsigned( 7 downto 0);

    s_valid      : in  std_ulogic;
    s_user       : in  std_ulogic_vector(1 downto 0);
    s_data       : in  std_ulogic_vector(DATA_WIDTH-1 downto 0);
    s_ready      : out std_ulogic;

    vid_vs       : out std_ulogic;
    vid_hs       : out std_ulogic;
    vid_active   : out std_ulogic;
    vid_data     : out std_ulogic_vector (DATA_WIDTH-1 downto 0)
  );
end entity;

use work.pixelmarker_pack_v1_1.all;

architecture arch of ds_video_out_v1_0 is

  type state_t is (S_SYNC, S_BP, S_ACTIVE, S_FP, S_WAIT_FOR_BA);

  signal hor_state      : state_t := S_SYNC;
  signal hor_cnt        : unsigned(hact_px'range) := to_unsigned(0, hact_px'length);

  signal clkdiv_cnt     : unsigned(clkdiv'range)  := to_unsigned(0, clkdiv'length);
  signal clkdiv_tc      : boolean                 := true;

  signal ver_state      : state_t := S_WAIT_FOR_BA;
  signal ver_cnt        : unsigned(vact_px'range) := to_unsigned(0, vact_px'length);

  signal vid_vs_r       : std_ulogic := '0';
  signal vid_hs_r       : std_ulogic := '0';
  signal vid_data_r     : std_ulogic_vector (DATA_WIDTH-1 downto 0) := (others=>'0');

  signal s_ready_i      : std_ulogic := '0';

begin
  vid_vs   <= vid_vs_r;
  vid_hs   <= vid_hs_r;
  vid_data <= vid_data_r;
  s_ready  <= s_ready_i;
  
  s_ready_i <=  
    '1' when ver_state = S_WAIT_FOR_BA and s_user /= PM_BA                                    else
    '1' when ver_state = S_ACTIVE      and hor_state = S_BP     and hor_cnt = 0 and clkdiv_tc else
    '1' when ver_state = S_ACTIVE      and hor_state = S_ACTIVE and hor_cnt > 0 and clkdiv_tc else
    '0';
    
  vid_active <= 
    '1' when ver_state = S_ACTIVE and hor_state = S_ACTIVE else
    '0';

  sync_proc: process is
    variable eol       : boolean := false;
  begin
    wait until rising_edge(clk);

    if rst = '1' or enable = '0' then
    
      clkdiv_cnt     <= to_unsigned(0, clkdiv_cnt'length);
      clkdiv_tc      <= false;
      vid_vs_r       <= vs_pol;
      vid_hs_r       <= hs_pol;
      hor_cnt        <= resize(hs_px - 1, hor_cnt'length);
      ver_cnt        <= resize(vs_px - 1, ver_cnt'length);
      eol            := false;
      vid_data_r     <= (others=>'0');

    else     

      -- clock divide counter
      if clkdiv_cnt > 0 then
      
        clkdiv_cnt <= clkdiv_cnt - 1;        
        clkdiv_tc      <= false;
        
      elsif clkdiv_cnt = 0 then
      
        clkdiv_cnt <= clkdiv;
        clkdiv_tc  <= true;
        
      end if;
    
      -- data register
      if s_ready_i = '1' then
      
        if s_valid = '1' then
          vid_data_r <= s_data;
        else
          vid_data_r <= (others=>'0');
        end if;
        
      end if;

      -- horizontal state machine
      eol            := false;
      
      case HOR_STATE is
      
        when S_SYNC =>
        
          if not clkdiv_tc then
          
            hor_state <= S_SYNC;
        
          elsif clkdiv_tc and hor_cnt /= 0 then
          
            hor_state <= S_SYNC;
            hor_cnt   <= hor_cnt - 1;

          elsif clkdiv_tc and hor_cnt = 0 then
          
            hor_state <= S_BP;
            vid_hs_r  <= not hs_pol;
            hor_cnt   <= resize(hbp_px - 1, hor_cnt'length);            
            
          end if;

        when S_BP =>
        
          if not clkdiv_tc then
          
            hor_state      <= S_BP;
            
          elsif clkdiv_tc and hor_cnt /= 0 then
          
            hor_state      <= S_BP;
            hor_cnt        <= hor_cnt - 1;

          elsif clkdiv_tc and hor_cnt = 0 then
          
            hor_state      <= S_ACTIVE;
            hor_cnt        <= resize(hact_px - 1, hor_cnt'length);
            
          end if;

        when S_ACTIVE =>
        
          if not clkdiv_tc then
          
            hor_state      <= S_ACTIVE;
          
          elsif clkdiv_tc and hor_cnt /= 0 then
          
            hor_cnt        <= hor_cnt - 1;
            
          elsif clkdiv_tc and hor_cnt = 0 then
          
            hor_state      <= S_FP;
            hor_cnt        <= resize(hfp_px - 1, hor_cnt'length);
            vid_data_r     <= (others=>'0');
            
          end if;

        when S_FP =>
        
          if not clkdiv_tc then
            
            hor_state <= S_FP;
          
          elsif clkdiv_tc and hor_cnt > 0 then
          
            hor_state <= S_FP;
            hor_cnt   <= hor_cnt - 1;
            
          elsif clkdiv_tc and hor_cnt = 0 then
          
            hor_state <= S_SYNC;
            vid_hs_r  <= hs_pol;
            hor_cnt   <= resize(hs_px - 1, hor_cnt'length);
            eol       := true;
            
          end if;
          
        when others=>
          
            hor_state <= S_SYNC;
            vid_hs_r  <= hs_pol;
            hor_cnt   <= resize(hs_px - 1, hor_cnt'length);
            eol       := true;

      end case;
            
      -- vertical state machine
      case VER_STATE is
      
        when S_WAIT_FOR_BA =>
        
          if s_valid = '0' or s_user /= PM_BA then
          
            ver_state <= S_WAIT_FOR_BA;
            
          elsif s_valid = '1' and s_user = PM_BA then
          
            ver_state <= S_SYNC;
            vid_vs_r  <= vs_pol;
            ver_cnt   <= resize(vs_px - 1, ver_cnt'length);              
            
          end if;
            
      
        when S_SYNC =>
        
          if not eol then
            
            ver_state <= S_SYNC;
        
          elsif eol and ver_cnt > 0 then
          
            ver_state <= S_SYNC;
            ver_cnt   <= ver_cnt - 1;
            
          elsif eol and ver_cnt = 0 then
          
            ver_state <= S_BP;
            vid_vs_r  <= not vs_pol;
            ver_cnt   <= resize(vbp_px - 1, ver_cnt'length);
            
          end if;

        when S_BP =>
        
          if not eol then

            ver_state <= S_BP;
            
          elsif eol and ver_cnt /= 0 then
          
            ver_state <= S_BP;
            ver_cnt   <= ver_cnt - 1;
            
          elsif eol and ver_cnt = 0 then
          
            ver_state <= S_ACTIVE;
            ver_cnt   <= resize(vact_px - 1, ver_cnt'length);
                          
          end if;

        when S_ACTIVE =>
        
          if not eol then
            
            ver_state <= S_ACTIVE;
          
          elsif eol and ver_cnt /= 0 then
          
            ver_state <= S_ACTIVE;
            ver_cnt   <= ver_cnt - 1;
            
          elsif eol and ver_cnt = 0 then
          
            ver_state <= S_FP;
            ver_cnt   <= resize(vfp_px - 1, ver_cnt'length);
            
          end if;

        when S_FP =>
        
          if not eol then
            
            ver_state <= S_FP;
          
          elsif eol and ver_cnt /= 0 then
          
            ver_state <= S_FP;
            ver_cnt   <= ver_cnt - 1;
            
          elsif eol and ver_cnt = 0 then
          
            ver_state <= S_SYNC;
            vid_vs_r  <= vs_pol;
            ver_cnt   <= resize(vs_px - 1, ver_cnt'length);              
            
          end if;

      end case;

    end if;
  end process;
end architecture;
