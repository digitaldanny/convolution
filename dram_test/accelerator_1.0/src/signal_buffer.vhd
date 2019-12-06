library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.user_pkg.all;
use ieee.std_logic_unsigned.all;

entity signal_buffer is
    generic(
        width : positive;
        size  : positive);
    port( 
        clk      : in  std_logic;
        rst      : in std_logic;
        en       : in std_logic;
        rd_en    : out std_logic;
        wr_en    : out  std_logic;
        full     : out std_logic;
        empty    : out  std_logic;
        input    : in std_logic_vector(width-1 downto 0);
        output   : out std_logic_vector(size*width-1 downto 0));
end signal_buffer;

architecture STR of signal_buffer is

    signal count: unsigned(width+1 downto 0);
    type reg_array is array (0 to size-1) of std_logic_vector(width-1 downto 0);
    signal output_array: reg_array;
    --signal output_array: window(0 to size-1); -- uses the array from within user_pkg
    signal empty_s, full_s, rd_en_s, being_read  : std_logic;

begin

    process(clk, rst)
    begin
        if (rst = '1') then

            -- reset logic
            count <= (others => '0'); 

            for i in 0 to size-1 loop
                output_array(i) <= (others => '0');
            end loop;

        elsif (rising_edge(clk)) then

            if (en = '1') then

                if (count < to_unsigned(size, width)) then -- TODO double check width is correct

                    count <= count + 1;
                    empty_s <= '1'; -- not full

                    -- 16-bit input goes to first array element
                    output_array(0) <= input;

                    -- shift elements by 1 and last element gets shifted out
                    -- this may need to be size-2, but that would always shift the entire array even when it's all 0's
                    for i in 0 to 2 loop
                        output_array(i+1) <= output_array(i);
                    end loop;

                else
                    -- reset count to 0
                    empty_s <= '0'; 
                    count 	<= (others => '0');
                    full_s <= '1'; -- count == 128
                    rd_en_s <= '1';
                end if;
            end if;
        end if;
    end process;


    -- smart buffer is full, ready to send window
    rd_en <= rd_en_s;
    empty <= empty_s;
    full <= full_s AND not(rd_en_s);


    -- vectorize array because datapath needs std_logic_vector
    process(output_array)
    begin
        for i in 0 to size-1 loop
            -- stores entire window
            output((i+1)*width-1 downto i*width) <= output_array(i);
        end loop;
    end process;

end STR;
