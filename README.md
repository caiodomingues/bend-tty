# bend-tty

The terminal for [Bend](https://bend-lang.com) 2: raw mode, the window size
and a timed read of stdin as host effects, plus the escapes and the key
decoder a terminal UI needs, in pure Bend with its laws proven. Requires
Bend 2.0.37: the effects use its C and JS effect API, which has no ABI
promise across releases.

The library is two files. `tty.bend` is pure: the escapes, `Key` and the
decoder, everything the proofs need. `tty_io.bend` holds the three effects.
A proof may import no foreign code, so the split keeps `PROOF.bend` on the
pure file; a program imports both (Bend does not re-export imports).

```python
import Base
import ./tty.bend as T
import ./tty_io.bend as IOT

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
            r : Maybe<&2, List<&2, U32>> <- IOT.Tty.read(50, 4096)
            loop(p, got(n, r))

def main() -> IO(Unit):
  do IO<Unit>:
    IOT.Tty.raw(True{})
    IO.write(T.Tty.alt(True{}))
    loop(100000n, Some{0})
    IO.write(T.Tty.alt(False{}))
    IOT.Tty.raw(False{})
```

That is `demos/minimal.bend`. `demos/counter.bend` adds Down, the size, and
painting only on change; `demos/keys.bend` prints what it decodes and works
piped: `printf '\033[Aq' | bend demos/keys.bend`.

## API

| effect (`tty_io.bend`) | type | host |
| --- | --- | --- |
| `Tty.raw(on)` | `Bool -> IO(Unit)` | raw mode: no echo, no line buffering, Ctrl-C as byte 3. Turning it off, at exit or on SIGTERM/SIGHUP/SIGINT, also shows the cursor and leaves the alternate screen (not on a runtime fail-stop); a no-op when stdin is not a terminal |
| `Tty.size()` | `IO(U32 & U32)` | columns and rows; 80 x 24 when unknown |
| `Tty.read(ms, max)` | `U32 -> U32 -> IO(Maybe<&2, List<&2, U32>>)` | the bytes stdin has within `ms`, at most `max` (at least 1): `Some{[]}` on a timeout or when another computation drained the terminal first, `None` at the end of a pipe or on an error. Waits without blocking the other computations |

| pure (`tty.bend`) | what |
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
closed, so `PROOF.bend` is sixteen `{==}`: the checker runs the decoder, and
`bend PROOF.bend` prints `ALL PROOFS CHECK`. Change `Up` to `Down` in
`Tty.letter.a` and it prints `SOME PROOFS FAIL` with the expected and
observed terms. Both import `tty.bend` alone: importing `tty_io.bend`, or
any file with foreign code, fails the verdict. A claim
over every byte (32..126 decodes as itself) needs lemmas over `U32`, which
no library has yet.

## Lanes

- **Native** (`bend x.bend -o x`): Linux and macOS. `tty_raw.c` is termios,
  `tty_size.c` is `ioctl(TIOCGWINSZ)`, `tty_read.c` is a `poll` on a helper
  thread (`io_work`), so the event loop keeps serving other computations.
  Verified on Linux (WSL) with Bend 2.0.37, under a pty and piped: keys,
  timeouts, the end of input, the size, raw mode on and restored at exit.
- **JS** (`bend x.bend`, or `bend x.bend -o x.js && bun x.js`): bun on
  POSIX. `tty_read.js` parks the computation on fd 0 with a deadline
  (`io_park_on`), then probes it with a zero-timeout `select` and reads what
  is there. Raw mode and the size go through `process.stdin`/`process.stdout`.
  Verified the same way under bun 1.4.2. node cannot run it: the runtime's
  libc access (`io_sys()`) is `bun:ffi`, so `Tty.read` stops with `Cannot
  find module 'bun:ffi'`. A `-o x.js` build succeeds even when an effect is
  broken; only running it shows the failure.
- Windows is not a Bend host and was not tried; `Tty.read` needs libc's
  `select` and `read` through `bun:ffi`.

## Writing an effect

`bend guide` and its `EFFECTS.md` (in `~/.bend/guide/`) are the reference,
and Base's own effects (`bend2/effs/*.c`, `*.js`) the examples. In short, as
of 2.0.37:

An effect is a def whose body is two imports:

```python
def Tty.read(ms: U32, max: U32) -> IO(Maybe<&2, List<&2, U32>>):
  import "./effs/tty_read.c"
  import "./effs/tty_read.js"
```

Each file registers it under the def's name with `io_eff(CID(Tty.read),
run)`, two arguments on both lanes. `CID(Name)` is read in the namespace of
the file that declares the def, then in Base's, so `CID(Tty.read)`,
`CID(Some)` and `CID(Con)` all work from `effs/`. The host function's name
is free.

**C**: `Term tty_read_run(Env e, Term* f, IoWork* w)`, registered in a
constructor. The arguments are `f[0..]`: a `U32` is the word (`(u32)f[0]`),
a `Bool` a constructor (`term_aux(f[0]) == CID(True)`). Answers are
`(Term)n`, `term_pak(CID(Unit), 0)`, `io_tup(e, a, b)`,
`io_node(e, CID(Con), head, tail)`, `io_box(e, CID(Some), v)`. A blocking
call goes to a helper thread with `io_work(w, call, pack)`; a wait on a
descriptor parks with `io_wait_on(w, fd, POLLIN, deadline, more)`, where
`deadline` is an absolute `io_tick()` or 0.

**JS**: `function tty_read(ms, max, k)` returns the answer (a constructor is
`{$: CID(Con), head, tail}`, a `Bool` a JS boolean, a pair `io_tup(a, b)`),
or parks with `io_park_on(fd, out, k, more, deadline)` and returns
`undefined`: the loop calls `more()` when `fd` is ready or the absolute
`performance.now()` deadline passes, and `more` answers or returns
`undefined` to park again. `io_sys()` is libc through `bun:ffi`: `read`,
`recv`, `select`, `fcntl`, `errno`; it has no `poll`.

The runtime moves fast and the guide says there is no ABI promise: rebuild
and rerun the demos on every update. A `-o x.js` build succeeds even when an
effect fails to register, so run its output.

Three rules of the language shaped the Bend side: a safe def is visible
only below its definition and two safe defs may not call each other, so a
loop is one recursive def and a helper never calls back (the decoder
classifies the bytes first, then one recursive def matches the tokens); a
`match` reads a parameter, never a computed value, so a read's answer is
matched by the def it is passed to; and names keep their file's namespace,
so a consumer that imports `as IOT` writes `IOT.Tty.raw`.

## Run

    bend tty.bend                        # the decoder on a sample
    bend PROOF.bend                      # ALL PROOFS CHECK
    bend demos/keys.bend                 # interactive; or piped
    bend demos/counter.bend -o counter && ./counter
    bend demos/counter.bend -o counter.js && bun counter.js

`bend LAWS.bend` reports the sixteen laws as TODOs (they are proven in
`PROOF.bend`). `--check-only` on `tty_io.bend` or a demo prints `SOME PROOFS
FAIL` and lists the effects as foreign code: that is expected for any file
that uses one, so their gate is a build with `-o` and a run. On Windows, run
everything in WSL.
