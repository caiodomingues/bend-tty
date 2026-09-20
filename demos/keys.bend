# keys: prints each key stdin gives, decoded, until Esc or a Ctrl key.
# Works interactively (raw mode) and piped:
#
#   bend demos/keys.bend
#   printf '\033[Aq\003' | bend demos/keys.bend
import Base
import ../tty.bend as T

# the keys of one read, printed; the loop is fuel-bounded
def show(fuel: Nat, ks: List<&2, T.Key>) -> IO(Unit):
  match fuel:
    case 0n:
      IO.print("(out of fuel)")
    case 1n+p:
      match ks:
        case Nil{}:
          do IO<Unit>:
            bs : List<&2, U32> <- T.Tty.read(100, 64)
            show(p, T.Tty.keys(bs))
        case T.Esc{} <> rest:
          IO.print("Esc: bye")
        case T.Ctrl{c} <> rest:
          IO.print("Ctrl " ++ U32.show(c) ++ ": bye")
        case k <> rest:
          do IO<Unit>:
            IO.print(T.Key.show(k))
            show(p, rest)

def main() -> IO(Unit):
  do IO<Unit>:
    T.Tty.raw(True{})
    IO.print("press keys; Esc or Ctrl-C quits")
    show(100000n, Nil{})
