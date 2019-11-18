-- Greg Stitt
-- University of Florida

library ieee;
use ieee.std_logic_1164.all;

use work.config_pkg.all;
use work.user_pkg.all;

entity user_app is
    port (
        clk : in std_logic;
        rst : in std_logic);
end user_app;

architecture default of user_app is

begin

-- memory map entity 

-- signal buffer entity 

-- kernel buffer(signal buffer entity)

    -- pipeline
    U_DATAPATH: entity work.mult_add_tree
        generic port(
            num_inputs => ,
            input1_width => ,
            input2_width => ;)
        port map (
            clk => clk,
            rst => rst,
            en => en,
            input1 => ,
            input2 => ,
            output => );
end mult_add_tree;

    -- maybe control



end default;
