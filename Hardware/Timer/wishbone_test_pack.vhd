library ieee;
use ieee.std_logic_1164.all;

package wishbone_test_pack is

	constant TIMEOUT_CYCLES : positive := 16;

	procedure wait_cycle (
		num_cycles   : in positive := 1;
		signal clk_i : in  std_logic
	);
  
	procedure wishbone_init (
		signal stb_o : out std_logic;
		signal we_o  : out std_logic;
		signal sel_o : out std_logic_vector;
		signal adr_o : out std_logic_vector;
		signal dat_o : out std_logic_vector
	);  

	procedure wishbone_write (
		sel          : in  std_logic_vector;
		adr          : in  std_logic_vector;
		dat          : in  std_logic_vector;
		signal clk_i : in  std_logic;       
		signal stb_o : out std_logic;
		signal we_o  : out std_logic;
		signal sel_o : out std_logic_vector;
		signal adr_o : out std_logic_vector;
		signal dat_o : out std_logic_vector;
		signal ack_i : in  std_logic;
		signal dat_i : in  std_logic_vector
	);

	procedure wishbone_read (
		adr          : in  std_logic_vector;
		dat          : out std_logic_vector;
		signal clk_i : in  std_logic;       
		signal stb_o : out std_logic;
		signal we_o  : out std_logic;
		signal sel_o : out std_logic_vector;
		signal adr_o : out std_logic_vector;
		signal dat_o : out std_logic_vector;
		signal ack_i : in  std_logic;
		signal dat_i : in  std_logic_vector
	);    
end package;

package body wishbone_test_pack is
  
	procedure wait_cycle(
		num_cycles   : in positive := 1;
		signal clk_i : in std_logic
	) is
	begin
		for i in 0 to num_cycles loop
			wait until falling_edge(clk_i);
		end loop;
	end procedure;
    
	procedure wishbone_init(
		signal stb_o : out std_logic;
		signal we_o  : out std_logic;
		signal sel_o : out std_logic_vector;
		signal adr_o : out std_logic_vector;
		signal dat_o : out std_logic_vector
	) is
	begin
		stb_o <= '0';
		we_o  <= '0';
		for i in sel_o'range loop
		  sel_o(i) <= '0';
		end loop;
		for i in adr_o'range loop
		  adr_o(i) <= '0';
		end loop;
	end procedure;
  
	procedure wishbone_write(
		sel          : in  std_logic_vector;
		adr          : in  std_logic_vector;
		dat          : in  std_logic_vector;
		signal clk_i : in  std_logic;      
		signal stb_o : out std_logic;
		signal we_o  : out std_logic;
		signal sel_o : out std_logic_vector;
		signal adr_o : out std_logic_vector;
		signal dat_o : out std_logic_vector;
		signal ack_i : in  std_logic;
		signal dat_i : in  std_logic_vector
	) is
		variable timeout_count: positive := 1;
	begin
		stb_o <= '1';
		we_o  <= '1';
		sel_o <= sel;
		adr_o <= adr;
		dat_o <= dat;

		loop
			wait until falling_edge(clk_i);
			if ack_i = '1' then exit; end if;
			assert timeout_count < TIMEOUT_CYCLES report "Timeout when waiting for ack" severity failure;
			timeout_count := timeout_count + 1;
		end loop;

		wishbone_init(
			stb_o => stb_o,
			we_o  => we_o,
			sel_o => sel_o,
			adr_o => adr_o,
			dat_o => dat_o
		);
	end procedure;

	procedure wishbone_read (
		adr          : in  std_logic_vector;
		dat          : out std_logic_vector;
		signal clk_i : in  std_logic;      
		signal stb_o : out std_logic;
		signal we_o  : out std_logic;
		signal sel_o : out std_logic_vector;
		signal adr_o : out std_logic_vector;
		signal dat_o : out std_logic_vector;
		signal ack_i : in  std_logic;
		signal dat_i : in  std_logic_vector
	) is
		variable timeout_count: positive := 1;
	begin
		stb_o <= '1';
		we_o  <= '0';
		adr_o <= adr;
		
		loop
			wait until rising_edge(clk_i);
			if ack_i = '1' then exit; end if;
			assert timeout_count < TIMEOUT_CYCLES report "Timeout when waiting for ack" severity failure;
			timeout_count := timeout_count + 1;
		end loop;

		dat := dat_i;
		wait until falling_edge(clk_i);

		wishbone_init(
			stb_o => stb_o,
			we_o  => we_o,
			sel_o => sel_o,
			adr_o => adr_o,
			dat_o => dat_o
		);
	end procedure;
end package body;

