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

# LAW: a lone ESC, or one before something that is no sequence, is Esc
law keys_esc:
  {T.Tty.keys([27, 27, 113]) == [T.Esc{}, T.Esc{}, T.Char{113}] : List<&2, T.Key>}

# LAW: UTF-8 decodes to the code point: ç is c3 a7, € is e2 82 ac
law keys_utf8:
  {T.Tty.keys([195, 167, 226, 130, 172]) == [T.Char{231}, T.Char{8364}] : List<&2, T.Key>}

# LAW: nothing decodes to nothing
law keys_nil:
  {T.Tty.keys(Nil{}) == Nil{} : List<&2, T.Key>}
