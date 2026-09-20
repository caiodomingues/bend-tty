# bend-tty

The terminal for [Bend](https://bend-lang.com) 2: raw mode, the window size
and a timed read of stdin as host effects, plus the escapes and the key
decoder a terminal UI needs, in pure Bend with its laws proven.

```python
import Base
import ./tty.bend as T

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
```

`demos/counter.bend` is that program in full; `demos/keys.bend` prints what
it decodes and works piped: `printf '\033[Aq' | bend demos/keys.bend`.

## API

| effect | type | host |
| --- | --- | --- |
| `Tty.raw(on)` | `Bool -> IO(Unit)` | raw mode: no echo, no line buffering, Ctrl-C as byte 3; restored at exit and on SIGTERM/SIGHUP/SIGINT (not on a runtime fail-stop); a no-op when stdin is not a terminal |
| `Tty.size()` | `IO(U32 & U32)` | columns and rows; 80 x 24 when unknown |
| `Tty.read(ms, max)` | `U32 -> U32 -> IO(Maybe<&2, List<&2, U32>>)` | the bytes stdin has within `ms`, at most `max` (at least 1): `Some{[]}` on a timeout or when another computation drained the terminal first, `None` at the end of a pipe or on an error. Waits without blocking the other computations |

| pure | what |
| --- | --- |
| `Tty.keys(bytes)` | `List<&2, U32> -> List<&2, Key>`: the decoder |
| `Key` | `Char{code}` (a Unicode code point), `Alt{code}`, `Ctrl{code}`, `F{n}`, `Enter`, `Tab`, `Backspace`, `Esc`, `Up`, `Down`, `Left`, `Right`, `Home`, `End`, `Insert`, `Delete`, `PageUp`, `PageDown` |
| `Key.show(k)` | a name for it |
| `Tty.clear()`, `Tty.home()`, `Tty.goto(x, y)` | erase; the cursor home; to column x, row y (from 1) |
| `Tty.alt(on)`, `Tty.cursor(show)` | the alternate screen; the cursor |
| `Tty.fg(c)`, `Tty.bg(c)`, `Tty.bold()`, `Tty.reset()` | 256-color paint |

Every escape is a `String` for `IO.write`. A program is a loop: read, decode,
update, draw a frame as one string.

The decoder classifies each byte by the range ECMA-48 gives it (`Tok`), then
one recursive def walks the tokens with the sequence in progress as its
state. A CSI (`ESC [`, parameters, intermediates, a final byte) and an SS3
(`ESC O x`) are consumed whole: the ones it knows become keys (arrows with
or without a modifier, Home/End in both spellings, Insert/Delete/PageUp/
PageDown, F1-F12), the rest become nothing, never a stray `Esc`. `ESC`
before a printable is `Alt`; a lone `ESC`, or one before another `ESC` or a
control byte, is `Esc`. UTF-8 decodes to the code point; a truncated,
overlong or impossible sequence is dropped. A sequence cut by a read (by
`ms`, or by `max`) is dropped too: read with a `max` a paste fits in (the
demos use 4096) and a `ms` that lets a keystroke land whole.

## Laws

`LAWS.bend` states what the sequences a terminal sends decode to: arrows,
`Delete`/`PageUp`/`PageDown`, `Enter`/`Tab`/`Backspace`, `Ctrl`, a lone
`Esc` and `Alt`, Home/End, Insert, F1-F12, a Shift-modified arrow, an
unknown CSI, UTF-8 (`ç`, `€`) and its malformed shapes. Every claim is
closed, so `PROOF.bend` is sixteen `{==}`: the checker runs the decoder. Change `Up` to `Down` in `Tty.csi.a`
and `bend PROOF.bend` refuses with the expected and observed terms. A claim
over every byte (32..126 decodes as itself) needs lemmas over `U32`, which
no library has yet.

## Lanes

- **Native** (`bend x.bend -o x`): Linux and macOS. `tty_raw.c` is termios,
  `tty_size.c` is `ioctl(TIOCGWINSZ)`, `tty_read.c` is a `poll` on a helper
  thread (`io_work`), so the event loop keeps serving other computations.
  Verified on Linux with clang 14, under a pty and piped: keys, timeouts,
  the end of input, raw mode on and restored at exit.
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
  a `String` becomes C text with `io_cstr(e, f[1], &w->size)`.
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
