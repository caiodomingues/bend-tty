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
