# bend-tty: the proofs. Every law is closed, so each is {==}: the
# checker runs the decoder, or Level.detect, and compares.

import Base
import ./tty.bend as T
import ./color.bend as C
import ./text.bend as X
import ./LAWS.bend as Laws

def Laws.keys_plain():
  {==}

def Laws.keys_up():
  {==}

def Laws.keys_arrows():
  {==}

def Laws.keys_delete():
  {==}

def Laws.keys_pages():
  {==}

def Laws.keys_enter():
  {==}

def Laws.keys_ctrl():
  {==}

def Laws.keys_esc():
  {==}

def Laws.keys_home_end():
  {==}

def Laws.keys_insert():
  {==}

def Laws.keys_fkeys():
  {==}

def Laws.keys_modified():
  {==}

def Laws.keys_unknown_csi():
  {==}

def Laws.keys_bad_utf8():
  {==}

def Laws.keys_utf8():
  {==}

def Laws.keys_nil():
  {==}

def Laws.detect_empty():
  {==}

def Laws.detect_term_256():
  {==}

def Laws.detect_term_256_pipe():
  {==}

def Laws.detect_term_xterm():
  {==}

def Laws.detect_dumb():
  {==}

def Laws.detect_dumb_forced():
  {==}

def Laws.detect_force_0():
  {==}

def Laws.detect_force_false():
  {==}

def Laws.detect_force_3_pipe():
  {==}

def Laws.detect_force_007():
  {==}

def Laws.detect_force_9():
  {==}

def Laws.detect_force_1_256():
  {==}

def Laws.detect_force_empty_pipe():
  {==}

def Laws.detect_force_junk():
  {==}

def Laws.detect_force_junk_pipe():
  {==}

def Laws.detect_colorterm_truecolor():
  {==}

def Laws.detect_colorterm_24bit():
  {==}

def Laws.detect_colorterm_24bit_xterm():
  {==}

def Laws.detect_colorterm_any():
  {==}

def Laws.detect_github_pipe():
  {==}

def Laws.detect_github():
  {==}

def Laws.detect_travis():
  {==}

def Laws.detect_ci_empty():
  {==}

def Laws.detect_codeship():
  {==}

def Laws.detect_azure_pipe():
  {==}

def Laws.detect_teamcity_9_1():
  {==}

def Laws.detect_teamcity_9_0():
  {==}

def Laws.detect_teamcity_2017():
  {==}

def Laws.detect_teamcity_8():
  {==}

def Laws.detect_iterm_3():
  {==}

def Laws.detect_iterm_2():
  {==}

def Laws.detect_iterm_noversion():
  {==}

def Laws.detect_apple():
  {==}

def Laws.detect_vscode():
  {==}

def Laws.detect_kitty():
  {==}

def Laws.detect_ghostty():
  {==}

def Laws.detect_wezterm():
  {==}

def Laws.detect_screen():
  {==}

def Laws.detect_linux():
  {==}

def Laws.detect_rxvt_256():
  {==}

def Laws.detect_upper_vt100():
  {==}

def Laws.detect_upper_256():
  {==}

def Laws.detect_has_color():
  {==}

def Laws.detect_no_color():
  {==}

def Laws.detect_no_color_empty():
  {==}

def Laws.detect_no_color_force_1():
  {==}

def Laws.detect_no_color_force_true():
  {==}

def Laws.detect_no_color_azure():
  {==}

def Laws.detect_flag_no_color():
  {==}

def Laws.detect_flag_no_color_env_3():
  {==}

def Laws.detect_flag_color_pipe():
  {==}

def Laws.detect_flag_color_dumb():
  {==}

def Laws.detect_flag_256_pipe():
  {==}

def Laws.detect_flag_16m():
  {==}

def Laws.detect_flag_16m_force_0():
  {==}

def Laws.detect_flag_color_no_color():
  {==}

def Laws.color_basic(l, n):
  match l:
    case C.Level.None{}:
      {==}
    case C.Level.Basic{}:
      {==}
    case C.Level.Ansi256{}:
      {==}
    case C.Level.TrueColor{}:
      {==}

def Laws.color_default(l):
  match l:
    case C.Level.None{}:
      {==}
    case C.Level.Basic{}:
      {==}
    case C.Level.Ansi256{}:
      {==}
    case C.Level.TrueColor{}:
      {==}

def Laws.color_truecolor(c):
  match c:
    case C.Color.Default{}:
      {==}
    case C.Color.Basic{n}:
      {==}
    case C.Color.Ansi256{n}:
      {==}
    case C.Color.Rgb{r, g, b}:
      {==}

def Laws.color_256(n):
  {==}

def Laws.color_idempotent(l, c):
  match l c:
    case C.Level.None{} C.Color.Default{}:
      {==}
    case C.Level.None{} C.Color.Basic{n}:
      {==}
    case C.Level.None{} C.Color.Ansi256{n}:
      {==}
    case C.Level.None{} C.Color.Rgb{r, g, b}:
      {==}
    case C.Level.Basic{} C.Color.Default{}:
      {==}
    case C.Level.Basic{} C.Color.Basic{n}:
      {==}
    case C.Level.Basic{} C.Color.Ansi256{n}:
      {==}
    case C.Level.Basic{} C.Color.Rgb{r, g, b}:
      {==}
    case C.Level.Ansi256{} C.Color.Default{}:
      {==}
    case C.Level.Ansi256{} C.Color.Basic{n}:
      {==}
    case C.Level.Ansi256{} C.Color.Ansi256{n}:
      {==}
    case C.Level.Ansi256{} C.Color.Rgb{r, g, b}:
      {==}
    case C.Level.TrueColor{} C.Color.Default{}:
      {==}
    case C.Level.TrueColor{} C.Color.Basic{n}:
      {==}
    case C.Level.TrueColor{} C.Color.Ansi256{n}:
      {==}
    case C.Level.TrueColor{} C.Color.Rgb{r, g, b}:
      {==}

def Laws.color_none(c, bg):
  {==}

def Laws.color_rgb_256():
  {==}

def Laws.color_256_16():
  {==}

def Laws.color_rgb_16():
  {==}

def Laws.color_hex():
  {==}

def Laws.color_escapes():
  {==}

def Laws.paint_none(st, s):
  {==}

def Laws.paint_empty_all(l, st):
  match l:
    case C.Level.None{}:
      {==}
    case C.Level.Basic{}:
      {==}
    case C.Level.Ansi256{}:
      {==}
    case C.Level.TrueColor{}:
      {==}

def Laws.paint_red():
  {==}

def Laws.paint_red_bold():
  {==}

def Laws.paint_nest_fg():
  {==}

def Laws.paint_nest_bold_dim():
  {==}

def Laws.paint_newline():
  {==}

def Laws.paint_crlf():
  {==}

def Laws.paint_trailing_newline():
  {==}

def Laws.paint_empty():
  {==}

def Laws.paint_level_none():
  {==}

def Laws.paint_hex_256():
  {==}

def Laws.paint_hex_16():
  {==}

def Laws.paint_hex_true():
  {==}

def Laws.paint_bg_underline():
  {==}

def Laws.paint_all_modifiers():
  {==}

def Laws.paint_reopen_two():
  {==}

def Laws.paint_deep():
  {==}

def Laws.paint_inverse_italic():
  {==}

def Laws.paint_fg_bg_lines():
  {==}

def Laws.paint_bg_hex_256():
  {==}

def Laws.paint_other_escape():
  {==}

def Laws.paint_ansi256_16():
  {==}

def Laws.paint_ansi256_256():
  {==}

def Laws.paint_rgb_true_nest():
  {==}

def Laws.paint_nest_inner_newline():
  {==}

def Laws.text_truncate_zero(s, c):
  {==}

def Laws.text_styled_width():
  {==}

def Laws.text_styled_strip():
  {==}

def Laws.text_wrap_fits():
  {==}

def Laws.w_ascii():
  {==}

def Laws.w_cjk():
  {==}

def Laws.w_decomposed():
  {==}

def Laws.w_thumbs_tone():
  {==}

def Laws.w_heart_vs16():
  {==}

def Laws.w_heart():
  {==}

def Laws.w_flag():
  {==}

def Laws.w_lone_ri():
  {==}

def Laws.w_family():
  {==}

def Laws.w_hangul_jamo():
  {==}

def Laws.w_hangul():
  {==}

def Laws.w_fullwidth():
  {==}

def Laws.w_watch_vs15():
  {==}

def Laws.w_watch():
  {==}

def Laws.w_keycap():
  {==}

def Laws.w_styled():
  {==}

def Laws.w_link():
  {==}

def Laws.w_tab():
  {==}

def Laws.w_cafe():
  {==}

def Laws.w_japanese():
  {==}

def Laws.w_halfwidth_dakuten():
  {==}

def Laws.w_devanagari():
  {==}

def Laws.w_stray_tone():
  {==}

def Laws.w_zwsp():
  {==}

def Laws.w_mixed():
  {==}

def Laws.w_empty():
  {==}

def Laws.w_rocket():
  {==}

def Laws.w_ellipsis():
  {==}

def Laws.w_box():
  {==}

def Laws.w_thai():
  {==}

def Laws.s_sgr():
  {==}

def Laws.s_osc_title():
  {==}

def Laws.s_save_restore():
  {==}

def Laws.s_charset():
  {==}

def Laws.s_private_csi():
  {==}

def Laws.s_dcs():
  {==}

def Laws.s_link_st():
  {==}

def Laws.s_link_bel():
  {==}

def Laws.s_open_osc():
  {==}

def Laws.s_open_dcs():
  {==}

def Laws.s_lone_esc():
  {==}

def Laws.s_esc_letter():
  {==}

def Laws.s_csi_bad():
  {==}

def Laws.l_plain():
  {==}

def Laws.l_styled_in():
  {==}

def Laws.l_wide_end():
  {==}

def Laws.l_wide_start():
  {==}

def Laws.l_wide_whole():
  {==}

def Laws.l_styled_all():
  {==}

def Laws.l_pending_open():
  {==}

def Laws.l_nested():
  {==}

def Laws.l_link():
  {==}

def Laws.l_emoji():
  {==}

def Laws.l_past():
  {==}

def Laws.l_empty_range():
  {==}

def Laws.l_bold_dim():
  {==}

def Laws.l_tone():
  {==}

def Laws.l_mark():
  {==}

def Laws.r_words():
  {==}

def Laws.r_styled():
  {==}

def Laws.r_hard():
  {==}

def Laws.r_soft_long():
  {==}

def Laws.r_tab():
  {==}

def Laws.r_cjk():
  {==}

def Laws.r_cjk_soft():
  {==}

def Laws.r_spaces():
  {==}

def Laws.r_leading():
  {==}

def Laws.r_trailing():
  {==}

def Laws.r_crlf():
  {==}

def Laws.r_empty_lines():
  {==}

def Laws.r_blank_line():
  {==}

def Laws.r_nested():
  {==}

def Laws.r_link():
  {==}

def Laws.r_emoji():
  {==}

def Laws.r_exact():
  {==}

def Laws.r_hard_exact():
  {==}

def Laws.r_close_at_break():
  {==}

def Laws.r_bg():
  {==}

def Laws.t_end():
  {==}

def Laws.t_start():
  {==}

def Laws.t_middle():
  {==}

def Laws.t_styled_end():
  {==}

def Laws.t_styled_start():
  {==}

def Laws.t_cjk_end():
  {==}

def Laws.t_cjk_start():
  {==}

def Laws.t_fits():
  {==}

def Laws.t_one():
  {==}

def Laws.t_zero():
  {==}

def Laws.t_middle_even():
  {==}

def Laws.t_emoji_end():
  {==}

def Laws.t_two():
  {==}

def Laws.inline_escapes():
  {==}

def Laws.inline_erase_lines():
  {==}

def Laws.inline_link():
  {==}

def Laws.inline_link_text():
  {==}
