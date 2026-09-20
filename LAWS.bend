# bend-tty: the laws of the decoder, as the sequences a terminal sends.
# Each is a closed claim, so its proof is reflexivity: the decoder
# computes it. A claim over every byte would need U32 lemmas (a byte
# in 32..126 decodes as itself), which no library has yet.

import Base
import ./tty.bend as T

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
