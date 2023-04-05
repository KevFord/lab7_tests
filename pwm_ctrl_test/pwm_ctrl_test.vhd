--////////////////////////////////////////////////////////
--  PWM Control unit.
--  Receives inputs from both physical buttons and over UART, reports the current Duty Cycle (DC) to the DC Ctrl component which
-- displays the value on three 7-segment displays.
--  The PWM output controls a led onboard the DE1 board with a period of 1 ms.
--
--  Author: Kevin Fordal
--
--////////////////////////////////////////////////////////

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity pwm_ctrl_test is
generic(
        g_period_time   : integer := 50000 - 1;
        g_compare       : integer := 500 - 1 -- Two orders of magnitude less than the period, to avoid having to use division
);
port(
    -- Inputs
        clk_50          : in std_logic; -- 50 MHz clock.

        reset           : in std_logic; -- Active high.

-- ///////////////// Block diagram A
    -- Key inputs will be pulsed high one clock pulse and key_up, key_down may be pulsed every 10 ms, indicating the key is being held.
        key_on              : in std_logic; -- Go back to previous DC (minimum 10%). Reset sets previous to 100%
        key_off             : in std_logic; -- Set current DC to 0%
        key_up              : in std_logic; -- Increase DC by 1%, 100% is maximum, minimum is 10%. If the unit is off, DC shall be set to 10% if this signal is received
        key_down            : in std_logic; -- Decrease DC by 1%, if unit is in the off state this signal is ignored

-- ///////////////// Block diagram C
    -- Inputs from the UART component. They have the same functionality as the key inputs but key inputs have priority.
        serial_on           : in std_logic; -- Go back to previous DC (minimum 10%). Reset sets previous to 100%
        serial_off          : in std_logic; -- Set current DC to 0%
        serial_up           : in std_logic; -- Increase DC by 1%, 100% is maximum, minimum is 10%. If the unit is off, DC shall be set to 10% if this signal is received
        serial_down         : in std_logic; -- Decrease DC by 1%, if unit is in the off state this signal is ignored

-- ///////////////// Block diagram D
    -- Outputs  
        current_dc          : out std_logic_vector(7 downto 0); -- A byte representing the current duty cycle. range 0 - 100
        current_dc_update   : out std_logic; -- A flag
-- PWM out
        ledg0               : out std_logic -- Output led. 1 ms period.
);
end entity pwm_ctrl_test;

architecture rtl of pwm_ctrl_test is

    type t_pwm_state is (
        s_pwm_idle,
        s_pwm_high,
        s_pwm_low,
        s_pwm_reset
    );

    signal pwm_state                : t_pwm_state := s_pwm_idle;

    signal count_pwm_period_time    : integer range 0 to g_period_time := g_period_time; -- 1 ms period time.
    signal count_pwm_compare        : integer := g_period_time; -- Set to period_time * duty cycle.
    signal current_pwm_duty_cycle   : integer range 0 to 100 := 10; -- Duty cycle, controlled by the inputs above.
    signal previous_duty_cycle      : integer range 0 to 100 := 0;

    signal init_pwm_value_flag      : std_logic := '1';

begin

    p_pwm_dc_control    : process(clk_50) is
    begin
        if rising_edge(clk_50) then
            if key_down = '1' or serial_down = '1' then
                if current_pwm_duty_cycle > 10 then
                    current_pwm_duty_cycle <= current_pwm_duty_cycle - 1;
                    previous_duty_cycle <= current_pwm_duty_cycle;
                end if;

            elsif key_up = '1' or serial_up = '1' then
                if current_pwm_duty_cycle < 100 then
                    current_pwm_duty_cycle <= current_pwm_duty_cycle + 1;
                    previous_duty_cycle <= current_pwm_duty_cycle;
                end if;

            elsif key_on = '1' or serial_on = '1' then
                if previous_duty_cycle > 10 then
                    current_pwm_duty_cycle <= previous_duty_cycle;
                else 
                    current_pwm_duty_cycle <= 10;
                    previous_duty_cycle <= 10;
                end if;

            elsif key_off = '1' or serial_off = '1' then
                current_pwm_duty_cycle <= 0;
            end if;
        end if;

        -- Reset
        if reset = '1' then
            previous_duty_cycle <= 100;
            current_pwm_duty_cycle <= 0; -- Set DC to 0. (or 100%)?
            --current_dc_update <= '1'; -- Set flag.
            --current_dc <= std_logic_vector(to_unsigned(current_pwm_duty_cycle, 8)); -- Report the change in DC.
        end if;
    end process p_pwm_dc_control;

    p_pwm_generation    : process(clk_50) is
    begin
        if rising_edge(clk_50) then
            if init_pwm_value_flag = '1' then
                -- set count compare to period time * duty cycle. Initial setup, gets run once.
                count_pwm_compare <= g_compare * current_pwm_duty_cycle;
                current_dc <= std_logic_vector(to_unsigned(current_pwm_duty_cycle, 8)); -- Report the change in DC.
                current_dc_update <= '1'; -- Set flag.
            else 
                init_pwm_value_flag <= '0';
                current_dc_update <= '0'; -- Reset flag.
            end if;

            if count_pwm_period_time = 0 then -- Stuff in here gets done once per ms
            -- set count compare to period time * duty cycle.
                count_pwm_compare <= g_compare * current_pwm_duty_cycle;
                count_pwm_period_time <= g_period_time;
                current_dc <= std_logic_vector(to_unsigned(current_pwm_duty_cycle, 8)); -- Report the change in DC.
                current_dc_update <= '1'; -- Set flag.
            else 
                -- Decrement counter.
                count_pwm_period_time <= count_pwm_period_time - 1;
                current_dc_update <= '0'; -- Reset flag.
            end if;
            -- Compare current counter value to the desired duty cycle and then either turn on or off the output.
            if count_pwm_period_time > count_pwm_compare then
                ledg0 <= '1'; -- Output on
            else
                ledg0 <= '0'; -- Output off
            end if;
        end if;
    end process p_pwm_generation;

end architecture;