library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.math_custom.all;
use work.user_pkg.all;

entity datapath_buffers_tb is
end datapath_buffers_tb;

architecture TB of datapath_buffers_tb is

    constant width : integer  := 4;
    constant size : integer := 4;
    
    -- valid bit latency delay
    constant valid_bit_delay : positive := clog2(size+1);

    constant CLK0_HALF_PERIOD : time := 5 ns;

    signal clk0 : std_logic := '0';
    signal rst  : std_logic := '1';
    signal en, rd_en, wr_en, full, empty : std_logic;
    signal ram1_wr_ready : std_logic;
    signal valid_in_s, valid_out_s : std_logic;
    signal input : std_logic_vector(width-1 downto 0); 
    signal sb_out_s, kernel_out_s : std_logic_vector(size*width-1 downto 0);
    signal dp_out_s : std_logic_vector(2*width+clog2(size)-1 downto 0);
    signal sim_done : std_logic := '0';

begin

    SMART_BUFFER : entity work.signal_buffer
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
            output => sb_out_s);
            

    KERNEL : entity work.signal_buffer
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
            output => kernel_out_s);
            
            
        -- datapath valid bit
        U_VALID_DP: entity work.delay
        generic map(
            cycles => valid_bit_delay,
            width  => 1,
            init => "0")
        port map(
            clk => clk0,
            rst => rst,
            en => ram1_wr_ready,
            input(0) => valid_in_s,
            output(0) => valid_out_s);


--    -- pipeline
    U_DATAPATH: entity work.mult_add_tree(unsigned_arch)
        generic map(
            num_inputs => size,
            input1_width => width,
            input2_width => width)
        port map (
            clk => clk0,
            rst => rst,
            en => ram1_wr_ready, -- stalls the pipeline if output RAM is not ready
            input1 => sb_out_s,
            input2 => kernel_out_s,
            output => dp_out_s);

    -- toggle clock
    clk0    <= not clk0 after 5 ns when sim_done = '0' else clk0;

    -- process to test different inputs
    process

    begin

        -- reset circuit  
        rst <= '1';
        input <= std_logic_vector(to_unsigned(0, width));
        en <= '0';
        rd_en <= '0';
        wr_en <= '0';
        ram1_wr_ready <= '0';
        

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
        wr_en <= '1';
        

        -- shift data into signal_buffer
        for i in 0 to size-1 loop
            wait until rising_edge(clk0);
            input <= std_logic_vector(to_unsigned(i, width));
        end loop;
        
        wr_en <= '0';
        -- start datapath
        ram1_wr_ready <= '1';
        
        -- let output stabilize
        for i in 0 to 20 loop
            wait until rising_edge(clk0);
        end loop;
        


        report "SIMULATION FINISHED!!!";
        sim_done <= '1';
        wait;

    end process;
end TB;
