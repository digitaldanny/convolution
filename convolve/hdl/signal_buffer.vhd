library ieee;
use ieee.std_logic_1164.all;

entity signal_buffer is
  generic( width : positive)
  port( clk      : in  std_logic;
        rst      : in std_logic;
        en       : in std_logic;
        rd_en    : out std_logic;
        wr_en    : out  std_logic;
        full     : out std_logic;
        empty    : out  std_logic;
        input    : in  std_logic;
        output   : out std_logic);
end signal_buffer;


architecture STR of signal_buffer is

begin


end STR;
