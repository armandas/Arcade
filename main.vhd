library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity main is
    port(
        clk, not_reset: in std_logic;
        nes_data_1: in std_logic;
        nes_data_2: in std_logic;
        hsync, vsync: out std_logic;
        rgb: out std_logic_vector(2 downto 0);
        buzzer: out std_logic;
        nes_clk_out: out std_logic;
        nes_ps_control: out std_logic
    );
end main;

architecture behaviour of main is
    signal rgb_reg, rgb_next: std_logic_vector(2 downto 0);

    signal px_x, px_y: std_logic_vector(9 downto 0);
    signal video_on: std_logic;

    signal menu_rgb, plong_rgb, fpgalaxy_rgb: std_logic_vector(2 downto 0);
    signal plong_buzzer, fpgalaxy_buzzer: std_logic;

    signal nes1_a, nes1_b, nes1_select, nes1_start,
           nes1_up, nes1_down, nes1_left, nes1_right: std_logic;

    signal nes2_a, nes2_b, nes2_select, nes2_start,
           nes2_up, nes2_down, nes2_left, nes2_right: std_logic;

    -- signals that go into graphics logic
    signal f_nes1_a, f_nes1_b, f_nes1_left, f_nes1_right: std_logic;
    signal p_nes1_up, p_nes1_down, p_nes1_start,
           p_nes2_up, p_nes2_down, p_nes2_start: std_logic;

    -- game selection: 0 - plong, 1 - fpgalaxy
    signal selected_menu: std_logic;
    -- which stream is enabled:
    -- 00: menu
    -- 01: fpgalaxy
    -- 10: plong
    -- 11: don't care
    signal enable, enable_next: std_logic_vector(1 downto 0);

    -- sound events
    signal shot, destroyed,
           ball_bounced, ball_missed: std_logic;

    signal buzzer1, buzzer2: std_logic;
begin

    process(clk, not_reset)
    begin
        if not_reset = '0' then
            rgb_reg <= (others => '0');
            enable <= (others => '0');
        elsif falling_edge(clk) then
            rgb_reg <= rgb_next;
            enable <= enable_next;
        end if;
    end process;

    rgb_next <= plong_rgb when enable = "01" else
                fpgalaxy_rgb when enable = "10" else
                menu_rgb;

    enable_next <= "01" when (enable = "00" and
                              selected_menu = '0' and
                              nes1_select = '1') else
                   "10" when (enable = "00" and
                              selected_menu = '1' and
                              nes1_select = '1') else
                   enable;

    f_nes1_a <= nes1_a when enable = "10" else '0';
    f_nes1_b <= nes1_a when enable = "10" else '0';
    f_nes1_left <= nes1_left when enable = "10" else '0';
    f_nes1_right <= nes1_right when enable = "10" else '0';

    p_nes1_up <= nes1_up when enable = "01" else '0';
    p_nes1_down <= nes1_down when enable = "01" else '0';
    p_nes1_start <= nes1_start when enable = "01" else '0';
    p_nes2_up <= nes2_up when enable = "01" else '0';
    p_nes2_down <= nes2_down when enable = "01" else '0';
    p_nes2_start <= nes2_start when enable = "01" else '0';

    vga:
        entity work.vga(sync)
        port map(
            clk => clk, not_reset => not_reset,
            hsync => hsync, vsync => vsync,
            video_on => video_on, p_tick => open,
            pixel_x => px_x, pixel_y => px_y
        );

    menu:
        entity work.menu(behaviour)
        port map(
            clk => clk, not_reset => not_reset,
            px_x => px_x, px_y => px_y,
            nes_up => nes1_up, nes_down => nes1_down,
            selection => selected_menu,
            rgb_pixel => menu_rgb
        );

    fpgalaxy:
        entity work.fpgalaxy_graphics(dispatcher)
        port map(
            clk => clk, not_reset => not_reset,
            px_x => px_x, px_y => px_y,
            video_on => video_on,
            nes_a => f_nes1_a, nes_b => f_nes1_b,
            nes_left => f_nes1_left, nes_right => f_nes1_right,
            rgb_stream => fpgalaxy_rgb,
            shooting_sound => shot, destruction_sound => destroyed
        );

    plong:
        entity work.plong_graphics(dispatcher)
        port map(
            clk => clk, not_reset => not_reset,
            nes1_up => p_nes1_up, nes1_down => p_nes1_down,
            nes2_up => p_nes2_up, nes2_down => p_nes2_down,
            nes1_start => p_nes1_start,
            nes2_start => p_nes2_start,
            px_x => px_x, px_y => px_y,
            video_on => video_on,
            rgb_stream => plong_rgb,
            ball_bounced => ball_bounced,
            ball_missed => ball_missed
        );

    sound1:
        entity work.player(behaviour)
        port map(
            clk => clk, not_reset => not_reset,
            bump_sound => ball_bounced, miss_sound => ball_missed,
            shooting_sound => shot, explosion_sound => '0',
            buzzer => buzzer2
        );
    -- two units needed for fpgalaxy due to one sound canceling the other
    buzzer <= buzzer1 or buzzer2;
    sound2:
        entity work.player(behaviour)
        port map(
            clk => clk, not_reset => not_reset,
            bump_sound => ball_bounced, miss_sound => ball_missed,
            shooting_sound => '0', explosion_sound => destroyed,
            buzzer => buzzer1
        );

    NES_controller1:
        entity work.controller(arch)
        port map(
            clk => clk, not_reset => not_reset,
            data_in => nes_data_1,
            clk_out => nes_clk_out,
            ps_control => nes_ps_control,
            gamepad(0) => nes1_a,      gamepad(1) => nes1_b,
            gamepad(2) => nes1_select, gamepad(3) => nes1_start,
            gamepad(4) => nes1_up,     gamepad(5) => nes1_down,
            gamepad(6) => nes1_left,   gamepad(7) => nes1_right
        );

    NES_controller2:
        entity work.controller(arch)
        port map(
            clk => clk, not_reset => not_reset,
            data_in => nes_data_2,
            clk_out => open,
            ps_control => open,
            gamepad(0) => nes2_a,      gamepad(1) => nes2_b,
            gamepad(2) => nes2_select, gamepad(3) => nes2_start,
            gamepad(4) => nes2_up,     gamepad(5) => nes2_down,
            gamepad(6) => nes2_left,   gamepad(7) => nes2_right
        );

    rgb <= rgb_reg;

end behaviour;