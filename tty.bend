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
  Alt{code: U32}    # Alt (Meta) with a printable: ESC then the byte
  Ctrl{code: U32}   # Ctrl-A .. Ctrl-Z as 1 .. 26 (Ctrl-C is 3)
  F{n: U32}         # F1 .. F12
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
  Insert{}
  Delete{}
  PageUp{}
  PageDown{}

# a byte classified by the range ECMA-48 gives it, once, so the
# decoder matches a parameter: a match reads a parameter, never a
# computed value, and the decoder is one recursive def over the tokens
type Tok is Data:
  TEsc{}            # 27
  TCtrl{c: U32}     # 0 .. 31 but 27; and 127
  TInter{c: U32}    # 32 .. 47: an intermediate byte of a CSI, a printable otherwise
  TParam{c: U32}    # 48 .. 63: a parameter byte of a CSI (digits, ;), a printable otherwise
  TBracket{}        # 91: [ , the CSI introducer after ESC
  TO{}              # 79: O , the SS3 introducer after ESC
  TFinal{c: U32}    # 64 .. 126 otherwise: the final byte of a CSI or SS3, a printable otherwise
  TCont{c: U32}     # 128 .. 191: a UTF-8 continuation, its 6 bits
  TLead2{c: U32}    # 194 .. 223: a UTF-8 lead of 2 bytes, its payload bits
  TLead3{c: U32}    # 224 .. 239
  TLead4{c: U32}    # 240 .. 244
  TBad{}            # 192, 193, 245 .. 255: never valid UTF-8

# the classifier is a chain of verdicts, each a def that matches the
# Bool the caller computed, from the highest range down
def Tty.tok.lead4(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TLead4{U32.and(b, 7)}
    case False{}:
      TBad{}

def Tty.tok.lead3(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TLead3{U32.and(b, 15)}
    case False{}:
      Tty.tok.lead4(b, U32.is_le(b, 244))

def Tty.tok.lead2(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TLead2{U32.and(b, 31)}
    case False{}:
      Tty.tok.lead3(b, U32.is_lt(b, 240))

def Tty.tok.overlong(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TBad{}
    case False{}:
      Tty.tok.lead2(b, U32.is_lt(b, 224))

def Tty.tok.cont(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TCont{U32.and(b, 63)}
    case False{}:
      Tty.tok.overlong(b, U32.is_lt(b, 194))

def Tty.tok.o(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TO{}
    case False{}:
      TFinal{b}

def Tty.tok.bracket(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TBracket{}
    case False{}:
      Tty.tok.o(b, U32.is_eq(b, 79))

def Tty.tok.param(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TParam{b}
    case False{}:
      Tty.tok.bracket(b, U32.is_eq(b, 91))

def Tty.tok.inter(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TInter{b}
    case False{}:
      Tty.tok.param(b, U32.is_lt(b, 64))

def Tty.tok.del(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TCtrl{b}
    case False{}:
      Tty.tok.inter(b, U32.is_lt(b, 48))

def Tty.tok.esc(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      TEsc{}
    case False{}:
      TCtrl{b}

def Tty.tok.low(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      Tty.tok.esc(b, U32.is_eq(b, 27))
    case False{}:
      Tty.tok.del(b, U32.is_eq(b, 127))

def Tty.tok.high(+b: U32, c: Bool) -> Tok:
  match c:
    case True{}:
      Tty.tok.cont(b, U32.is_lt(b, 192))
    case False{}:
      Tty.tok.low(b, U32.is_lt(b, 32))

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

# The keys a final byte names
# ---------------------------

# a control byte on its own
def Tty.ctrl.enter(+c: U32, e: Bool) -> Key:
  match e:
    case True{}:
      Enter{}
    case False{}:
      Ctrl{c}

def Tty.ctrl.tab(+c: U32, e: Bool) -> Key:
  match e:
    case True{}:
      Tab{}
    case False{}:
      Tty.ctrl.enter(c, Bool.or(U32.is_eq(c, 13), U32.is_eq(c, 10)))

def Tty.ctrl.bs(+c: U32, e: Bool) -> Key:
  match e:
    case True{}:
      Backspace{}
    case False{}:
      Tty.ctrl.tab(c, U32.is_eq(c, 9))

def Tty.ctrl(+c: U32) -> Key:
  Tty.ctrl.bs(c, Bool.or(U32.is_eq(c, 127), U32.is_eq(c, 8)))

# the letter that ends ESC [ .. or ESC O ..: A B C D H F name keys, and
# after ESC O, P Q R S name F1 .. F4; anything else is dropped
def Tty.letter.s(+c: U32, e: Bool) -> List<&2, Key>:
  match e:
    case True{}:
      [F{4}]
    case False{}:
      Nil{}

def Tty.letter.r(+c: U32, e: Bool) -> List<&2, Key>:
  match e:
    case True{}:
      [F{3}]
    case False{}:
      Tty.letter.s(c, U32.is_eq(c, 83))

def Tty.letter.q(+c: U32, e: Bool) -> List<&2, Key>:
  match e:
    case True{}:
      [F{2}]
    case False{}:
      Tty.letter.r(c, U32.is_eq(c, 82))

def Tty.letter.p(+c: U32, e: Bool) -> List<&2, Key>:
  match e:
    case True{}:
      [F{1}]
    case False{}:
      Tty.letter.q(c, U32.is_eq(c, 81))

def Tty.letter.f(+c: U32, e: Bool) -> List<&2, Key>:
  match e:
    case True{}:
      [End{}]
    case False{}:
      Tty.letter.p(c, U32.is_eq(c, 80))

def Tty.letter.h(+c: U32, e: Bool) -> List<&2, Key>:
  match e:
    case True{}:
      [Home{}]
    case False{}:
      Tty.letter.f(c, U32.is_eq(c, 70))

def Tty.letter.d(+c: U32, e: Bool) -> List<&2, Key>:
  match e:
    case True{}:
      [Left{}]
    case False{}:
      Tty.letter.h(c, U32.is_eq(c, 72))

def Tty.letter.c(+c: U32, e: Bool) -> List<&2, Key>:
  match e:
    case True{}:
      [Right{}]
    case False{}:
      Tty.letter.d(c, U32.is_eq(c, 68))

def Tty.letter.b(+c: U32, e: Bool) -> List<&2, Key>:
  match e:
    case True{}:
      [Down{}]
    case False{}:
      Tty.letter.c(c, U32.is_eq(c, 67))

def Tty.letter.a(+c: U32, e: Bool) -> List<&2, Key>:
  match e:
    case True{}:
      [Up{}]
    case False{}:
      Tty.letter.b(c, U32.is_eq(c, 66))

def Tty.letter(+c: U32) -> List<&2, Key>:
  Tty.letter.a(c, U32.is_eq(c, 65))

# the first number of a CSI's parameters, the digits up to the first ;
# (ESC [ 1 ; 2 A is Up with Shift: the modifier is ignored). ps holds
# the parameter bytes reversed; value and done fold them with no match
def Tty.num.go(+ps: List<&2, U32>, +value: U32, +done: Bool) -> U32:
  match ps:
    case Nil{}:
      value
    case c <> t:
      +digit = Bool.and(U32.is_ge(c, 48), U32.is_le(c, 57))
      +stop  = Bool.or(done, Bool.not(digit))
      Tty.num.go(t, Bool.pick(U32, stop, value, U32.add(U32.mul(value, 10), U32.sub(c, 48))), stop)

def Tty.num(ps: List<&2, U32>) -> U32:
  Tty.num.go(List.reverse(&2, U32, ps), 0, False{})

# ESC [ n ~ : Home Insert Delete End PageUp PageDown, then F5 .. F12
def Tty.tilde.at(n: Nat) -> List<&2, Key>:
  match n:
    case 1n+0n:
      [Home{}]
    case 1n+1n+0n:
      [Insert{}]
    case 1n+1n+1n+0n:
      [Delete{}]
    case 1n+1n+1n+1n+0n:
      [End{}]
    case 1n+1n+1n+1n+1n+0n:
      [PageUp{}]
    case 1n+1n+1n+1n+1n+1n+0n:
      [PageDown{}]
    case 1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+0n:
      [F{5}]
    case 1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+0n:
      [F{6}]
    case 1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+0n:
      [F{7}]
    case 1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+0n:
      [F{8}]
    case 1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+0n:
      [F{9}]
    case 1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+0n:
      [F{10}]
    case 1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+0n:
      [F{11}]
    case 1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+0n:
      [F{12}]
    case other:
      Nil{}

def Tty.tilde(n: U32) -> List<&2, Key>:
  Tty.tilde.at(U32.to_nat(n))

# ESC [ ps c : ~ reads the number, a letter names the key
def Tty.csi.fin(+c: U32, ps: List<&2, U32>, e: Bool) -> List<&2, Key>:
  match e:
    case True{}:
      Tty.tilde(Tty.num(ps))
    case False{}:
      Tty.letter(c)

def Tty.csi(+c: U32, ps: List<&2, U32>) -> List<&2, Key>:
  Tty.csi.fin(c, ps, U32.is_eq(c, 126))

# The decoder
# -----------
# One recursive def over the tokens, with the state of the sequence
# in progress. Every recursive call is on the tail, so termination is
# structural. A sequence that ends or breaks decodes to nothing, but a
# lone ESC (at the end, or before another ESC or a control byte) is the
# Esc key, and ESC before a printable is Alt with it.

type St is Data:
  Start{}
  AfterEsc{}
  Csi{ps: List<&2, U32>}       # ESC [ seen; the parameter bytes so far, reversed
  Ss3{}                        # ESC O seen
  Utf{need: Nat, acc: U32}     # a code point with need continuation bytes to go

def Tty.flush(st: St) -> List<&2, Key>:
  match st:
    case AfterEsc{}:
      [Esc{}]
    case other:
      Nil{}

def Tty.keys.go(ts: List<&2, Tok>, st: St) -> List<&2, Key>:
  match ts:
    case Nil{}:
      Tty.flush(st)
    case t <> rest:
      match t st:
        case TEsc{} Start{}:
          Tty.keys.go(rest, AfterEsc{})
        case TCtrl{c} Start{}:
          Tty.ctrl(c) <> Tty.keys.go(rest, Start{})
        case TInter{c} Start{}:
          Char{c} <> Tty.keys.go(rest, Start{})
        case TParam{c} Start{}:
          Char{c} <> Tty.keys.go(rest, Start{})
        case TBracket{} Start{}:
          Char{91} <> Tty.keys.go(rest, Start{})
        case TO{} Start{}:
          Char{79} <> Tty.keys.go(rest, Start{})
        case TFinal{c} Start{}:
          Char{c} <> Tty.keys.go(rest, Start{})
        case TLead2{c} Start{}:
          Tty.keys.go(rest, Utf{1n, c})
        case TLead3{c} Start{}:
          Tty.keys.go(rest, Utf{2n, c})
        case TLead4{c} Start{}:
          Tty.keys.go(rest, Utf{3n, c})
        case TCont{c} Start{}:
          Tty.keys.go(rest, Start{})
        case TBad{} Start{}:
          Tty.keys.go(rest, Start{})
        case TEsc{} AfterEsc{}:
          Esc{} <> Tty.keys.go(rest, AfterEsc{})
        case TBracket{} AfterEsc{}:
          Tty.keys.go(rest, Csi{Nil{}})
        case TO{} AfterEsc{}:
          Tty.keys.go(rest, Ss3{})
        case TInter{c} AfterEsc{}:
          Alt{c} <> Tty.keys.go(rest, Start{})
        case TParam{c} AfterEsc{}:
          Alt{c} <> Tty.keys.go(rest, Start{})
        case TFinal{c} AfterEsc{}:
          Alt{c} <> Tty.keys.go(rest, Start{})
        case TCtrl{c} AfterEsc{}:
          Esc{} <> Tty.ctrl(c) <> Tty.keys.go(rest, Start{})
        case other AfterEsc{}:
          Esc{} <> Tty.keys.go(rest, Start{})
        case TParam{c} Csi{ps}:
          Tty.keys.go(rest, Csi{c <> ps})
        case TInter{c} Csi{ps}:
          Tty.keys.go(rest, Csi{ps})
        case TFinal{c} Csi{ps}:
          List.append(&2, Key, Tty.csi(c, ps), Tty.keys.go(rest, Start{}))
        case other Csi{ps}:
          Tty.keys.go(rest, Start{})
        case TFinal{c} Ss3{}:
          List.append(&2, Key, Tty.letter(c), Tty.keys.go(rest, Start{}))
        case other Ss3{}:
          Tty.keys.go(rest, Start{})
        case TCont{c} Utf{need, acc}:
          match need:
            case 1n+0n:
              Char{U32.or(U32.shln(acc, 6n), c)} <> Tty.keys.go(rest, Start{})
            case 1n+1n+p:
              Tty.keys.go(rest, Utf{1n+p, U32.or(U32.shln(acc, 6n), c)})
            case 0n:
              Tty.keys.go(rest, Start{})
        case other Utf{need, acc}:
          Tty.keys.go(rest, Start{})

# the keys in a run of bytes from stdin
def Tty.keys(bs: List<&2, U32>) -> List<&2, Key>:
  Tty.keys.go(Tty.toks(bs), Start{})

def Key.show(k: Key) -> String:
  match k:
    case Char{c}:
      "Char " ++ U32.show(c)
    case Alt{c}:
      "Alt " ++ U32.show(c)
    case Ctrl{c}:
      "Ctrl " ++ U32.show(c)
    case F{n}:
      "F" ++ U32.show(n)
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
    case Insert{}:
      "Insert"
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

# q, Up, Enter, Delete, Ctrl-C, ç (c3 a7), F5, Shift+Up, F1, Alt-q, a lone Esc
def main() -> List<&2, String>:
  Key.show_all(Tty.keys([113, 27, 91, 65, 13, 27, 91, 51, 126, 3, 195, 167, 27, 91, 49, 53, 126, 27, 91, 49, 59, 50, 65, 27, 79, 80, 27, 113, 27]))
