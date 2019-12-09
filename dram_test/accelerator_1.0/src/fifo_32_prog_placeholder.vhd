-- Daniel Hamilton & Michael Thomas
-- SUMMARY: This entity is a placeholder file for the fifo_32 entity
-- from mthe Vivado IP generator. This is being used to connect wires
-- while creating the dma_rd_ram0 file.

library ieee;
use ieee.std_logic_1164.all;

ENTITY fifo_32_prog_placeholder IS
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
	
    dout : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    prog_full : OUT STD_LOGIC
  );
END fifo_32_prog_placeholder;

architecture default of fifo_32_prog_placeholder is
begin
	dout <= (others => '0');
	full <= '0';
	empty <= '0';
	prog_full <= '0';
end default;