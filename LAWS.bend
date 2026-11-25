# bend-tty: the laws of the decoder, as the sequences a terminal sends.
# Each is a closed claim, so its proof is reflexivity: the decoder
# computes it. A claim over every byte would need U32 lemmas (a byte
# in 32..126 decodes as itself), which no library has yet.

import Base
import ./tty.bend as T
import ./color.bend as C
import ./text.bend as X

# LAW: a printable byte is that character
law keys_plain:
  {T.Tty.keys([113]) == [T.Char{113}] : List<&2, T.Key>}

# LAW: ESC [ A is Up; B, C, D are Down, Right, Left
law keys_up:
  {T.Tty.keys([27, 91, 65]) == [T.Up{}] : List<&2, T.Key>}

law keys_arrows:
  {T.Tty.keys([27, 91, 66, 27, 91, 67, 27, 91, 68]) == [T.Down{}, T.Right{}, T.Left{}] : List<&2, T.Key>}

# LAW: ESC [ 3 ~ is Delete; 5 ~ and 6 ~ page
law keys_delete:
  {T.Tty.keys([27, 91, 51, 126]) == [T.Delete{}] : List<&2, T.Key>}

law keys_pages:
  {T.Tty.keys([27, 91, 53, 126, 27, 91, 54, 126]) == [T.PageUp{}, T.PageDown{}] : List<&2, T.Key>}

# LAW: Enter is 13 or 10, Tab 9, Backspace 127 or 8
law keys_enter:
  {T.Tty.keys([13, 10, 9, 127, 8]) == [T.Enter{}, T.Enter{}, T.Tab{}, T.Backspace{}, T.Backspace{}] : List<&2, T.Key>}

# LAW: a control byte is Ctrl of its code: Ctrl-C is 3
law keys_ctrl:
  {T.Tty.keys([3, 1]) == [T.Ctrl{3}, T.Ctrl{1}] : List<&2, T.Key>}

# LAW: a lone ESC, or one before another ESC or a control byte, is
# Esc; ESC before a printable is Alt with it
law keys_esc:
  {T.Tty.keys([27, 27, 113, 27, 3, 27]) == [T.Esc{}, T.Alt{113}, T.Esc{}, T.Ctrl{3}, T.Esc{}] : List<&2, T.Key>}

# LAW: ESC [ H and ESC [ F, and ESC [ 1 ~ and ESC [ 4 ~, are Home and End
law keys_home_end:
  {T.Tty.keys([27, 91, 72, 27, 91, 70, 27, 91, 49, 126, 27, 91, 52, 126]) == [T.Home{}, T.End{}, T.Home{}, T.End{}] : List<&2, T.Key>}

# LAW: ESC [ 2 ~ is Insert
law keys_insert:
  {T.Tty.keys([27, 91, 50, 126]) == [T.Insert{}] : List<&2, T.Key>}

# LAW: ESC O P .. S are F1 .. F4; ESC [ 15 ~ .. ESC [ 24 ~ are F5 .. F12
law keys_fkeys:
  {T.Tty.keys([27, 79, 80, 27, 79, 83, 27, 91, 49, 53, 126, 27, 91, 50, 52, 126]) == [T.F{1}, T.F{4}, T.F{5}, T.F{12}] : List<&2, T.Key>}

# LAW: a modifier parameter is ignored (Shift+Up is Up), and the
# application-mode arrows (ESC O A) are arrows too
law keys_modified:
  {T.Tty.keys([27, 91, 49, 59, 50, 65, 27, 79, 66]) == [T.Up{}, T.Down{}] : List<&2, T.Key>}

# LAW: an unknown CSI is consumed whole and decodes to nothing: no Esc,
# no stray characters. ESC [ 9 9 z here
law keys_unknown_csi:
  {T.Tty.keys([27, 91, 57, 57, 122, 113]) == [T.Char{113}] : List<&2, T.Key>}

# LAW: a truncated UTF-8 sequence, an overlong encoding and a byte no
# UTF-8 has decode to nothing
law keys_bad_utf8:
  {T.Tty.keys([195, 192, 128, 255, 128, 128, 128, 113]) == [T.Char{113}] : List<&2, T.Key>}

# LAW: UTF-8 decodes to the code point: ç is c3 a7, € is e2 82 ac
law keys_utf8:
  {T.Tty.keys([195, 167, 226, 130, 172]) == [T.Char{231}, T.Char{8364}] : List<&2, T.Key>}

# LAW: nothing decodes to nothing
law keys_nil:
  {T.Tty.keys(Nil{}) == Nil{} : List<&2, T.Key>}

# Colour level
# ------------
# Level.detect on the environments a CLI meets. Each answer is
# supports-color 11.0.0's for the same facts, except where a row notes it:
# bend-tty reads NO_COLOR and takes COLORTERM=24bit as truecolor.

# no variables, on a terminal: None
law detect_empty:
  {C.Level.detect(C.Facts{True{}, None{}, Nil{}}) == C.Level.None{} : C.Level}

# TERM=xterm-256color, on a terminal: Ansi256
law detect_term_256:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "xterm-256color")]}) == C.Level.Ansi256{} : C.Level}

# TERM=xterm-256color, on a pipe: None
law detect_term_256_pipe:
  {C.Level.detect(C.Facts{False{}, None{}, [C.Var.set("TERM", "xterm-256color")]}) == C.Level.None{} : C.Level}

# TERM=xterm, on a terminal: Basic
law detect_term_xterm:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "xterm")]}) == C.Level.Basic{} : C.Level}

# TERM=dumb, on a terminal: None
law detect_dumb:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "dumb")]}) == C.Level.None{} : C.Level}

# TERM=dumb FORCE_COLOR=true, on a terminal: Basic
law detect_dumb_forced:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "dumb"), C.Var.set("FORCE_COLOR", "true")]}) == C.Level.Basic{} : C.Level}

# TERM=xterm-256color FORCE_COLOR=0, on a terminal: None
law detect_force_0:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "xterm-256color"), C.Var.set("FORCE_COLOR", "0")]}) == C.Level.None{} : C.Level}

# TERM=xterm-256color FORCE_COLOR=false, on a terminal: None
law detect_force_false:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "xterm-256color"), C.Var.set("FORCE_COLOR", "false")]}) == C.Level.None{} : C.Level}

# FORCE_COLOR=3, on a pipe: TrueColor
law detect_force_3_pipe:
  {C.Level.detect(C.Facts{False{}, None{}, [C.Var.set("FORCE_COLOR", "3")]}) == C.Level.TrueColor{} : C.Level}

# FORCE_COLOR=007, on a pipe: TrueColor
law detect_force_007:
  {C.Level.detect(C.Facts{False{}, None{}, [C.Var.set("FORCE_COLOR", "007")]}) == C.Level.TrueColor{} : C.Level}

# FORCE_COLOR=9, on a terminal: TrueColor
law detect_force_9:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("FORCE_COLOR", "9")]}) == C.Level.TrueColor{} : C.Level}

# TERM=xterm-256color FORCE_COLOR=1, on a terminal: Basic
law detect_force_1_256:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "xterm-256color"), C.Var.set("FORCE_COLOR", "1")]}) == C.Level.Basic{} : C.Level}

# TERM=xterm-256color FORCE_COLOR='', on a pipe: Ansi256
law detect_force_empty_pipe:
  {C.Level.detect(C.Facts{False{}, None{}, [C.Var.set("TERM", "xterm-256color"), C.Var.set("FORCE_COLOR", "")]}) == C.Level.Ansi256{} : C.Level}

# TERM=xterm FORCE_COLOR=yes, on a terminal: Basic
law detect_force_junk:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "xterm"), C.Var.set("FORCE_COLOR", "yes")]}) == C.Level.Basic{} : C.Level}

# TERM=xterm FORCE_COLOR=yes, on a pipe: None
law detect_force_junk_pipe:
  {C.Level.detect(C.Facts{False{}, None{}, [C.Var.set("TERM", "xterm"), C.Var.set("FORCE_COLOR", "yes")]}) == C.Level.None{} : C.Level}

# TERM=xterm-256color COLORTERM=truecolor, on a terminal: TrueColor
law detect_colorterm_truecolor:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "xterm-256color"), C.Var.set("COLORTERM", "truecolor")]}) == C.Level.TrueColor{} : C.Level}

# TERM=xterm-256color COLORTERM=24bit, on a terminal: TrueColor  (supports-color: Ansi256)
law detect_colorterm_24bit:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "xterm-256color"), C.Var.set("COLORTERM", "24bit")]}) == C.Level.TrueColor{} : C.Level}

# TERM=xterm COLORTERM=24bit, on a terminal: TrueColor  (supports-color: Basic)
law detect_colorterm_24bit_xterm:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "xterm"), C.Var.set("COLORTERM", "24bit")]}) == C.Level.TrueColor{} : C.Level}

# TERM=foo COLORTERM=yes, on a terminal: Basic
law detect_colorterm_any:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "foo"), C.Var.set("COLORTERM", "yes")]}) == C.Level.Basic{} : C.Level}

# CI=true GITHUB_ACTIONS=true, on a pipe: None
law detect_github_pipe:
  {C.Level.detect(C.Facts{False{}, None{}, [C.Var.set("CI", "true"), C.Var.set("GITHUB_ACTIONS", "true")]}) == C.Level.None{} : C.Level}

# CI=true GITHUB_ACTIONS=true, on a terminal: TrueColor
law detect_github:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("CI", "true"), C.Var.set("GITHUB_ACTIONS", "true")]}) == C.Level.TrueColor{} : C.Level}

# CI=true TRAVIS=1 TERM=xterm-256color, on a terminal: Basic
law detect_travis:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("CI", "true"), C.Var.set("TRAVIS", "1"), C.Var.set("TERM", "xterm-256color")]}) == C.Level.Basic{} : C.Level}

# CI='' TERM=xterm-256color, on a terminal: None
law detect_ci_empty:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("CI", ""), C.Var.set("TERM", "xterm-256color")]}) == C.Level.None{} : C.Level}

# CI=1 CI_NAME=codeship, on a terminal: Basic
law detect_codeship:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("CI", "1"), C.Var.set("CI_NAME", "codeship")]}) == C.Level.Basic{} : C.Level}

# TF_BUILD=True AGENT_NAME=x, on a pipe: Basic
law detect_azure_pipe:
  {C.Level.detect(C.Facts{False{}, None{}, [C.Var.set("TF_BUILD", "True"), C.Var.set("AGENT_NAME", "x")]}) == C.Level.Basic{} : C.Level}

# TEAMCITY_VERSION=9.1.5, on a terminal: Basic
law detect_teamcity_9_1:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TEAMCITY_VERSION", "9.1.5")]}) == C.Level.Basic{} : C.Level}

# TEAMCITY_VERSION=9.0.5 TERM=xterm-256color, on a terminal: None
law detect_teamcity_9_0:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TEAMCITY_VERSION", "9.0.5"), C.Var.set("TERM", "xterm-256color")]}) == C.Level.None{} : C.Level}

# TEAMCITY_VERSION=2017.1, on a terminal: Basic
law detect_teamcity_2017:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TEAMCITY_VERSION", "2017.1")]}) == C.Level.Basic{} : C.Level}

# TEAMCITY_VERSION=8.0, on a terminal: None
law detect_teamcity_8:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TEAMCITY_VERSION", "8.0")]}) == C.Level.None{} : C.Level}

# TERM=xterm-256color TERM_PROGRAM=iTerm.app TERM_PROGRAM_VERSION=3.4.19, on a terminal: TrueColor
law detect_iterm_3:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "xterm-256color"), C.Var.set("TERM_PROGRAM", "iTerm.app"), C.Var.set("TERM_PROGRAM_VERSION", "3.4.19")]}) == C.Level.TrueColor{} : C.Level}

# TERM=xterm-256color TERM_PROGRAM=iTerm.app TERM_PROGRAM_VERSION=2.9, on a terminal: Ansi256
law detect_iterm_2:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "xterm-256color"), C.Var.set("TERM_PROGRAM", "iTerm.app"), C.Var.set("TERM_PROGRAM_VERSION", "2.9")]}) == C.Level.Ansi256{} : C.Level}

# TERM_PROGRAM=iTerm.app, on a terminal: Ansi256
law detect_iterm_noversion:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM_PROGRAM", "iTerm.app")]}) == C.Level.Ansi256{} : C.Level}

# TERM=xterm TERM_PROGRAM=Apple_Terminal, on a terminal: Ansi256
law detect_apple:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "xterm"), C.Var.set("TERM_PROGRAM", "Apple_Terminal")]}) == C.Level.Ansi256{} : C.Level}

# TERM=xterm-256color TERM_PROGRAM=vscode, on a terminal: Ansi256
law detect_vscode:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "xterm-256color"), C.Var.set("TERM_PROGRAM", "vscode")]}) == C.Level.Ansi256{} : C.Level}

# TERM=xterm-kitty, on a terminal: TrueColor
law detect_kitty:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "xterm-kitty")]}) == C.Level.TrueColor{} : C.Level}

# TERM=xterm-ghostty, on a terminal: TrueColor
law detect_ghostty:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "xterm-ghostty")]}) == C.Level.TrueColor{} : C.Level}

# TERM=wezterm, on a terminal: TrueColor
law detect_wezterm:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "wezterm")]}) == C.Level.TrueColor{} : C.Level}

# TERM=screen, on a terminal: Basic
law detect_screen:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "screen")]}) == C.Level.Basic{} : C.Level}

# TERM=linux, on a terminal: Basic
law detect_linux:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "linux")]}) == C.Level.Basic{} : C.Level}

# TERM=rxvt-unicode-256color, on a terminal: Ansi256
law detect_rxvt_256:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "rxvt-unicode-256color")]}) == C.Level.Ansi256{} : C.Level}

# TERM=VT100, on a terminal: Basic
law detect_upper_vt100:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "VT100")]}) == C.Level.Basic{} : C.Level}

# TERM=XTERM-256, on a terminal: Ansi256
law detect_upper_256:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "XTERM-256")]}) == C.Level.Ansi256{} : C.Level}

# TERM=mycolorterm, on a terminal: Basic
law detect_has_color:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "mycolorterm")]}) == C.Level.Basic{} : C.Level}

# TERM=xterm-256color NO_COLOR=1, on a terminal: None  (supports-color: Ansi256)
law detect_no_color:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "xterm-256color"), C.Var.set("NO_COLOR", "1")]}) == C.Level.None{} : C.Level}

# TERM=xterm-256color NO_COLOR='', on a terminal: Ansi256
law detect_no_color_empty:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "xterm-256color"), C.Var.set("NO_COLOR", "")]}) == C.Level.Ansi256{} : C.Level}

# TERM=xterm-256color NO_COLOR=1 FORCE_COLOR=1, on a terminal: Basic
law detect_no_color_force_1:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "xterm-256color"), C.Var.set("NO_COLOR", "1"), C.Var.set("FORCE_COLOR", "1")]}) == C.Level.Basic{} : C.Level}

# TERM=xterm-256color NO_COLOR=1 FORCE_COLOR=true, on a terminal: Ansi256
law detect_no_color_force_true:
  {C.Level.detect(C.Facts{True{}, None{}, [C.Var.set("TERM", "xterm-256color"), C.Var.set("NO_COLOR", "1"), C.Var.set("FORCE_COLOR", "true")]}) == C.Level.Ansi256{} : C.Level}

# NO_COLOR=1 TF_BUILD=1 AGENT_NAME=x, on a pipe: None  (supports-color: Basic)
law detect_no_color_azure:
  {C.Level.detect(C.Facts{False{}, None{}, [C.Var.set("NO_COLOR", "1"), C.Var.set("TF_BUILD", "1"), C.Var.set("AGENT_NAME", "x")]}) == C.Level.None{} : C.Level}

# TERM=xterm-256color, on a terminal, the program passing --no-color: None
law detect_flag_no_color:
  {C.Level.detect(C.Facts{True{}, Some{C.Level.None{}}, [C.Var.set("TERM", "xterm-256color")]}) == C.Level.None{} : C.Level}

# TERM=xterm-256color FORCE_COLOR=3, on a terminal, the program passing --no-color: TrueColor
law detect_flag_no_color_env_3:
  {C.Level.detect(C.Facts{True{}, Some{C.Level.None{}}, [C.Var.set("TERM", "xterm-256color"), C.Var.set("FORCE_COLOR", "3")]}) == C.Level.TrueColor{} : C.Level}

# TERM=xterm-256color, on a pipe, the program passing --color: Ansi256
law detect_flag_color_pipe:
  {C.Level.detect(C.Facts{False{}, Some{C.Level.Basic{}}, [C.Var.set("TERM", "xterm-256color")]}) == C.Level.Ansi256{} : C.Level}

# TERM=dumb, on a terminal, the program passing --color: Basic
law detect_flag_color_dumb:
  {C.Level.detect(C.Facts{True{}, Some{C.Level.Basic{}}, [C.Var.set("TERM", "dumb")]}) == C.Level.Basic{} : C.Level}

# no variables, on a pipe, the program passing --color=256: Ansi256
law detect_flag_256_pipe:
  {C.Level.detect(C.Facts{False{}, Some{C.Level.Ansi256{}}, Nil{}}) == C.Level.Ansi256{} : C.Level}

# TERM=xterm, on a terminal, the program passing --color=16m: TrueColor
law detect_flag_16m:
  {C.Level.detect(C.Facts{True{}, Some{C.Level.TrueColor{}}, [C.Var.set("TERM", "xterm")]}) == C.Level.TrueColor{} : C.Level}

# FORCE_COLOR=0, on a terminal, the program passing --color=16m: None
law detect_flag_16m_force_0:
  {C.Level.detect(C.Facts{True{}, Some{C.Level.TrueColor{}}, [C.Var.set("FORCE_COLOR", "0")]}) == C.Level.None{} : C.Level}

# TERM=xterm-256color NO_COLOR=1, on a terminal, the program passing --color: Ansi256
law detect_flag_color_no_color:
  {C.Level.detect(C.Facts{True{}, Some{C.Level.Basic{}}, [C.Var.set("TERM", "xterm-256color"), C.Var.set("NO_COLOR", "1")]}) == C.Level.Ansi256{} : C.Level}

# Colours
# -------
# Color.at, a colour as a level shows it. The first five laws hold for
# every level and colour; the samples after them are ansi-styles 7.0.0's
# answers (rgbToAnsi256, ansi256ToAnsi, hexToRgb at 8cf247a), and the
# conversions agree with a port of those functions on all 256 palette
# entries and on 4096 RGB colours.

# LAW: a basic colour is never changed, at any level
law color_basic:
  for l: C.Level
  for n: U32
  {C.Color.at(l, C.Color.Basic{n}) == C.Color.Basic{n} : C.Color}

# LAW: nor is the terminal's default colour
law color_default:
  for l: C.Level
  {C.Color.at(l, C.Color.Default{}) == C.Color.Default{} : C.Color}

# LAW: truecolor shows every colour as it is
law color_truecolor:
  for c: C.Color
  {C.Color.at(C.Level.TrueColor{}, c) == c : C.Color}

# LAW: a 256 colour is unchanged at 256
law color_256:
  for n: U32
  {C.Color.at(C.Level.Ansi256{}, C.Color.Ansi256{n}) == C.Color.Ansi256{n} : C.Color}

# LAW: a colour already at the level is unchanged: converting twice is
# converting once
law color_idempotent:
  for l: C.Level
  for c: C.Color
  {C.Color.at(l, C.Color.at(l, c)) == C.Color.at(l, c) : C.Color}

# LAW: at Level.None no colour writes an escape
law color_none:
  for c: C.Color
  for bg: Bool
  {C.Color.paint(C.Level.None{}, c, bg) ++ C.Color.close(C.Level.None{}, bg) == "" : String}

# red, grey 128 and orange to the 256 palette
law color_rgb_256:
  {[C.Color.at(C.Level.Ansi256{}, C.Color.Rgb{255, 0, 0}), C.Color.at(C.Level.Ansi256{}, C.Color.Rgb{128, 128, 128}),
    C.Color.at(C.Level.Ansi256{}, C.Color.Rgb{255, 136, 0}), C.Color.at(C.Level.Ansi256{}, C.Color.Rgb{0, 0, 0}),
    C.Color.at(C.Level.Ansi256{}, C.Color.Rgb{255, 255, 255})]
   == [C.Color.Ansi256{196}, C.Color.Ansi256{244}, C.Color.Ansi256{214}, C.Color.Ansi256{16}, C.Color.Ansi256{231}] : List<&2, C.Color>}

# the palette to the 16: 196 bright red, 214 bright yellow, 88 black (no
# channel past 2 of 5), grey 244 white and 240 black, 21 bright blue
law color_256_16:
  {[C.Color.at(C.Level.Basic{}, C.Color.Ansi256{196}), C.Color.at(C.Level.Basic{}, C.Color.Ansi256{214}),
    C.Color.at(C.Level.Basic{}, C.Color.Ansi256{88}), C.Color.at(C.Level.Basic{}, C.Color.Ansi256{244}),
    C.Color.at(C.Level.Basic{}, C.Color.Ansi256{240}), C.Color.at(C.Level.Basic{}, C.Color.Ansi256{21}),
    C.Color.at(C.Level.Basic{}, C.Color.Ansi256{3})]
   == [C.Color.Basic{9}, C.Color.Basic{11}, C.Color.Basic{0}, C.Color.Basic{7}, C.Color.Basic{0}, C.Color.Basic{12}, C.Color.Basic{3}] : List<&2, C.Color>}

# RGB at 16 colours goes through the palette: orange is bright yellow
law color_rgb_16:
  {C.Color.at(C.Level.Basic{}, C.Color.Rgb{255, 136, 0}) == C.Color.Basic{11} : C.Color}

# hex: six digits, three doubled, either case, the leftmost run that
# fits (#12345 has no six, so 123), black when there is none
law color_hex:
  {[C.Color.hex("#ff8800"), C.Color.hex("f80"), C.Color.hex("#FF8800"), C.Color.hex("#12345"), C.Color.hex("zz")]
   == [C.Color.Rgb{255, 136, 0}, C.Color.Rgb{255, 136, 0}, C.Color.Rgb{255, 136, 0}, C.Color.Rgb{17, 34, 51}, C.Color.Rgb{0, 0, 0}] : List<&2, C.Color>}

# the escapes: 31 red, 101 bright red behind, 39 the default, 38;5;n
# and 38;2;r;g;b, each downsampled to the level first
law color_escapes:
  {[C.Color.fg(C.Level.Basic{}, C.Color.red()), C.Color.bg(C.Level.Basic{}, C.Color.bright(C.Color.red())),
    C.Color.fg(C.Level.TrueColor{}, C.Color.Default{}), C.Color.fg(C.Level.Ansi256{}, C.Color.Rgb{255, 0, 0}),
    C.Color.fg(C.Level.TrueColor{}, C.Color.Rgb{255, 136, 0}), C.Color.bg(C.Level.Basic{}, C.Color.Ansi256{196})]
   == [SCon{Chr{27}, "[31m"}, SCon{Chr{27}, "[101m"}, SCon{Chr{27}, "[39m"}, SCon{Chr{27}, "[38;5;196m"},
       SCon{Chr{27}, "[38;2;255;136;0m"}, SCon{Chr{27}, "[101m"}] : List<&2, String>}

# Styles
# ------
# Style.paint. The first two laws hold for every style and string; the
# samples are chalk 6.0.1's output for the same chain (source/index.js at
# 7211001): nesting reopens the outer style after each of its closing codes
# inside, and a line break is wrapped in close-all and open-all.

# LAW: at Level.None the string is itself: nothing styled sends an
# escape to a pipe
law paint_none:
  for st: C.Style
  for s: String
  {C.Style.paint(C.Level.None{}, st, s) == s : String}

# LAW: the empty string stays empty at every level
law paint_empty_all:
  for l: C.Level
  for st: C.Style
  {C.Style.paint(l, st, "") == "" : String}

law paint_red:
  {C.Style.paint(C.Level.Basic{}, C.Style.fg(C.Color.Basic{1}, C.Style.plain()), ("x"))
   == SCon{Chr{27}, SNil{}} ++ "[31mx" ++ SCon{Chr{27}, SNil{}} ++ "[39m" : String}

law paint_red_bold:
  {C.Style.paint(C.Level.Basic{}, C.Style.bold(C.Style.fg(C.Color.Basic{1}, C.Style.plain())), ("x"))
   == SCon{Chr{27}, SNil{}} ++ "[31m" ++ SCon{Chr{27}, SNil{}} ++ "[1mx" ++ SCon{Chr{27}, SNil{}} ++ "[22m" ++ SCon{Chr{27}, SNil{}} ++ "[39m" : String}

law paint_nest_fg:
  {C.Style.paint(C.Level.Basic{}, C.Style.fg(C.Color.Basic{1}, C.Style.plain()), (C.Style.paint(C.Level.Basic{}, C.Style.fg(C.Color.Basic{4}, C.Style.plain()), ("a"))) ++ ("b"))
   == SCon{Chr{27}, SNil{}} ++ "[31m" ++ SCon{Chr{27}, SNil{}} ++ "[34ma" ++ SCon{Chr{27}, SNil{}} ++ "[39m" ++ SCon{Chr{27}, SNil{}} ++ "[31mb" ++ SCon{Chr{27}, SNil{}} ++ "[39m" : String}

law paint_nest_bold_dim:
  {C.Style.paint(C.Level.Basic{}, C.Style.bold(C.Style.plain()), (C.Style.paint(C.Level.Basic{}, C.Style.dim(C.Style.plain()), ("a"))) ++ ("b"))
   == SCon{Chr{27}, SNil{}} ++ "[1m" ++ SCon{Chr{27}, SNil{}} ++ "[2ma" ++ SCon{Chr{27}, SNil{}} ++ "[22m" ++ SCon{Chr{27}, SNil{}} ++ "[1mb" ++ SCon{Chr{27}, SNil{}} ++ "[22m" : String}

law paint_newline:
  {C.Style.paint(C.Level.Basic{}, C.Style.fg(C.Color.Basic{1}, C.Style.plain()), ("a" ++ SCon{Chr{10}, SNil{}} ++ "b"))
   == SCon{Chr{27}, SNil{}} ++ "[31ma" ++ SCon{Chr{27}, SNil{}} ++ "[39m" ++ SCon{Chr{10}, SNil{}} ++ SCon{Chr{27}, SNil{}} ++ "[31mb" ++ SCon{Chr{27}, SNil{}} ++ "[39m" : String}

law paint_crlf:
  {C.Style.paint(C.Level.Basic{}, C.Style.fg(C.Color.Basic{1}, C.Style.plain()), ("a" ++ SCon{Chr{13}, SNil{}} ++ SCon{Chr{10}, SNil{}} ++ "b"))
   == SCon{Chr{27}, SNil{}} ++ "[31ma" ++ SCon{Chr{27}, SNil{}} ++ "[39m" ++ SCon{Chr{13}, SNil{}} ++ SCon{Chr{10}, SNil{}} ++ SCon{Chr{27}, SNil{}} ++ "[31mb" ++ SCon{Chr{27}, SNil{}} ++ "[39m" : String}

law paint_trailing_newline:
  {C.Style.paint(C.Level.Basic{}, C.Style.bold(C.Style.fg(C.Color.Basic{1}, C.Style.plain())), ("a" ++ SCon{Chr{10}, SNil{}}))
   == SCon{Chr{27}, SNil{}} ++ "[31m" ++ SCon{Chr{27}, SNil{}} ++ "[1ma" ++ SCon{Chr{27}, SNil{}} ++ "[22m" ++ SCon{Chr{27}, SNil{}} ++ "[39m" ++ SCon{Chr{10}, SNil{}} ++ SCon{Chr{27}, SNil{}} ++ "[31m" ++ SCon{Chr{27}, SNil{}} ++ "[1m" ++ SCon{Chr{27}, SNil{}} ++ "[22m" ++ SCon{Chr{27}, SNil{}} ++ "[39m" : String}

law paint_empty:
  {C.Style.paint(C.Level.Basic{}, C.Style.fg(C.Color.Basic{1}, C.Style.plain()), (""))
   == "" : String}

law paint_level_none:
  {C.Style.paint(C.Level.None{}, C.Style.bold(C.Style.fg(C.Color.Basic{1}, C.Style.plain())), ("x"))
   == "x" : String}

law paint_hex_256:
  {C.Style.paint(C.Level.Ansi256{}, C.Style.fg(C.Color.hex("#ff8800"), C.Style.plain()), ("x"))
   == SCon{Chr{27}, SNil{}} ++ "[38;5;214mx" ++ SCon{Chr{27}, SNil{}} ++ "[39m" : String}

law paint_hex_16:
  {C.Style.paint(C.Level.Basic{}, C.Style.fg(C.Color.hex("#ff8800"), C.Style.plain()), ("x"))
   == SCon{Chr{27}, SNil{}} ++ "[93mx" ++ SCon{Chr{27}, SNil{}} ++ "[39m" : String}

law paint_hex_true:
  {C.Style.paint(C.Level.TrueColor{}, C.Style.fg(C.Color.hex("#ff8800"), C.Style.plain()), ("x"))
   == SCon{Chr{27}, SNil{}} ++ "[38;2;255;136;0mx" ++ SCon{Chr{27}, SNil{}} ++ "[39m" : String}

law paint_bg_underline:
  {C.Style.paint(C.Level.Basic{}, C.Style.underline(C.Style.bg(C.Color.Basic{4}, C.Style.plain())), ("x"))
   == SCon{Chr{27}, SNil{}} ++ "[44m" ++ SCon{Chr{27}, SNil{}} ++ "[4mx" ++ SCon{Chr{27}, SNil{}} ++ "[24m" ++ SCon{Chr{27}, SNil{}} ++ "[49m" : String}

law paint_all_modifiers:
  {C.Style.paint(C.Level.Basic{}, C.Style.strike(C.Style.hidden(C.Style.inverse(C.Style.underline(C.Style.italic(C.Style.dim(C.Style.bold(C.Style.plain()))))))), ("x"))
   == SCon{Chr{27}, SNil{}} ++ "[1m" ++ SCon{Chr{27}, SNil{}} ++ "[2m" ++ SCon{Chr{27}, SNil{}} ++ "[3m" ++ SCon{Chr{27}, SNil{}} ++ "[4m" ++ SCon{Chr{27}, SNil{}} ++ "[7m" ++ SCon{Chr{27}, SNil{}} ++ "[8m" ++ SCon{Chr{27}, SNil{}} ++ "[9mx" ++ SCon{Chr{27}, SNil{}} ++ "[29m" ++ SCon{Chr{27}, SNil{}} ++ "[28m" ++ SCon{Chr{27}, SNil{}} ++ "[27m" ++ SCon{Chr{27}, SNil{}} ++ "[24m" ++ SCon{Chr{27}, SNil{}} ++ "[23m" ++ SCon{Chr{27}, SNil{}} ++ "[22m" ++ SCon{Chr{27}, SNil{}} ++ "[22m" : String}

law paint_reopen_two:
  {C.Style.paint(C.Level.Basic{}, C.Style.bold(C.Style.fg(C.Color.Basic{1}, C.Style.plain())), (C.Style.paint(C.Level.Basic{}, C.Style.fg(C.Color.Basic{4}, C.Style.plain()), ("a"))) ++ ("b") ++ (C.Style.paint(C.Level.Basic{}, C.Style.bold(C.Style.plain()), ("c"))) ++ ("d"))
   == SCon{Chr{27}, SNil{}} ++ "[31m" ++ SCon{Chr{27}, SNil{}} ++ "[1m" ++ SCon{Chr{27}, SNil{}} ++ "[34ma" ++ SCon{Chr{27}, SNil{}} ++ "[39m" ++ SCon{Chr{27}, SNil{}} ++ "[31mb" ++ SCon{Chr{27}, SNil{}} ++ "[1mc" ++ SCon{Chr{27}, SNil{}} ++ "[22m" ++ SCon{Chr{27}, SNil{}} ++ "[1md" ++ SCon{Chr{27}, SNil{}} ++ "[22m" ++ SCon{Chr{27}, SNil{}} ++ "[39m" : String}

law paint_deep:
  {C.Style.paint(C.Level.Basic{}, C.Style.fg(C.Color.Basic{1}, C.Style.plain()), (C.Style.paint(C.Level.Basic{}, C.Style.fg(C.Color.Basic{2}, C.Style.plain()), (C.Style.paint(C.Level.Basic{}, C.Style.fg(C.Color.Basic{4}, C.Style.plain()), ("a"))) ++ ("b"))) ++ ("c"))
   == SCon{Chr{27}, SNil{}} ++ "[31m" ++ SCon{Chr{27}, SNil{}} ++ "[32m" ++ SCon{Chr{27}, SNil{}} ++ "[34ma" ++ SCon{Chr{27}, SNil{}} ++ "[39m" ++ SCon{Chr{27}, SNil{}} ++ "[31m" ++ SCon{Chr{27}, SNil{}} ++ "[32mb" ++ SCon{Chr{27}, SNil{}} ++ "[39m" ++ SCon{Chr{27}, SNil{}} ++ "[31mc" ++ SCon{Chr{27}, SNil{}} ++ "[39m" : String}

law paint_inverse_italic:
  {C.Style.paint(C.Level.Basic{}, C.Style.inverse(C.Style.plain()), (C.Style.paint(C.Level.Basic{}, C.Style.italic(C.Style.plain()), ("a"))) ++ ("b"))
   == SCon{Chr{27}, SNil{}} ++ "[7m" ++ SCon{Chr{27}, SNil{}} ++ "[3ma" ++ SCon{Chr{27}, SNil{}} ++ "[23mb" ++ SCon{Chr{27}, SNil{}} ++ "[27m" : String}

law paint_fg_bg_lines:
  {C.Style.paint(C.Level.Basic{}, C.Style.bg(C.Color.Basic{7}, C.Style.fg(C.Color.Basic{1}, C.Style.plain())), ("a" ++ SCon{Chr{10}, SNil{}} ++ "b"))
   == SCon{Chr{27}, SNil{}} ++ "[31m" ++ SCon{Chr{27}, SNil{}} ++ "[47ma" ++ SCon{Chr{27}, SNil{}} ++ "[49m" ++ SCon{Chr{27}, SNil{}} ++ "[39m" ++ SCon{Chr{10}, SNil{}} ++ SCon{Chr{27}, SNil{}} ++ "[31m" ++ SCon{Chr{27}, SNil{}} ++ "[47mb" ++ SCon{Chr{27}, SNil{}} ++ "[49m" ++ SCon{Chr{27}, SNil{}} ++ "[39m" : String}

law paint_bg_hex_256:
  {C.Style.paint(C.Level.Ansi256{}, C.Style.bg(C.Color.hex("#0080ff"), C.Style.plain()), ("x"))
   == SCon{Chr{27}, SNil{}} ++ "[48;5;39mx" ++ SCon{Chr{27}, SNil{}} ++ "[49m" : String}

law paint_other_escape:
  {C.Style.paint(C.Level.Basic{}, C.Style.fg(C.Color.Basic{1}, C.Style.plain()), (SCon{Chr{27}, SNil{}} ++ "[1mx"))
   == SCon{Chr{27}, SNil{}} ++ "[31m" ++ SCon{Chr{27}, SNil{}} ++ "[1mx" ++ SCon{Chr{27}, SNil{}} ++ "[39m" : String}

law paint_ansi256_16:
  {C.Style.paint(C.Level.Basic{}, C.Style.fg(C.Color.Ansi256{196}, C.Style.plain()), ("x"))
   == SCon{Chr{27}, SNil{}} ++ "[91mx" ++ SCon{Chr{27}, SNil{}} ++ "[39m" : String}

law paint_ansi256_256:
  {C.Style.paint(C.Level.Ansi256{}, C.Style.bg(C.Color.Ansi256{21}, C.Style.fg(C.Color.Ansi256{196}, C.Style.plain())), ("x"))
   == SCon{Chr{27}, SNil{}} ++ "[38;5;196m" ++ SCon{Chr{27}, SNil{}} ++ "[48;5;21mx" ++ SCon{Chr{27}, SNil{}} ++ "[49m" ++ SCon{Chr{27}, SNil{}} ++ "[39m" : String}

law paint_rgb_true_nest:
  {C.Style.paint(C.Level.TrueColor{}, C.Style.fg(C.Color.Rgb{10, 20, 30}, C.Style.plain()), (C.Style.paint(C.Level.TrueColor{}, C.Style.fg(C.Color.Rgb{200, 100, 0}, C.Style.plain()), ("a"))) ++ ("b" ++ SCon{Chr{10}, SNil{}} ++ "c"))
   == SCon{Chr{27}, SNil{}} ++ "[38;2;10;20;30m" ++ SCon{Chr{27}, SNil{}} ++ "[38;2;200;100;0ma" ++ SCon{Chr{27}, SNil{}} ++ "[39m" ++ SCon{Chr{27}, SNil{}} ++ "[38;2;10;20;30mb" ++ SCon{Chr{27}, SNil{}} ++ "[39m" ++ SCon{Chr{10}, SNil{}} ++ SCon{Chr{27}, SNil{}} ++ "[38;2;10;20;30mc" ++ SCon{Chr{27}, SNil{}} ++ "[39m" : String}

law paint_nest_inner_newline:
  {C.Style.paint(C.Level.Basic{}, C.Style.fg(C.Color.Basic{1}, C.Style.plain()), (C.Style.paint(C.Level.Basic{}, C.Style.bold(C.Style.plain()), ("a" ++ SCon{Chr{10}, SNil{}} ++ "b"))) ++ ("c"))
   == SCon{Chr{27}, SNil{}} ++ "[31m" ++ SCon{Chr{27}, SNil{}} ++ "[1ma" ++ SCon{Chr{27}, SNil{}} ++ "[22m" ++ SCon{Chr{27}, SNil{}} ++ "[39m" ++ SCon{Chr{10}, SNil{}} ++ SCon{Chr{27}, SNil{}} ++ "[31m" ++ SCon{Chr{27}, SNil{}} ++ "[1mb" ++ SCon{Chr{27}, SNil{}} ++ "[22mc" ++ SCon{Chr{27}, SNil{}} ++ "[39m" : String}

# Text
# ----
# text.bend. The samples are the answers of string-width 9.0.0,
# strip-ansi 7.2.0, slice-ansi 10.0.1, wrap-ansi 10.0.2 and cli-truncate
# 6.2.0 (run under bun 1.4.5 on these same strings), except where a law
# notes it: widths of CJK, emoji (ZWJ sequences, flags, skin tones,
# keycaps, VS15 and VS16), combining marks and Hangul jamo; escapes of
# every kind; slices across wide characters and styles; wraps with styles,
# links, tabs and long words; truncation at each end and the middle.

# LAW: truncating to no columns leaves nothing, whatever the string
law text_truncate_zero:
  for s: String
  for c: X.Cut
  {X.Ansi.truncate(s, 0, c) == "" : String}

# LAW: a width of 0 leaves the string as it is
law text_wrap_zero:
  for s: String
  for hard: Bool
  {X.Ansi.wrap(s, 0, hard) == s : String}

# styling changes neither the width nor, stripped, the text
law text_styled_width:
  {[X.Ansi.width(C.Style.paint(C.Level.Basic{}, C.Style.bold(C.Style.fg(C.Color.red(), C.Style.plain())), X.S.of([20013, 25991, 32, 97, 98, 99]))), X.Ansi.width(C.Style.paint(C.Level.Basic{}, C.Style.bold(C.Style.fg(C.Color.red(), C.Style.plain())), X.S.of([128104, 8205, 128105, 8205, 128103, 32, 111, 107]))), X.Ansi.width(C.Style.paint(C.Level.Basic{}, C.Style.bold(C.Style.fg(C.Color.red(), C.Style.plain())), X.S.of([101, 769, 769]))), X.Ansi.width(C.Style.paint(C.Level.Basic{}, C.Style.bold(C.Style.fg(C.Color.red(), C.Style.plain())), X.S.of([26085, 26412, 10, 35486, 32, 10084, 65039]))), X.Ansi.width(C.Style.paint(C.Level.TrueColor{}, C.Style.underline(C.Style.bg(C.Color.Rgb{10, 20, 30}, C.Style.plain())), X.S.of([20013, 25991, 32, 97, 98, 99]))), X.Ansi.width(C.Style.paint(C.Level.TrueColor{}, C.Style.underline(C.Style.bg(C.Color.Rgb{10, 20, 30}, C.Style.plain())), X.S.of([128104, 8205, 128105, 8205, 128103, 32, 111, 107]))), X.Ansi.width(C.Style.paint(C.Level.TrueColor{}, C.Style.underline(C.Style.bg(C.Color.Rgb{10, 20, 30}, C.Style.plain())), X.S.of([101, 769, 769]))), X.Ansi.width(C.Style.paint(C.Level.TrueColor{}, C.Style.underline(C.Style.bg(C.Color.Rgb{10, 20, 30}, C.Style.plain())), X.S.of([26085, 26412, 10, 35486, 32, 10084, 65039])))]
   == [X.Ansi.width(X.S.of([20013, 25991, 32, 97, 98, 99])), X.Ansi.width(X.S.of([128104, 8205, 128105, 8205, 128103, 32, 111, 107])), X.Ansi.width(X.S.of([101, 769, 769])), X.Ansi.width(X.S.of([26085, 26412, 10, 35486, 32, 10084, 65039])), X.Ansi.width(X.S.of([20013, 25991, 32, 97, 98, 99])), X.Ansi.width(X.S.of([128104, 8205, 128105, 8205, 128103, 32, 111, 107])), X.Ansi.width(X.S.of([101, 769, 769])), X.Ansi.width(X.S.of([26085, 26412, 10, 35486, 32, 10084, 65039]))] : List<&2, U32>}

law text_styled_strip:
  {[X.Ansi.strip(C.Style.paint(C.Level.Ansi256{}, C.Style.bold(C.Style.fg(C.Color.red(), C.Style.plain())), X.S.of([20013, 25991, 32, 97, 98, 99]))), X.Ansi.strip(C.Style.paint(C.Level.Ansi256{}, C.Style.bold(C.Style.fg(C.Color.red(), C.Style.plain())), X.S.of([128104, 8205, 128105, 8205, 128103, 32, 111, 107]))), X.Ansi.strip(C.Style.paint(C.Level.Ansi256{}, C.Style.bold(C.Style.fg(C.Color.red(), C.Style.plain())), X.S.of([101, 769, 769]))), X.Ansi.strip(C.Style.paint(C.Level.Ansi256{}, C.Style.bold(C.Style.fg(C.Color.red(), C.Style.plain())), X.S.of([26085, 26412, 10, 35486, 32, 10084, 65039]))), X.Ansi.strip(C.Style.paint(C.Level.TrueColor{}, C.Style.underline(C.Style.bg(C.Color.Rgb{10, 20, 30}, C.Style.plain())), X.S.of([20013, 25991, 32, 97, 98, 99]))), X.Ansi.strip(C.Style.paint(C.Level.TrueColor{}, C.Style.underline(C.Style.bg(C.Color.Rgb{10, 20, 30}, C.Style.plain())), X.S.of([128104, 8205, 128105, 8205, 128103, 32, 111, 107]))), X.Ansi.strip(C.Style.paint(C.Level.TrueColor{}, C.Style.underline(C.Style.bg(C.Color.Rgb{10, 20, 30}, C.Style.plain())), X.S.of([101, 769, 769]))), X.Ansi.strip(C.Style.paint(C.Level.TrueColor{}, C.Style.underline(C.Style.bg(C.Color.Rgb{10, 20, 30}, C.Style.plain())), X.S.of([26085, 26412, 10, 35486, 32, 10084, 65039])))]
   == [X.S.of([20013, 25991, 32, 97, 98, 99]), X.S.of([128104, 8205, 128105, 8205, 128103, 32, 111, 107]), X.S.of([101, 769, 769]), X.S.of([26085, 26412, 10, 35486, 32, 10084, 65039]), X.S.of([20013, 25991, 32, 97, 98, 99]), X.S.of([128104, 8205, 128105, 8205, 128103, 32, 111, 107]), X.S.of([101, 769, 769]), X.S.of([26085, 26412, 10, 35486, 32, 10084, 65039])] : List<&2, String>}

# wrapped lines are never wider than the width, but for a single word
# longer than it when the wrap is soft, which keeps it whole on its row
law text_wrap_fits:
  {[X.Ansi.widest(X.Ansi.wrap(X.S.of([27, 91, 51, 49, 109, 116, 104, 101, 32, 113, 117, 105, 99, 107, 32, 98, 114, 111, 119, 110, 32, 102, 111, 120, 32, 106, 117, 109, 112, 115, 32, 111, 118, 101, 114, 27, 91, 51, 57, 109]), 10, False{})), X.Ansi.widest(X.Ansi.wrap(X.S.of([26085, 26412, 35486, 26085, 26412, 35486, 32, 128512, 128512, 128512]), 5, True{})),
    X.Ansi.widest(X.Ansi.wrap(X.S.of([115, 117, 112, 101, 114, 99, 97, 108, 105, 102, 114, 97, 103, 105, 108, 105, 115, 116, 105, 99, 32, 101, 120, 112, 105, 97, 108, 105, 100, 111, 99, 105, 111, 117, 115]), 7, True{})), X.Ansi.widest(X.Ansi.wrap(X.S.of([20013, 25991, 20013]), 3, True{})),
    X.Ansi.widest(X.Ansi.wrap(X.S.of([97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 32, 120, 121]), 5, False{}))]
   == [10, 4, 7, 2, 12] : List<&2, U32>}

law w_ascii:
  {X.Ansi.width(X.S.of([97, 98, 99])) == 3 : U32}

law w_cjk:
  {X.Ansi.width(X.S.of([20013, 25991])) == 4 : U32}

law w_decomposed:
  {X.Ansi.width(X.S.of([101, 769])) == 1 : U32}

law w_thumbs_tone:
  {X.Ansi.width(X.S.of([128077, 127997])) == 2 : U32}

law w_heart_vs16:
  {X.Ansi.width(X.S.of([10084, 65039])) == 2 : U32}

law w_heart:
  {X.Ansi.width(X.S.of([10084])) == 1 : U32}

law w_flag:
  {X.Ansi.width(X.S.of([127463, 127479])) == 2 : U32}

law w_lone_ri:
  {X.Ansi.width(X.S.of([127463])) == 2 : U32}

law w_family:
  {X.Ansi.width(X.S.of([128104, 8205, 128105, 8205, 128103])) == 2 : U32}

law w_hangul_jamo:
  {X.Ansi.width(X.S.of([4370, 4449, 4523])) == 2 : U32}

law w_hangul:
  {X.Ansi.width(X.S.of([54620, 44544])) == 4 : U32}

law w_fullwidth:
  {X.Ansi.width(X.S.of([65345, 65346])) == 4 : U32}

law w_watch_vs15:
  {X.Ansi.width(X.S.of([8986, 65038])) == 1 : U32}

law w_watch:
  {X.Ansi.width(X.S.of([8986])) == 2 : U32}

law w_keycap:
  {X.Ansi.width(X.S.of([49, 65039, 8419])) == 2 : U32}

law w_styled:
  {X.Ansi.width(X.S.of([27, 91, 51, 49, 109, 97, 98, 27, 91, 51, 57, 109])) == 2 : U32}

law w_link:
  {X.Ansi.width(X.S.of([27, 93, 56, 59, 59, 104, 116, 116, 112, 115, 58, 47, 47, 98, 101, 110, 100, 45, 108, 97, 110, 103, 46, 99, 111, 109, 27, 92, 115, 105, 116, 101, 27, 93, 56, 59, 59, 27, 92])) == 4 : U32}

law w_tab:
  {X.Ansi.width(X.S.of([97, 9, 98])) == 2 : U32}

law w_cafe:
  {X.Ansi.width(X.S.of([99, 97, 102, 233])) == 4 : U32}

law w_japanese:
  {X.Ansi.width(X.S.of([26085, 26412, 35486, 12486, 12461, 12473, 12488])) == 14 : U32}

law w_halfwidth_dakuten:
  {X.Ansi.width(X.S.of([65398, 65438])) == 2 : U32}

law w_devanagari:
  {X.Ansi.width(X.S.of([2325, 2381, 2359, 2367])) == 3 : U32}

law w_stray_tone:
  {X.Ansi.width(X.S.of([127997])) == 2 : U32}

law w_zwsp:
  {X.Ansi.width(X.S.of([97, 8203, 98])) == 2 : U32}

law w_mixed:
  {X.Ansi.width(X.S.of([97, 20013, 128512, 98])) == 6 : U32}

law w_empty:
  {X.Ansi.width("") == 0 : U32}

law w_rocket:
  {X.Ansi.width(X.S.of([128640])) == 2 : U32}

law w_ellipsis:
  {X.Ansi.width(X.S.of([8230])) == 1 : U32}

law w_box:
  {X.Ansi.width(X.S.of([9472, 9474])) == 2 : U32}

law w_thai:
  {X.Ansi.width(X.S.of([3585, 3635])) == 2 : U32}

law s_sgr:
  {X.Ansi.strip(X.S.of([27, 91, 49, 59, 51, 49, 109, 120, 27, 91, 48, 109])) == X.S.of([120]) : String}

law s_osc_title:
  {X.Ansi.strip(X.S.of([27, 93, 48, 59, 116, 105, 116, 108, 101, 7, 120])) == X.S.of([120]) : String}

law s_save_restore:
  {X.Ansi.strip(X.S.of([27, 55, 120, 27, 56])) == X.S.of([120]) : String}

law s_charset:
  {X.Ansi.strip(X.S.of([27, 40, 48, 120])) == X.S.of([120]) : String}

law s_private_csi:
  {X.Ansi.strip(X.S.of([27, 91, 63, 50, 53, 108, 120])) == X.S.of([120]) : String}

law s_dcs:
  {X.Ansi.strip(X.S.of([27, 80, 113, 35, 48, 27, 92, 120])) == X.S.of([120]) : String}

law s_link_st:
  {X.Ansi.strip(X.S.of([27, 93, 56, 59, 59, 104, 116, 116, 112, 115, 58, 47, 47, 98, 101, 110, 100, 45, 108, 97, 110, 103, 46, 99, 111, 109, 27, 92, 97, 27, 93, 56, 59, 59, 27, 92])) == X.S.of([97]) : String}

law s_link_bel:
  {X.Ansi.strip(X.S.of([27, 93, 56, 59, 59, 104, 116, 116, 112, 115, 58, 47, 47, 120, 46, 121, 7, 97, 27, 93, 56, 59, 59, 7])) == X.S.of([97]) : String}

law s_open_osc:
  {X.Ansi.strip(X.S.of([27, 93, 56, 59, 59, 117, 114, 108])) == X.S.of([27, 93, 56, 59, 59, 117, 114, 108]) : String}

law s_open_dcs:
  {X.Ansi.strip(X.S.of([27, 80, 113, 97, 98, 99])) == X.S.of([113, 97, 98, 99]) : String}

law s_lone_esc:
  {X.Ansi.strip(X.S.of([97, 27])) == X.S.of([97, 27]) : String}

law s_esc_letter:
  {X.Ansi.strip(X.S.of([27, 97])) == X.S.of([27, 97]) : String}

law s_csi_bad:
  {X.Ansi.strip(X.S.of([27, 91, 49, 50, 1, 120])) == X.S.of([27, 91, 49, 50, 1, 120]) : String}

law l_plain:
  {X.Ansi.slice(X.S.of([97, 98, 99, 100, 101, 102]), 1, 4) == X.S.of([98, 99, 100]) : String}

law l_styled_in:
  {X.Ansi.slice(X.S.of([27, 91, 51, 49, 109, 97, 98, 99, 27, 91, 51, 57, 109, 100, 101, 102]), 1, 5) == X.S.of([27, 91, 51, 49, 109, 98, 99, 27, 91, 51, 57, 109, 100, 101]) : String}

law l_wide_end:
  {X.Ansi.slice(X.S.of([97, 20013, 98]), 0, 2) == X.S.of([97]) : String}

law l_wide_start:
  {X.Ansi.slice(X.S.of([97, 20013, 98]), 2, 4) == X.S.of([98]) : String}

law l_wide_whole:
  {X.Ansi.slice(X.S.of([97, 20013, 98]), 1, 3) == X.S.of([20013]) : String}

law l_styled_all:
  {X.Ansi.slice(X.S.of([27, 91, 51, 49, 109, 97, 98, 99, 27, 91, 51, 57, 109]), 0, 3) == X.S.of([27, 91, 51, 49, 109, 97, 98, 99, 27, 91, 51, 57, 109]) : String}

law l_pending_open:
  {X.Ansi.slice(X.S.of([97, 98, 27, 91, 51, 49, 109, 20013]), 0, 3) == X.S.of([97, 98]) : String}

law l_nested:
  {X.Ansi.slice(X.S.of([27, 91, 51, 49, 109, 97, 27, 91, 49, 109, 98, 99, 27, 91, 50, 50, 109, 100, 27, 91, 51, 57, 109]), 1, 3) == X.S.of([27, 91, 51, 49, 109, 27, 91, 49, 109, 98, 99, 27, 91, 50, 50, 109, 27, 91, 51, 57, 109]) : String}

law l_link:
  {X.Ansi.slice(X.S.of([120, 27, 93, 56, 59, 59, 104, 116, 116, 112, 115, 58, 47, 47, 98, 101, 110, 100, 45, 108, 97, 110, 103, 46, 99, 111, 109, 27, 92, 115, 105, 116, 101, 27, 93, 56, 59, 59, 27, 92, 121]), 2, 4) == X.S.of([27, 93, 56, 59, 59, 104, 116, 116, 112, 115, 58, 47, 47, 98, 101, 110, 100, 45, 108, 97, 110, 103, 46, 99, 111, 109, 27, 92, 105, 116, 27, 93, 56, 59, 59, 27, 92]) : String}

law l_emoji:
  {X.Ansi.slice(X.S.of([97, 128512, 98]), 1, 3) == X.S.of([128512]) : String}

law l_past:
  {X.Ansi.slice(X.S.of([97, 98, 99]), 5, 8) == "" : String}

law l_empty_range:
  {X.Ansi.slice(X.S.of([97, 98, 99]), 2, 2) == "" : String}

law l_bold_dim:
  {X.Ansi.slice(X.S.of([27, 91, 49, 109, 27, 91, 50, 109, 97, 98, 27, 91, 50, 50, 109]), 1, 2) == X.S.of([27, 91, 50, 109, 98, 27, 91, 50, 50, 109]) : String}

law l_tone:
  {X.Ansi.slice(X.S.of([97, 128077, 127997, 98]), 1, 3) == X.S.of([128077, 127997]) : String}

law l_mark:
  {X.Ansi.slice(X.S.of([101, 769, 102]), 0, 1) == X.S.of([101, 769]) : String}

law r_words:
  {X.Ansi.wrap(X.S.of([116, 104, 101, 32, 113, 117, 105, 99, 107, 32, 98, 114, 111, 119, 110, 32, 102, 111, 120, 32, 106, 117, 109, 112, 115]), 10, False{}) == X.S.of([116, 104, 101, 32, 113, 117, 105, 99, 107, 10, 98, 114, 111, 119, 110, 32, 102, 111, 120, 10, 106, 117, 109, 112, 115]) : String}

law r_styled:
  {X.Ansi.wrap(X.S.of([27, 91, 51, 49, 109, 116, 104, 101, 32, 113, 117, 105, 99, 107, 32, 98, 114, 111, 119, 110, 27, 91, 51, 57, 109]), 10, False{}) == X.S.of([27, 91, 51, 49, 109, 116, 104, 101, 32, 113, 117, 105, 99, 107, 27, 91, 51, 57, 109, 10, 27, 91, 51, 49, 109, 98, 114, 111, 119, 110, 27, 91, 51, 57, 109]) : String}

law r_hard:
  {X.Ansi.wrap(X.S.of([97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 32, 120, 121]), 5, True{}) == X.S.of([97, 98, 99, 100, 101, 10, 102, 103, 104, 105, 106, 10, 107, 108, 32, 120, 121]) : String}

law r_soft_long:
  {X.Ansi.wrap(X.S.of([97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 32, 120, 121]), 5, False{}) == X.S.of([97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 10, 120, 121]) : String}

law r_tab:
  {X.Ansi.wrap(X.S.of([97, 9, 98]), 20, False{}) == X.S.of([97, 32, 32, 32, 32, 32, 32, 32, 98]) : String}

law r_cjk:
  {X.Ansi.wrap(X.S.of([26085, 26412, 35486, 26085, 26412, 35486]), 5, True{}) == X.S.of([26085, 26412, 10, 35486, 26085, 10, 26412, 35486]) : String}

law r_cjk_soft:
  {X.Ansi.wrap(X.S.of([26085, 26412, 35486, 32, 26085, 26412]), 4, False{}) == X.S.of([26085, 26412, 35486, 10, 26085, 26412]) : String}

law r_spaces:
  {X.Ansi.wrap(X.S.of([97, 32, 32, 98, 32, 32, 32, 99]), 3, False{}) == X.S.of([97, 10, 98, 10, 99]) : String}

law r_leading:
  {X.Ansi.wrap(X.S.of([32, 32, 32, 97, 98, 99, 32, 100, 101, 102]), 4, False{}) == X.S.of([97, 98, 99, 10, 100, 101, 102]) : String}

law r_trailing:
  {X.Ansi.wrap(X.S.of([97, 98, 99, 32, 32, 32]), 10, False{}) == X.S.of([97, 98, 99]) : String}

law r_crlf:
  {X.Ansi.wrap(X.S.of([97, 98, 32, 99, 100, 13, 10, 101, 102]), 3, False{}) == X.S.of([97, 98, 10, 99, 100, 10, 101, 102]) : String}

law r_empty_lines:
  {X.Ansi.wrap(X.S.of([97, 10, 10, 98]), 5, False{}) == X.S.of([97, 10, 10, 98]) : String}

law r_blank_line:
  {X.Ansi.wrap(X.S.of([32, 32, 32, 10, 120]), 5, False{}) == X.S.of([10, 120]) : String}

law r_nested:
  {X.Ansi.wrap(X.S.of([27, 91, 51, 49, 109, 97, 97, 32, 27, 91, 49, 109, 98, 98, 32, 99, 99, 27, 91, 50, 50, 109, 32, 100, 100, 27, 91, 51, 57, 109]), 5, False{}) == X.S.of([27, 91, 51, 49, 109, 97, 97, 32, 27, 91, 49, 109, 98, 98, 27, 91, 50, 50, 109, 27, 91, 51, 57, 109, 10, 27, 91, 51, 49, 109, 27, 91, 49, 109, 99, 99, 27, 91, 50, 50, 109, 32, 100, 100, 27, 91, 51, 57, 109]) : String}

# wrap-ansi reopens the link with BEL; bend-tty keeps the ST it was written with
law r_link:
  {X.Ansi.wrap(X.S.of([27, 93, 56, 59, 59, 104, 116, 116, 112, 115, 58, 47, 47, 98, 101, 110, 100, 45, 108, 97, 110, 103, 46, 99, 111, 109, 27, 92, 97, 97, 32, 98, 98, 32, 99, 99, 27, 93, 56, 59, 59, 27, 92]), 5, False{}) == X.S.of([27, 93, 56, 59, 59, 104, 116, 116, 112, 115, 58, 47, 47, 98, 101, 110, 100, 45, 108, 97, 110, 103, 46, 99, 111, 109, 27, 92, 97, 97, 32, 98, 98, 27, 93, 56, 59, 59, 27, 92, 10, 27, 93, 56, 59, 59, 104, 116, 116, 112, 115, 58, 47, 47, 98, 101, 110, 100, 45, 108, 97, 110, 103, 46, 99, 111, 109, 27, 92, 99, 99, 27, 93, 56, 59, 59, 27, 92]) : String}

law r_emoji:
  {X.Ansi.wrap(X.S.of([128512, 128512, 128512, 32, 97, 98]), 4, True{}) == X.S.of([128512, 128512, 10, 128512, 10, 97, 98]) : String}

law r_exact:
  {X.Ansi.wrap(X.S.of([97, 98, 99, 32, 100, 101, 102]), 3, False{}) == X.S.of([97, 98, 99, 10, 100, 101, 102]) : String}

law r_hard_exact:
  {X.Ansi.wrap(X.S.of([97, 98, 99, 100, 101, 102]), 3, True{}) == X.S.of([97, 98, 99, 10, 100, 101, 102]) : String}

law r_close_at_break:
  {X.Ansi.wrap(X.S.of([27, 91, 51, 49, 109, 97, 97, 97, 32, 27, 91, 51, 57, 109, 98, 98, 98]), 3, False{}) == X.S.of([27, 91, 51, 49, 109, 97, 97, 97, 27, 91, 51, 57, 109, 10, 27, 91, 51, 57, 109, 98, 98, 98]) : String}

law r_bg:
  {X.Ansi.wrap(X.S.of([27, 91, 52, 52, 109, 97, 97, 97, 32, 98, 98, 98, 27, 91, 52, 57, 109]), 3, False{}) == X.S.of([27, 91, 52, 52, 109, 97, 97, 97, 27, 91, 52, 57, 109, 10, 27, 91, 52, 52, 109, 98, 98, 98, 27, 91, 52, 57, 109]) : String}

law t_end:
  {X.Ansi.truncate(X.S.of([117, 110, 105, 99, 111, 114, 110, 115, 32, 114, 97, 105, 110, 98, 111, 119]), 7, X.Cut.End{}) == X.S.of([117, 110, 105, 99, 111, 114, 8230]) : String}

law t_start:
  {X.Ansi.truncate(X.S.of([117, 110, 105, 99, 111, 114, 110, 115, 32, 114, 97, 105, 110, 98, 111, 119]), 7, X.Cut.Start{}) == X.S.of([8230, 97, 105, 110, 98, 111, 119]) : String}

law t_middle:
  {X.Ansi.truncate(X.S.of([117, 110, 105, 99, 111, 114, 110, 115, 32, 114, 97, 105, 110, 98, 111, 119]), 7, X.Cut.Middle{}) == X.S.of([117, 110, 105, 8230, 98, 111, 119]) : String}

law t_styled_end:
  {X.Ansi.truncate(X.S.of([27, 91, 51, 49, 109, 117, 110, 105, 99, 111, 114, 110, 115, 27, 91, 51, 57, 109]), 5, X.Cut.End{}) == X.S.of([27, 91, 51, 49, 109, 117, 110, 105, 99, 8230, 27, 91, 51, 57, 109]) : String}

law t_styled_start:
  {X.Ansi.truncate(X.S.of([27, 91, 51, 49, 109, 117, 110, 105, 99, 111, 114, 110, 115, 27, 91, 51, 57, 109]), 5, X.Cut.Start{}) == X.S.of([27, 91, 51, 49, 109, 8230, 111, 114, 110, 115, 27, 91, 51, 57, 109]) : String}

law t_cjk_end:
  {X.Ansi.truncate(X.S.of([20013, 25991, 20013, 25991]), 5, X.Cut.End{}) == X.S.of([20013, 25991, 8230]) : String}

law t_cjk_start:
  {X.Ansi.truncate(X.S.of([20013, 25991, 20013, 25991]), 4, X.Cut.Start{}) == X.S.of([8230, 25991]) : String}

law t_fits:
  {X.Ansi.truncate(X.S.of([97, 98, 99]), 3, X.Cut.End{}) == X.S.of([97, 98, 99]) : String}

law t_one:
  {X.Ansi.truncate(X.S.of([97, 98, 99]), 1, X.Cut.End{}) == X.S.of([8230]) : String}

law t_zero:
  {X.Ansi.truncate(X.S.of([97, 98, 99]), 0, X.Cut.End{}) == "" : String}

law t_middle_even:
  {X.Ansi.truncate(X.S.of([97, 98, 99, 100, 101, 102, 103, 104]), 6, X.Cut.Middle{}) == X.S.of([97, 98, 99, 8230, 103, 104]) : String}

law t_emoji_end:
  {X.Ansi.truncate(X.S.of([97, 128512, 128512]), 3, X.Cut.End{}) == X.S.of([97, 8230]) : String}

law t_two:
  {X.Ansi.truncate(X.S.of([97, 98, 99]), 2, X.Cut.Middle{}) == X.S.of([97, 8230]) : String}

# Inline
# ------
# The escapes an inline frame needs, as bytes; a link stripped is its
# text, and takes its text's width

law inline_escapes:
  {[T.Tty.up(3), T.Tty.down(1), T.Tty.up(0), T.Tty.column(5), T.Tty.erase_line(), T.Tty.erase_down(),
    T.Tty.save(), T.Tty.restore(), T.Tty.sync(True{}), T.Tty.sync(False{}), T.Tty.erase_lines(0)]
   == [SCon{Chr{27}, "[3A"}, SCon{Chr{27}, "[1B"}, "", SCon{Chr{27}, "[5G"}, SCon{Chr{27}, "[2K"}, SCon{Chr{27}, "[J"}, SCon{Chr{27}, "7"}, SCon{Chr{27}, "8"}, SCon{Chr{27}, "[?2026h"}, SCon{Chr{27}, "[?2026l"}, ""] : List<&2, String>}

# three rows erased: erase, up, erase, up, erase, then column 1
law inline_erase_lines:
  {T.Tty.erase_lines(3) == SCon{Chr{27}, "[2K"} ++ SCon{Chr{27}, "[1A"} ++ SCon{Chr{27}, "[2K"} ++ SCon{Chr{27}, "[1A"} ++ SCon{Chr{27}, "[2K"} ++ SCon{Chr{27}, "[1G"} : String}

law inline_link:
  {[T.Tty.link(True{}, "https://bend-lang.com", "Bend"), T.Tty.link(False{}, "https://bend-lang.com", "Bend"),
    T.Tty.link(False{}, "https://bend-lang.com", "https://bend-lang.com")]
   == [SCon{Chr{27}, "]8;;"} ++ "https://bend-lang.com" ++ SCon{Chr{27}, "\\"} ++ "Bend" ++ SCon{Chr{27}, "]8;;"} ++ SCon{Chr{27}, "\\"}, "Bend (https://bend-lang.com)", "https://bend-lang.com"] : List<&2, String>}

law inline_link_text:
  {[X.Ansi.strip(T.Tty.link(True{}, "https://bend-lang.com", "Bend 日本")), U32.show(X.Ansi.width(T.Tty.link(True{}, "https://bend-lang.com", "Bend 日本")))]
   == ["Bend 日本", "9"] : List<&2, String>}
