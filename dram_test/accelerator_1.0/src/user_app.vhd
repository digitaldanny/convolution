-- Greg Stitt
-- University of Florida
library ieee;
use ieee.std_logic_1164.all;
use work.config_pkg.all;
use work.user_pkg.all;
use work.math_custom.all;

entity user_app is
    generic (
        width: positive;
        size : positive);
    port (
        clks   : in  std_logic_vector(NUM_CLKS_RANGE);
        rst    : in  std_logic;
        sw_rst : out std_logic;

        -- memory-map interface
        mmap_wr_en   : in  std_logic;
        mmap_wr_addr : in  std_logic_vector(MMAP_ADDR_RANGE);
        mmap_wr_data : in  std_logic_vector(MMAP_DATA_RANGE);
        mmap_rd_en   : in  std_logic;
        mmap_rd_addr : in  std_logic_vector(MMAP_ADDR_RANGE);
        mmap_rd_data : out std_logic_vector(MMAP_DATA_RANGE);

        -- DMA interface for RAM 0
        -- read interface
        ram0_rd_rd_en : out std_logic;
        ram0_rd_clear : out std_logic;
        ram0_rd_go    : out std_logic;
        ram0_rd_valid : in  std_logic;
        ram0_rd_data  : in  std_logic_vector(RAM0_RD_DATA_RANGE);
        ram0_rd_addr  : out std_logic_vector(RAM0_ADDR_RANGE);
        ram0_rd_size  : out std_logic_vector(RAM0_RD_SIZE_RANGE);
        ram0_rd_done  : in  std_logic;
        -- write interface
        ram0_wr_ready : in  std_logic;
        ram0_wr_clear : out std_logic;
        ram0_wr_go    : out std_logic;
        ram0_wr_valid : out std_logic;
        ram0_wr_data  : out std_logic_vector(RAM0_WR_DATA_RANGE);
        ram0_wr_addr  : out std_logic_vector(RAM0_ADDR_RANGE);
        ram0_wr_size  : out std_logic_vector(RAM0_WR_SIZE_RANGE);
        ram0_wr_done  : in  std_logic;

        -- DMA interface for RAM 1
        -- read interface
        ram1_rd_rd_en : out std_logic;
        ram1_rd_clear : out std_logic;
        ram1_rd_go    : out std_logic;
        ram1_rd_valid : in  std_logic;
        ram1_rd_data  : in  std_logic_vector(RAM1_RD_DATA_RANGE);
        ram1_rd_addr  : out std_logic_vector(RAM1_ADDR_RANGE);
        ram1_rd_size  : out std_logic_vector(RAM1_RD_SIZE_RANGE);
        ram1_rd_done  : in  std_logic;
        -- write interface
        ram1_wr_ready : in  std_logic;
        ram1_wr_clear : out std_logic;
        ram1_wr_go    : out std_logic;
        ram1_wr_valid : out std_logic;
        ram1_wr_data  : out std_logic_vector(RAM1_WR_DATA_RANGE);
        ram1_wr_addr  : out std_logic_vector(RAM1_ADDR_RANGE);
        ram1_wr_size  : out std_logic_vector(RAM1_WR_SIZE_RANGE);
        ram1_wr_done  : in  std_logic);
end user_app;

architecture default of user_app is

    signal go        : std_logic;
    signal sw_rst_s  : std_logic;
    signal rst_s     : std_logic;
    signal size      : std_logic_vector(RAM0_RD_SIZE_RANGE);
--    signal ram0_rd_addr : std_logic_vector(RAM0_ADDR_RANGE);
--    signal ram1_wr_addr : std_logic_vector(RAM1_ADDR_RANGE);
    signal done      : std_logic;

    -------------------------------------------------------------------------------------------------------------------------------
    -- convolusion signals
    signal sb_full  : std_logic;
    signal sb_wr_en : std_logic;
    signal sb_empty : std_logic;
    signal valid_out_s : std_logic;
    signal dp_out : std_logic_vector(width+clog2(size)-1 downto 0));
    signal sb_out, kernel_out : std_logic_vector(size*width-1 downto 0);

    -------------------------------------------------------------------------------------------------------------------------------

begin

    U_MMAP : entity work.memory_map
        port map (
            clk     => clks(C_CLK_USER),
            rst     => rst,
            wr_en   => mmap_wr_en,
            wr_addr => mmap_wr_addr,
            wr_data => mmap_wr_data,
            rd_en   => mmap_rd_en,
            rd_addr => mmap_rd_addr,
            rd_data => mmap_rd_data,

            -- dma interface for accessing DRAM from software
            ram0_wr_ready => ram0_wr_ready,
            ram0_wr_clear => ram0_wr_clear,
            ram0_wr_go    => ram0_wr_go,
            ram0_wr_valid => ram0_wr_valid,
            ram0_wr_data  => ram0_wr_data,
            ram0_wr_addr  => ram0_wr_addr,
            ram0_wr_size  => ram0_wr_size,
            ram0_wr_done  => ram0_wr_done,

            ram1_rd_rd_en => ram1_rd_rd_en,
            ram1_rd_clear => ram1_rd_clear,
            ram1_rd_go    => ram1_rd_go,
            ram1_rd_valid => ram1_rd_valid,
            ram1_rd_data  => ram1_rd_data,
            ram1_rd_addr  => ram1_rd_addr,
            ram1_rd_size  => ram1_rd_size,
            ram1_rd_done  => ram1_rd_done,

            -- circuit interface from software
            go        => go,
            sw_rst    => sw_rst_s,
            size      => size,
            ram0_rd_addr => ram0_rd_addr,
            ram1_wr_addr => ram1_wr_addr,
            done      => done);

    rst_s  <= rst or sw_rst_s;
    sw_rst <= sw_rst_s;

    U_CTRL : entity work.ctrl
        port map (
            clk           => clks(C_CLK_USER),
            rst           => rst_s,
            go            => go,
            mem_in_go     => ram0_rd_go,
            mem_out_go    => ram1_wr_go,
            mem_in_clear  => ram0_rd_clear,
            mem_out_clear => ram1_wr_clear,
            mem_out_done  => ram1_wr_done,
            done          => done);

    -- DRAM_TEST version
    ram0_rd_rd_en <= ram0_rd_valid and ram1_wr_ready;
    ram0_rd_size  <= size;
--    ram0_rd_addr  <= ram0_rd_addr;
    ram1_wr_size  <= size;
--    ram1_wr_addr  <= ram1_rd_addr;
    ram1_wr_data  <= ram0_rd_data;
    ram1_wr_valid <= ram0_rd_valid and ram1_wr_ready;




    ---------------------------------------------------------------------------------------------------------------------------------------------

    -- convolusion version (comment out DRAM_TEST version)

    -- control signals --
    -- RAM0 read
    ram0_rd_rd_en_s <= ram0_rd_valid and not(sb_full);
    ram0_rd_rd_en <= ram_rd_rd_en_s;

    -- signal buffer
    sb_rd_en <= not(sb_empty) and ram1_wr_ready;

    -- anytime we read from input memory, we write into signal buffer. This only works
    -- because of first word fall through for max throughput
    sb_wr_en <= ram0_rd_rd_en_s; 

    ram1_wr_valid <= valid_out_s and ram1_wr_ready; 
    ram1_wr_data <= dp_out;




    -- memory map entity 




    -- signal buffer entity 
    U_SIG_BUFF: entity work.signal_buffer
        generic map(
            width => width,
            size  => size)
        port map( 
            clk => clks(C_CLK_USER),
            rst => rst,
            en => '1', -- TODO may need to change later
            rd_en => sb_rd_en,
            wr_en => sb_wr_en,
            full => sb_full,
            empty => sb_empty,
            input => ram0_rd_data,
            output => sb_out);




    -- kernel buffer using signal buffer entity
    U_KERN_BUFF: entity work.signal_buffer
        generic map(
            width => width,
            size  => size)
        port map( 
            clk => clks(C_CLK_USER),
            rst => rst,
            en => '1', -- TODO may need to change later
            rd_en => ,
            wr_en => ,
            full => ,
            empty => ,
            input => mmap_rd_data,
            output => kernel_out);




    -- pipeline
    U_DATAPATH: entity work.mult_add_tree(unsigned_arch)
        generic map(
            num_inputs => size,
            input1_width => width,
            input2_width => width)
        port map (
            clk => clk,
            rst => rst,
            en => ram1_wr_ready, -- stalls the pipeline if output RAM is not ready
            input1 => sb_out,
            input2 => kernel_out,
            output => dp_out);
    end mult_add_tree;




    -- clipping logic --
    -- if any bit above 16th is 1, output all 1's, else output lower 16 bits
    if (dp_out(width to dp_out'range) > 0) then -- TODO this may not work
        dp_out_clipped <= (others => '1');
    else
        dp_out_clipped <= dp_out(width-1 downto 0);




    -- valid bit for datapath valid output
    U_DELAY: entity work.delay
        generic map(
            cycles : 1 -- TODO ;
            width  : 1;
            init   "0");
        port map(
            clk => clks(C_CLK_USER),
            rst => rst,
            en => ram1_wr_ready,
            input => sb_rd_en,
            output => valid_out_s);




    -- maybe control

end default;
