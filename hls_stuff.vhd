library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity ook_demodulator is
    Generic (
        -- Goertzel Parameters
        N : integer := 8;                    -- Block length
        SAMPLE_FREQ : real := 1.0e6;        -- Sample frequency (Hz)
        TARGET_FREQ : real := 100.0e3;      -- Target frequency (Hz)
        DATA_WIDTH : integer := 16;          -- Input data width
        COEFF_WIDTH : integer := 18          -- Coefficient width
    );
    Port (
        clk : in std_logic;
        rst : in std_logic;
        
        -- Input signal
        data_in : in signed(DATA_WIDTH-1 downto 0);
        data_valid : in std_logic;
        
        -- Output
        ook_out : out std_logic;
        magnitude : out unsigned(DATA_WIDTH-1 downto 0);
        data_ready : out std_logic
    );
end ook_demodulator;

architecture Behavioral of ook_demodulator is
    
    -- Goertzel coefficient: 2*cos(2*pi*k/N) where k = TARGET_FREQ/SAMPLE_FREQ * N
    constant K : real := TARGET_FREQ / SAMPLE_FREQ * real(N);
    constant COEFF_REAL : real := 2.0 * cos(2.0 * MATH_PI * K / real(N));
    constant COEFF : signed(COEFF_WIDTH-1 downto 0) := 
        to_signed(integer(COEFF_REAL * real(2**(COEFF_WIDTH-2))), COEFF_WIDTH);
    
    -- State machine
    type state_type is (IDLE, ACCUMULATE, COMPUTE_OUTPUT);
    signal state : state_type := IDLE;
    
    -- Goertzel algorithm registers
    signal s0, s1, s2 : signed(DATA_WIDTH+COEFF_WIDTH-1 downto 0) := (others => '0');
    signal sample_count : integer range 0 to N := 0;
    
    -- Magnitude calculation
    signal real_part : signed(DATA_WIDTH+COEFF_WIDTH-1 downto 0);
    signal imag_part : signed(DATA_WIDTH+COEFF_WIDTH-1 downto 0);
    signal mag_squared : unsigned(2*(DATA_WIDTH+COEFF_WIDTH)-1 downto 0);
    signal mag_out : unsigned(DATA_WIDTH-1 downto 0);
    
    -- Threshold for OOK detection
    signal threshold : unsigned(DATA_WIDTH-1 downto 0) := to_unsigned(1000, DATA_WIDTH);
    
    -- Delay registers for filtering
    signal mag_delayed : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');
    
    -- Sine and cosine for final computation
    constant COS_VAL : real := cos(2.0 * MATH_PI * K / real(N));
    constant SIN_VAL : real := sin(2.0 * MATH_PI * K / real(N));
    constant COS_COEFF : signed(COEFF_WIDTH-1 downto 0) := 
        to_signed(integer(COS_VAL * real(2**(COEFF_WIDTH-1))), COEFF_WIDTH);
    constant SIN_COEFF : signed(COEFF_WIDTH-1 downto 0) := 
        to_signed(integer(SIN_VAL * real(2**(COEFF_WIDTH-1))), COEFF_WIDTH);

begin

    -- Main Goertzel process
    process(clk)
        variable temp : signed(DATA_WIDTH+2*COEFF_WIDTH-1 downto 0);
        variable real_temp, imag_temp : signed(DATA_WIDTH+2*COEFF_WIDTH-1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                s0 <= (others => '0');
                s1 <= (others => '0');
                s2 <= (others => '0');
                sample_count <= 0;
                data_ready <= '0';
                ook_out <= '0';
                
            else
                data_ready <= '0';
                
                case state is
                    when IDLE =>
                        if data_valid = '1' then
                            -- Reset for new block
                            s1 <= (others => '0');
                            s2 <= (others => '0');
                            sample_count <= 0;
                            state <= ACCUMULATE;
                        end if;
                    
                    when ACCUMULATE =>
                        if data_valid = '1' then
                            -- Goertzel recursion: s[n] = x[n] + coeff*s[n-1] - s[n-2]
                            temp := (COEFF * s1) / (2**(COEFF_WIDTH-2));
                            s0 <= resize(data_in, s0'length) + temp(s0'range) - s2;
                            s2 <= s1;
                            s1 <= s0;
                            
                            sample_count <= sample_count + 1;
                            
                            if sample_count = N-1 then
                                state <= COMPUTE_OUTPUT;
                            end if;
                        end if;
                    
                    when COMPUTE_OUTPUT =>
                        -- Compute real and imaginary parts
                        -- Real: s1 - s2*cos(2πk/N)
                        -- Imag: s2*sin(2πk/N)
                        real_temp := (s2 * COS_COEFF) / (2**(COEFF_WIDTH-1));
                        real_part <= s1 - real_temp(real_part'range);
                        
                        imag_temp := (s2 * SIN_COEFF) / (2**(COEFF_WIDTH-1));
                        imag_part <= imag_temp(imag_part'range);
                        
                        -- Compute magnitude squared: real^2 + imag^2
                        mag_squared <= unsigned(real_part * real_part + imag_part * imag_part);
                        
                        -- Approximate square root (right shift for simplification)
                        -- For better accuracy, implement CORDIC or Newton-Raphson
                        mag_out <= mag_squared(DATA_WIDTH+COEFF_WIDTH-1 downto COEFF_WIDTH);
                        
                        -- Simple delay for filtering
                        mag_delayed <= mag_out;
                        magnitude <= mag_out;
                        
                        -- OOK decision based on threshold
                        if mag_out > threshold then
                            ook_out <= '1';
                        else
                            ook_out <= '0';
                        end if;
                        
                        data_ready <= '1';
                        state <= IDLE;
                        
                end case;
            end if;
        end if;
    end process;

end Behavioral;


-- Testbench
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity ook_demodulator_tb is
end ook_demodulator_tb;

architecture Behavioral of ook_demodulator_tb is
    constant CLK_PERIOD : time := 10 ns;
    constant N : integer := 8;
    constant SAMPLE_FREQ : real := 100.0e6;
    constant TARGET_FREQ : real := 10.0e6;
    constant DATA_WIDTH : integer := 16;
    
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal data_in : signed(DATA_WIDTH-1 downto 0) := (others => '0');
    signal data_valid : std_logic := '0';
    signal ook_out : std_logic;
    signal magnitude : unsigned(DATA_WIDTH-1 downto 0);
    signal data_ready : std_logic;
    
begin
    
    uut: entity work.ook_demodulator
        generic map (
            N => N,
            SAMPLE_FREQ => SAMPLE_FREQ,
            TARGET_FREQ => TARGET_FREQ,
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk => clk,
            rst => rst,
            data_in => data_in,
            data_valid => data_valid,
            ook_out => ook_out,
            magnitude => magnitude,
            data_ready => data_ready
        );
    
    clk <= not clk after CLK_PERIOD/2;
    
    stim_proc: process
        variable seed1, seed2 : positive := 1;
        variable rand : real;
    begin
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;
        
        -- Generate test signal with OOK modulation
        for i in 0 to 100 loop
            uniform(seed1, seed2, rand);
            -- Simulate OOK signal: carrier present or absent
            if (i mod 20) < 10 then
                -- Carrier present
                data_in <= to_signed(integer(10000.0 * sin(2.0 * MATH_PI * TARGET_FREQ * real(i) / SAMPLE_FREQ)), DATA_WIDTH);
            else
                -- Carrier absent (noise only)
                data_in <= to_signed(integer(500.0 * (rand - 0.5)), DATA_WIDTH);
            end if;
            data_valid <= '1';
            wait for CLK_PERIOD;
        end loop;
        
        wait;
    end process;

end Behavioral;
