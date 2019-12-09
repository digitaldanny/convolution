
library ieee;
use ieee.std_logic_1164.all;

entity dual_flop is
  port( clk_src  : in  std_logic;
        clk_dest : in std_logic;
        rst_src  : in  std_logic;
        rst_dest : in std_logic;
        en       : in  std_logic;
        input    : in  std_logic;
        output   : out std_logic);
end dual_flop;


architecture STR of dual_flop is

	signal input_s : std_logic_vector(0 downto 0);
    signal src_out_s : std_logic_vector(0 downto 0);
    signal dest_out_s : std_logic_vector(0 downto 0);

begin

	input_s(0) <= input; -- assign std_logic to vector to fix delay bug

    U_SRC: entity work.delay
        generic map (
            cycles => 1, 
            width  => 1,
            init => "0")
        port map (
            clk     => clk_src,
            rst     => rst_src,
            en      => en,
            input   => input_s,
            output  => src_out_s);


    U_DEST: entity work.delay
        generic map (
            cycles => 2, -- includes 2 registers for dest sync
            width  => 1,
            init => "0")
        port map (
            clk    => clk_dest,
            rst    => rst_dest,
            en     => '1',
            input  => src_out_s,
            output => dest_out_s);
			
	output <= dest_out_s(0);

end STR;
