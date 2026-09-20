# minimal: the README program. Up counts, Esc quits; the frame is one
# string. The read's answer is folded into the state by a def of its
# own, so a match never reads a computed value, and the loop is one
# recursive def counting fuel down.
#
#   bend demos/minimal.bend -o minimal && ./minimal
import Base
import ../tty.bend as T

# the keys of one read applied: None at the end of the input or on Esc
def apply(ks: List<&2, T.Key>, st: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match ks:
    case Nil{}:
      st
    case k <> rest:
      match k st:
        case T.Esc{} s:
          None{}
        case T.Up{} Some{n}:
          apply(rest, Some{(n + 1 : U32)})
        case other s:
          apply(rest, s)

def got(n: U32, r: Maybe<&2, List<&2, U32>>) -> Maybe<&2, U32>:
  match r:
    case None{}:
      None{}
    case Some{bs}:
      apply(T.Tty.keys(bs), Some{n})

def loop(fuel: Nat, st: Maybe<&2, U32>) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      match st:
        case None{}:
          IO.pure(Unit, Unit{})
        case Some{+n}:
          do IO<Unit>:
            IO.write(T.Tty.clear() ++ T.Tty.goto(2, 2) ++ U32.show(n))
            r : Maybe<&2, List<&2, U32>> <- T.Tty.read(50, 4096)
            loop(p, got(n, r))

def main() -> IO(Unit):
  do IO<Unit>:
    T.Tty.raw(True{})
    IO.write(T.Tty.alt(True{}))
    loop(100000n, Some{0})
    IO.write(T.Tty.alt(False{}))
    T.Tty.raw(False{})
