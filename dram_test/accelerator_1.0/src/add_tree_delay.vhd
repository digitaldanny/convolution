library ieee;
use ieee.std_logic_1164.all;


entity add_tree_delay is

  generic(cycles :     natural;
          width  :     positive;
          init   :     std_logic_vector);
  port( clk      : in  std_logic;
        rst      : in  std_logic;
        en       : in  std_logic;
        input    : in  std_logic_vector(width-1 downto 0);
        output   : out std_logic_vector(width-1 downto 0));

end add_tree_delay;

architecture delay of add_tree_delay is

begin

    -- valid bit for datapath valid output
    U_DELAY: entity work.delay
        generic map(
            cycles => cycles,
            width  => width,
            init => init)
        port map(
            clk => clk,
            rst => rst,
            en => en,
            input => input,
            output => output);

end delay;
