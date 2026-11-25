# colors: the same colours at every level. On a terminal each row is
# painted as that level paints it; piped, stdout's level is none, so each
# row is printed with its escapes made visible (\e for ESC): what that
# level would send, and no escape reaches the pipe.
#
#   bend demos/colors.bend
#   bend demos/colors.bend | cat
import Base
import ../color.bend as C
import ../tty_io.bend as IOT

def visible.char(+c: U32, esc: Bool) -> String:
  match esc:
    case True{}:
      "\\e"
    case False{}:
      SCon{Chr{c}, SNil{}}

def visible(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c}, t}:
      visible.char(c, U32.is_eq(c, 27)) ++ visible(t)

def basics(n: Nat, +i: U32) -> List<&2, C.Color>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      C.Color.Basic{i} <> basics(p, (i + 1 : U32))

# a ramp from red through yellow, green, cyan and blue to magenta
def ramp() -> List<&2, C.Color>:
  [C.Color.hex("ff0000"), C.Color.hex("ff8000"), C.Color.hex("ffff00"), C.Color.hex("80ff00"),
   C.Color.hex("00ff00"), C.Color.hex("00ff80"), C.Color.hex("00ffff"), C.Color.hex("0080ff"),
   C.Color.hex("0000ff"), C.Color.hex("8000ff"), C.Color.hex("ff00ff"), C.Color.hex("ff0080")]

def greys(n: Nat, +v: U32) -> List<&2, C.Color>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      C.Color.Rgb{v, v, v} <> greys(p, (v + 21 : U32))

def swatches(+l: C.Level, cs: List<&2, C.Color>) -> String:
  match cs:
    case Nil{}:
      C.Color.bg_close(l)
    case c <> t:
      C.Color.bg(l, c) ++ "  " ++ swatches(l, t)

def row(+l: C.Level, name: String) -> String:
  name ++ swatches(l, basics(16n, 0)) ++ " " ++ swatches(l, ramp()) ++ " " ++ swatches(l, greys(13n, 0))
    ++ " " ++ C.Color.fg(l, C.Color.hex("ff8800")) ++ "orange" ++ C.Color.fg_close(l)

def show(+out: C.Level, s: String) -> String:
  match out:
    case C.Level.None{}:
      visible(s) ++ "\n"
    case other:
      s ++ "\n"

def page(+out: C.Level) -> String:
  "stdout: " ++ C.Level.show(out) ++ "\n"
    ++ show(out, row(C.Level.TrueColor{}, "truecolor "))
    ++ show(out, row(C.Level.Ansi256{}, "256       "))
    ++ show(out, row(C.Level.Basic{}, "16        "))
    ++ show(out, row(C.Level.None{}, "none      "))

def main() -> IO(Unit):
  do IO<Unit>:
    l : C.Level <- IOT.Tty.level(1)
    IO.write(page(l))
