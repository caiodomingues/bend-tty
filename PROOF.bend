# bend-tty: the proofs. Every law is closed, so each is {==}: the
# checker runs the decoder, or Level.detect, and compares.

import Base
import ./tty.bend as T
import ./color.bend as C
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
