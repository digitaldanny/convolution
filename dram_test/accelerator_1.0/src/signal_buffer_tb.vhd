library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity signal_buffer_tb is
end signal_buffer_tb;

architecture TB of signal_buffer_tb is

    constant width : integer  := 4;
    constant size : integer := 4;
    constant CLK0_HALF_PERIOD : time := 5 ns;

    signal clk0 : std_logic := '0';
    signal rst  : std_logic := '1';
    signal en, rd_en, wr_en, full, empty : std_logic;
    signal input : std_logic_vector(width-1 downto 0);
    signal output : std_logic_vector(size*width-1 downto 0);
    signal sim_done : std_logic := '0';

begin

    UUT : entity work.signal_buffer
        generic map (
            width => width,
            size => size)
        port map (
            clk    => clk0,
            rst    => rst,
            en     => en,
            rd_en  => rd_en,
            wr_en  => wr_en,
            full   => full,
            empty  => empty,
            input  => input,
            output => output);

    -- toggle clock
    clk0    <= not clk0 after 5 ns when sim_done = '0' else clk0;

    -- process to test different inputs
    process

        -- function to check if the outputs is correct
        function checkOutput (
            i : integer)
            return integer is

        begin
            return i+1;
        end checkOutput;

        variable result : std_logic_vector(size*width-1 downto 0);
        variable done   : std_logic;
        variable count  : integer;

    begin

        -- reset circuit  
        rst <= '1';
        input <= std_logic_vector(to_unsigned(0, width));
        en <= '0';
        rd_en <= '0';
        wr_en <= '0';

        -- wait for 500 ns;
        for i in 0 to 20 loop
            wait until rising_edge(clk0);
        end loop;


        -- wait 500 ns
        rst <= '0';
   
        
        for i in 0 to 20 loop
            wait until rising_edge(clk0);
        end loop;

        en <= '1';
        rd_en <= '0';
        wr_en <= '0';


        -- shift data into signal_buffer
        for i in 5 to size+5-1 loop
            wr_en <= '1';
            input <= std_logic_vector(to_unsigned(i, width));
            wait until rising_edge(clk0);
        end loop;
        
        wr_en <= '0';
        
        -- let output stabilize
        for i in 0 to 20 loop
            wait until rising_edge(clk0);
        end loop;
        
        rd_en <= '1';
        
        for i in 0 to 20 loop
            wait until rising_edge(clk0);
        end loop;
        
        wr_en <= '1';
        for i in 0 to 20 loop
            wait until rising_edge(clk0);
        end loop;

        report "SIMULATION FINISHED!!!";
        sim_done <= '1';
        wait;

    end process;
end TB;
