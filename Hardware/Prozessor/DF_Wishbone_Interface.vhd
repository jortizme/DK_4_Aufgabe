----------------------------------------------------------------------------
-- Wishbone Interface wit DataFlow command Interface with the
-- following commands:
--   Input Reset Command:     X;
--   Output Reset Response:   x;
--   Input Write Command:     Waaaaaaaa,dddddddd;
--   Output Write Response:   w;
--   Input Read Command:      Raaaaaaaa;
--   Output Read Response:    rdddddddd;
--   Input Version Command:   V;
--   Output Version Response: vcccccccc;
--   Output IR on Message:    I;
--   Output IR off Message:   i;
-- (c) Bernhard Lang, Hochschule Osnabrueck
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
entity DF_Wishbone_Interface is
  port (
    -- Dataflow input
    ValidIn:  in  std_ulogic;
    DataIn:   in  std_ulogic_vector(7 downto 0);
    WaitIn:   out std_ulogic;
    -- Dataflow output
    ValidOut: out std_ulogic;
    LastOut:  out std_ulogic;
    DataOut:  out std_ulogic_vector(7 downto 0);
    WaitOut:  in  std_ulogic;
    -- non-wishbone signals
    interrupt:      in  std_ulogic;
    -- wishbone signals
    CLK_I:          in  std_ulogic;
    RST_I:          in  std_ulogic;
    STB_O:          out std_ulogic;
    WE_O:           out std_ulogic;
    ACK_I:          in  std_ulogic;
    ADR_O:          out std_ulogic_vector(31 downto 0);
    DAT_O:          out std_ulogic_vector(31 downto 0);
    DAT_I:          in  std_ulogic_vector(31 downto 0);
    -- reset output
    Reset:          out std_ulogic
  );
  constant VersionString: string(1 to 8) := "20200218";
end DF_Wishbone_Interface;

library ieee;
use ieee.numeric_std.all;
architecture arch of DF_Wishbone_Interface is
    
  function character_2_std_ulv(char:character) return std_ulogic_vector is
  begin
    return std_ulogic_vector(to_unsigned(character'pos(char),8));
  end character_2_std_ulv;

  signal DoWrite:   std_ulogic;
  signal DoRead:    std_ulogic;
  signal DoVersion: std_ulogic;
  signal DoError:   std_ulogic;
  signal DoReset:   std_ulogic;
  signal Done:      std_ulogic;

  signal Reset_i:   std_ulogic := '0';
  signal STB_O_i:   std_ulogic := '0';
begin
  Reset <= Reset_i;
  STB_O <= STB_O_i;

  --------------------------------------------------------
  Input_Unit: block
  --------------------------------------------------------
    type InChar_t is ( Rd,Wr,Ver,Rst,Digit,Comma,Semicolon,otherChar);
    signal InCharClass:  InChar_t;
    signal ShiftA:       std_ulogic;
    signal ShiftWD:      std_ulogic;
    -- Input Character Counter
    signal InCharCount:    unsigned(2 downto 0);
    signal ClrInCharCount: std_ulogic;
    signal EnInCharCount:  std_ulogic;
    
  begin
    --------------------------------------------------------
    DataPath: block
    --------------------------------------------------------
      
      signal InCharValue: std_ulogic_vector(3 downto 0);
      signal Address:     std_ulogic_vector(31 downto 0) := (others=>'0');
      signal WriteData:   std_ulogic_vector(31 downto 0) := (others=>'0');
      
    begin

      -- CharClass Detection: detect class of input character
      InCharClass <= Rd        when DataIn = character_2_std_ulv('R') else
                     Wr        when DataIn = character_2_std_ulv('W') else
                     Ver       when DataIn = character_2_std_ulv('V') else
                     Rst       when DataIn = character_2_std_ulv('X') else
                     Digit     when DataIn = character_2_std_ulv('0') else
                     Digit     when DataIn = character_2_std_ulv('1') else
                     Digit     when DataIn = character_2_std_ulv('2') else
                     Digit     when DataIn = character_2_std_ulv('3') else
                     Digit     when DataIn = character_2_std_ulv('4') else
                     Digit     when DataIn = character_2_std_ulv('5') else
                     Digit     when DataIn = character_2_std_ulv('6') else
                     Digit     when DataIn = character_2_std_ulv('7') else
                     Digit     when DataIn = character_2_std_ulv('8') else
                     Digit     when DataIn = character_2_std_ulv('9') else
                     Digit     when DataIn = character_2_std_ulv('A') else
                     Digit     when DataIn = character_2_std_ulv('B') else
                     Digit     when DataIn = character_2_std_ulv('C') else
                     Digit     when DataIn = character_2_std_ulv('D') else
                     Digit     when DataIn = character_2_std_ulv('E') else
                     Digit     when DataIn = character_2_std_ulv('F') else
                     Digit     when DataIn = character_2_std_ulv('a') else
                     Digit     when DataIn = character_2_std_ulv('b') else
                     Digit     when DataIn = character_2_std_ulv('c') else
                     Digit     when DataIn = character_2_std_ulv('d') else
                     Digit     when DataIn = character_2_std_ulv('e') else
                     Digit     when DataIn = character_2_std_ulv('f') else
                     Comma     when DataIn = character_2_std_ulv(',') else
                     Semicolon when DataIn = character_2_std_ulv(';') else
                     otherChar;

      -- ASCII Digit to Binary: convert ascii numner to binary value
      InCharValue <= x"0"      when DataIn = character_2_std_ulv('0') else
                     x"1"      when DataIn = character_2_std_ulv('1') else
                     x"2"      when DataIn = character_2_std_ulv('2') else
                     x"3"      when DataIn = character_2_std_ulv('3') else
                     x"4"      when DataIn = character_2_std_ulv('4') else
                     x"5"      when DataIn = character_2_std_ulv('5') else
                     x"6"      when DataIn = character_2_std_ulv('6') else
                     x"7"      when DataIn = character_2_std_ulv('7') else
                     x"8"      when DataIn = character_2_std_ulv('8') else
                     x"9"      when DataIn = character_2_std_ulv('9') else
                     x"A"      when DataIn = character_2_std_ulv('A') else
                     x"B"      when DataIn = character_2_std_ulv('B') else
                     x"C"      when DataIn = character_2_std_ulv('C') else
                     x"D"      when DataIn = character_2_std_ulv('D') else
                     x"E"      when DataIn = character_2_std_ulv('E') else
                     x"F"      when DataIn = character_2_std_ulv('F') else
                     x"A"      when DataIn = character_2_std_ulv('a') else
                     x"B"      when DataIn = character_2_std_ulv('b') else
                     x"C"      when DataIn = character_2_std_ulv('c') else
                     x"D"      when DataIn = character_2_std_ulv('d') else
                     x"E"      when DataIn = character_2_std_ulv('e') else
                     x"F"      when DataIn = character_2_std_ulv('f') else
                     "----";
                     
      -- Address and Data Shift registers: get values nibble by nibble from ASCII-Digits
      process(CLK_I)
      begin
        if rising_edge(CLK_I) then
          if ShiftA='1' then
            Address <= Address(27 downto 0) & InCharValue;
          end if;
          if ShiftWD='1' then
            WriteData <= WriteData(27 downto 0) & InCharValue;
          end if;
        end if;
      end process;
      DAT_O <= WriteData;
      ADR_O <= Address;
      
      -- Input Character Counter 
      InCharCounter: process(CLK_I)
      begin
        if rising_edge(CLK_I) then
          if ClrInCharCount='1' then
            InCharCount <= (others=>'0');
          elsif EnInCharCount='1' then
            InCharCount <= InCharCount + 1;
          end if;
        end if;
      end process;

    end block; -- DataPath
    --------------------------------------------------------
    ControlPath: block
    --------------------------------------------------------
      -- States
      type InputState_t is ( Idle,
                             WrGetAddr, WrComma, WrGetData, WrSemicolon, WrExecute,
                             RdGetAddr, RdSemicolon, RdExecute,
                             VersionSemicolon, VersionExecute,
                             ResetSemicolon, ResetExecute,
                             Error);
      signal State:          InputState_t := Idle;
      signal NextState:      InputState_t;
      -- Precomputed Moore Outputs
      signal NextWaitIn:     std_ulogic;
      signal NextDoWrite:    std_ulogic;
      signal NextDoRead:     std_ulogic;
      signal NextDoVersion:  std_ulogic;
      signal NextDoReset:    std_ulogic;
      signal NextDoError:    std_ulogic;
      -- constant MaxInCharCount: unsigned(InCharCount'range) := to_unsigned(7,InCharCount'High+1); 
      constant MaxInCharCount: Natural := 7; 
    begin
  
      Compute_NextState_and_Mealy_Outputs:
      process (RST_I, State, ValidIn, InCharClass, InCharCount, Done)
      begin

        -- Default Mealy Values
        ShiftA  <= '0';
        ShiftWD <= '0';
        ClrInCharCount <= '0';
        EnInCharCount  <= '0';
        if RST_I='1' then
          NextState <= Idle;
        else
          case(State) is
            ------------------------------------
            -- Idle
            ------------------------------------
            when idle => 
              if (InCharClass=Wr and ValidIn='1') then
                NextState <= WrGetAddr;
                ClrInCharCount <= '1';
              elsif (InCharClass=Rd and ValidIn='1') then
                NextState <= RdGetAddr;
                ClrInCharCount <= '1';
              elsif (InCharClass=Ver and ValidIn='1') then
                NextState <= VersionSemicolon;
              elsif (InCharClass=Rst and ValidIn='1') then
                NextState <= ResetSemicolon;
              elsif (ValidIn='1') then
                NextState <= Error;
              else
                NextState <= Idle;
              end if;
            ------------------------------------
            -- Process Write Command
            ------------------------------------
            when WrGetAddr =>
              if (InCharClass=Digit and ValidIn='1') then
                if InCharCount=MaxInCharCount then
                  ShiftA  <= '1';
                  NextState <= WrComma;
                else
                  EnInCharCount  <= '1';
                  ShiftA  <= '1';
                  NextState <= WrGetAddr;
                end if;
              elsif (ValidIn='0') then
                NextState <= WrGetAddr;
              else
                NextState <= Error;
              end if;
            ------------------------------------
            when WrComma =>
              if (InCharClass=Comma and ValidIn='1') then
                ClrInCharCount <= '1';
                NextState <= WrGetData;
              elsif (ValidIn='0') then
                NextState <= WrComma;
              else
                NextState <= Error;
              end if;
            ------------------------------------
            when WrGetData =>
              if (InCharClass=Digit and ValidIn='1') then
                if InCharCount=MaxInCharCount then
                  ShiftWD        <= '1';
                  NextState <= WrSemicolon;
                else
                  EnInCharCount  <= '1';
                  ShiftWD        <= '1';
                  NextState <= WrGetData;
                end if;
              elsif (ValidIn='0') then
                NextState <= WrGetData;
              else
                NextState <= Error;
              end if;
            ------------------------------------
            when WrSemicolon =>
              if (InCharClass=Semicolon and ValidIn='1') then
                NextState <= WrExecute;
              elsif (ValidIn='0') then
                NextState <= WrSemicolon;
              else
                NextState <= Error;
              end if;
            ------------------------------------
            when WrExecute =>
              if Done='1' then
                NextState <= Idle;
              else
                NextState <= WrExecute;
              end if;
            ------------------------------------
            -- Process Read Command
            ------------------------------------
            when RdGetAddr =>
              if (InCharClass=Digit and ValidIn='1') then
                if InCharCount=MaxInCharCount then
                  ShiftA        <= '1';
                  NextState    <= RdSemicolon;
                else
                  EnInCharCount <= '1';
                  ShiftA        <= '1';
                  NextState    <= RdGetAddr;
                end if;
              elsif (ValidIn='0') then
                NextState <= RdGetAddr;
              else
                NextState <= Error;
              end if;
            ------------------------------------
            when RdSemicolon =>
              if (InCharClass=Semicolon and ValidIn='1') then
                NextState <= RdExecute;
              elsif (ValidIn='0') then
                NextState <= RdSemicolon;
              else
                NextState <= Error;
              end if;
            ------------------------------------
            when RdExecute =>
              if Done='1' then
                NextState <= Idle;
              else
                NextState <= RdExecute;
              end if;
            ------------------------------------
            -- Process Version Command
            ------------------------------------
            when VersionSemicolon =>
              if (InCharClass=Semicolon and ValidIn='1') then
                NextState <= VersionExecute;
              elsif (ValidIn='0') then
                NextState <= VersionSemicolon;
              else
                NextState <= Error;
              end if;
            ------------------------------------
            when VersionExecute =>
              if Done='1' then
                NextState <= Idle;
              else
                NextState <= VersionExecute;
              end if;
            ------------------------------------
            -- Process Reset Command
            ------------------------------------
            when ResetSemicolon =>
              if (InCharClass=Semicolon and ValidIn='1') then
                NextState <= ResetExecute;
              elsif (ValidIn='0') then
                NextState <= ResetSemicolon;
              else
                NextState <= Error;
              end if;
            ------------------------------------
            when ResetExecute =>
              if Done='1' then
                NextState <= Idle;
              else
                NextState <= ResetExecute;
              end if;
            ------------------------------------
            -- Handle Error State
            ------------------------------------
            when Error =>
              if Done='1' then
                NextState <= Idle;
              else
                NextState <= Error;
              end if;
            ------------------------------------
            -- Unhandles Transitions
            ------------------------------------
            when others =>
              NextState <= Error;
          end case;
        end if;
      end process; -- Compute_NextState_and_Mealy_Outputs

      Compute_Next_Moore_Outputs: process (NextState)
      begin
        NextWaitIn     <= '0';  
        NextDoWrite    <= '0';
        NextDoRead     <= '0';
        NextDoVersion  <= '0';
        NextDoReset    <= '0';
        NextDoError    <= '0';
        case(NextState) is
          when Error =>
            NextDoError   <= '1';
            NextWaitIn  <= '1';
          when WrExecute =>
            NextDoWrite <= '1';
            NextWaitIn  <= '1';
          when RdExecute =>
            NextDoRead  <= '1';
            NextWaitIn  <= '1';
          when VersionExecute =>
            NextDoVersion <= '1';
            NextWaitIn    <= '1';
          when ResetExecute =>
            NextDoReset   <= '1';
            NextWaitIn    <= '1';
          when others =>
            null;
        end case;
      end process; -- Compute_Next_Moore_Outputs
      
      Compute_new_State_and_Moore_Outputs:
      process (CLK_I)
      begin
        if rising_edge(CLK_I) then
          -- State register
          State    <= NextState;
          -- Mealy Registers
          WaitIn     <= NextWaitIn; 
          DoWrite    <= NextDoWrite;
          DoRead     <= NextDoRead;        
          DoVersion  <= NextDoVersion;
          DoReset    <= NextDoReset;
          DoError    <= NextDoError;
        end if;
      end process;
    end block; -- ControlPath
  end block; -- Input_Unit

  --------------------------------------------------------
  Output_Unit: block
  --------------------------------------------------------
    type OutChar_t is ( Rd,Wr,Ver,Digit,VerChar,Rst,IrOn, IrOff, Semicolon, Error, None);
    signal OMUX:             OutChar_t;
    signal ShiftRD:          std_ulogic;
    signal IntervalCount:    unsigned(4 downto 0);
    signal EnIntervalCount:  std_ulogic;
    signal ClrIntervalCount: std_ulogic;
    signal EnableRD:         std_ulogic;
    signal AcceptIr:         std_ulogic;
    signal IrChanged:        std_ulogic;
  begin
    --------------------------------------------------------
    DataPath: block
    --------------------------------------------------------
      signal OutReadChar:       std_ulogic_vector(7 downto 0);
      signal OutVersChar:       std_ulogic_vector(7 downto 0);
      signal ReadData:  std_ulogic_vector(31 downto 0);
    begin
      -- Binary to ASCII; convert read data nibbles into ascii characters
      OutReadChar <=  character_2_std_ulv('0') when ReadData(31 downto 28) = x"0" else
                      character_2_std_ulv('1') when ReadData(31 downto 28) = x"1" else
                      character_2_std_ulv('2') when ReadData(31 downto 28) = x"2" else
                      character_2_std_ulv('3') when ReadData(31 downto 28) = x"3" else
                      character_2_std_ulv('4') when ReadData(31 downto 28) = x"4" else
                      character_2_std_ulv('5') when ReadData(31 downto 28) = x"5" else
                      character_2_std_ulv('6') when ReadData(31 downto 28) = x"6" else
                      character_2_std_ulv('7') when ReadData(31 downto 28) = x"7" else
                      character_2_std_ulv('8') when ReadData(31 downto 28) = x"8" else
                      character_2_std_ulv('9') when ReadData(31 downto 28) = x"9" else
                      character_2_std_ulv('A') when ReadData(31 downto 28) = x"A" else
                      character_2_std_ulv('B') when ReadData(31 downto 28) = x"B" else
                      character_2_std_ulv('C') when ReadData(31 downto 28) = x"C" else
                      character_2_std_ulv('D') when ReadData(31 downto 28) = x"D" else
                      character_2_std_ulv('E') when ReadData(31 downto 28) = x"E" else
                      character_2_std_ulv('F') when ReadData(31 downto 28) = x"F" else
                      "XXXXXXXX";
                      
      -- Interval Counter
      IntervalCounter: process(CLK_I)
      begin
        if rising_edge(CLK_I) then
          if (EnIntervalCount='1') then
            IntervalCount <= IntervalCount + 1;
          elsif (ClrIntervalCount='1') then
            IntervalCount <= (others => '0');
          end if;
        end if;
      end process;

      -- Select version character from version string of size 8 characters
      OutVersChar <= character_2_std_ulv(VersionString(to_integer(IntervalCount(2 downto 0))+1));
      
      InterruptDetectionUnit: block
        signal StoredIr: std_ulogic := '0';
      begin
      -- Detection Unit for Interrupt changes
      InterruptDetection: process(CLK_I)
      begin
        if rising_edge(CLK_I) then
          if (AcceptIr='1') then
            StoredIr <= Interrupt;
          end if;
        end if;
      end process;
      IrChanged <= '1' when (StoredIr='0') and (Interrupt='1') else
                   '1' when (StoredIr='1') and (Interrupt='0') else
                   '0';
      end block; -- InterruptDetectionUnit
      
      -- Output Multiplexer
      DataOut <=  character_2_std_ulv('w') when OMUX=Wr        else
                  character_2_std_ulv('r') when OMUX=Rd        else
                  OutReadChar              when OMUX=Digit     else
                  character_2_std_ulv('v') when OMUX=Ver       else
                  OutVersChar              when OMUX=VerChar   else
                  character_2_std_ulv('x') when OMUX=Rst     else
                  character_2_std_ulv('I') when OMUX=IrOn      else
                  character_2_std_ulv('i') when OMUX=IrOff     else
                  character_2_std_ulv(';') when OMUX=Semicolon else
                  character_2_std_ulv('E') when OMUX=Error     else
                  "--------";
      -- catch address or write data nibble by nibble
      process(CLK_I)
      begin
        if rising_edge(CLK_I) then
          if ShiftRD='1' then
            ReadData <= ReadData(27 downto 0) & "0000";
          elsif EnableRD='1' then
            ReadData <= DAT_I;
          end if;
        end if;
      end process;
    end block; -- DataPath
    
    --------------------------------------------------------
    ControlPath: block
    --------------------------------------------------------
      -- States
      type OutputState_t is ( Idle,
                              WB_Write, WrPut_w,
                              WB_Read,  RdPut_r, RdPutData,
                              VersionPut_v, VersionPutString,
                              ResetExecute, ResetPut_r,
                              Put_Semicolon,
                              IrOn, IrOff,
                              ErrorFromInput, AckError, Error);
      signal State:          OutputState_t := Idle;
      signal NextState:      OutputState_t;
      -- precumputed moore outputs
      signal NextValidOut: std_ulogic;
      signal NextLastOut:  std_ulogic;
      signal NextOMUX:     OutChar_t;       
      signal NextReset:    std_ulogic;
      signal NextDone:     std_ulogic;
      signal NextEnableRD: std_ulogic;
      signal NextCYC_O:    std_ulogic;
      signal NextSTB_O:    std_ulogic;
      signal NextWE_O:     std_ulogic;
      -- counter constants (check that the range of IntervalCount is big enough)
      constant MaxOutCharCount: Natural := 7; -- do not modify unless you completely checked version handling
      constant MaxResetCount:   Natural := 10; 
      constant MaxAckCount:     Natural := 15;
      constant MaxIntervalCount: unsigned(IntervalCount'range) := (others =>'1');
    begin
      assert (MaxOutCharCount<=MaxIntervalCount) and (MaxResetCount<=MaxIntervalCount)  and (MaxAckCount<=MaxIntervalCount)
        report "Range of IntervalCount is to small"
        severity failure;
      process(RST_I, State, DoWrite, DoRead, DoVersion, DoReset, DoError, WaitOut, interrupt, IrChanged, ACK_I, IntervalCount)
      begin
        ShiftRD          <= '0';
        EnIntervalCount  <= '0';
        ClrIntervalCount <= '0';
        AcceptIr         <= '0';
        NextState        <= Error;
        if RST_I='1' then
          NextState <= Idle;
        else
          case State is
            when Idle =>
              if DoWrite='1' then
                NextState <= WB_Write;
                ClrIntervalCount <= '1';
              elsif DoRead='1' then
                NextState <= WB_Read;
                ClrIntervalCount <= '1';
              elsif DoVersion='1' then
                NextState <= VersionPut_v;
              elsif DoReset='1' then
                NextState <= ResetExecute;
                ClrIntervalCount <= '1';
              elsif DoError='1' then
                NextState <= ErrorFromInput;
              elsif interrupt='1' and IrChanged='1' then
                AcceptIr <= '1';
                NextState <= IrOn;
              elsif interrupt='0' and IrChanged='1' then
                AcceptIr <= '1';
                NextState <= IrOff;
              elsif DoWrite='0' or DoRead='0' or DoVersion='0' or DoReset='0' or DoError='0' or IrChanged='0' then
                NextState <= Idle;
              else
                NextState <= Error;
              end if;
            when WB_Write =>
              if (ACK_I='0') and (IntervalCount<MaxAckCount)then
                NextState <= WB_Write;
                EnIntervalCount  <= '1';
              elsif ACK_I='1' then
                NextState <= WrPut_w;
              else
                NextState <= AckError;
              end if;
            when WrPut_w =>
              if WaitOut='1' then
                NextState <= WrPut_w;
              elsif WaitOut='0' then
                NextState <= Put_Semicolon;
              else
                NextState <= Error;
              end if;
            when WB_Read =>
              if (ACK_I='0') and (IntervalCount<MaxAckCount) then
                NextState <= WB_Read;
                EnIntervalCount  <= '1';
              elsif ACK_I='1' then
                NextState <= RdPut_r;
              else
                NextState <= AckError;
              end if;
            when RdPut_r =>
              if WaitOut='1' then
                NextState <= RdPut_r;
              elsif WaitOut='0' then
                NextState <= RdPutData;
                ClrIntervalCount <= '1';
              else
                NextState <= Error;
              end if;
            when RdPutData =>
              if WaitOut='1' then
                NextState <= RdPutData;
              elsif (WaitOut='0') and (IntervalCount<MaxOutCharCount) then
                NextState <= RdPutData;
                EnIntervalCount  <= '1';
                ShiftRD         <= '1';
              elsif (WaitOut='0') and (IntervalCount=MaxOutCharCount) then
                NextState <= Put_Semicolon;
              else
                NextState <= Error;
              end if;
            when VersionPut_v =>
              if WaitOut='1' then
                NextState <= VersionPut_v;
              elsif WaitOut='0' then
                NextState <= VersionPutString;
                ClrIntervalCount <= '1';
              else
                NextState <= Error;
              end if;
            when VersionPutString =>
              if WaitOut='1' then
                NextState <= VersionPutString;
              elsif (WaitOut='0') and (IntervalCount<MaxOutCharCount) then
                NextState <= VersionPutString;
                EnIntervalCount  <= '1';
              elsif (WaitOut='0') and (IntervalCount=MaxOutCharCount) then
                NextState <= Put_Semicolon;
              else
                NextState <= Error;
              end if;
            when ResetExecute =>
              if (IntervalCount<MaxResetCount) then
                NextState <= ResetExecute;
                EnIntervalCount  <= '1';
              else 
                NextState <= ResetPut_r;
              end if;
            when ResetPut_r =>
              if WaitOut='1' then
                NextState <= ResetPut_r;
              elsif WaitOut='0' then
                NextState <= Put_Semicolon;
              else
                NextState <= Error;
              end if;
            when Put_Semicolon =>
              if WaitOut='1' then
                NextState <= Put_Semicolon;
              elsif WaitOut='0' then
                NextState <= Idle;
              else
                NextState <= Error;
              end if;
            when IrOn =>
              if WaitOut='1' then
                NextState <= IrOn;
              elsif WaitOut='0' then
                NextState <= Put_Semicolon;
              else
                NextState <= Error;
              end if;
            when IrOff =>
              if WaitOut='1' then
                NextState <= IrOff;
              elsif WaitOut='0' then
                NextState <= Put_Semicolon;
              else
                NextState <= Error;
              end if;
            when ErrorFromInput =>
                NextState <= Error;
            when AckError =>  -- remain only one cycle in this state to output the "done" signal
              if WaitOut='1' then
                NextState <= Error;
              elsif WaitOut='0' then
                NextState <= Put_Semicolon;
              else
                NextState <= Error;
              end if;
            when Error =>
              if WaitOut='1' then
                NextState <= Error;
              elsif WaitOut='0' then
                NextState <= Put_Semicolon;
              else
                NextState <= Error;
              end if;
          end case;
        end if;
      end process;
      
      Compute_Next_Moore_Outputs: process (NextState)
      begin
        NextValidOut <= '0';
        NextLastOut  <= '0';
        NextOMUX     <= None;
        NextReset    <= '0';
        NextDone     <= '0';
        NextEnableRD <= '0';
        NextCYC_O    <= '0';
        NextSTB_O    <= '0';
        NextWE_O     <= '0';
        case(NextState) is
          when Idle =>
            null;
          when WB_Write =>
            NextCYC_O    <= '1';
            NextSTB_O    <= '1';
            NextWE_O     <= '1';
          when WrPut_w =>
            NextValidOut <= '1';
            NextOMUX     <= Wr; 
            NextDone     <= '1';
          when WB_Read =>
            NextEnableRD <= '1';
            NextCYC_O    <= '1';
            NextSTB_O    <= '1';
          when RdPut_r =>
            NextValidOut <= '1';
            NextOMUX     <= Rd;
            NextDone     <= '1';
          when RdPutData =>
            NextValidOut <= '1';
            NextOMUX     <= Digit;
          when VersionPut_v =>
            NextValidOut <= '1';
            NextOMUX     <= Ver;
            NextDone     <= '1';
          when VersionPutString =>
            NextValidOut <= '1';
            NextOMUX     <= VerChar;
          when ResetExecute =>
            NextReset    <= '1';
          when ResetPut_r =>
            NextValidOut <= '1';
            NextOMUX     <= Rst;
            NextDone     <= '1';
          when Put_Semicolon =>
            NextValidOut <= '1';
            NextLastOut  <= '1';
            NextOMUX     <= Semicolon;
          when IrOn =>
            NextValidOut <= '1';
            NextOMUX     <= IrOn;
          when IrOff =>
            NextValidOut <= '1';
            NextOMUX     <= IrOff;
          when ErrorFromInput =>
            NextDone     <= '1';
          when AckError =>
            NextValidOut <= '1';
            NextOMUX     <= Error;
            NextDone     <= '1';
          when Error =>
            NextValidOut <= '1';
            NextOMUX     <= Error;
        end case;
      end process;
      
      Compute_new_State_and_Moore_Outputs:
      process (CLK_I)
      begin
        if rising_edge(CLK_I) then
          -- State register
          State    <= NextState;
          -- Mealy Registers
          ValidOut <= NextValidOut;
          LastOut  <= NextLastOut;
          OMUX     <= NextOMUX;
          Reset_i  <= NextReset;
          Done     <= NextDone;
          EnableRD <= NextEnableRD;
          STB_O_i  <= NextSTB_O;
          WE_O     <= NextWE_O;
        end if;
      end process;

    end block; -- ControlPath
  end block; -- Output_Unit
end arch;