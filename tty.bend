# bend-tty: the terminal for Bend 2. Three host effects Base lacks (raw
# mode, the window size, a timed read of stdin), plus what a terminal
# UI needs on top of them in pure Bend: the escape sequences that move
# the cursor and paint, and a decoder from the bytes stdin gives to
# Tty.keys. A program loops: read bytes, decode, update, draw.
#
#   bend tty.bend        # checks; main prints the keys in a sample
#
# Every effect is a def whose body is a .c and a .js import; the host
# function has the def's name lowercased, dots to underscores. The C
# side is the native lane (Linux, macOS); the JS side runs under bun
# on POSIX, where bun:ffi reaches poll and Tty.read.

import Base

# Effects
# -------

# raw mode on or off: no echo, no line buffering, Ctrl-C as byte 3.
# Restored at exit. A no-op when stdin is not a terminal
def Tty.raw(on: Bool) -> IO(Unit):
  import "./effs/tty_raw.c"
  import "./effs/tty_raw.js"

# the terminal's columns and rows; 80 x 24 when unknown
def Tty.size() -> IO(U32 & U32):
  import "./effs/tty_size.c"
  import "./effs/tty_size.js"

# the bytes stdin has within ms milliseconds, at most max of them:
# Some{[]} on a timeout, None at the end of the input (a closed pipe)
# or on an error. Waits on a helper thread (C) or a parked fd (JS), so
# other computations keep running
def Tty.read(ms: U32, max: U32) -> IO(Maybe<&2, List<&2, U32>>):
  import "./effs/tty_read.c"
  import "./effs/tty_read.js"

# Escapes
# -------
# Each is a String to IO.write; ESC is character 27

def Tty.esc() -> String:
  SCon{Chr{27}, "["}

def Tty.clear() -> String:
  Tty.esc() ++ "2J"

def Tty.home() -> String:
  Tty.esc() ++ "H"

# the cursor to column x, row y, both from 1
def Tty.goto(x: U32, y: U32) -> String:
  Tty.esc() ++ U32.show(y) ++ ";" ++ U32.show(x) ++ "H"

def Tty.alt(on: Bool) -> String:
  match on:
    case True{}:
      Tty.esc() ++ "?1049h"
    case False{}:
      Tty.esc() ++ "?1049l"

def Tty.cursor(show: Bool) -> String:
  match show:
    case True{}:
      Tty.esc() ++ "?25h"
    case False{}:
      Tty.esc() ++ "?25l"

# a foreground or background color, 0..255
def Tty.fg(c: U32) -> String:
  Tty.esc() ++ "38;5;" ++ U32.show(c) ++ "m"

def Tty.bg(c: U32) -> String:
  Tty.esc() ++ "48;5;" ++ U32.show(c) ++ "m"

def Tty.bold() -> String:
  Tty.esc() ++ "1m"

def Tty.reset() -> String:
  Tty.esc() ++ "0m"

# Keys
# ----

type Key is Data:
  Char{code: U32}   # a printable, as a Unicode code point
  Ctrl{code: U32}   # Ctrl-A .. Ctrl-Z as 1 .. 26 (Ctrl-C is 3)
  Enter{}
  Tab{}
  Backspace{}
  Esc{}
  Up{}
  Down{}
  Left{}
  Right{}
  Home{}
  End{}
  Delete{}
  PageUp{}
  PageDown{}

# a byte, classified once, so the decoder matches a parameter: a match
# reads a parameter, never a computed value, and the decoder is one
# recursive def over the bytes it has not seen yet
type Tok is Data:
  TEsc{}            # 27
  TBracket{}        # [
  TTilde{}          # ~
  TDigit{d: U32}    # 0 .. 9, as its value
  TLetter{c: U32}   # A .. Z
  TCtrl{c: U32}     # 1 .. 31 but 9, 10, 13; and 127
  TPlain{c: U32}    # 32 .. 126, and 9, 10, 13
  TLead2{c: U32}    # a UTF-8 lead of 2 bytes, its payload bits
  TLead3{c: U32}
  TLead4{c: U32}
  TCont{c: U32}     # a UTF-8 continuation, its 6 bits

def Tty.tok.lead3(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TLead3{U32.and(b, 15)}
    case False{}:
      TLead4{U32.and(b, 7)}

def Tty.tok.lead2(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TLead2{U32.and(b, 31)}
    case False{}:
      Tty.tok.lead3(b, U32.is_lt(b, 240))

def Tty.tok.cont(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TCont{U32.and(b, 63)}
    case False{}:
      Tty.tok.lead2(b, U32.is_lt(b, 224))

def Tty.tok.letter(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TLetter{b}
    case False{}:
      TPlain{b}

def Tty.tok.digit(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TDigit{U32.sub(b, 48)}
    case False{}:
      Tty.tok.letter(b, Bool.and(U32.is_ge(b, 65), U32.is_le(b, 90)))

def Tty.tok.tilde(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TTilde{}
    case False{}:
      Tty.tok.digit(b, Bool.and(U32.is_ge(b, 48), U32.is_le(b, 57)))

def Tty.tok.bracket(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TBracket{}
    case False{}:
      Tty.tok.tilde(b, U32.is_eq(b, 126))

def Tty.tok.ctrl(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TCtrl{b}
    case False{}:
      Tty.tok.bracket(b, U32.is_eq(b, 91))

def Tty.tok.esc(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TEsc{}
    case False{}:
      Tty.tok.ctrl(b, Bool.and(U32.is_lt(b, 32), Bool.not(Bool.or(U32.is_eq(b, 9), Bool.or(U32.is_eq(b, 10), U32.is_eq(b, 13))))))

def Tty.tok.del(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TCtrl{127}
    case False{}:
      Tty.tok.esc(b, U32.is_eq(b, 27))

def Tty.tok.high(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      Tty.tok.cont(b, U32.is_lt(b, 192))
    case False{}:
      Tty.tok.del(b, U32.is_eq(b, 127))

def Tty.tok.go(+b: U32) -> Tok:
  Tty.tok.high(b, U32.is_ge(b, 128))

def Tty.tok(b: U32) -> Tok:
  Tty.tok.go(b)

def Tty.toks(bs: List<&2, U32>) -> List<&2, Tok>:
  match bs:
    case Nil{}:
      Nil{}
    case b <> t:
      Tty.tok(b) <> Tty.toks(t)

# the letter after ESC [ names a key; anything else is dropped
def Tty.csi.f(+c: U32, e: Bool) -> List<&2, Key>:
  match e:
    case True{}:
      [End{}]
    case False{}:
      Nil{}

def Tty.csi.h(+c: U32, e: Bool) -> List<&2, Key>:
  match e:
    case True{}:
      [Home{}]
    case False{}:
      Tty.csi.f(c, U32.is_eq(c, 70))

def Tty.csi.d(+c: U32, e: Bool) -> List<&2, Key>:
  match e:
    case True{}:
      [Left{}]
    case False{}:
      Tty.csi.h(c, U32.is_eq(c, 72))

def Tty.csi.c(+c: U32, e: Bool) -> List<&2, Key>:
  match e:
    case True{}:
      [Right{}]
    case False{}:
      Tty.csi.d(c, U32.is_eq(c, 68))

def Tty.csi.b(+c: U32, e: Bool) -> List<&2, Key>:
  match e:
    case True{}:
      [Down{}]
    case False{}:
      Tty.csi.c(c, U32.is_eq(c, 67))

def Tty.csi.a(+c: U32, e: Bool) -> List<&2, Key>:
  match e:
    case True{}:
      [Up{}]
    case False{}:
      Tty.csi.b(c, U32.is_eq(c, 66))

def Tty.csi(+c: U32) -> List<&2, Key>:
  Tty.csi.a(c, U32.is_eq(c, 65))

# ESC [ n ~ : 1 Home, 3 Delete, 4 End, 5 PageUp, 6 PageDown
def Tty.tilde.at(n: Nat) -> List<&2, Key>:
  match n:
    case 0n:
      Nil{}
    case 1n+0n:
      [Home{}]
    case 1n+1n+0n:
      Nil{}
    case 1n+1n+1n+0n:
      [Delete{}]
    case 1n+1n+1n+1n+0n:
      [End{}]
    case 1n+1n+1n+1n+1n+0n:
      [PageUp{}]
    case 1n+1n+1n+1n+1n+1n+0n:
      [PageDown{}]
    case 1n+1n+1n+1n+1n+1n+1n+p:
      Nil{}

def Tty.tilde(d: U32) -> List<&2, Key>:
  Tty.tilde.at(U32.to_nat(d))

# a plain byte is a key on its own
def Tty.plain.tab(+c: U32, e: Bool) -> Key:
  match e:
    case True{}:
      Tab{}
    case False{}:
      Char{c}

def Tty.plain.enter(+c: U32, e: Bool) -> Key:
  match e:
    case True{}:
      Enter{}
    case False{}:
      Tty.plain.tab(c, U32.is_eq(c, 9))

def Tty.plain(+c: U32) -> Key:
  Tty.plain.enter(c, Bool.or(U32.is_eq(c, 13), U32.is_eq(c, 10)))

def Tty.ctrl.bs(+c: U32, e: Bool) -> Key:
  match e:
    case True{}:
      Backspace{}
    case False{}:
      Ctrl{c}

def Tty.ctrl(+c: U32) -> Key:
  Tty.ctrl.bs(c, Bool.or(U32.is_eq(c, 127), U32.is_eq(c, 8)))

# The decoder: the bytes classified into tokens, then one recursive
# def over the tokens, whose nested
# patterns look ahead as far as an escape sequence goes. Every
# recursive call is on a strict tail, so termination is structural.

# ESC [ X, ESC [ n ~, and the UTF-8 shapes; an escape that fits
# nothing decodes as Esc and its bytes as themselves
def Tty.keys.go(ts: List<&2, Tok>) -> List<&2, Key>:
  match ts:
    case Nil{}:
      Nil{}
    case TEsc{} <> TBracket{} <> TLetter{c} <> rest:
      List.append(&2, Key, Tty.csi(c), Tty.keys.go(rest))
    case TEsc{} <> TBracket{} <> TDigit{d} <> TTilde{} <> rest:
      List.append(&2, Key, Tty.tilde(d), Tty.keys.go(rest))
    case TEsc{} <> rest:
      Esc{} <> Tty.keys.go(rest)
    case TLead2{a} <> TCont{b} <> rest:
      Char{U32.or(U32.shln(a, 6n), b)} <> Tty.keys.go(rest)
    case TLead3{a} <> TCont{b} <> TCont{c} <> rest:
      Char{U32.or(U32.shln(U32.or(U32.shln(a, 6n), b), 6n), c)} <> Tty.keys.go(rest)
    case TLead4{a} <> TCont{b} <> TCont{c} <> TCont{d} <> rest:
      Char{U32.or(U32.shln(U32.or(U32.shln(U32.or(U32.shln(a, 6n), b), 6n), c), 6n), d)} <> Tty.keys.go(rest)
    case TLead2{a} <> rest:
      Tty.keys.go(rest)
    case TLead3{a} <> rest:
      Tty.keys.go(rest)
    case TLead4{a} <> rest:
      Tty.keys.go(rest)
    case TCont{a} <> rest:
      Tty.keys.go(rest)
    case TBracket{} <> rest:
      Char{91} <> Tty.keys.go(rest)
    case TTilde{} <> rest:
      Char{126} <> Tty.keys.go(rest)
    case TDigit{d} <> rest:
      Char{U32.add(d, 48)} <> Tty.keys.go(rest)
    case TLetter{c} <> rest:
      Char{c} <> Tty.keys.go(rest)
    case TCtrl{c} <> rest:
      Tty.ctrl(c) <> Tty.keys.go(rest)
    case TPlain{c} <> rest:
      Tty.plain(c) <> Tty.keys.go(rest)

# the keys in a run of bytes from stdin
def Tty.keys(bs: List<&2, U32>) -> List<&2, Key>:
  Tty.keys.go(Tty.toks(bs))

def Key.show(k: Key) -> String:
  match k:
    case Char{c}:
      "Char " ++ U32.show(c)
    case Ctrl{c}:
      "Ctrl " ++ U32.show(c)
    case Enter{}:
      "Enter"
    case Tab{}:
      "Tab"
    case Backspace{}:
      "Backspace"
    case Esc{}:
      "Esc"
    case Up{}:
      "Up"
    case Down{}:
      "Down"
    case Left{}:
      "Left"
    case Right{}:
      "Right"
    case Home{}:
      "Home"
    case End{}:
      "End"
    case Delete{}:
      "Delete"
    case PageUp{}:
      "PageUp"
    case PageDown{}:
      "PageDown"

def Key.show_all(ks: List<&2, Key>) -> List<&2, String>:
  match ks:
    case Nil{}:
      Nil{}
    case k <> t:
      Key.show(k) <> Key.show_all(t)

# q, Up, Enter, Delete, Ctrl-C, ç (UTF-8 c3 a7), a lone Esc
def main() -> List<&2, String>:
  Key.show_all(Tty.keys([113, 27, 91, 65, 13, 27, 91, 51, 126, 3, 195, 167, 27]))
