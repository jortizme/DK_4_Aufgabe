-- Wishbone Slave Address Range:
--
-- 0x000 – 0x07F GPR $0-$31
-- 0x080         cp0 status register
-- 0x084         lo
-- 0x088         hi
-- 0x08C         reserved (bad)
-- 0x090         cp0 cause register
-- 0x094         program counter
-- 0x098 – 0x117 reserved ($f0-$f31)
-- 0x118         reserved (fsr)
-- 0x11C         reserved (fir)
-- 0x120         reserved (fp)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bsr2_processor_core is
    generic (
        Reset_Vector : std_logic_vector(31 downto 0);
        AdEL_Vector  : std_logic_vector(31 downto 0);
        AdES_Vector  : std_logic_vector(31 downto 0);
        Sys_Vector   : std_logic_vector(31 downto 0);
        RI_Vector    : std_logic_vector(31 downto 0);
        IP0_Vector   : std_logic_vector(31 downto 0);
        IP2_Vector   : std_logic_vector(31 downto 0);
        IP3_Vector   : std_logic_vector(31 downto 0);
        IP4_Vector   : std_logic_vector(31 downto 0);
        DELAY_SLOT   : boolean
    );
    port(
        -- Clock and Reset
        CLK_I  : in  std_logic;
        RST_I  : in  std_logic;

        -- Wishbone Master Interface
        STB_O  : out std_logic;
        WE_O   : out std_logic;
        ADR_O  : out std_logic_vector(31 downto 0);
        SEL_O  : out std_logic_vector( 3 downto 0);
        ACK_I  : in  std_logic;
        DAT_O  : out std_logic_vector(31 downto 0);
        DAT_I  : in  std_logic_vector(31 downto 0);

        -- Interrupt Requests
        IP2    : in  std_logic;
        IP3    : in  std_logic;
        IP4    : in  std_logic;

        -- Wishbone Slave Interface (Debug)
        DBG_STB_I  : in  std_logic;
        DBG_WE_I   : in  std_logic;
        DBG_ADR_I  : in  std_logic_vector(31 downto 0);
        DBG_ACK_O  : out std_logic;
        DBG_DAT_I  : in  std_logic_vector(31 downto 0);
        DBG_DAT_O  : out std_logic_vector(31 downto 0);

        -- Debug signals
        step_valid : in  std_logic;
        step_ready : out std_logic;
        trap       : out std_logic
    );
end entity;

architecture behavioral of bsr2_processor_core is
    type Bus_Addr_T       is (Sel_PC, Sel_Reg);
    type Bus_WordLen_T    is (Sel_Byte, Sel_Halfword, Sel_Word);

    type Reg_WrData_T     is (Sel_ALU, Sel_Bus, Sel_PC, Sel_CP0, Sel_Hi, Sel_Lo);
    type Reg_WrAddr_T     is (Sel_rd, Sel_rt, Sel_r31);

    type ALU_Op1_T        is (Sel_RDs, Sel_Sixteen, Sel_SA);
    type ALU_Op2_T        is (Sel_RDt, Sel_Immediate, Sel_Zero);
    type ALU_Func_T       is (Sel_NOP, Sel_ADD, Sel_SUB, Sel_AND, Sel_OR, Sel_XOR, Sel_SLL, Sel_SRL, Sel_SRA, Sel_NOR, Sel_LTS, Sel_LTU);

    type PC_Sel_T         is (Sel_Keep, Sel_Increment, Sel_Decrement, Sel_Branch, Sel_JumpReg, Sel_JumpInst, Sel_Exception, Sel_EPC);

    type Extend_T         is (Sel_Zero, Sel_Sign);

    type Instructions_T   is (
        -- Arithmetic Logic Unit
        Inst_ADD, Inst_ADDI, Inst_ADDIU, Inst_ADDU, Inst_AND, Inst_ANDI, Inst_LUI, Inst_NOR, Inst_OR, Inst_ORI, Inst_SLT, Inst_SLTI, Inst_SLTIU, Inst_SLTU, Inst_SUB, Inst_SUBU, Inst_XOR, Inst_XORI,
        -- Shifter
        Inst_SLL, Inst_SLLV, Inst_SRA, Inst_SRAV, Inst_SRL, Inst_SRLV,
        -- Multiply
        Inst_DIV, Inst_DIVU, Inst_MFHI, Inst_MFLO, Inst_MTHI, Inst_MTLO, Inst_MULT, Inst_MULTU,
        -- Branch
        Inst_BEQ, Inst_BGEZ, Inst_BGEZAL, Inst_BGTZ, Inst_BLEZ, Inst_BLTZ, Inst_BLTZAL, Inst_BNE, Inst_J, Inst_JAL, Inst_JALR, Inst_JR,
        -- Memory Access
        Inst_LB, Inst_LBU, Inst_LH, Inst_LHU, Inst_LW, Inst_SB, Inst_SH, Inst_SW,
        -- Special
        Inst_MFC0, Inst_MTC0, Inst_SYSCALL, Inst_ERET, Inst_EI, Inst_DI, Inst_BREAK, Inst_Illegal
    );
                            
    type Lo_Hi_t          is (Sel_Mult, Sel_Div, Sel_ALU);

    constant ExcCode_Int  : std_logic_vector(4 downto 0) := "00000"; -- Interrupt
    constant ExcCode_AdEL : std_logic_vector(4 downto 0) := "00100"; -- Address error exception (load or instruction fetch)
    constant ExcCode_AdES : std_logic_vector(4 downto 0) := "00101"; -- Address error exception (store)
    constant ExcCode_Sys  : std_logic_vector(4 downto 0) := "01000"; -- Syscall exception
    constant ExcCode_RI   : std_logic_vector(4 downto 0) := "01010"; -- Reserved instruction exception

    signal Prefetch       : std_logic_vector(31 downto 0) := (others=>'0'); -- Prefetch Instruction Register; Start with NOP after reset
    signal Instruction    : std_logic_vector(31 downto 0) := (others=>'0'); -- Instruction Register; Start with NOP after reset

    signal Inst_En        : std_logic;
    signal Reg_WE         : std_logic := '0';
    signal Reg_RE         : std_logic := '0';
    signal Reg_WrAddr     : Reg_WrAddr_T;
    signal Reg_WrData     : Reg_WrData_T;
    signal Bus_WordLen    : Bus_WordLen_T;
    signal Bus_Extend     : Extend_T;
    signal Sign_Extend    : std_logic;
    signal ALU_Op2        : ALU_Op2_T;
    signal ALU_Func       : ALU_Func_T;
    signal ALU_Op1        : ALU_Op1_T;
    signal Bus_Addr       : Bus_Addr_T := Sel_PC;

    signal Op1_equ_Op2    : std_logic;
    signal OP1_lts_Op2    : std_logic;

    signal Start_Div      : std_logic := '0';
    signal Div_Done       : std_logic;
    signal Start_Mult     : std_logic := '0';
    signal Mult_Done      : std_logic;
    signal Signed_Op      : std_logic;

    signal EX_Enter       : std_logic;
    signal EX_Leave       : std_logic;
    signal IR_Enable      : std_logic;
    signal IR_Disable     : std_logic;
    signal Interrupt      : std_logic;

    signal PC_Sel         : PC_Sel_T;

    signal Set_ExcCode    : std_logic;
    signal The_ExcCode    : std_logic_vector(4 downto 0);
    signal CP0_Write      : std_logic;
    signal EXL            : std_logic := '0';
    signal IP0            : std_logic := '0';
    signal ExcCode        : std_logic_vector(4 downto 0);
    signal Err_Align      : std_logic;

    signal Hi_WE          : std_logic;
    signal Lo_WE          : std_logic;
    signal HiLo_Sel       : Lo_Hi_t;
    
    signal trap_i         : std_logic := '0';  

    -- Instruction fields
    signal immediate      : std_logic_vector(15 downto 0);
    signal rd             : std_logic_vector(4 downto 0);
    signal rs             : std_logic_vector(4 downto 0);
    signal rt             : std_logic_vector(4 downto 0);
    signal sa             : std_logic_vector(4 downto 0);
    signal target         : std_logic_vector(25 downto 0);

    signal Ex_offset      : signed(31 downto 0);

    signal PC             : std_logic_vector(31 downto 0) := Reset_Vector;
    signal Dec_Instr      : Instructions_T;

    -- synthesis translate off
    function regname(r : std_logic_vector(4 downto 0)) return string is
        variable ri: integer range 0 to 31 := to_integer(unsigned(r));
    begin
        case ri is
            when  0 => return "$zero"; when  1 => return "$at"; when  2 => return "$v0"; when  3 => return "$v1";
            when  4 => return "$a0";   when  5 => return "$a1"; when  6 => return "$a2"; when  7 => return "$a3";
            when  8 => return "$t0";   when  9 => return "$t1"; when 10 => return "$t2"; when 11 => return "$t3";
            when 12 => return "$t4";   when 13 => return "$t5"; when 14 => return "$t6"; when 15 => return "$s7";
            when 16 => return "$s0";   when 17 => return "$s1"; when 18 => return "$s2"; when 19 => return "$s3";
            when 20 => return "$s4";   when 21 => return "$s5"; when 22 => return "$s6"; when 23 => return "$s7";
            when 24 => return "$t8";   when 25 => return "$t9"; when 26 => return "$k0"; when 27 => return "$k1";
            when 28 => return "$gp";   when 29 => return "$sp"; when 30 => return "$fp"; when 31 => return "$ra";
        end case;
    end function;

    function regname(r : natural) return string is
    begin
    return regname(std_logic_vector(to_unsigned(r, 5)));
    end function;
    -- synthesis translate on

begin
    ---------------------------------------------------------------------------
    -- Data Path
    ---------------------------------------------------------------------------
    DataPath: block
        -- Lo and Hi registers
        signal lo            : std_logic_vector(31 downto 0) := x"00000000";
        signal hi            : std_logic_vector(31 downto 0) := x"00000000";

        -- Debug bus signals
        signal gpr_stb_i     : std_logic;
        signal gpr_dat_o     : std_logic_vector(31 downto 0);
        signal gpr_ack_o     : std_logic;
        signal pc_stb_i      : std_logic;
        signal sr_stb_i      : std_logic;
        signal cr_stb_i      : std_logic;
        signal lo_stb_i      : std_logic;
        signal hi_stb_i      : std_logic;

        -- Data Path signals
        signal RDs           : std_logic_vector(31 downto 0);
        signal RDt           : std_logic_vector(31 downto 0);
        signal CP0_Data      : std_logic_vector(31 downto 0);
        signal Bus_Data      : std_logic_vector(31 downto 0);
        signal ALU_Result    : unsigned(31 downto 0);
        signal mult_product  : std_logic_vector(63 downto 0);
        signal div_quotient  : std_logic_vector(31 downto 0);
        signal div_remainder : std_logic_vector(31 downto 0);

        -- Bus signals
        signal ADR_O_i    : std_logic_vector(31 downto 0);

        -- Interrupt handling signals
        signal sr            : std_logic_vector(31 downto 0);
        signal cr            : std_logic_vector(31 downto 0);
        signal IE            : std_logic := '0';
        signal IM0           : std_logic := '0';
        signal IM2           : std_logic := '0';
        signal IM3           : std_logic := '0';
        signal IM4           : std_logic := '0';
        signal EPC_Write     : std_logic := '0';
        signal EPC           : std_logic_vector(31 downto 0) := (others=>'-');
    begin
        trap <= trap_i;

        ---------------------------------------------------------------------------
        -- Wishbone Slave for Debugger Access
        ---------------------------------------------------------------------------
        wb_slave: block
            signal ack_read_regs  : std_logic := '0';
        begin
            mux: process(dbg_stb_i, dbg_adr_i, dbg_we_i, gpr_ack_o, gpr_dat_o, sr, lo, hi, cr, pc) is
                variable dbg_adr    : unsigned(11 downto 0);
            begin
                gpr_stb_i <= '0';
                sr_stb_i  <= '0';
                lo_stb_i  <= '0';
                hi_stb_i  <= '0';
                cr_stb_i  <= '0';
                pc_stb_i  <= '0';

                dbg_adr := unsigned(dbg_adr_i(11 downto 0));

                if    dbg_adr <= 16#07f# then
                    gpr_stb_i <= dbg_stb_i;
                    dbg_dat_o <= gpr_dat_o;
                    if dbg_we_i = '0' then
                        dbg_ack_o <= gpr_ack_o;
                    else
                        dbg_ack_o <= dbg_stb_i;
                    end if;
                elsif dbg_adr = 16#080# then
                    sr_stb_i  <= dbg_stb_i;
                    dbg_dat_o <= sr;
                    dbg_ack_o <= dbg_stb_i;
                elsif dbg_adr = 16#084# then
                    lo_stb_i  <= dbg_stb_i;
                    dbg_dat_o <= lo;
                    dbg_ack_o <= dbg_stb_i;
                elsif dbg_adr = 16#088# then
                    hi_stb_i  <= dbg_stb_i;
                    dbg_dat_o <= hi;
                    dbg_ack_o <= dbg_stb_i;
                elsif dbg_adr = 16#090# then
                    cr_stb_i  <= dbg_stb_i;
                    dbg_dat_o <= cr;
                    dbg_ack_o <= dbg_stb_i;
                elsif dbg_adr = 16#094# then
                    pc_stb_i  <= dbg_stb_i;
                    dbg_dat_o <= pc;
                    dbg_ack_o <= dbg_stb_i;
                else
                    dbg_dat_o <= x"ffffffff";
                    dbg_ack_o <= dbg_stb_i;
                end if;
            end process;

            gen_ack: process(CLK_I) is
            begin
                if rising_edge(CLK_I) then
                    gpr_ack_o <= '0';
                    if gpr_ack_o ='0' and gpr_stb_i = '1' and dbg_we_i = '0' then
                        gpr_ack_o <= '1';
                    end if;
                end if;
            end process;
        end block wb_slave;

        ---------------------------------------------------------------------------
        -- Instruction Register
        ---------------------------------------------------------------------------
        InstReg: process(CLK_I)
        begin
            if rising_edge(CLK_I) then
                if RST_I = '1' then
                    Prefetch    <= (others=>'0');
                    Instruction <= (others=>'0');
                elsif Inst_En='1' then 
                    if DELAY_SLOT then
                        Prefetch    <= DAT_I; 
                        Instruction <= Prefetch; 
                    else
                        Instruction <= DAT_I;
                    end if;
                end if;
            end if;
        end process;

        -- instruction code fields
        immediate <= Instruction(15 downto 0);
        rd        <= Instruction(15 downto 11);
        rs        <= Instruction(25 downto 21);
        rt        <= Instruction(20 downto 16);
        sa        <= Instruction(10 downto 6);
        target    <= Instruction(25 downto 0);

        ---------------------------------------------------------------------------
        -- Registers
        ---------------------------------------------------------------------------
        Registers: block    
            type regs_t is array(natural range <>) of std_logic_vector(31 downto 0);
            
            signal regs : regs_t(0 to 31) := (others=>x"00000000");
            signal WA   : std_logic_vector(4 downto 0);
            signal WD   : std_logic_vector(31 downto 0);    
        begin
        -- synthesis translate off
        process(EXL, regs)
            variable stored_regs : regs_t(0 to 31);
        begin
            if rising_edge(EXL) then
            stored_regs := regs;
            elsif falling_edge(EXL) then
            for i in regs'range loop
                assert stored_regs(i) = regs(i) report regname(i) & " wurde im Interrupt-Handler veraendert!" severity warning;
            end loop;
            end if;
        end process;
        -- synthesis translate on
    
        -- Write Address MUX
        WA_Mux: process(Reg_WrAddr, rt, rd)
        begin
            case Reg_WrAddr is
            when Sel_rt  => WA <= rt;
            when Sel_rd  => WA <= rd;
            when Sel_r31 => WA <= "11111";
            end case;
        end process;
    
        -- Write Data MUX
        WD_Mux: process(Reg_WrData, ALU_Result, Bus_Data, PC, CP0_Data, hi, lo)
        begin
            case Reg_WrData is
            when Sel_ALU => WD <= std_logic_vector(ALU_Result);
            when Sel_Bus => WD <= Bus_Data;
            when Sel_PC  => WD <= std_logic_vector(PC);
            when Sel_CP0 => WD <= CP0_Data;
            when Sel_Hi  => WD <= hi;
            when Sel_Lo  => WD <= lo;
            end case;
        end process;
    
        rd_proc: process(CLK_I) is
            variable addr : integer range regs'low to regs'high;
        begin
            if rising_edge(CLK_I) then
            if gpr_stb_i = '1' and dbg_we_i = '1' then
                addr := to_integer(unsigned(DBG_ADR_I(6 downto 2)));
                if addr > 0 then -- don't write to $zero
                regs(addr) <= DBG_DAT_I;
                end if;
            elsif Reg_WE = '1' then
                addr := to_integer(unsigned(WA));
                if addr > 0 then -- don't write to $zero
                regs(addr) <= WD;
                end if;
            end if;
            end if;
        end process;
    
        rs_proc: process(CLK_I) is
            variable addr : integer range regs'low to regs'high;
        begin
            if rising_edge(CLK_I) then
            if gpr_stb_i = '1' and dbg_we_i = '0' then
                addr := to_integer(unsigned(DBG_ADR_I(6 downto 2)));
                gpr_dat_o <= regs(addr);
            elsif Reg_RE = '1' then
                addr := to_integer(unsigned(rs));
                RDs <= regs(addr);
            end if;
            end if;
        end process;
    
        -- read port "rt"
        rt_proc: process(CLK_I) is
            variable addr : integer range regs'low to regs'high;
        begin
            if rising_edge(CLK_I) then
            if Reg_RE = '1' then
                addr := to_integer(unsigned(rt));
                RDt <= regs(addr);
            end if;
            end if;
        end process;
        end block registers;

        -- Lo and Hi Registers
        lo_hi_reg: process(CLK_I) is
        begin
            if rising_edge(CLK_I) then
                if RST_I = '1' then
                    hi <= x"00000000";
                    lo <= x"00000000";
                else
                    if (hi_stb_i = '1' and dbg_we_i = '1') then
                        hi <= dbg_dat_i;
                    elsif Hi_WE = '1' then
                        case HiLo_Sel is
                            when Sel_Mult =>
                                hi <= mult_product(63 downto 32);
                            when Sel_Div  =>
                                hi <= div_remainder;
                            when Sel_ALU =>
                                hi <= std_logic_vector(ALU_Result);
                        end case;
                    end if;
                    
                    if (lo_stb_i = '1' and dbg_we_i = '1') then
                        lo <= dbg_dat_i;
                    elsif Lo_WE = '1' then
                        case HiLo_Sel is
                            when Sel_Mult =>
                                lo <= mult_product(31 downto 0);
                            when Sel_Div  =>
                                lo <= div_quotient;
                            when Sel_ALU =>
                                lo <= std_logic_vector(ALU_Result);
                        end case;
                    end if;
                end if;
            end if;
        end process;

        ---------------------------------------------------------------------------
        -- Extend
        ---------------------------------------------------------------------------
        Extend: process(Immediate, Sign_Extend)
        begin
            Ex_offset(15 downto 0) <= signed(Immediate);
            if    Sign_Extend = '0' then
                Ex_offset(31 downto 16) <= (31 downto 16 => '0');
            else
                Ex_offset(31 downto 16) <= (31 downto 16 => Immediate(15));
            end if;
        end process;

        ---------------------------------------------------------------------------
        -- ALU
        ---------------------------------------------------------------------------
        ALU: block
            signal OP1 : unsigned(31 downto 0);
            signal OP2 : unsigned(31 downto 0);
        begin
            PrepareOPs: process(Ex_offset, RDt, RDs, ALU_Op1, ALU_Op2, sa)
            begin
            case ALU_OP1 is
                when Sel_RDs     =>
                OP1 <= unsigned(RDs);
    
                when Sel_Sixteen =>
                OP1 <= to_unsigned(16, OP1'length);
                
                when Sel_SA =>
                OP1 <= unsigned(x"000000" & "000" & sa);
            end case;
    
            case ALU_OP2 is
                when Sel_RDt =>
                OP2 <= unsigned(RDt);
    
                when Sel_Immediate =>
                OP2 <= unsigned(Ex_offset);
    
                when Sel_Zero =>
                OP2 <= to_unsigned(0, OP2'length);
            end case;
            end process;
    
            Calculate: process(OP1, OP2, ALU_Func)
                variable Op1_equ_Op2_v : std_logic;
                variable Op1_lts_Op2_v : std_logic;
                variable Op1_ltu_Op2_v : std_logic;
            begin
                if Op1           = Op2           then Op1_equ_Op2_v := '1'; else Op1_equ_Op2_v := '0'; end if;
                if signed(Op1)   < signed(Op2)   then OP1_lts_Op2_v := '1'; else Op1_lts_Op2_v := '0'; end if;
                if unsigned(Op1) < unsigned(Op2) then OP1_ltu_Op2_v := '1'; else Op1_ltu_Op2_v := '0'; end if;
                
                -- output results for use in conditional branches
                Op1_equ_Op2 <= Op1_equ_Op2_v;
                OP1_lts_Op2 <= Op1_lts_Op2_v;
                
                case ALU_Func is
                    when Sel_ADD => ALU_Result <= OP1 + OP2;
                    when Sel_SUB => ALU_Result <= OP1 - OP2;
                    when Sel_AND => ALU_Result <= OP1 and OP2;
                    when Sel_OR  => ALU_Result <= OP1 or OP2;
                    when Sel_XOR => ALU_Result <= OP1 xor OP2;
                    when Sel_SLL => ALU_Result <= SHIFT_LEFT(OP2, to_integer(OP1(4 downto 0)));
                    when Sel_SRL => ALU_Result <= SHIFT_RIGHT(OP2, to_integer(OP1(4 downto 0)));
                    when Sel_SRA => ALU_Result <= unsigned(SHIFT_RIGHT(signed(OP2), to_integer(OP1(4 downto 0))));
                    when Sel_NOR => ALU_Result <= OP1 nor OP2;
                    when Sel_LTS => if OP1_lts_Op2_v = '1'
                                    then ALU_Result <= to_unsigned(1, ALU_Result'length);
                                    else ALU_Result <= to_unsigned(0, ALU_Result'length);
                                    end if;
                    when Sel_LTU => if OP1_ltu_Op2_v = '1' 
                                    then ALU_Result <= to_unsigned(1, ALU_Result'length);
                                    else ALU_Result <= to_unsigned(0, ALU_Result'length);
                                    end if;
                    when Sel_NOP => ALU_Result <= (others=>'-');
                end case;            
            end process;
            
            mult: entity work.mult
            generic map (
                N         => 32,
                STAGES    => 0
            )
            port map (
                clk       => CLK_I,
                start     => start_mult,
                done      => Mult_Done,
                signs     => Signed_Op,
                factor_a  => RDs,
                factor_b  => RDt,
                product   => mult_product
            );
            
            div: entity work.div
            generic map (
                N         => 32
            )
            port map (
                clk       => CLK_I,
                start     => start_div,
                done      => div_done,
                signs     => Signed_Op,
                dividend  => RDs,
                divisor   => RDt,
                quotient  => div_quotient,
                remainder => div_remainder
            );
        end block;

        ---------------------------------------------------------------------------
        -- Bus
        ---------------------------------------------------------------------------
        ADR_O <= ADR_O_i(31 downto 2) & "00";

        Align_and_Sign_Extend: process (Bus_WordLen, ADR_O_i(1 downto 0), Bus_Extend, DAT_I)
          variable ExtendedValue : std_logic_vector(31 downto 0);
        begin
          Err_Align <= '0';

          case Bus_WordLen is
            when Sel_Byte  =>
              -- byte placement
              case ADR_O_i(1 downto 0) is
                when "00"   => ExtendedValue(7 downto 0) := DAT_I( 7 downto  0);
                when "01"   => ExtendedValue(7 downto 0) := DAT_I(15 downto  8);
                when "10"   => ExtendedValue(7 downto 0) := DAT_I(23 downto 16);
                when "11"   => ExtendedValue(7 downto 0) := DAT_I(31 downto 24);
                when others => ExtendedValue(7 downto 0) := (others=>'-');
              end case;

              -- extension
              if    Bus_Extend = Sel_Zero then ExtendedValue(31 downto 8) := (others=>'0');              -- Zero Extend
              elsif Bus_Extend = Sel_Sign then ExtendedValue(31 downto 8) := (others=>ExtendedValue(7)); -- Sign extend
              end if;

            when Sel_Halfword =>
              -- halfword placement
              case ADR_O_i(1) is
                when '0'    => ExtendedValue(15 downto 0) := DAT_I(15 downto  0);
                when '1'    => ExtendedValue(15 downto 0) := DAT_I(31 downto 16);
                when others => ExtendedValue(15 downto 0) := (others=>'-');
              end case;

              -- extension
              if    Bus_Extend = Sel_Zero then ExtendedValue(31 downto 16) := (others=>'0');               -- Zero Extend
              elsif Bus_Extend = Sel_Sign then ExtendedValue(31 downto 16) := (others=>ExtendedValue(15)); -- Sign extend
              end if;

              -- check alignment
              if ADR_O_i(0 downto 0) /= "0" then Err_Align <= '1'; end if;

            when Sel_Word  =>
              ExtendedValue := DAT_I;

              -- check alignment
              if ADR_O_i(1 downto 0) /= "00" then Err_Align <= '1'; end if;
          end case;

          Bus_Data <= ExtendedValue;
        end process;

        Generate_Select: process(Bus_WordLen, ADR_O_i(1 downto 0))
        begin
          case Bus_WordLen is
            when Sel_Byte  =>
              case ADR_O_i(1 downto 0) is
                when "00"   => SEL_O <= "0001";
                when "01"   => SEL_O <= "0010";
                when "10"   => SEL_O <= "0100";
                when "11"   => SEL_O <= "1000";
                when others => SEL_O <= "----";
              end case;

            when Sel_Halfword =>
              case ADR_O_i(1) is
                when '0'    => SEL_O <= "0011";
                when '1'    => SEL_O <= "1100";
                when others => SEL_O <= "----";
              end case;

            when Sel_Word  =>
              SEL_O <= "1111";
          end case;
        end process;

        Place_in_Word: process(Bus_WordLen, ADR_O_i(1 downto 0), RDt)
        begin
          case Bus_WordLen is
            when Sel_Byte  =>
              case ADR_O_i(1 downto 0) is
                when "00"   => DAT_O <= x"000000" & RDt(7 downto 0);
                when "01"   => DAT_O <= x"0000" & RDt(7 downto 0) & x"00";
                when "10"   => DAT_O <= x"00" & RDt(7 downto 0) & x"0000";
                when "11"   => DAT_O <= RDt(7 downto 0) & x"000000";
                when others => DAT_O <= (others=>'-');
              end case;

            when Sel_Halfword =>
              case ADR_O_i(1) is
                when '0'    => DAT_O <= x"0000" & RDt(15 downto 0);
                when '1'    => DAT_O <= RDt(15 downto 0) & x"0000";
                when others => DAT_O <= (others=>'-');
              end case;

            when Sel_Word  =>
              DAT_O <= RDt;
          end case;
        end process;

        Examine_OutputAddress: process(RDs, Ex_offset, Bus_Addr, PC)
        begin

          if    Bus_Addr = Sel_Reg then ADR_O_i <= std_logic_vector(signed(RDs) + signed(Ex_offset));
          elsif Bus_Addr = Sel_PC  then ADR_O_i <= std_logic_vector(PC);
          end if;
        end process;

        ---------------------------------------------------------------------------
        -- Program Counter and Exception Handling
        ---------------------------------------------------------------------------
        PC_and_Exceptions: block
          signal Exception_Vector : std_logic_vector(31 downto 0) := (others=>'-');
        begin
          FF: process(CLK_I)
          begin
            if rising_edge(CLK_I) then
              if RST_I = '1' then
                EXL <= '0';
                IE  <= '0';
              else
                if    EX_Enter = '1' then EXL <= '1';
                elsif EX_Leave = '1' then EXL <= '0';
                end if;

                if    IR_Enable  = '1' then IE <= '1';
                elsif IR_Disable = '1' then IE <= '0';
                end if;
              end if;
            end if;
          end process;

          Vectored_Interrupt: process(EXL, IE, IP0, IP2, IP3, IP4, IM0, IM2, IM3, IM4, ExcCode)
            variable active_interrupts : std_logic_vector(3 downto 0);
          begin
            active_interrupts(0) := IP0 and IM0;
            active_interrupts(1) := IP2 and IM2;
            active_interrupts(2) := IP3 and IM3;
            active_interrupts(3) := IP4 and IM4;

            if unsigned(active_interrupts) /= 0 and EXL = '0' and IE = '1' then
              Interrupt <= '1';
            else
              Interrupt <= '0';
            end if;

            case ExcCode is
              when ExcCode_AdEL =>
                Exception_Vector <= AdEL_Vector;

              when ExcCode_AdES =>
                Exception_Vector <= AdES_Vector;

              when ExcCode_Sys  =>
                Exception_Vector <= Sys_Vector;

              when ExcCode_RI   =>
                Exception_Vector <= RI_Vector;

              when ExcCode_Int  =>
                if    active_interrupts(0) = '1' then Exception_Vector <= IP0_Vector;
                elsif active_interrupts(1) = '1' then Exception_Vector <= IP2_Vector;
                elsif active_interrupts(2) = '1' then Exception_Vector <= IP3_Vector;
                elsif active_interrupts(3) = '1' then Exception_Vector <= IP4_Vector;
                else                                  Exception_Vector <= (others=>'-');
                end if;

              when others =>
                Exception_Vector <= (others=>'-');
            end case;
          end process;

          Program_Counter: process(CLK_I)
            variable extended_offset : signed(31 downto 0);
          begin
            if rising_edge(CLK_I) then
              if RST_I = '1' then
                EPC <= (others=>'0');
                PC  <= Reset_Vector;
              else
                if EX_Enter = '1' then
                  EPC <= std_logic_vector(PC);
                elsif EPC_Write = '1' then
                  EPC <= RDt;
                end if;

                case PC_Sel is
                  when Sel_Keep =>
                    null; -- don't alter the program counter

                  when Sel_Increment =>
                    PC <= std_logic_vector(signed(PC) + 4); -- fetch the next instruction

                  when Sel_Decrement =>
                    PC <= std_logic_vector(signed(PC) - 4); -- fetch the next instruction

                  when Sel_Branch =>
                    -- calculate the branch target from the offset indicated by the instruction
                    extended_offset := Ex_offset(29 downto 0) & "00";
                    PC <= std_logic_vector(signed(PC) + extended_offset);

                  when Sel_JumpReg =>
                    PC <= RDs; -- absolute jump to address from register

                  when Sel_JumpInst =>
                    PC <= PC(31 downto 28) & target & "00"; -- absolute jump to address from instruction

                  when Sel_Exception =>
                    PC <= Exception_Vector; -- In case of an exception, jump to the corresponding vector

                  when Sel_EPC =>
                    PC <= EPC; -- use the Exception Program Counter's value as jump target

                end case;

              end if;
            end if;
          end process;

        end block; -- PC_and_Exceptions

        ---------------------------------------------------------------------------
        -- Coprocessor 0
        ---------------------------------------------------------------------------
        Coprocessor0: block
          signal Status_Write : std_logic;
          signal Cause_Write  : std_logic;
        begin
          CP0_decoding: process(CP0_Write, rd)
          begin
            Status_Write <= '0';
            Cause_Write  <= '0';
            EPC_Write   <= '0';

            if CP0_Write = '1' then
              if    signed(rd) = 12 then Status_Write <= '1';
              elsif signed(rd) = 13 then Cause_Write  <= '1';
              elsif signed(rd) = 14 then EPC_Write    <= '1';
              end if;
            end if;
          end process;

          registers: process(CLK_I) is
          begin
            if rising_edge(CLK_I) then
              if RST_I = '1' then
                IM4    <= '0';
                IM3    <= '0';
                IM2    <= '0';
                IM0    <= '0';
                IP0    <= '0';
                ExcCode <= (others=>'0');
              else
                if sr_stb_i = '1' and dbg_we_i = '1' then
                  IM4 <= dbg_dat_i(12);
                  IM3 <= dbg_dat_i(11);
                  IM2 <= dbg_dat_i(10);
                  IM0 <= dbg_dat_i(8);
                elsif Status_Write = '1' then
                  IM4 <= RDt(12);
                  IM3 <= RDt(11);
                  IM2 <= RDt(10);
                  IM0 <= RDt(8);
                end if;

                if cr_stb_i = '1' and dbg_we_i = '1' then
                    IP0 <= dbg_dat_i(8);
                elsif Cause_Write = '1' then
                    IP0 <= RDt(8);
                end if;

                if Set_ExcCode = '1' then ExcCode <= The_ExcCode; end if;

              end if;
            end if;
          end process;

          sr <= x"0000" & "000" & IM4 & IM3 & IM2 & "0" & IM0 & "000000"     & EXL & IE;
          cr <= x"0000" & "000" & IP4 & IP3 & IP2 & "0" & IP0 & "0" & ExcCode & "00";

          CP0_mux: CP0_Data <=
            sr  when signed(rd) = 12 else
            cr  when signed(rd) = 13 else
            EPC when signed(rd) = 14 else
            (others=>'-');

        end block; -- Coprocessor0
    end block; -- DataPath

    ---------------------------------------------------------------------------
    -- Instruction Decoding
    ---------------------------------------------------------------------------
    Instruction_Decoding: process(Instruction)
      variable opcode : integer range 0 to 63;
      variable rs     : integer range 0 to 31;
      variable rt     : integer range 0 to 31;
      variable rd     : integer range 0 to 31;
      variable shamt  : integer range 0 to 31;
      variable funct  : integer range 0 to 63;
    begin
      Dec_Instr <= Inst_Illegal;
  
      opcode := to_integer(unsigned(Instruction(31 downto 26)));
      rs     := to_integer(unsigned(Instruction(25 downto 21)));
      rt     := to_integer(unsigned(Instruction(20 downto 16)));
      rd     := to_integer(unsigned(Instruction(15 downto 11)));
      shamt  := to_integer(unsigned(Instruction(10 downto 6)));
      funct  := to_integer(unsigned(Instruction(5 downto 0)));
  
        case opcode is
            when 0 => -- SPECIAL
            
              case funct is
                when  0 => Dec_Instr <= Inst_SLL;
                -- 1: MOVCI
                when  2 => Dec_Instr <= Inst_SRL;
                when  3 => Dec_Instr <= Inst_SRA;
                when  4 => Dec_Instr <= Inst_SLLV;
                -- 5: LSA
                when  6 => Dec_Instr <= Inst_SRLV;
                when  7 => Dec_Instr <= Inst_SRAV;
                when  8 => Dec_Instr <= Inst_JR;
                when  9 => Dec_Instr <= Inst_JALR;
                -- 10: MOVZ
                -- 11: MOVN
                when 12 => Dec_Instr <= Inst_SYSCALL;
                when 13 => Dec_Instr <= Inst_BREAK;
                -- 14: SDBBP
                -- 15: SYNC
                when 16 => Dec_Instr <= Inst_MFHI;
                when 17 => Dec_Instr <= Inst_MTHI;
                when 18 => Dec_Instr <= Inst_MFLO;
                when 19 => Dec_Instr <= Inst_MTLO;
                -- 20: RESERVED
                -- 21: RESERVED
                -- 22: RESERVED
                -- 23: RESERVED
                when 24 => Dec_Instr <= Inst_MULT;
                when 25 => Dec_Instr <= Inst_MULTU;
                when 26 => Dec_Instr <= Inst_DIV;
                when 27 => Dec_Instr <= Inst_DIVU;
                -- 28: RESERVED
                -- 29: RESERVED
                -- 30: RESERVED
                -- 31: RESERVED
                when 32 => Dec_Instr <= Inst_ADD;
                when 33 => Dec_Instr <= Inst_ADDU;
                when 34 => Dec_Instr <= Inst_SUB;
                when 35 => Dec_Instr <= Inst_SUBU;
                when 36 => Dec_Instr <= Inst_AND;
                when 37 => Dec_Instr <= Inst_OR;
                when 38 => Dec_Instr <= Inst_XOR;
                when 39 => Dec_Instr <= Inst_NOR;
                -- 40: RESERVED
                -- 41: RESERVED
                when 42 => Dec_Instr <= Inst_SLT;
                when 43 => Dec_Instr <= Inst_SLTU;
                -- 44: RESERVED
                -- 45: RESERVED
                -- 46: RESERVED
                -- 47: RESERVED
                -- 48: TGE
                -- 49: TGEU
                -- 50: TLT
                -- 51: TLTU
                -- 52: TEQ
                -- 53: SELEQZ
                -- 54: TNE
                -- 55: SELNEZ
                -- 56: RESERVED
                -- 57: RESERVED
                -- 58: RESERVED
                -- 59: RESERVED
                -- 60: RESERVED
                -- 61: RESERVED
                -- 62: RESERVED
                -- 63: RESERVED
                when others => null;
              end case;
            
            when  1 => -- REGIMM
              case rt is
                when  0 => Dec_Instr <= Inst_BLTZ;
                when  1 => Dec_Instr <= Inst_BGEZ;
                -- 2: BLTZL
                -- 3: BGEZL
                -- 4: RESERVED
                -- 5: RESERVED
                -- 6: DAHI
                -- 7: RESERVED
                -- 8: TGEI
                -- 9: TGEIU
                -- 10: TLTI
                -- 11: TLTIU
                -- 12: TEQI
                -- 13: RESERVED
                -- 14: TNEI
                -- 15: RESERVED
                when 16 => Dec_Instr <= Inst_BLTZAL;
                when 17 => Dec_Instr <= Inst_BGEZAL;
                -- 18: BLTZALL
                -- 19: BGEZALL
                -- 20: RESERVED
                -- 21: RESERVED
                -- 22: RESERVED
                -- 23: SIGRIE
                -- 24: RESERVED
                -- 25: RESERVED
                -- 26: RESERVED
                -- 27: RESERVED
                -- 28: RESERVED
                -- 29: RESERVED
                -- 30: DATI
                -- 31: SYNCI
                when others => null;
              end case;
            when  2 => Dec_Instr <= Inst_J;
            when  3 => Dec_Instr <= Inst_JAL;
            when  4 => Dec_Instr <= Inst_BEQ;
            when  5 => Dec_Instr <= Inst_BNE;
            when  6 => Dec_Instr <= Inst_BLEZ;
            when  7 => Dec_Instr <= Inst_BGTZ;
            when  8 => Dec_Instr <= Inst_ADDI;
            when  9 => Dec_Instr <= Inst_ADDIU;
            when 10 => Dec_Instr <= Inst_SLTI;
            when 11 => Dec_Instr <= Inst_SLTIU;
            when 12 => Dec_Instr <= Inst_ANDI;
            when 13 => Dec_Instr <= Inst_ORI;
            when 14 => Dec_Instr <= Inst_XORI;
            when 15 => Dec_Instr <= Inst_LUI;
            
            when 16 => -- COP0
              if Instruction(25) = '1' then -- rs = C0
                if funct = 24 then Dec_Instr <= Inst_ERET; end if;
              else
                case rs is
                  when  0 => Dec_Instr <= Inst_MFC0;
                  when  4 => Dec_Instr <= Inst_MTC0;
                  when 11 => -- MFMC0
                    if    Instruction(5) = '0' then Dec_Instr <= Inst_DI;
                    elsif Instruction(5) = '1' then Dec_Instr <= Inst_EI; end if;
                  when others => null;
                end case;
              end if;
            -- 17: COP1
            -- 18: COP2
            -- 19: COP3
            -- 20: BEQL
            -- 21: BNEL
            -- 22: BLEZL
            -- 23: BGTZL
            -- 24: RESERVED
            -- 25: RESERVED
            -- 26: RESERVED
            -- 27: RESERVED
            -- 28: SPECIAL2
            -- 29: JALX
            -- 30: MSA
            -- 31: SPECIAL3
            when 32 => Dec_Instr <= Inst_LB;
            when 33 => Dec_Instr <= Inst_LH;
            -- 34: LWL
            when 35 => Dec_Instr <= Inst_LW;
            when 36 => Dec_Instr <= Inst_LBU;
            when 37 => Dec_Instr <= Inst_LHU;
            -- 38: LWR
            -- 39: RESERVED
            when 40 => Dec_Instr <= Inst_SB;
            when 41 => Dec_Instr <= Inst_SH;
            -- 42: SWL
            when 43 => Dec_Instr <= Inst_SW;
            -- 44: RESERVED
            -- 45: RESERVED
            -- 46: SWR
            -- 47: CACHE
            -- 48: LL
            -- 49: LWC1
            -- 50: LWC2
            -- 51: PREF
            -- 52: RESERVED
            -- 53: LDC1
            -- 54: LDC2
            -- 55: RESERVED
            -- 56: SC
            -- 57: SWC1
            -- 58: SWC2
            -- 59: PCREL
            -- 60: RESERVED
            -- 61: SDC1
            -- 62: SDC2
            -- 63: RESERVED
            when others => null;
        end case;
    end process;

  ---------------------------------------------------------------------------
  -- Disassembler (for Simulation only)
  ---------------------------------------------------------------------------
  -- synthesis translate off
  DissBlock: block
    function hstr(slv: std_logic_vector) return string is
      constant hexlen  : integer := (slv'length + 3) / 4;
      variable longslv : std_logic_vector(4 * hexlen - 1 downto 0) := (others=>'0');
      variable hex     : string(1 to hexlen);
      variable nibble  : std_logic_vector(3 downto 0);
    begin
      longslv(slv'length - 1 downto 0) := slv;
      
      for i in (hexlen - 1) downto 0 loop
        nibble := longslv(((i * 4) + 3) downto (i * 4));
        case nibble is
          when "0000" => hex(hexlen - i) := '0';
          when "0001" => hex(hexlen - i) := '1';
          when "0010" => hex(hexlen - i) := '2';
          when "0011" => hex(hexlen - i) := '3';
          when "0100" => hex(hexlen - i) := '4';
          when "0101" => hex(hexlen - i) := '5';
          when "0110" => hex(hexlen - i) := '6';
          when "0111" => hex(hexlen - i) := '7';
          when "1000" => hex(hexlen - i) := '8';
          when "1001" => hex(hexlen - i) := '9';
          when "1010" => hex(hexlen - i) := 'A';
          when "1011" => hex(hexlen - i) := 'B';
          when "1100" => hex(hexlen - i) := 'C';
          when "1101" => hex(hexlen - i) := 'D';
          when "1110" => hex(hexlen - i) := 'E';
          when "1111" => hex(hexlen - i) := 'F';
          when "ZZZZ" => hex(hexlen - i) := 'z';
          when "UUUU" => hex(hexlen - i) := 'u';
          when "XXXX" => hex(hexlen - i) := 'x';
          when others => hex(hexlen - i) := '?';
        end case;
      end loop;
      return hex(1 to hexlen);
    end function;

    signal Diss_Inst       : string(1 to 32);
  begin
    DissProc: process(Dec_Instr, rs, rt, rd, immediate, Ex_offset, sa, target, pc)

      function expand(s:string; n:integer) return string is
        variable str: string(1 to n) := (others=>' ');
      begin
        for i in s'range loop
          exit when i>n;
          str(i) := s(i);
        end loop;
        return str;
      end expand;

    begin
      Diss_Inst <= (others=>' ');

      case Dec_Instr is
        -- arithmetic logic unit
        when Inst_ADD     => Diss_Inst <= expand("ADD "   & regname(rd) & ", " & regname(rs) & ", "      & regname(rt),            Diss_Inst'length);
        when Inst_ADDI    => Diss_Inst <= expand("ADDI "  & regname(rt) & ", " & regname(rs) & ", "      & integer'image(to_integer(signed(immediate))), Diss_Inst'length);
        when Inst_ADDIU   => Diss_Inst <= expand("ADDIU " & regname(rt) & ", " & regname(rs) & ", "      & integer'image(to_integer(signed(immediate))), Diss_Inst'length);
        when Inst_ADDU    => Diss_Inst <= expand("ADDU "  & regname(rd) & ", " & regname(rs) & ", "      & regname(rt),            Diss_Inst'length);
        when Inst_AND     => Diss_Inst <= expand("AND "   & regname(rd) & ", " & regname(rs) & ", "      & regname(rt),            Diss_Inst'length);
        when Inst_ANDI    => Diss_Inst <= expand("ANDI "  & regname(rt) & ", " & regname(rs) & ", "      & "0x" & hstr(immediate), Diss_Inst'length);
        when Inst_LUI     => Diss_Inst <= expand("LUI "   & regname(rt) & ", " & "0x" & hstr(immediate),                           Diss_Inst'length);
        when Inst_NOR     => Diss_Inst <= expand("NOR "   & regname(rd) & ", " & regname(rs) & ", "      & regname(rt),            Diss_Inst'length);
        when Inst_OR      => Diss_Inst <= expand("OR "    & regname(rd) & ", " & regname(rs) & ", "      & regname(rt),            Diss_Inst'length);
        when Inst_ORI     => Diss_Inst <= expand("ORI "   & regname(rt) & ", " & regname(rs) & ", "      & "0x" & hstr(immediate), Diss_Inst'length);
        when Inst_SLT     => Diss_Inst <= expand("SLT"    & regname(rd) & ", " & regname(rs) & ", "      & regname(rt),            Diss_Inst'length);
        when Inst_SLTI    => Diss_Inst <= expand("SLTI "  & regname(rt) & ", " & regname(rs) & ", "      & integer'image(to_integer(signed(immediate))), Diss_Inst'length);
        when Inst_SLTIU   => Diss_Inst <= expand("SLTIU"  & regname(rt) & ", " & regname(rs) & ", "      & integer'image(to_integer(unsigned(immediate))), Diss_Inst'length);
        when Inst_SLTU    => Diss_Inst <= expand("SLTU"   & regname(rd) & ", " & regname(rs) & ", "      & regname(rt),            Diss_Inst'length);
        when Inst_SUB     => Diss_Inst <= expand("SUB "   & regname(rd) & ", " & regname(rs) & ", "      & regname(rt),            Diss_Inst'length);
        when Inst_SUBU    => Diss_Inst <= expand("SUBU "  & regname(rd) & ", " & regname(rs) & ", "      & regname(rt),            Diss_Inst'length);
        when Inst_XOR     => Diss_Inst <= expand("XOR "   & regname(rd) & ", " & regname(rs) & ", "      & regname(rt),            Diss_Inst'length);
        when Inst_XORI    => Diss_Inst <= expand("XORI "  & regname(rt) & ", " & regname(rs) & ", "      & "0x" & hstr(immediate), Diss_Inst'length);
        
        -- shifter
        when Inst_SLL     => 
            if unsigned(rt) = 0 and unsigned(sa) = 0 then
                Diss_Inst <= expand("NOP", Diss_Inst'length);
            else
                Diss_Inst <= expand("SLL " & regname(rd) & ", " & regname(rt) & ", " & integer'image(to_integer(unsigned(sa))), Diss_Inst'length);
            end if;
        when Inst_SLLV    => Diss_Inst <= expand("SLLV "  & regname(rd) & ", " & regname(rt) & ", " & regname(rs),                             Diss_Inst'length);
        when Inst_SRA     => Diss_Inst <= expand("SRA "   & regname(rd) & ", " & regname(rt) & ", " & integer'image(to_integer(unsigned(sa))), Diss_Inst'length);
        when Inst_SRAV    => Diss_Inst <= expand("SRAV "  & regname(rd) & ", " & regname(rt) & ", " & regname(rs),                             Diss_Inst'length);
        when Inst_SRL     => Diss_Inst <= expand("SRL "   & regname(rd) & ", " & regname(rt) & ", " & integer'image(to_integer(unsigned(sa))), Diss_Inst'length);
        when Inst_SRLV    => Diss_Inst <= expand("SRLV "  & regname(rd) & ", " & regname(rt) & ", " & regname(rs),                             Diss_Inst'length);

        -- multiply
        when Inst_DIV     => Diss_Inst <= expand("DIV "   & regname(rs) & ", " & regname(rt), Diss_Inst'length);
        when Inst_DIVU    => Diss_Inst <= expand("DIVU "  & regname(rs) & ", " & regname(rt), Diss_Inst'length);
        when Inst_MFHI    => Diss_Inst <= expand("MFHI "  & regname(rd),                      Diss_Inst'length);
        when Inst_MFLO    => Diss_Inst <= expand("MFLO "  & regname(rd),                      Diss_Inst'length);
        when Inst_MTHI    => Diss_Inst <= expand("MTHI "  & regname(rd),                      Diss_Inst'length);
        when Inst_MTLO    => Diss_Inst <= expand("MTLO "  & regname(rd),                      Diss_Inst'length);
        when Inst_MULT    => Diss_Inst <= expand("MULT "  & regname(rs) & ", " & regname(rt), Diss_Inst'length);
        when Inst_MULTU   => Diss_Inst <= expand("MULTU " & regname(rs) & ", " & regname(rt), Diss_Inst'length);

        -- branch
        when Inst_BEQ     => Diss_Inst <= expand("BEQ "    & regname(rs) & ", " & regname(rt) & ", " & integer'image(4 * to_integer(Ex_offset)), Diss_Inst'length);
        when Inst_BGEZ    => Diss_Inst <= expand("BGEZ "   & regname(rs) & ", " & integer'image(4 * to_integer(Ex_offset)),                      Diss_Inst'length);
        when Inst_BGEZAL  => Diss_Inst <= expand("BGEZAL " & regname(rs) & ", " & integer'image(4 * to_integer(Ex_offset)),                      Diss_Inst'length);
        when Inst_BGTZ    => Diss_Inst <= expand("BGTZ "   & regname(rs) & ", " & integer'image(4 * to_integer(Ex_offset)),                      Diss_Inst'length);
        when Inst_BLEZ    => Diss_Inst <= expand("BLEZ "   & regname(rs) & ", " & integer'image(4 * to_integer(Ex_offset)),                      Diss_Inst'length);
        when Inst_BLTZ    => Diss_Inst <= expand("BLTZ "   & regname(rs) & ", " & integer'image(4 * to_integer(Ex_offset)),                      Diss_Inst'length);
        when Inst_BLTZAL  => Diss_Inst <= expand("BLTZAL " & regname(rs) & ", " & integer'image(4 * to_integer(Ex_offset)),                      Diss_Inst'length);
        when Inst_BNE     => Diss_Inst <= expand("BNE "    & regname(rs) & ", " & regname(rt) & ", " & integer'image(4 * to_integer(Ex_offset)), Diss_Inst'length);
        when Inst_J       => Diss_Inst <= expand("J "      & "0x" & hstr(pc(31 downto 28) & target & "00"),                                      Diss_Inst'length);
        when Inst_JAL     => Diss_Inst <= expand("JAL "    & "0x" & hstr(pc(31 downto 28) & target & "00"),                                      Diss_Inst'length);
        when Inst_JALR    => Diss_Inst <= expand("JALR "   & regname(rd) & ", " & regname(rs),                                                   Diss_Inst'length);
        when Inst_JR      => Diss_Inst <= expand("JR "     & regname(rs),                                                                        Diss_Inst'length);

        -- memory access
        when Inst_LB      => Diss_Inst <= expand("LB "    & regname(rt) & ", "   & integer'image(to_integer(Ex_offset))    & "(" & regname(rs) & ")", Diss_Inst'length);
        when Inst_LBU     => Diss_Inst <= expand("LBU "   & regname(rt) & ", "   & integer'image(to_integer(Ex_offset))    & "(" & regname(rs) & ")", Diss_Inst'length);
        when Inst_LH      => Diss_Inst <= expand("LH "    & regname(rt) & ", "   & integer'image(to_integer(Ex_offset))    & "(" & regname(rs) & ")", Diss_Inst'length);
        when Inst_LHU     => Diss_Inst <= expand("LHU "   & regname(rt) & ", "   & integer'image(to_integer(Ex_offset))    & "(" & regname(rs) & ")", Diss_Inst'length);
        when Inst_LW      => Diss_Inst <= expand("LW "    & regname(rt) & ", "   & integer'image(to_integer(Ex_offset))    & "(" & regname(rs) & ")", Diss_Inst'length);
        when Inst_SB      => Diss_Inst <= expand("SB "    & regname(rt) & ", "   & integer'image(to_integer(Ex_offset))    & "(" & regname(rs) & ")", Diss_Inst'length);
        when Inst_SH      => Diss_Inst <= expand("SH "    & regname(rt) & ", "   & integer'image(to_integer(Ex_offset))    & "(" & regname(rs) & ")", Diss_Inst'length);
        when Inst_SW      => Diss_Inst <= expand("SW "    & regname(rt) & ", "   & integer'image(to_integer(Ex_offset))    & "(" & regname(rs) & ")", Diss_Inst'length);

        -- Special
        when Inst_MFC0    => Diss_Inst <= expand("MFC0 "  & regname(rt) & ", $"  & integer'image(to_integer(unsigned(rd))), Diss_Inst'length);
        when Inst_MTC0    => Diss_Inst <= expand("MTC0 "  & regname(rt) & ", $"  & integer'image(to_integer(unsigned(rd))), Diss_Inst'length);
        when Inst_SYSCALL => Diss_Inst <= expand("SYSCALL",                                                                 Diss_Inst'length);
        when Inst_ERET    => Diss_Inst <= expand("ERET",                                                                    Diss_Inst'length);
        when Inst_EI      => Diss_Inst <= expand("EI "    & regname(rt),                                                    Diss_Inst'length);
        when Inst_DI      => Diss_Inst <= expand("DI "    & regname(rt),                                                    Diss_Inst'length);
        when Inst_BREAK   => Diss_Inst <= expand("BREAK",                                                                   Diss_Inst'length);
        when Inst_Illegal => Diss_Inst <= expand("???",                                                                     Diss_Inst'length);
      end case;
    end process;
  end block;
  -- synthesis translate on

  ---------------------------------------------------------------------------
  -- Control Unit
  ---------------------------------------------------------------------------
  ControlUnit: block
    type state_t is (INIT, EXCEPTION, FETCH, DECODE, CHKINT,
        EX_ADD, EX_ADDI, EX_ADDIU, EX_ADDU, EX_AND, EX_ANDI, EX_LUI, EX_NOR, EX_OR, EX_ORI, EX_SLT, EX_SLTI, EX_SLTIU, EX_SLTU, EX_SUB, EX_SUBU, EX_XOR, EX_XORI,
        EX_SLL, EX_SLLV, EX_SRA, EX_SRAV, EX_SRL, EX_SRLV,
        EX_DIV, EX_DIVU, WAIT_DIV, EX_MFHI, EX_MFLO, EX_MTHI, EX_MTLO, EX_MULT, EX_MULTU, WAIT_MULT,
        EX_BEQ, EX_BGEZ, EX_BGEZAL, EX_BGTZ, EX_BLEZ, EX_BLTZ, EX_BLTZAL, EX_BNE, EX_J, EX_JAL, EX_JALR, EX_JR,
        EX_LB, EX_LBU, EX_LH, EX_LHU, EX_LW, EX_SB, EX_SH, EX_SW,
        EX_MFC0, EX_MTC0, EX_SYSCALL, EX_ERET, EX_EI, EX_DI, EX_BREAK,
        HALT, ERROR_STATE
    );

    signal state      : state_t := INIT;
    signal state_next : state_t;

    -- "internal" signals for setting up reset values for out ports
    signal WE_O_i  : std_logic := '0';
  begin
    WE_O  <= WE_O_i;

    fsm_trans: process(state, Dec_Instr, ACK_I, OP1_lts_Op2, Op1_equ_Op2, Interrupt, EXL, Err_Align, step_valid, Div_Done, Mult_Done)
    begin
      -- ERROR_STATE for catching incompletely specified states
      state_next <= ERROR_STATE;

      -- Defaults for Mealy type outputs
      Inst_En     <= '0';
      Set_ExcCode  <= '0';
      The_ExcCode  <= (others=>'0');
      Reg_WE      <= '0';
      PC_Sel      <= Sel_Keep;
      EX_Enter    <= '0';
      EX_Leave    <= '0';
      step_ready  <= '0';
      STB_O       <= '0';
      Hi_WE       <= '0';
      Lo_WE       <= '0';

      case state is

        when HALT =>
          state_next <= HALT;
          -- synthesis translate off
          report "bsr2_processor: HALT" severity failure;
          -- synthesis translate on
        when INIT      => state_next <= FETCH;
        when CHKINT    => if Interrupt = '0' then
                            state_next <= FETCH;
                          elsif Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          end if;
        when EXCEPTION => if EXL = '0' then
                            -- Jump to exception vector if not already handling an exception
                            state_next <= FETCH;
                            PC_Sel     <= Sel_Exception;
                            EX_Enter   <= '1';
                          elsif EXL = '1' then
                            -- If an exception occurs while in interrupt context all the processor can do is to stop working
                            state_next <= HALT;
                          end if;
        when FETCH     => if step_valid = '0' then
                            state_next <= FETCH;
                          elsif step_valid = '1' then
                            if Err_Align = '0' then
                                -- Start a bus transcaction and look for the acknowledgement.
                                -- after acknowledgement register the next instruction and switch to the DECODE state
                                STB_O <= '1';
                                if ACK_I = '0' then
                                  state_next <= FETCH;
                                elsif ACK_I = '1' then
                                  state_next <= DECODE;
                                  Inst_En    <= '1';
                                  PC_Sel     <= Sel_Increment;
                                  step_ready <= '1';
                                end if;
                            elsif Err_Align = '1' then
                              -- Request exception with ExcCode "AdEL"
                              Set_ExcCode <= '1';
                              The_ExcCode <= ExcCode_AdEL;
                              state_next <= EXCEPTION;
                            end if;
                          end if;
        when DECODE    =>
          case Dec_Instr is
            when Inst_ADD     => state_next <= EX_ADD;
            when Inst_ADDI    => state_next <= EX_ADDI;
            when Inst_ADDIU   => state_next <= EX_ADDIU;
            when Inst_ADDU    => state_next <= EX_ADDU;
            when Inst_AND     => state_next <= EX_AND;
            when Inst_ANDI    => state_next <= EX_ANDI;
            when Inst_LUI     => state_next <= EX_LUI;
            when Inst_NOR     => state_next <= EX_NOR;
            when Inst_OR      => state_next <= EX_OR;
            when Inst_ORI     => state_next <= EX_ORI;
            when Inst_SLT     => state_next <= EX_SLT;
            when Inst_SLTI    => state_next <= EX_SLTI;
            when Inst_SLTIU   => state_next <= EX_SLTIU;
            when Inst_SLTU    => state_next <= EX_SLTU;
            when Inst_SUB     => state_next <= EX_SUB;
            when Inst_SUBU    => state_next <= EX_SUBU;
            when Inst_XOR     => state_next <= EX_XOR;
            when Inst_XORI    => state_next <= EX_XORI;

            when Inst_SLL     => state_next <= EX_SLL;
            when Inst_SLLV    => state_next <= EX_SLLV;
            when Inst_SRA     => state_next <= EX_SRA;
            when Inst_SRAV    => state_next <= EX_SRAV;
            when Inst_SRL     => state_next <= EX_SRL;
            when Inst_SRLV    => state_next <= EX_SRLV;
            
            when Inst_DIV     => state_next <= EX_DIV;
            when Inst_DIVU    => state_next <= EX_DIVU;
            when Inst_MFHI    => state_next <= EX_MFHI;
            when Inst_MFLO    => state_next <= EX_MFLO;
            when Inst_MTHI    => state_next <= EX_MTHI;
            when Inst_MTLO    => state_next <= EX_MTLO;
            when Inst_MULT    => state_next <= EX_MULT;
            when Inst_MULTU   => state_next <= EX_MULTU;
          
            when Inst_BEQ     => state_next <= EX_BEQ;
            when Inst_BGEZ    => state_next <= EX_BGEZ;
            when Inst_BGEZAL  => state_next <= EX_BGEZAL;
            when Inst_BGTZ    => state_next <= EX_BGTZ;
            when Inst_BLEZ    => state_next <= EX_BLEZ;
            when Inst_BLTZ    => state_next <= EX_BLTZ;
            when Inst_BLTZAL  => state_next <= EX_BLTZAL;
            when Inst_BNE     => state_next <= EX_BNE;
            when Inst_J       => state_next <= EX_J;
            when Inst_JAL     => state_next <= EX_JAL;
            when Inst_JALR    => state_next <= EX_JALR;
            when Inst_JR      => state_next <= EX_JR;
            
            when Inst_LB      => state_next <= EX_LB;
            when Inst_LBU     => state_next <= EX_LBU;
            when Inst_LH      => state_next <= EX_LH;
            when Inst_LHU     => state_next <= EX_LHU;
            when Inst_LW      => state_next <= EX_LW;
            when Inst_SB      => state_next <= EX_SB;
            when Inst_SH      => state_next <= EX_SH;
            when Inst_SW      => state_next <= EX_SW;
            
            when Inst_MFC0    => state_next <= EX_MFC0;
            when Inst_MTC0    => state_next <= EX_MTC0;
            when Inst_SYSCALL => state_next <= EX_SYSCALL;
            when Inst_ERET    => state_next <= EX_ERET;
            when Inst_EI      => state_next <= EX_EI;
            when Inst_DI      => state_next <= EX_DI;
            when Inst_BREAK   => state_next <= EX_BREAK;
            
            when Inst_Illegal => Set_ExcCode <= '1';
                                 The_ExcCode <= ExcCode_RI;
                                 state_next <= EXCEPTION;
            when others       => state_next <= ERROR_STATE;
          end case;
        when EX_ADD    => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_ADDI   => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_ADDIU  => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_ADDU   => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_AND    => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_ANDI   => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_LUI    => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_NOR    => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_OR     => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_ORI    => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_SLT    => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_SLTI   => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_SLTIU  => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_SLTU   => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_SUB    => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_SUBU   => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_XOR    => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_XORI   => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_SLL    => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_SLLV   => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_SRA    => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_SRAV   => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_SRL    => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_SRLV   => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_DIV    => state_next <= WAIT_DIV;
        when EX_DIVU   => state_next <= WAIT_DIV;
        when WAIT_DIV  => if Div_Done = '0' then
                            state_next <= WAIT_DIV;
                          elsif Div_Done = '1' then
                              Hi_WE <= '1';
                              Lo_WE <= '1';
                              if Interrupt = '1' then
                                state_next <= EXCEPTION;
                                Set_ExcCode <= '1';
                                The_ExcCode <= ExcCode_Int;
                              elsif Interrupt = '0' then
                                state_next <= FETCH;
                              end if;
                          end if;
        when EX_MFHI   => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_MFLO   => Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_MTHI   => Hi_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_MTLO   => Lo_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_MULT   => state_next <= WAIT_MULT;
        when EX_MULTU  => state_next <= WAIT_MULT;
        when WAIT_MULT => if Mult_Done = '0' then
                            state_next <= WAIT_MULT;
                          elsif Mult_Done = '1' then
                              Hi_WE <= '1';
                              Lo_WE <= '1';
                              if Interrupt = '1' then
                                state_next <= EXCEPTION;
                                Set_ExcCode <= '1';
                                The_ExcCode <= ExcCode_Int;
                              elsif Interrupt = '0' then
                                state_next <= FETCH;
                              end if;
                          end if;
        when EX_BEQ    => if Op1_equ_Op2 = '1' then
                            PC_Sel <= Sel_Branch;
                          end if;
                          if Interrupt = '0' then
                            state_next <= FETCH;
                          elsif Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          end if;
        when EX_BGEZ   => if OP1_lts_Op2 = '0' then
                            PC_Sel <= Sel_Branch;
                          end if;
                          if Interrupt = '0' then
                            state_next <= FETCH;
                          elsif Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          end if;
        when EX_BGEZAL => if OP1_lts_Op2 = '0' then
                            PC_Sel <= Sel_Branch;
                            Reg_WE <= '1';
                          end if;
                          if Interrupt = '0' then
                            state_next <= FETCH;
                          elsif Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          end if;
        when EX_BGTZ   => if OP1_lts_Op2 = '0' and Op1_equ_Op2 = '0' then
                            PC_Sel <= Sel_Branch;
                          end if;
                          if Interrupt = '0' then
                            state_next <= FETCH;
                          elsif Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          end if;
        when EX_BLEZ   => if OP1_lts_Op2 = '1' or Op1_equ_Op2 = '1' then
                            PC_Sel <= Sel_Branch;
                          end if;
                          if Interrupt = '0' then
                            state_next <= FETCH;
                          elsif Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          end if;
        when EX_BLTZ   => if OP1_lts_Op2 = '1' then
                            PC_Sel <= Sel_Branch;
                          end if;
                          if Interrupt = '0' then
                            state_next <= FETCH;
                          elsif Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          end if;
        when EX_BLTZAL => if OP1_lts_Op2 = '1' then
                            PC_Sel <= Sel_Branch;
                            Reg_WE <= '1';
                          end if;
                          if Interrupt = '0' then
                            state_next <= FETCH;
                          elsif Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          end if;
        when EX_BNE    => if Op1_equ_Op2 = '0' then
                            PC_Sel <= Sel_Branch;
                          end if;
                          if Interrupt = '0' then
                            state_next <= FETCH;
                          elsif Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          end if;
        when EX_J      => PC_Sel <= Sel_JumpInst;
                          if Interrupt = '0' then
                            state_next <= FETCH;
                          elsif Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          end if;
        when EX_JAL    => PC_Sel <= Sel_JumpInst;
                          Reg_WE <= '1';
                          if Interrupt = '0' then
                            state_next <= FETCH;
                          elsif Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          end if;
        when EX_JALR   => PC_Sel <= Sel_JumpReg;
                          Reg_WE <= '1';
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_JR     => PC_Sel <= Sel_JumpReg;
                          if Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          elsif Interrupt = '0' then
                            state_next <= FETCH;
                          end if;
        when EX_LB     => STB_O <= '1';
                          if ACK_I = '0' then
                            state_next <= EX_LB;
                          elsif ACK_I = '1' then
                            Reg_WE <= '1';
                            if Interrupt = '1' then
                              state_next <= EXCEPTION;
                              Set_ExcCode <= '1';
                              The_ExcCode <= ExcCode_Int;
                            elsif Interrupt = '0' then
                              state_next <= FETCH;
                            end if;
                          end if;
        when EX_LBU    => STB_O <= '1';
                          if ACK_I = '0' then
                            state_next <= EX_LBU;
                          elsif ACK_I = '1' then
                            Reg_WE <= '1';
                            if Interrupt = '1' then
                              state_next <= EXCEPTION;
                              Set_ExcCode <= '1';
                              The_ExcCode <= ExcCode_Int;
                            elsif Interrupt = '0' then
                              state_next <= FETCH;
                            end if;
                          end if;
        when EX_LH     => if Err_Align = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_AdEL;
                          elsif Err_Align = '0' then
                            STB_O <= '1';
                            if ACK_I = '0' then
                              state_next <= EX_LHU;
                            elsif ACK_I = '1' then
                              Reg_WE <= '1';
                              if Interrupt = '1' then
                                state_next <= EXCEPTION;
                                Set_ExcCode <= '1';
                                The_ExcCode <= ExcCode_Int;
                              elsif Interrupt = '0' then
                                state_next <= FETCH;
                              end if;
                            end if;
                          end if;
        when EX_LHU    => if Err_Align = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_AdEL;
                          elsif Err_Align = '0' then
                            STB_O <= '1';
                            if ACK_I = '0' then
                              state_next <= EX_LHU;
                            elsif ACK_I = '1' then
                              Reg_WE <= '1';
                              if Interrupt = '1' then
                                state_next <= EXCEPTION;
                                Set_ExcCode <= '1';
                                The_ExcCode <= ExcCode_Int;
                              elsif Interrupt = '0' then
                                state_next <= FETCH;
                              end if;
                            end if;
                          end if;
        when EX_LW     => if Err_Align = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_AdEL;
                          elsif Err_Align = '0' then
                            STB_O <= '1';
                            if ACK_I = '0' then
                              state_next <= EX_LW;
                            elsif ACK_I = '1' then
                              Reg_WE <= '1';
                              if Interrupt = '1' then
                                state_next <= EXCEPTION;
                                Set_ExcCode <= '1';
                                The_ExcCode <= ExcCode_Int;
                              elsif Interrupt = '0' then
                                state_next <= FETCH;
                              end if;
                            end if;
                          end if;
        when EX_SB     => STB_O <= '1';
                          if ACK_I = '0' then
                            state_next <= EX_SB;
                          elsif ACK_I = '1' then
                            if Interrupt = '0' then
                              state_next <= FETCH;
                            elsif Interrupt = '1' then
                              state_next <= EXCEPTION;
                              Set_ExcCode <= '1';
                              The_ExcCode <= ExcCode_Int;
                            end if;
                          end if;
        when EX_SH     => if Err_Align = '0' then
                            STB_O <= '1';
                            if ACK_I = '0' then
                              state_next <= EX_SH;
                            elsif ACK_I = '1' then
                              if Interrupt = '0' then
                                state_next <= FETCH;
                              elsif Interrupt = '1' then
                                state_next <= EXCEPTION;
                                Set_ExcCode <= '1';
                                The_ExcCode <= ExcCode_Int;
                              end if;
                            end if;
                          elsif Err_Align = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_AdES;
                          end if;
        when EX_SW     => if Err_Align = '0' then
                            STB_O <= '1';
                            if ACK_I = '0' then
                              state_next <= EX_SW;
                            elsif ACK_I = '1' then
                              if Interrupt = '0' then
                                state_next <= FETCH;
                              elsif Interrupt = '1' then
                                state_next <= EXCEPTION;
                                Set_ExcCode <= '1';
                                The_ExcCode <= ExcCode_Int;
                              end if;
                            end if;
                          elsif Err_Align = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_AdES;
                          end if;
        when EX_MFC0   => Reg_WE     <= '1';
                          if Interrupt = '0' then
                            state_next <= FETCH;
                          elsif Interrupt = '1' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Int;
                          end if;
        when EX_MTC0   => state_next <= CHKINT;
        when EX_SYSCALL=> if EXL = '0' then
                            state_next <= EXCEPTION;
                            Set_ExcCode <= '1';
                            The_ExcCode <= ExcCode_Sys;
                          elsif EXL = '1' then
                            state_next <= HALT;
                          end if;
        when EX_ERET   => if EXL = '0' then
                            state_next <= HALT;
                          elsif EXL = '1' then
                            state_next <= CHKINT;
                            PC_Sel     <= Sel_EPC;
                            EX_Leave   <= '1';
                          end if;
        when EX_EI     => state_next <= CHKINT;
                          Reg_WE     <= '1';
        when EX_DI     => state_next <= FETCH;
                          Reg_WE     <= '1';
        when EX_BREAK  => state_next <= FETCH;
                          PC_Sel     <= Sel_Decrement;
        when others =>
          state_next <= ERROR_STATE;
          -- synthesis translate off
          report "bsr2_processor: ERROR_STATE" severity failure;
          -- synthesis translate on

      end case;
    end process;

    fsm_reg: process(CLK_I)
    begin
      if rising_edge(CLK_I) then

        -- Defaults
        state       <= INIT;
        WE_O_i      <= '0';
        Bus_Addr    <= Sel_PC;
        Bus_WordLen <= Sel_Byte;
        Bus_Extend  <= Sel_Zero;
        Reg_WrData  <= Sel_ALU;
        Sign_Extend <= '0';
        Reg_WrAddr  <= Sel_rd;
        ALU_Op2     <= Sel_RDt;
        ALU_Func    <= Sel_NOP;
        ALU_OP1     <= Sel_RDs;
        IR_Enable   <= '0';
        IR_Disable  <= '0';
        Reg_RE      <= '0';
        CP0_Write   <= '0';
        trap_i      <= '0';
        HiLo_Sel    <= Sel_Mult;
        Signed_Op   <= '0';
        Start_Mult  <= '0';
        Start_Div   <= '0';

        if RST_I = '0' then

          -- State register
          state <= state_next;

          -- Moore type outputs
          case state_next is
            when INIT        => null;
            when CHKINT      => null;
            when EXCEPTION   => null;
            when DECODE      => Reg_RE      <= '1'; -- register prefetch
            when FETCH       => Bus_Addr    <= Sel_PC;
                                Bus_WordLen <= Sel_Word;
            when EX_ADD      => ALU_Func    <= Sel_ADD;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_RDt;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rd;
            when EX_ADDI     => ALU_Func    <= Sel_ADD;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_Immediate;
                                Sign_Extend <= '1';
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rt;
            when EX_ADDIU    => ALU_Func    <= Sel_ADD;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_Immediate;
                                Sign_Extend <= '1';
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rt;
            when EX_ADDU     => ALU_Func    <= Sel_ADD;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_RDt;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rd;
            when EX_AND      => ALU_Func    <= Sel_AND;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_RDt;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rd;
            when EX_ANDI     => ALU_Func    <= Sel_AND;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_Immediate;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rt;
            when EX_LUI      => ALU_Func    <= Sel_SLL;
                                ALU_Op1     <= Sel_Sixteen;
                                ALU_Op2     <= Sel_Immediate;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rt;
            when EX_NOR      => ALU_Func    <= Sel_NOR;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_RDt;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rd;
            when EX_OR       => ALU_Func    <= Sel_OR;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_RDt;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rd;
            when EX_ORI      => ALU_Func    <= Sel_OR;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_Immediate;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rt;
            when EX_SLT      => ALU_Func    <= Sel_LTS;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_RDt;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rd;
            when EX_SLTI     => ALU_Func    <= Sel_LTS;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_Immediate;
                                Sign_Extend <= '1';
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rt;
            when EX_SLTIU    => ALU_Func    <= Sel_LTU;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_Immediate;
                                Sign_Extend <= '1';
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rt;
            when EX_SLTU     => ALU_Func    <= Sel_LTU;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_RDt;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rd;
            when EX_SUB      => ALU_Func    <= Sel_SUB;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_RDt;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rd;
            when EX_SUBU     => ALU_Func    <= Sel_SUB;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_RDt;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rd;
            when EX_XOR      => ALU_Func    <= Sel_XOR;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_RDt;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rd;
            when EX_XORI     => ALU_Func    <= Sel_XOR;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_Immediate;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rt;
            when EX_SLL      => ALU_Func    <= Sel_SLL;
                                ALU_Op1     <= Sel_SA;
                                ALU_Op2     <= Sel_RDt;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rd;
            when EX_SLLV     => ALU_Func    <= Sel_SLL;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_RDt;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rd;
            when EX_SRA      => ALU_Func    <= Sel_SRA;
                                ALU_Op1     <= Sel_SA;
                                ALU_Op2     <= Sel_RDt;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rd;
            when EX_SRAV     => ALU_Func    <= Sel_SRA;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_RDt;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rd;
            when EX_SRL      => ALU_Func    <= Sel_SRL;
                                ALU_Op1     <= Sel_SA;
                                ALU_Op2     <= Sel_RDt;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rd;
            when EX_SRLV     => ALU_Func    <= Sel_SRL;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_RDt;
                                Reg_WrData  <= Sel_ALU;
                                Reg_WrAddr  <= Sel_rd;
            when EX_DIV      => Signed_Op   <= '1';
                                Start_Div   <= '1';
            when EX_DIVU     => Signed_Op   <= '0';
                                Start_Div   <= '1';
            when WAIT_DIV    => HiLo_Sel    <= Sel_Div;
            when EX_MFHI     => Reg_WrData  <= Sel_Hi;
                                Reg_WrAddr  <= Sel_rd;
            when EX_MFLO     => Reg_WrData  <= Sel_Lo;
                                Reg_WrAddr  <= Sel_rd;
            when EX_MTHI     => ALU_Func    <= Sel_ADD;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_Zero;
                                HiLo_Sel    <= Sel_ALU;
            when EX_MTLO     => ALU_Func    <= Sel_ADD;
                                ALU_Op1     <= Sel_RDs;
                                ALU_Op2     <= Sel_Zero;
                                HiLo_Sel    <= Sel_ALU;
            when EX_MULT     => Signed_Op   <= '1';
                                Start_Mult  <= '1';
            when EX_MULTU    => Signed_Op   <= '0';
                                Start_Mult  <= '1';
            when WAIT_MULT   => HiLo_Sel    <= Sel_Mult;
            when EX_BEQ      => ALU_OP1     <= Sel_RDs;
                                ALU_Op2     <= Sel_RDt;
                                Sign_Extend <= '1';
            when EX_BGEZ     => ALU_OP1     <= Sel_RDs;
                                ALU_Op2     <= Sel_Zero;
                                Sign_Extend <= '1';
            when EX_BGEZAL   => ALU_OP1     <= Sel_RDs;
                                ALU_Op2     <= Sel_Zero;
                                Sign_Extend <= '1';
                                Reg_WrData  <= Sel_PC;
                                Reg_WrAddr  <= Sel_r31;
            when EX_BGTZ     => ALU_OP1     <= Sel_RDs;
                                ALU_Op2     <= Sel_Zero;
                                Sign_Extend <= '1';
            when EX_BLEZ     => ALU_OP1     <= Sel_RDs;
                                ALU_Op2     <= Sel_Zero;
                                Sign_Extend <= '1';
            when EX_BLTZ     => ALU_OP1     <= Sel_RDs;
                                ALU_Op2     <= Sel_Zero;
                                Sign_Extend <= '1';
            when EX_BLTZAL   => ALU_OP1     <= Sel_RDs;
                                ALU_Op2     <= Sel_Zero;
                                Sign_Extend <= '1';
                                Reg_WrData  <= Sel_PC;
                                Reg_WrAddr  <= Sel_r31;
            when EX_BNE      => ALU_OP1     <= Sel_RDs;
                                ALU_Op2     <= Sel_RDt;
                                Sign_Extend <= '1';
            when EX_J        => null;
            when EX_JAL      => Reg_WrData  <= Sel_PC;
                                Reg_WrAddr  <= Sel_r31;
            when EX_JALR     => Reg_WrData  <= Sel_PC;
                                Reg_WrAddr  <= Sel_rd;
            when EX_JR       => null;
            when EX_LB       => Bus_Addr    <= Sel_Reg;
                                Bus_WordLen <= Sel_Byte;
                                Bus_Extend  <= Sel_Sign;
                                Reg_WrData  <= Sel_Bus;
                                Reg_WrAddr  <= Sel_rt;
            when EX_LBU      => Bus_Addr    <= Sel_Reg;
                                Bus_WordLen <= Sel_Byte;
                                Bus_Extend  <= Sel_Zero;
                                Reg_WrData  <= Sel_Bus;
                                Reg_WrAddr  <= Sel_rt;
            when EX_LH       => Bus_WordLen <= Sel_Halfword;
                                Bus_Extend  <= Sel_Sign;
                                Reg_WrData  <= Sel_Bus;
                                Reg_WrAddr  <= Sel_rt;
            when EX_LHU      => Bus_Addr    <= Sel_Reg;
                                Bus_WordLen <= Sel_Halfword;
                                Bus_Extend  <= Sel_Zero;
                                Reg_WrData  <= Sel_Bus;
                                Reg_WrAddr  <= Sel_rt;
            when EX_LW       => Bus_Addr    <= Sel_Reg;
                                Bus_WordLen <= Sel_Word;
                                Reg_WrData  <= Sel_Bus;
                                Reg_WrAddr  <= Sel_rt;
            when EX_SB       => WE_O_i      <= '1';
                                Bus_Addr    <= Sel_Reg;
                                Bus_WordLen <= Sel_Byte;
            when EX_SH       => WE_O_i      <= '1';
                                Bus_Addr    <= Sel_Reg;
                                Bus_WordLen <= Sel_Halfword;
            when EX_SW       => WE_O_i      <= '1';
                                Bus_Addr    <= Sel_Reg;
                                Bus_WordLen <= Sel_Word;
            when EX_MFC0     => Reg_WrData  <= Sel_CP0;
                                Reg_WrAddr  <= Sel_rt;
            when EX_MTC0     => CP0_Write   <= '1';
            when EX_SYSCALL  => null;
            when EX_ERET     => null;
            when EX_EI       => IR_Enable   <= '1';
                                Reg_WrData  <= Sel_CP0;
                                Reg_WrAddr  <= Sel_rt;
            when EX_DI       => IR_Disable  <= '1';
                                Reg_WrData  <= Sel_CP0;
                                Reg_WrAddr  <= Sel_rt;
            when EX_BREAK    => trap_i      <= '1';
            when HALT        => trap_i      <= '1';
            when ERROR_STATE => null;
          end case;
        end if;
      end if;
    end process;

  end block;
end architecture;


