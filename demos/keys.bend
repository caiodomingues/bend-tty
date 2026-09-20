# keys: prints each key stdin gives, decoded, until Esc or a Ctrl key.
# Works interactively (raw mode) and piped:
#
#   bend demos/keys.bend
#   printf '\033[Aq\003' | bend demos/keys.bend
import Base
import ../tty.bend as T

# a read's answer decoded: None at the end of the input
def keys_of(r: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, T.Key>>:
  match r:
    case None{}:
      None{}
    case Some{bs}:
      Some{T.Tty.keys(bs)}

# the keys of one read, printed; the loop is fuel-bounded
def show(fuel: Nat, r: Maybe<&2, List<&2, T.Key>>) -> IO(Unit):
  match fuel:
    case 0n:
      IO.print("(out of fuel)")
    case 1n+p:
      match r:
        case None{}:
          IO.print("end of input: bye")
        case Some{ks}:
          match ks:
            case Nil{}:
              do IO<Unit>:
                r2 : Maybe<&2, List<&2, U32>> <- T.Tty.read(100, 64)
                show(p, keys_of(r2))
            case T.Esc{} <> rest:
              IO.print("Esc: bye")
            case T.Ctrl{c} <> rest:
              IO.print("Ctrl " ++ U32.show(c) ++ ": bye")
            case k <> rest:
              do IO<Unit>:
                IO.print(T.Key.show(k))
                show(p, Some{rest})

def main() -> IO(Unit):
  do IO<Unit>:
    T.Tty.raw(True{})
    IO.print("press keys; Esc or Ctrl-C quits")
    show(100000n, Some{Nil{}})
