library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity menu is
    port(
        clk, not_reset: in std_logic;
        px_x, px_y: in std_logic_vector(9 downto 0);
        nes_up, nes_down: in std_logic;
        selection: out std_logic;
        rgb_pixel: out std_logic_vector(2 downto 0)
    );
end menu;

architecture behaviour of menu is
    type rom_type is array(0 to 32) of std_logic_vector(8 downto 0);
    constant CREDITS: rom_type :=
    (
        "000000000",
        "100001000",
        "110010000",
        "101101000",
        "100001000",
        "101110000",
        "100100000",
        "100001000",
        "110011000",
        "000000000",
        "101010000",
        "100001000",
        "110010000",
        "110101000",
        "110011000",
        "100001000",
        "110101000",
        "110011000",
        "101011000",
        "100001000",
        "110011000",
        "001100000",
        "000000000",
        "010010000",
        "010000000",
        "010001000",
        "010000000",
        "000000000",
        "000000000",
        "000000000",
        "000000000",
        "000000000",
        "000000000"
    );

    signal credits_addr: std_logic_vector(6 downto 0);

    signal font_addr: std_logic_vector(8 downto 0);
    signal font_data: std_logic_vector(0 to 7);
    signal font_pixel: std_logic;
    -- logo pixel is separate because of scaling
    signal logo_pixel: std_logic;

    signal arrow_pos, arrow_pos_next: std_logic;

    signal logo_on,
           plong_text_on,
           fpgalaxy_text_on,
           arrow_on,
           credits_on,
           hr_on: std_logic;

    signal logo_font_addr,
           plong_text_font_addr,
           fpgalaxy_text_font_addr,
           arrow_font_addr: std_logic_vector(8 downto 0);

    signal logo_rgb, font_rgb: std_logic_vector(2 downto 0);
begin

    process(clk, not_reset)
    begin
        if not_reset = '0' then
            arrow_pos <= '0';
        elsif falling_edge(clk) then
            arrow_pos <= arrow_pos_next;
        end if;
    end process;

    logo_on <= '1' when (px_x >= 128 and
                         px_x < 512 and
                         px_y >= 64 and
                         px_y < 128) else
               '0';

    plong_text_on <= '1' when (px_x >= 280 and
                               px_x < 320 and
                               px_y >= 272 and
                               px_y < 280) else
                     '0';   

    fpgalaxy_text_on <= '1' when (px_x >= 280 and
                                  px_x < 344 and
                                  px_y >= 288 and
                                  px_y < 296) else
                        '0';

    arrow_pos_next <= '1' when nes_down = '1' else
                      '0' when nes_up = '1' else
                      arrow_pos;

    arrow_on <= '1' when (arrow_pos = '0' and
                          px_x >= 264 and
                          px_x < 272 and
                          px_y >= 272 and
                          px_y < 280) or
                         (arrow_pos = '1' and
                          px_x >= 264 and
                          px_x < 272 and
                          px_y >= 288 and
                          px_y < 296) else
                '0';

    credits_on <= '1' when (px_x >= 0 and
                            px_x < 256 and
                            px_y >= 472 and
                            px_y < 480) else
                  '0';

    -- horizontal rule
    hr_on <= '1' when px_y > 470 else '0';

    with px_x(9 downto 6) select
        logo_font_addr <= "010010000" when "0010", -- 2
                          "101001000" when "0100", -- I
                          "101110000" when "0101", -- N
                          "010001000" when "0111", -- 1
                          "000000000" when others;    -- spaces

    with px_x(9 downto 3) select
        plong_text_font_addr <= "110000000" when "0100011", -- P
                                "101100000" when "0100100", -- L
                                "101111000" when "0100101", -- O
                                "101110000" when "0100110", -- N
                                "100111000" when "0100111", -- G
                                "000000000" when others;

    with px_x(9 downto 3) select
        fpgalaxy_text_font_addr <= "100110000" when "0100011", -- F
                                   "110000000" when "0100100", -- P
                                   "100111000" when "0100101", -- G
                                   "100001000" when "0100110", -- A
                                   "101100000" when "0100111", -- L
                                   "100001000" when "0101000", -- A
                                   "111000000" when "0101001", -- X
                                   "111001000" when "0101010", -- Y
                                   "000000000" when others;
    -- single symbol
    arrow_font_addr <= "111100000";

    credits_addr <= px_x(9 downto 3) when px_x(9 downto 3) < 33 else
                    (others => '0');

    font_addr <= px_y(5 downto 3) + logo_font_addr when logo_on = '1' else
                 px_y(2 downto 0) + plong_text_font_addr when plong_text_on = '1' else
                 px_y(2 downto 0) + fpgalaxy_text_font_addr when fpgalaxy_text_on = '1' else
                 px_y(2 downto 0) + arrow_font_addr when arrow_on = '1' else
                 px_y(2 downto 0) + CREDITS(conv_integer(credits_addr)) when credits_on = '1' else
                 (others => '0');

    logo_pixel <= font_data(conv_integer(px_x(5 downto 3)));
    logo_rgb <= "111" when logo_pixel = '1' else "000";

    font_pixel <= font_data(conv_integer(px_x(2 downto 0)));
    font_rgb <= "111" when font_pixel = '1' else "000";

    rgb_pixel <= logo_rgb when logo_on = '1' else
                 font_rgb when (plong_text_on = '1' or
                                fpgalaxy_text_on = '1' or
                                arrow_on = '1') else
                 not font_rgb when credits_on = '1' else
                 "111" when hr_on = '1' else
                 (others => '0');

    selection <= arrow_pos;

    codepage:
        entity work.codepage_rom(content)
        port map(addr => font_addr, data => font_data);

end behaviour;