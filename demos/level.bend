# level: what this terminal can show, as bend-tty and supports-color
# decide it for stdout, and the facts behind the answer.
#
#   bend demos/level.bend                 # on a terminal
#   bend demos/level.bend | cat           # piped: none
#   NO_COLOR=1 bend demos/level.bend
import Base
import ../color.bend as C
import ../tty_io.bend as IOT

def show.var(v: C.Var) -> String:
  match v:
    case C.Var{n, None{}}:
      ""
    case C.Var{n, Some{x}}:
      n ++ "=" ++ x ++ "
"

def show.vars(vs: List<&2, C.Var>) -> String:
  match vs:
    case Nil{}:
      ""
    case v <> t:
      show.var(v) ++ show.vars(t)

def show(f: C.Facts) -> String:
  match f:
    case C.Facts{+tty, +force, +env}:
      "stdout is a terminal: " ++ Bool.show(tty) ++ "
" ++ show.vars(env)
        ++ "level: " ++ C.Level.show(C.Level.detect(C.Facts{tty, force, env})) ++ "
"

def main() -> IO(Unit):
  do IO<Unit>:
    f : C.Facts <- IOT.Tty.facts(1)
    IO.write(show(f))
