-- Greg Stitt
-- University of Florida
library ieee;
use ieee.std_logic_1164.all;
use work.config_pkg.all;
use work.user_pkg.all;
use work.math_custom.all;

entity user_app is
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
    signal sb_full_s, kernel_full_s : std_logic;
    signal sb_wr_en_s : std_logic;
    signal sb_rd_en_s, kernel_rd_en_s, valid_out_s : std_logic_vector(0 downto 0);
    signal sb_empty_s : std_logic;
    --signal padded_signal_size_s : std_logic_vector(C_SIGNAL_WIDTH+2*size-1 downto 0);
    signal dp_out_s : std_logic_vector(C_SIGNAL_WIDTH+clog2(C_SIGNAL_WIDTH)-1 downto 0);
    signal dp_out_clipped_s : std_logic_vector(RAM1_WR_DATA_RANGE);                     -- output to RAM1_WR
    signal kernel_load_s, kernel_empty_s, kernel_loaded_s : std_logic;
    signal kernel_data_s : std_logic_vector(SIGNAL_WIDTH_RANGE);                      -- output from memory map into kernel buffer
    signal sb_out_s, kernel_out_s : std_logic_vector(C_SIGNAL_WIDTH*C_SIGNAL_WIDTH-1 downto 0);   -- output from both smart buffers
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
            --signal_size => size,
            ram0_rd_addr => ram0_rd_addr,
            ram1_wr_addr => ram1_wr_addr,

            ---------------------------------------
            -- convolution memory_map specific
            --kernel_data => kernel_data_s,
            --kernel_load => kernel_load_s,
            --kernel_loaded => kernel_loaded_s,
            ---------------------------------------

            done => done);

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
    kernel_loaded_s <= not(kernel_empty_s); -- software can read and verify kernel is loaded

    -- RAM0 read
    --ram0_rd_size <= padded_signal_size_s;
    --ram0_rd_rd_en_s <= ram0_rd_valid and not(sb_full_s);
    --ram0_rd_rd_en <= ram_rd_rd_en_s;

    -- signal buffer
    --sb_rd_en_s <= not(sb_empty_s) and ram1_wr_ready;

    -- anytime we read from input memory, we write into signal buffer. This only works
    -- because of first word fall through for max throughput
    --sb_wr_en_s <= ram0_rd_rd_en_s; 

    --ram1_wr_valid <= valid_out_s and ram1_wr_ready; 
    --ram1_wr_data <= dp_out_s;




    -- memory map entity 




    -- signal buffer entity 
    U_SIG_BUFF: entity work.signal_buffer
        generic map(
            width => 4,
            size  => 4)
        port map( 
            clk => clks(C_CLK_USER),
            rst => rst,
            en => '1', -- TODO may need to change later
            rd_en => sb_rd_en_s(0),
            wr_en => sb_wr_en_s,
            full => sb_full_s,
            empty => sb_empty_s,
            input => ram0_rd_data,
            output => sb_out_s);




    -- kernel buffer using signal buffer entity
    U_KERN_BUFF: entity work.signal_buffer
        generic map(
            width => 4,
            size  => 4)
        port map( 
            clk => clks(C_CLK_USER),
            rst => rst,
            en => '1',
            rd_en => kernel_rd_en_s(0),
            wr_en => kernel_load_s, -- causes a shift by one inside buffer
            full => kernel_full_s,
            empty => kernel_empty_s,
            input => kernel_data_s,
            output => kernel_out_s);




--    -- pipeline
    U_DATAPATH: entity work.mult_add_tree(unsigned_arch)
        generic map(
            num_inputs => C_SIGNAL_WIDTH,
            input1_width => C_SIGNAL_WIDTH,
            input2_width => C_SIGNAL_WIDTH)
        port map (
            clk => clks(C_CLK_USER),
            rst => rst,
            en => ram1_wr_ready, -- stalls the pipeline if output RAM is not ready
            input1 => sb_out_s,
            input2 => kernel_out_s,
            output => dp_out_s);




    -- clipping logic --
    -- if any bit above 16th is 1, output all 1's, else output lower 16 bits
--    process(dp_out_s)
--    begin
--        if (dp_out_s(C_SIGNAL_WIDTH to dp_out_s'range) > 0) then -- TODO this may not work
--            dp_out_s <= (others => '1');                      -- set to all 1's
--            dp_out_clipped_s <= dp_out_s(C_SIGNAL_WIDTH-1 downto 0);     -- clip size to 16 bits
--        else
--            dp_out_clipped_s <= dp_out_s(C_SIGNAL_WIDTH-1 downto 0);
--    end process;




    -- maybe control

end default;
