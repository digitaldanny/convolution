library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.user_pkg.all;
use ieee.std_logic_unsigned.all;
use work.math_custom.all;

entity signal_buffer is
    generic(
        width : positive := 16;
        size  : positive := 128);
    port( 
        clk      : in std_logic;
        rst      : in std_logic;
        rd_en    : in std_logic;
        wr_en    : in std_logic;
        full     : out std_logic;
        empty    : out std_logic;
        input    : in std_logic_vector(width-1 downto 0);
        output   : out std_logic_vector(size*width-1 downto 0));
end signal_buffer;

architecture STR of signal_buffer is

    type reg_array is array (0 to size-1) of std_logic_vector(width-1 downto 0);
    signal output_array: reg_array;
    constant max_bits : positive := clog2(C_KERNEL_SIZE+1);

	signal count      : unsigned(max_bits-1 downto 0);
    signal empty_s    : std_logic;
    signal full_s     : std_logic;

begin

    process(clk, rst)
    begin

        if (rst = '1') then

            -- reset logic
            count <= (others => '0'); 
            empty_s <= '1';
            full_s <= '0';

            -- clear each index in array
            for i in 0 to size-1 loop
                output_array(i) <= (others => '0');
            end loop;

        elsif (rising_edge(clk)) then

            -- reads data into buffer and shifts
            -- if wr_en and rd_en asserted, wr_en gets priority 
            if (wr_en = '1') then

                -- count is less that size, so update count and shift elements
                if (count < to_unsigned(size, max_bits)) then
                    count <= count + 1;
                    empty_s <= '1'; -- not full
                    full_s <= '0';

                    -- input goes to first array element
                    output_array(0) <= input;

                    -- shift elements by 1 and last element gets shifted out
                    for i in 0 to size-2 loop
                        output_array(i+1) <= output_array(i);
                    end loop;

                -- count == 128
                elsif (count = to_unsigned(size, max_bits)) then
                    empty_s <= '0';
                    full_s <= '1';

                end if;

            elsif (rd_en = '1') then
                if (count <= to_unsigned(size, max_bits)) then
                    -- decrement since we can read 1 more element
                    count <= count - 1;
                    empty_s <= '1';
                    full_s <= '0';
                end if;
            end if;
        end if;
    end process;

    empty <= empty_s;

    -- if rd_en is asserted, then buffer will never be full since
    -- it reads and writes a window in the same cycle
    full <= full_s and not(rd_en); 
    



    -- vectorize array because datapath needs std_logic_vector
    U_OUTPUT_VECTOR : for i in 0 to size-1 generate
        -- stores entire window
        output((i+1)*width-1 downto i*width) <= output_array(i);
    end generate;

end STR;
