# bend-tty

The terminal for [Bend](https://bend-lang.com) 2: raw mode, the window size
and a timed read of stdin as host effects, plus the escapes and the key
decoder a terminal UI needs, in pure Bend with its laws proven.

```python
import Base
import ./tty.bend as T

def loop(fuel: Nat, n: U32, ks: List<&2, T.Key>) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      match ks:
        case Nil{}:
          do IO<Unit>:
            IO.write(T.Tty.clear() ++ T.Tty.goto(2, 2) ++ U32.show(n))
            r : Maybe<&2, List<&2, U32>> <- T.Tty.read(50, 64)   # bytes within 50 ms
            loop(p, n, keys_of(r))                                 # decoded; [] at the end of input
        case T.Up{} <> rest:
          loop(p, (n + 1 : U32), rest)
        case T.Esc{} <> rest:
          IO.pure(Unit, Unit{})
        case k <> rest:
          loop(p, n, rest)

def main() -> IO(Unit):
  do IO<Unit>:
    T.Tty.raw(True{})
    IO.write(T.Tty.alt(True{}))
    loop(100000n, 0, Nil{})
    IO.write(T.Tty.alt(False{}))
    T.Tty.raw(False{})
```

`demos/counter.bend` is that program in full; `demos/keys.bend` prints what
it decodes and works piped: `printf '\033[Aq' | bend demos/keys.bend`.

## API

| effect | type | host |
| --- | --- | --- |
| `Tty.raw(on)` | `Bool -> IO(Unit)` | raw mode: no echo, no line buffering, Ctrl-C as byte 3; restored at exit; a no-op when stdin is not a terminal |
| `Tty.size()` | `IO(U32 & U32)` | columns and rows; 80 x 24 when unknown |
| `Tty.read(ms, max)` | `U32 -> U32 -> IO(Maybe<&2, List<&2, U32>>)` | the bytes stdin has within `ms`, at most `max`: `Some{[]}` on a timeout, `None` at the end of the input (a closed pipe) or on an error. Waits without blocking the other computations |

| pure | what |
| --- | --- |
| `Tty.keys(bytes)` | `List<&2, U32> -> List<&2, Key>`: the decoder |
| `Key` | `Char{code}` (a Unicode code point), `Ctrl{code}`, `Enter`, `Tab`, `Backspace`, `Esc`, `Up`, `Down`, `Left`, `Right`, `Home`, `End`, `Delete`, `PageUp`, `PageDown` |
| `Key.show(k)` | a name for it |
| `Tty.clear()`, `Tty.home()`, `Tty.goto(x, y)` | erase; the cursor home; to column x, row y (from 1) |
| `Tty.alt(on)`, `Tty.cursor(show)` | the alternate screen; the cursor |
| `Tty.fg(c)`, `Tty.bg(c)`, `Tty.bold()`, `Tty.reset()` | 256-color paint |

Every escape is a `String` for `IO.write`. A program is a loop: read, decode,
update, draw a frame as one string.

The decoder classifies each byte once (`Tok`) and then matches the token
list with lookahead, so an escape sequence is a pattern: `TEsc <> TBracket <>
TLetter{c} <> rest`. What it knows: `ESC [ A-D` (arrows), `ESC [ H`/`F`
(Home/End), `ESC [ 1/3/4/5/6 ~` (Home/Delete/End/PageUp/PageDown), UTF-8 up
to four bytes. What it drops: `ESC [ 2 ~` (Insert), any other `ESC [ x`
letter, and the `ESC O x` shape of F1-F4 and of arrows in application mode,
which decode as `Esc` and the characters. An escape split across two reads
is not a sequence either; read with a `ms` that lets one land whole
(terminals send it in one write).

## Laws

`LAWS.bend` states what the sequences a terminal sends decode to: arrows,
`Delete`/`PageUp`/`PageDown`, `Enter`/`Tab`/`Backspace`, `Ctrl`, a lone
`Esc`, UTF-8 (`ç`, `€`). Every claim is closed, so `PROOF.bend` is ten
`{==}`: the checker runs the decoder. Change `Up` to `Down` in `Tty.csi.a`
and `bend PROOF.bend` refuses with the expected and observed terms. A claim
over every byte (32..126 decodes as itself) needs lemmas over `U32`, which
no library has yet.

## Lanes

- **Native** (`bend x.bend -o x`): Linux and macOS. `tty_raw.c` is termios,
  `tty_size.c` is `ioctl(TIOCGWINSZ)`, `tty_read.c` is a `poll` on a helper
  thread (`io_work`), so the event loop keeps serving other computations.
- **JS** (`bend x.bend`): bun on POSIX. `tty_read.js` parks the computation
  on fd 0 with a deadline, the runtime's own wait shape, then reads what is
  there. Raw mode and the size go through `process.stdin`/`process.stdout`.
  Verified under a pty and piped: keys, timeouts, the end of input, raw mode
  (no echo, no line buffering).
- Windows is not a Bend host; `Tty.raw` and `Tty.size` run there on the JS
  lane, `Tty.read` does not (the runtime reaches `poll` through `bun:ffi` on
  libc).

## Writing an effect (what the guide leaves out)

An effect is a def whose body is two imports; the host function is the def's
name lowercased, dots to underscores:

```python
def Tty.read(ms: U32, max: U32) -> IO(Maybe<&2, List<&2, U32>>):
  import "./effs/tty_read.c"
  import "./effs/tty_read.js"
```

**C** (`bend2/comp.ts` holds the runtime; these are its calls, as of 2.0.16):

- `Term tty_read_run(Env e, Term* f, IoWork* w)`: the arguments are `f[0..]`.
  A `U32`/`Nat` argument is the word itself (`(u32)f[0]`); a `Bool` is a
  constructor (`term_aux(f[0]) == CID_TRUE`); a handle is `io_hand_v(f[0])`;
  a `String` becomes C text with `io_cstr(e, f[1], &w->size)`. The C side of
  this package is written against those calls but has not been compiled yet
  (no clang on the machine it was written on); the JS side has run.
- Answers: `(Term)n` for a number, `term_pak(CID_UNIT, 0)`, `io_tup(e, a, b)`,
  `io_node(e, CID_CON, head, tail, IO_HOTS & 16)` to cons a list,
  `io_str(e, p, n)` for a string, `io_done(e, v)` / `io_fail(e, code, NULL)`
  for a `Result`.
- A blocking call goes to a helper thread: `return io_work(w, call, pack)`,
  where `call(IoWork*)` runs off the loop and `pack(Env, IoWork*)` builds
  the answer on it; `io_sys_end(w, n)` records `errno` into `w->code`.
- A wait on a descriptor: `return io_wait_on(w, fd, POLLIN, more)`; the loop
  calls `more` when it is ready.
- Register in a constructor: `io_eff(CID_TTY_READ, tty_read_run, 0)`; the
  last argument is `IO_READ` (park on the handle in `f[0]` first) or
  `IO_TIME` (wait `f[0]` ms first) for the two shapes the runtime does itself.

**JS**: `function tty_read(ms, max, k)` returns the value (a constructor is
`{$: "Con", head, tail}`, but a `Bool` is a JS boolean and a `String` a JS
string; a pair is `io_tup(a, b)`, a `Result` `io_done(v)`/`io_fail(code)`),
or `undefined` after parking: `globalThis.BEND_IO.waits.push({fd, out, at,
k, more})` fires `more()` when `fd` is ready or `at` (a `performance.now()`
deadline) passes, and hands its value to `k`. A `tty_read_need()` returning
`{time: true}` or `{read: true}` asks the loop to wait on `args[0]` first.
`io_sys()` is libc through `bun:ffi`: `read`, `poll`, `fcntl`, sockets.

None of this is documented upstream (bendlang/bend#825) and the runtime
moves fast; this package pins what it was written against.

Three rules of the language shaped the Bend side and will shape yours: a
def is visible only below its definition and two defs may not call each
other, so a loop is one recursive def and a helper never calls back (the
decoder classifies the bytes first, then one recursive def matches the
tokens); a `match` reads a parameter, never a computed value, so a read's
answer is matched by the def it is passed to; and the host name is
the def's dotted name, so effects are `Tty.raw`, not `raw`, and a consumer
that imports `as T` writes `T.Tty.raw`.

## Run

    bend tty.bend                        # the decoder on a sample
    bend PROOF.bend                      # All terms check.
    bend demos/keys.bend                 # interactive; or piped
    bend demos/counter.bend -o counter && ./counter

Windows: `bun <bend checkout>/bend2/main.ts <file>` checks and proves; run
the demos in WSL.
