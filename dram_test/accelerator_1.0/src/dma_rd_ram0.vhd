-- Daniel Hamilton & Michael Thomas

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.config_pkg.all;
use work.user_pkg.all;

entity dma_rd_ram0 is
	port (
		-- user ports
		user_clk   : in  std_logic;
		rst        : in  std_logic;
		clear      : in  std_logic;
		go         : in  std_logic;
		rd_en      : in  std_logic;
		stall      : in  std_logic;
		start_addr : in  std_logic_vector(14 downto 0);
		size       : in  std_logic_vector(16 downto 0);
		valid      : out std_logic;
		data       : out std_logic_vector(15 downto 0);
		done       : out std_logic;
	
		-- dram ports
		dram_clk 	  : in 	std_logic;
		dram_ready    : in  std_logic;
		dram_rd_en    : out std_logic;
		dram_rd_addr  : out std_logic_vector(14 downto 0);
		dram_rd_data  : in  std_logic_vector(31 downto 0);
		dram_rd_valid : in  std_logic;
		dram_rd_flush : out std_logic
	);
end dma_rd_ram0;

architecture BHV of dma_rd_ram0 is

	-- +=====+=====+=====+=====+=====+=====+=====+=====+=====+
	--                 COMPONENT DECLARATION
	-- +=====+=====+=====+=====+=====+=====+=====+=====+=====+
	
	-- ADDR_GEN
	component addr_gen
		generic(
			width : positive
		);
		port (
			clk         : in  std_logic;
			rst         : in  std_logic;
			start_addr 	: in  std_logic_vector(width-1 downto 0);
			size        : in  std_logic_vector(16 downto 0);
			addr        : out std_logic_vector(width-1 downto 0);
			
			dram_rdy 	: in  std_logic; -- dram side 'go' signal
			go          : in  std_logic; -- user side 'go' signal
			stall       : in  std_logic;
			
			valid       : out std_logic;
			done        : out std_logic
		);
	end component;
		
	--FIFO_32_PROG_FULL (change from fifo_32_placeholder -> fifo_32_prog_full during sim/synthesis)
	component fifo_w32_r16_prog_full
		port (
			rst 	: in STD_LOGIC;
			wr_clk 	: in STD_LOGIC;
			rd_clk 	: in STD_LOGIC;
			din 	: in STD_LOGIC_VECTOR(31 DOWNTO 0);
			wr_en 	: in STD_LOGIC;
			rd_en 	: in STD_LOGIC;
			
			dout 	: out STD_LOGIC_VECTOR(15 DOWNTO 0);
			full 	: out STD_LOGIC;
			empty 	: out STD_LOGIC;
			prog_full : out STD_LOGIC
		);
	end component;
		
	-- HANDSHAKE
	
	component handshake
		port (
			clk_src   : in  std_logic;
			clk_dest  : in  std_logic;
			rst       : in  std_logic;
			
			go        : in  std_logic;
			delay_ack : in  std_logic;
			rcv       : out std_logic;
			ack       : out std_logic
		);
	end component;
		
	-- DELAY
	component delay
		generic(
			cycles :     natural;
			width  :     positive;
			init   :     std_logic_vector
		);
		port( 	
			clk    : in  std_logic;
			rst    : in  std_logic;
			en     : in  std_logic;
			input  : in  std_logic_vector(width-1 downto 0);
			output : out std_logic_vector(width-1 downto 0)
		);
	end component;
		
	-- +=====+=====+=====+=====+=====+=====+=====+=====+=====+
	--                   SIGNAL DECLARATION
	-- +=====+=====+=====+=====+=====+=====+=====+=====+=====+
	
	-- REGISTER SIGNALS
	signal size_r_s : std_logic_vector(16 downto 0); -- registered size 
	signal start_addr_r : std_logic_vector(14 downto 0); -- registered start address
	
	-- HANDSHAKE SIGNALS
	signal go_synchronized_s : std_logic; -- rcv of the handshake is the synchronized 'go' signal
	signal ack_handshake_s   : std_logic;
	
	-- ADDR GENERATOR SIGNALS
	signal addr_gen_done_s : std_logic; -- unused
	
	-- FIFO SIGNALS
	signal dram_rd_data_flipped_s : std_logic_vector(31 downto 0);
	signal fifo_prog_full_s	: std_logic;
	signal fifo_empty_s 	: std_logic;
	signal fifo_full_s		: std_logic; -- unused
	signal fifo_rst_s 		: std_logic;
	
	-- MISC SIGNALS
	signal size_div2_s : std_logic_vector(16 downto 0);
	signal rstn_s : std_logic;
	signal done_s : std_logic;
	signal debug_count_s : std_logic_vector(16 downto 0);
	
	type state_t is (S_START, S_COUNT, S_COMPLETE);
	signal state_s, next_state_s : state_t;
	
	-- +=====+=====+=====+=====+=====+=====+=====+=====+=====+
	--                   CONSTANT DECLARATION
	-- +=====+=====+=====+=====+=====+=====+=====+=====+=====+
	constant C_0 : std_logic := '0';
	
begin
	
	-- +=====+=====+=====+=====+=====+=====+=====+=====+=====+
	--                 COMPONENT INSTANTIATION
	-- +=====+=====+=====+=====+=====+=====+=====+=====+=====+
	
	-- This register holds the 'size' signal while the 'go' signal 
	-- passes through the handshake.
	U_SIZE_REG : delay
		generic map (
			cycles => 1,
			width  => 17,
			init   => "00000000000000000"
		)
		port map ( 	
			clk    => user_clk,
			rst    => rst,
			en     => go,
			input  => size,
			output => size_r_s
		);
		
	-- This register holds the 'start_addr' signal while the 'go' signal 
	-- passes through the handshake.
	U_START_ADDR_REG : delay
		generic map (
			cycles => 1,
			width  => 15,
			init   => "000000000000000"
		)
		port map ( 	
			clk    => user_clk,
			rst    => rst,
			en     => go,
			input  => start_addr,
			output => start_addr_r
		);
		
	-- This handshake is used to synchronize the 'go' signal between
	-- user and dram clock domains.
	U_HANDSHAKE : handshake
		port map (
			clk_src   => user_clk,
			clk_dest  => dram_clk,
			rst       => rst,
			
			go        => go,
			delay_ack => C_0,
			rcv       => go_synchronized_s,
			ack       => ack_handshake_s -- this signal is unused
		);
	
	-- Generate 'size' number of addresses starting at 'start_addr'
	U_ADDR_GEN : addr_gen
		generic map (
			width => 15
		)
		port map (
			clk       	=> dram_clk,   -- (In)
			rst         => rst,        -- (In)
			start_addr  => start_addr, -- (In)
			size        => size_r_s,     -- (In)
			
			addr        => dram_rd_addr, -- (Out)
			
			dram_rdy 	=> dram_ready, -- dram side 'go' signal (Out)
			go          => go_synchronized_s, -- user side 'go' signal (In)
			stall       => fifo_prog_full_s, -- (In)
			
			valid       => dram_rd_en, 		-- (Out)
			done        => addr_gen_done_s 	-- (Out)
		);	
		
	-- FIFO with programmable full flag. Automatically converts from 
	-- 32 bit inputs to 16 bit outputs.
	-- U_FIFO_32_PROG_FULL : fifo_32_placeholder
	U_FIFO_32_PROG_FULL : fifo_w32_r16_prog_full
		port map (
			rst 		=> fifo_rst_s,
			wr_clk 		=> dram_clk,
			rd_clk 		=> user_clk,
			din 		=> dram_rd_data_flipped_s,
			wr_en 		=> dram_rd_valid,
			rd_en 		=> rd_en,
			dout 		=> data,
			full 		=> fifo_full_s,
			empty 		=> fifo_empty_s,
			prog_full 	=> fifo_prog_full_s
		);
		
	-- +=====+=====+=====+=====+=====+=====+=====+=====+=====+
	--                          LOGIC 
	-- +=====+=====+=====+=====+=====+=====+=====+=====+=====+
	
	done <= done_s;		-- controlled by P_DONE
	rstn_s <= not(rst);	-- controlled by rst port
	
	-- fifo flips MSWord and LSWord in resize.. Flipping the words on input
	-- will fix that issue.
	dram_rd_data_flipped_s <= dram_rd_data(15 downto 0) & dram_rd_data(31 downto 16);
	
	-- User will know FIFO has data available when the empty flag
	-- is false.
	valid <= not(fifo_empty_s);
	
	-- Fifo contents should be cleared when system is reset OR when
	-- the clear input is set.
	fifo_rst_s <= rst or clear;
	
	-- clear/go are wired directly to flush to reset the RAM
	dram_rd_flush <= (clear or go_synchronized_s) and rstn_s;
	
	-- +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
	-- SUMMARY: 
	-- This process will tell the datapath that the whole DMA transfer
	-- is complete when the number of 16 bit data words are read from 
	-- the RAM.
	-- +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
	P_DONE_1ST_PROC : process(rst, user_clk)
	begin
	   if (rst = '1') then
	       state_s <= S_COMPLETE;
	   elsif (rising_edge(user_clk)) then
	       state_s <= next_state_s;
	   end if;
	end process;
	
	P_DONE_2ND_PROC : process(go, user_clk, state_s, size_r_s, rd_en)
		variable counter_v 	: unsigned(16 downto 0);
		variable usize_v 	: unsigned(16 downto 0);
	begin
	
	   -- always true..
	   usize_v := unsigned(size_r_s);
	   debug_count_s <= std_logic_vector(counter_v);
	   
	    -- default values
		done_s <= '0';
		next_state_s <= state_s;	   
	   
	   -- STATE MACHINE
	   case (state_s) is
	   when S_START =>
	       -- +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
	       -- S_START: This is the reset state used to set done back to 0
	       -- +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
	   
	       counter_v := (others => '0');
	       done_s <= '0'; -- not required bc of default, just here for clarification.
	       next_state_s <= S_COUNT;
	   
	   when S_COUNT =>
	   	   -- +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
	       -- S_COUNT: This state increments the done counter based on the 
	       -- number of reads requested from the FIFO.
	       -- +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
	   
	       if (rd_en = '1' and rising_edge(user_clk)) then
	           counter_v := counter_v + to_unsigned(1, counter_v'length);
	       end if;
	   
	       -- DMA transfer is complete if the counter equals the requested size.
	   	   if (counter_v = usize_v) then
				next_state_s <= S_COMPLETE;
		  end if;
	   
	   when S_COMPLETE =>
	       -- +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
	       -- S_COMPLETE: This state is used to keep done high until the next
	       -- transfer needs to begin.
	       -- +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
	   
	       counter_v := (others => '0');
	       done_s <= '1';
	       
	       if (go = '1') then
	           next_state_s <= S_START;
	       end if;
	   
	   when others =>
	       next_state_s <= S_START;
	   end case;
	   
	end process;
	
end BHV;