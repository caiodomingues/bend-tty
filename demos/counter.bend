# counter: a number on the alternate screen; Up/Down or k/j change it,
# Esc quits. A frame is one String: clear, draw. The loop carries the
# state as Maybe<U32>, None to quit, so the result of a step is a
# parameter of the next iteration, never a matched computation.
#
#   bend demos/counter.bend -o counter && ./counter
import Base
import ../tty.bend as T

def frame(n: U32, cols: U32, rows: U32) -> String:
  T.Tty.clear() ++ T.Tty.goto(2, 2) ++ T.Tty.bold() ++ "counter" ++ T.Tty.reset()
    ++ T.Tty.goto(2, 4) ++ T.Tty.fg(45) ++ U32.show(n) ++ T.Tty.reset()
    ++ T.Tty.goto(2, 6) ++ "Up/Down or k/j, Esc quits   " ++ U32.show(cols) ++ "x" ++ U32.show(rows)

def step.char(+n: U32, k: Bool, j: Bool) -> U32:
  match k j:
    case True{} b:
      (n + 1 : U32)
    case False{} True{}:
      (n - 1 : U32)
    case False{} False{}:
      n

# one key applied; None quits
def step(n: U32, k: T.Key) -> Maybe<&2, U32>:
  match k:
    case T.Up{}:
      Some{(n + 1 : U32)}
    case T.Down{}:
      Some{(n - 1 : U32)}
    case T.Char{+c}:
      Some{step.char(n, U32.is_eq(c, 107), U32.is_eq(c, 106))}
    case T.Esc{}:
      None{}
    case T.Ctrl{c}:
      None{}
    case other:
      Some{n}

def draw(wh: U32 & U32, n: U32) -> IO(Unit):
  (w, h) = wh
  IO.write(frame(n, w, h))

def loop(fuel: Nat, st: Maybe<&2, U32>, ks: List<&2, T.Key>) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      match st:
        case None{}:
          IO.pure(Unit, Unit{})
        case Some{+n}:
          match ks:
            case Nil{}:
              do IO<Unit>:
                wh : U32 & U32 <- T.Tty.size()
                draw(wh, n)
                bs : List<&2, U32> <- T.Tty.read(50, 64)
                loop(p, Some{n}, T.Tty.keys(bs))
            case k <> rest:
              loop(p, step(n, k), rest)

def main() -> IO(Unit):
  do IO<Unit>:
    T.Tty.raw(True{})
    IO.write(T.Tty.alt(True{}) ++ T.Tty.cursor(False{}))
    loop(1000000n, Some{0}, Nil{})
    IO.write(T.Tty.cursor(True{}) ++ T.Tty.alt(False{}))
    T.Tty.raw(False{})
