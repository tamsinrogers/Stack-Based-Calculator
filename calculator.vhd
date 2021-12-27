-- Tamsin Rogers
-- 10/23/20
-- CS232 Project 6
-- calculator.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity calculator is

	-- calculator port
	port
	( 
        clock: in std_logic;						
        reset: in std_logic; 							-- button 1
        b2:    in std_logic; 							-- capture input (button 2)
        b3:    in std_logic; 							-- enter (button 3)
        b4:    in std_logic; 							-- action (button 4)
        --op:	in std_logic_vector(2 downto 0);			-- action switches (this is the operation)
        --data:  in std_logic_vector(6 downto 0);			-- input data switches (this is the number)
		  
		  switches	:	in std_logic_vector(9 downto 0);
		  
        digit0:	out std_logic_vector(6 downto 0);		-- first digit in display output values
        digit1:	out std_logic_vector(6 downto 0);		-- second digit in display output values
        stackview: out std_logic_vector(3 downto 0);	-- use to debug the stuck
        
        progressLight	 : out	std_logic_vector(5 downto 0);
		  switchLight	 : out	std_logic_vector(9 downto 0)
    );

end entity;

architecture rtl of calculator is

	component memram

	-- memram port
	PORT
	(
		address	: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		wren		: IN STD_LOGIC ;
		q			: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
	
	end component;
	
	component hexDisplay

	-- hexDisplay port
	port 
	(
		a: in STD_LOGIC_VECTOR(3 downto 0);
		result: out STD_LOGIC_VECTOR(6 downto 0)
	);
	
	end component;
	
	-- internal signals
	signal RAM_input	:	std_logic_vector(7 downto 0);	
	signal RAM_output	:	std_logic_vector(7 downto 0);	
	signal RAM_we		:	std_logic;		
	signal stack_ptr	:	unsigned(3 downto 0);
	signal mbr			: 	std_logic_vector(7 downto 0);
	signal state		: 	std_logic_vector(2 downto 0);
	--signal tempreg		: 	std_logic_vector(15 downto 0); 	-- temporary register to hold operand removed from the stack (multiplication result)
	
	signal op	: std_logic_vector(2 downto 0);
	signal data	: std_logic_vector(7 downto 0);

begin

	op <= switches(9 downto 7);
	data <= switches(7 downto 0);

	-- port map statements
	memram1: memram					
		port map
		(
			address => std_logic_vector(stack_ptr),
			clock => clock, 
			data => RAM_input, 
			wren => RAM_we, 
			q => RAM_output
		);
		 
	display1: hexDisplay
		port map(a => mbr(3 downto 0), result => digit0);	-- first digit of mbr result shows up on the first hex display
	
	display2: hexDisplay
		port map(a => mbr(7 downto 4), result => digit1);	-- second digit of mbr result shows up on the second hex display
		
	-- connect internal signals to output signals
	stackview <= std_logic_vector(stack_ptr);
 
	-- logic to advance to the next state
	process (clock, reset)
	begin
	
		if reset = '0' then									-- reset all of the signals
       		stack_ptr <= "0000";
       	 	mbr <= "00000000";
       	 	RAM_input <= "00000000";
        	RAM_we <= '0';
        	state <= "000";
			
		elsif rising_edge(clock) then
			case state is
			
			-- value switches store binary value for entered number in "data"
			
				when "000" =>								-- wait for a button press
					if b2 = '0' then						-- click capture button (2) to move data into the mbr
						mbr <= data;
						state <= "111";
					elsif b3 = '0' then					-- click enter button (3) to push mbr onto the stack
						RAM_input <= mbr;
						RAM_we <= '1';
						state <= "001";
					elsif b4 = '0' then					-- click action button (4) to operate on current mbr (second number entered) and the top value of the stack (first number entered)
						
						if stack_ptr /= "0000" then		-- check that the stack pointer value is not zero
						stack_ptr <= stack_ptr - 1;
							state <= "100";
						end if;
						
					end if;
				
				when "001" =>								-- next step in writing to memory
					RAM_we <= '0';
					if stack_ptr /= "1111" then			-- check that stack isn't full
						stack_ptr <= stack_ptr + 1;		-- stack pointer has the address of the next free memory location
						state <= "111";
					end if;
				
				when "100" =>								-- next step in the read process
					state <= "101";
				
				when "101" =>
					state <= "110";
				
				when "110" =>
					mbr <= RAM_output;
					
					-- operation action switches
					if op = "000" then													-- add
						mbr <= std_logic_vector(unsigned(RAM_output) + unsigned(mbr));
					elsif op = "001" then												-- subtract
						mbr <= std_logic_vector(unsigned(RAM_output) - unsigned(mbr));
					elsif op = "010" then												-- multiply (limit to low 4 bits)
						mbr <= std_logic_vector(unsigned(RAM_output(3 downto 0)) * unsigned(mbr(3 downto 0)));	
					elsif op = "011" then												-- divide
						mbr <= std_logic_vector(unsigned(RAM_output) / unsigned(mbr));
					elsif op = "100" then												-- mod
						mbr <= std_logic_vector(unsigned(RAM_output) mod unsigned(mbr));
					elsif op = "101" then												-- remainder
						mbr <= std_logic_vector(unsigned(RAM_output) rem unsigned(mbr));
					elsif op = "110" then												-- square (limit to low 4 bits)
						mbr <= std_logic_vector(unsigned(mbr(3 downto 0)) * unsigned(mbr(3 downto 0)));
					elsif op = "111" then												-- double (limit to low 4 bits)
						mbr <= std_logic_vector(unsigned(mbr(3 downto 0)) * 2);
					end if;
					
					state <= "111";
				
				when "111" =>
					if ((b2 = '1') and (b3 = '1') and (b4 = '1')) then
						state <= "000";
						end if;
					
				when others =>
					state <= "000";
						
			end case;					
					
		end if;
	end process;
	
	-- light control
	progressLight(0) <= '0' when reset = '1' else '1';
	progressLight(1) <= '0' when b2 = '1' else '1';
	progressLight(2) <= '0' when b3 = '1' else '1';
	progressLight(3) <= '0' when b4 = '1' else '1';
	
	switchLight(0) <= '1' when switches(0) = '1' else '0';
	switchLight(1) <= '1' when switches(1) = '1' else '0';
	switchLight(2) <= '1' when switches(2) = '1' else '0';
	switchLight(3) <= '1' when switches(3) = '1' else '0';
	switchLight(4) <= '1' when switches(4) = '1' else '0';
	switchLight(5) <= '1' when switches(5) = '1' else '0';
	switchLight(6) <= '1' when switches(6) = '1' else '0';
	switchLight(7) <= '1' when switches(7) = '1' else '0';
	switchLight(8) <= '1' when switches(8) = '1' else '0';
	switchLight(9) <= '1' when switches(9) = '1' else '0';
	
	
end rtl;