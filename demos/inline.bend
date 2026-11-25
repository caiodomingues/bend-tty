# inline: a three-row progress frame redrawn in place under the prompt,
# with no alternate screen, then a link. Each redraw erases the frame it
# drew (Tty.erase_lines) and writes the next one inside synchronized
# output, with the cursor hidden. Moving the cursor needs a terminal, not
# colour: when stdout is not one, or TERM is dumb, only the finished frame
# is written, and the link as plain text, whatever FORCE_COLOR says. The
# colour level decides the paint alone.
#
#   bend demos/inline.bend
#   bend demos/inline.bend | cat
import Base
import ../tty.bend as T
import ../color.bend as C
import ../text.bend as X
import ../tty_io.bend as IOT

def bar.go(n: Nat, +done: U32, +i: U32) -> String:
  match n:
    case 0n:
      ""
    case 1n+p:
      Bool.pick(String, U32.is_lt(i, done), "#", ".") ++ bar.go(p, done, (i + 1 : U32))

# step i of 20 as three rows, the last with no line break after it
def frame(+l: C.Level, +i: U32) -> String:
  +p = C.Style.plain()
  C.Style.paint(l, C.Style.bold(p), "installing engine 2.0.40") ++ "\n"
    ++ "[" ++ C.Style.paint(l, C.Style.fg(C.Color.green(), p), bar.go(20n, i, 0)) ++ "] " ++ U32.show((i * 5 : U32)) ++ "%\n"
    ++ C.Style.paint(l, C.Style.dim(p), X.Ansi.truncate("fetching bend-tty, bend-tui, bend-math, bend-draw and bend-physics", 40, X.Cut.Middle{}))

def redraw(+l: C.Level, +i: U32) -> String:
  T.Tty.sync(True{}) ++ T.Tty.erase_lines(3) ++ frame(l, i) ++ T.Tty.sync(False{})

def steps(n: Nat, +l: C.Level, +i: U32) -> IO(Unit):
  match n:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      do IO<Unit>:
        IO.sleep(60)
        IO.write(redraw(l, i))
        steps(p, l, (i + 1 : U32))

def link(live: Bool) -> String:
  "\ndocs: " ++ T.Tty.link(live, "https://bend-lang.com", "bend-lang.com") ++ "\n"

def run(+l: C.Level, live: Bool) -> IO(Unit):
  match live:
    case False{}:
      IO.write(frame(l, 20) ++ link(False{}))
    case True{}:
      do IO<Unit>:
        IO.write(T.Tty.cursor(False{}) ++ frame(l, 0))
        steps(20n, l, 1)
        IO.write(link(True{}) ++ T.Tty.cursor(True{}))

def dumb(r: Result<&1, &1, U32 & String, String>) -> Bool:
  match r:
    case Done{v}:
      String.eq(v, "dumb")
    case Fail{e}:
      False{}

def main() -> IO(Unit):
  do IO<Unit>:
    l : C.Level <- IOT.Tty.level(1)
    tty : Bool <- IOT.Tty.isatty(1)
    term : Result<&1, &1, U32 & String, String> <- IO.get_env("TERM")
    run(l, Bool.and(tty, Bool.not(dumb(term))))
