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
			size        : in  std_logic_vector(width downto 0);
			addr        : out std_logic_vector(width-1 downto 0);
			
			dram_rdy 	: in  std_logic; -- dram side 'go' signal
			go          : in  std_logic; -- user side 'go' signal
			stall       : in  std_logic;
			
			valid       : out std_logic;
			done        : out std_logic
		);
	end component;
		
	-- FIFO_32_PROG_FULL (change from fifo_32_placeholder -> fifo_32_prog_full during sim/synthesis)
	component fifo_32_placeholder
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
	signal size_div2_r_s : std_logic_vector(16 downto 0); -- registered size 
	signal start_addr_r : std_logic_vector(14 downto 0); -- registered start address
	
	-- HANDSHAKE SIGNALS
	signal go_synchronized_s : std_logic; -- rcv of the handshake is the synchronized 'go' signal
	signal ack_handshake_s   : std_logic;
	
	-- ADDR GENERATOR SIGNALS
	signal addr_gen_done_s : std_logic; -- all addresses have been generated
	
	-- FIFO SIGNALS
	signal fifo_prog_full_s	: std_logic;
	signal fifo_empty_s 	: std_logic;
	signal fifo_full_s		: std_logic; -- unused
	signal fifo_rst_s 		: std_logic;
	
	-- MISC SIGNALS
	signal size_div2_s : std_logic_vector(16 downto 0);
	
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
			input  => size_div2_s,
			output => size_div2_r_s
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
			size        => size_div2_r_s,     -- (In)
			
			addr        => dram_rd_addr, -- (Out)
			
			dram_rdy 	=> dram_ready, -- dram side 'go' signal (Out)
			go          => go_synchronized_s, -- user side 'go' signal (In)
			stall       => fifo_prog_full_s, -- (In)
			
			valid       => dram_rd_en, 		-- (Out)
			done        => addr_gen_done_s 	-- (Out)
		);	
		
	-- FIFO with programmable full flag. Automatically converts from 
	-- 32 bit inputs to 16 bit outputs.
	U_FIFO_32_PROG_FULL : fifo_32_placeholder
		port map (
			rst 		=> fifo_rst_s,
			wr_clk 		=> dram_clk,
			rd_clk 		=> user_clk,
			din 		=> dram_rd_data,
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
	
	-- Divide the size requested from RAM by 2 to handle conversion
	-- from 32-bit values in RAM to 16-bit values in datapath.
	size_div2_s <= std_logic_vector(shift_right(unsigned(size), 1));
	
	-- User will know FIFO has data available when the empty flag
	-- is false.
	valid <= not(fifo_empty_s);
	
	-- Fifo contents should be cleared when system is reset OR when
	-- the clear input is set.
	fifo_rst_s <= rst or clear;
	
	-- clear is wired directly to flush to reset the RAM
	dram_rd_flush <= clear;
	
	-- +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
	-- SUMMARY: 
	-- This process will tell the datapath that the whole DMA transfer
	-- is complete when the number of 16 bit data words are read from 
	-- the RAM.
	-- +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
	P_DONE : process(rst, user_clk, size_div2_r_s, rd_en)
		variable counter_v 	: unsigned(16 downto 0);
		variable usize_v 	: unsigned(16 downto 0);
		variable done_v 	: std_logic;
	begin
		
		done_v := '0'; -- default
		usize_v := unsigned(size_div2_r_s);
		
		if (rst = '1') then
			counter_v 	:= (others => '0');
			done_v 		:= '0'; -- not required bc of default, just here for clarification.
			
		elsif (rising_edge(user_clk)) then
			
			if (counter_v = usize_v) then
				-- DMA transfer is complete if the counter equals the requested size.
				done_v := '1';
			else
				-- only increment counter if the clock is rising and 
				-- if the read enable was set.
				if (rd_en = '1') then
					counter_v := counter_v + to_unsigned(1, counter_v'length);
				end if;
			end if;
			
		end if;
		
		done <= done_v;
		
	end process;
	
end BHV;