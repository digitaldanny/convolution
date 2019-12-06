-- Daniel Hamilton & Michael Thomas

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity addr_gen is
  generic(width :     positive);
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
	start_addr 	: in  std_logic_vector(width-1 downto 0);
    size        : in  std_logic_vector(width downto 0);
	addr        : out std_logic_vector(width-1 downto 0);
	
	dram_rdy 	: in  std_logic; -- dram side 'go' signal (12/5/19)
    go          : in  std_logic; -- user side 'go' signal
    stall       : in  std_logic;
	
    valid       : out std_logic;
    done        : out std_logic);
end addr_gen;

architecture BHV of addr_gen is

  type state_type is (S_INIT, S_PREP, S_EXECUTE);
  signal state, next_state : state_type;

  signal size_reg, next_size_reg : unsigned(width downto 0);
  signal addr_s, next_addr_s     : std_logic_vector(width downto 0);

begin  -- BHV

  process (clk, rst)
  begin
    if (rst = '1') then
      addr_s   <= (others => '0');
      size_reg <= (others => '0');
      state    <= S_INIT;
    elsif (clk'event and clk = '1') then
      addr_s   <= next_addr_s;
      size_reg <= next_size_reg;
      state    <= next_state;
    end if;
  end process;

  process(addr_s, size_reg, size, state, go, stall)
  begin

    next_state    <= state;
    next_addr_s   <= addr_s;
    next_size_reg <= size_reg;
    done          <= '1';

    case state is
	
	  -- +=====+=====+=====+=====+=====+=====+=====+=====+=====+
	  -- INIT: Reset state - infinite loop until 'go' signal is
	  -- set high.
	  -- +=====+=====+=====+=====+=====+=====+=====+=====+=====+
      when S_INIT =>

        next_addr_s <= std_logic_vector(to_unsigned(0, width+1));
        valid       <= '0';

        if (go = '1') then
          done          <= '0';
		  next_state    <= S_PREP;
        end if;
		
	  -- +=====+=====+=====+=====+=====+=====+=====+=====+=====+
	  -- PREP: Done has been set and waiting in this state for 
	  -- dram_rdy to be set high.
	  -- +=====+=====+=====+=====+=====+=====+=====+=====+=====+	  
	  when S_PREP =>

        next_addr_s <= std_logic_vector(to_unsigned(0, width+1));
        valid       <= '0';	  
	  
	    if (dram_rdy = '1') then
          done          <= '0';
		  next_addr_s 	<= start_addr; -- first address is at the starting addr (12/5/19)
          next_size_reg <= unsigned(size);
          next_state    <= S_EXECUTE;
        end if;

	  -- +=====+=====+=====+=====+=====+=====+=====+=====+=====+
	  -- EXECUTE: 
	  -- ~ 	This state will increment the output address if still 
	  -- 	less than the requested size. 
	  -- ~ 	The state can also stall, continuing to output the same
	  -- 	address until the 'stall' signal goes low again.
	  -- ~  Once 'size' number of addresses has been output, the state
	  -- 	will return to INIT.
	  -- +=====+=====+=====+=====+=====+=====+=====+=====+=====+
      when S_EXECUTE =>

        valid <= '1';
        done  <= '0';

        if (unsigned(addr_s) = size_reg) then
          done        <= '1';
          next_state  <= S_INIT;
        elsif (stall = '0') then
          next_addr_s <= std_logic_vector(unsigned(addr_s)+1);
        elsif (stall = '1') then
          valid <= '0';
        end if;

      when others => null;
    end case;

  end process;

  addr <= addr_s(width-1 downto 0);

end BHV;

