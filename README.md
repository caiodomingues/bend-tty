<p align="center">
  <img src="docs/media/banner.jpg" alt="bend-tty" width="720">
</p>

<h1 align="center">bend-tty</h1>

<p align="center">
  The terminal for <a href="https://bend-lang.com">Bend</a> 2: keys, colours, text and raw mode, with the laws proven.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/bend-2.0.40-8a2be2.svg" alt="Bend 2.0.40">
  <img src="https://img.shields.io/badge/laws-209%20proven-2ea44f.svg" alt="209 laws proven">
  <img src="https://img.shields.io/badge/unicode-18.0.0-informational.svg" alt="Unicode 18.0.0">
</p>

Raw mode, the window size, a timed read of stdin and whether a stream is a
terminal as host effects, plus the escapes, the key decoder and the colour
level a terminal program needs, in pure Bend with its laws proven.

## Highlights

- **Keys**: one decoder for UTF-8, arrows with modifiers, Home/End in both
  spellings, F1-F12 and `Alt`; an unknown sequence becomes nothing, never a
  stray `Esc`.
- **Colour**: `Level.detect` answers what
  [supports-color](https://github.com/chalk/supports-color) answers, and
  `Style.paint` writes what [chalk](https://github.com/chalk/chalk) writes,
  nesting included.
- **Text**: strip, width, slice, wrap and truncate by display columns, as
  string-width, slice-ansi, wrap-ansi and cli-truncate do, on CJK and emoji.
- **Proven**: `bend PROOF.bend` checks 209 laws over the pure files.
- **Two lanes**: native (Linux, macOS) and JS under bun, each verified
  under a pty and piped.

## Install

Requires Bend 2.0.40: the effects use its C and JS effect API, which has no
ABI promise across releases. Clone the repo next to your program (or vendor
it) and import the files by path:

    git clone https://github.com/caiodomingues/bend-tty

The pure files are `tty.bend` (the escapes, `Key` and the decoder) and
`color.bend` (what a terminal can show: `Level` and `Level.detect`, and
`Color` and its escapes at each level, `Style` and `Style.paint`),
`text.bend` (strip, width, slice, wrap and truncate by display columns)
and `unicode.bend` (the character classes text.bend measures with,
generated from the Unicode Character Database 18.0.0 by
`tools/gen_unicode.py`);
`tty_io.bend` holds the effects. A proof may import no foreign code, so the
split keeps `PROOF.bend` on the pure files; a program imports each file it
names (Bend does not re-export imports).

## Usage

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
| `Tty.isatty(fd)` | `U32 -> IO(Bool)` | is the descriptor a terminal (0 stdin, 1 stdout, 2 stderr); a closed or invalid one is not |
| `Tty.facts(fd)` | `U32 -> IO(C.Facts)` | whether `fd` is a terminal and the environment `Level.detect` reads, with no override |
| `Tty.level(fd)` | `U32 -> IO(C.Level)` | what the stream on `fd` can show: `Level.detect` of its facts |

| pure (`tty.bend`) | what |
| --- | --- |
| `Tty.keys(bytes)` | `List<&2, U32> -> List<&2, Key>`: the decoder |
| `Key` | `Char{code}` (a Unicode code point), `Alt{code}`, `Ctrl{code}`, `F{n}`, `Enter`, `Tab`, `Backspace`, `Esc`, `Up`, `Down`, `Left`, `Right`, `Home`, `End`, `Insert`, `Delete`, `PageUp`, `PageDown` |
| `Key.show(k)` | a name for it |
| `Tty.clear()`, `Tty.home()`, `Tty.goto(x, y)` | erase; the cursor home; to column x, row y (from 1) |
| `Tty.alt(on)`, `Tty.cursor(show)` | the alternate screen; the cursor |
| `Tty.fg(c)`, `Tty.bg(c)`, `Tty.bold()`, `Tty.reset()` | 256-color paint |
| `Tty.up(n)`, `Tty.down(n)`, `Tty.column(x)` | the cursor `n` rows up or down (nothing for 0), or to column `x` (from 1) |
| `Tty.erase_line()`, `Tty.erase_down()`, `Tty.erase_lines(n)` | erase the cursor's row; from the cursor to the end of the screen; the `n` rows ending at the cursor's, leaving it at the start of the top one, as ansi-escapes' `eraseLines` (what an inline frame clears before it is drawn again) |
| `Tty.save()`, `Tty.restore()` | the cursor's position, saved and restored (`ESC 7`, `ESC 8`) |
| `Tty.sync(on)` | synchronized output (DEC mode 2026): what is written between on and off shows at once where the terminal supports it, and both are ignored where it does not |
| `Tty.link(on, url, text)` | an OSC 8 hyperlink; off, `text (url)`, or `url` alone when the text is the url |

| pure (`color.bend`) | what |
| --- | --- |
| `Level` | `Level.None` (no escapes at all), `Level.Basic` (16 colours), `Level.Ansi256`, `Level.TrueColor`; `Level.show(l)`, `Level.is_none(l)` |
| `Facts{tty, force, env}` | `tty`: is the stream a terminal; `force`: the program's own override (`Some{Level.None{}}` for `--no-color`, `Basic` for `--color`, `Ansi256` for `--color=256`, `TrueColor` for `--color=16m`); `env`: a `Var{name, value}` per variable, `None` when unset and `Some{""}` when set but empty |
| `Facts.forced(f, l)`, `Facts.names()` | the facts with an override; the variables `Level.detect` reads |
| `Level.detect(f)` | `Facts -> Level`: [supports-color](https://github.com/chalk/supports-color)'s rules in its order, with `NO_COLOR` read and `COLORTERM=24bit` as truecolor (see below) |

| `Color` | `Color.Default`, `Color.Basic{n}` (0..7, then 8..15 bright), `Color.Ansi256{n}`, `Color.Rgb{r, g, b}` (each 0..255, more reads as 255); `Color.red()` .. `Color.white()`, `Color.gray()`, `Color.bright(c)`, `Color.rgb(r, g, b)`, `Color.hex(s)` (`"#ff8800"`, `"f80"`) |
| `Color.at(l, c)` | `Level -> Color -> Color`: the colour as the level shows it, as chalk does: RGB to the 256 palette at 256, the palette and RGB to the 16 at 16, nothing changed at truecolor; a basic colour and the default never change |
| `Color.fg(l, c)`, `Color.bg(l, c)` | the escape that paints the foreground or the background, `c` converted to `l` first; `""` at `Level.None` |
| `Color.fg_close(l)`, `Color.bg_close(l)` | the default colour back (`ESC [ 39 m`, `ESC [ 49 m`); `""` at `Level.None` |
| `Style` | a foreground, a background (`Color.Default` is unset) and bold, dim, italic, underline, inverse, hidden, strike; `Style.plain()`, then `Style.fg(c, st)`, `Style.bg(c, st)`, `Style.bold(st)`, `Style.dim(st)`, `Style.italic(st)`, `Style.underline(st)`, `Style.inverse(st)`, `Style.hidden(st)`, `Style.strike(st)` |
| `Style.paint(l, st, s)` | `Level -> Style -> String -> String`: `s` in `st` as chalk paints it at level `l`. Each part has its own close (39, 49, 22, 22, 23, 24, 27, 28, 29), so a painted string nests in another: after each of the outer style's closes found inside, the outer part is opened again; each line break is wrapped in the closes and the opens. At `Level.None`, and for `""`, the answer is `s` itself |

| pure (`text.bend`) | what |
| --- | --- |
| `Ansi.strip(s)` | `s` without its escapes: CSI, OSC (BEL or `ESC \`), DCS, SOS, PM and APC strings, and the short escapes, as [strip-ansi](https://github.com/chalk/strip-ansi) matches them in 7-bit form |
| `Ansi.width(s)` | the columns `s` takes, as [string-width](https://github.com/sindresorhus/string-width) counts them: escapes and zero-width characters 0, East Asian Wide and Fullwidth 2, an emoji ZWJ sequence, a flag, an emoji with its skin tone or a keycap one cluster of 2, VS16 and VS15 switching an emoji's presentation |
| `Ansi.slice(s, a, b)` | columns `a` up to `b`, as [slice-ansi](https://github.com/chalk/slice-ansi): the styles and link in force at `a` opened first, all in force at the end closed, a wide character across either edge left out |
| `Ansi.wrap(s, cols, hard)` | `s` wrapped to `cols`, as [wrap-ansi](https://github.com/chalk/wrap-ansi): words to the next row, tabs to 8, trailing spaces trimmed, a word wider than `cols` alone on its row or, with `hard`, cut; every style and link in force at a line break closed before it and opened after it |
| `Ansi.truncate(s, cols, cut)` | `s` in `cols` columns with `…` at `Cut.End`, `Cut.Start` or `Cut.Middle`, as [cli-truncate](https://github.com/sindresorhus/cli-truncate); the ellipsis takes the style of the text beside it |
| `Ansi.widest(s)` | the width of the widest line of `s` |

`Level.detect` answers what supports-color 11.0.0 answers for the same
stream and environment, with three exceptions, each on purpose
(`docs/grounding.md` has the comparison with the Node and Go libraries):

- a non-empty `NO_COLOR` is `Level.None`, unless `FORCE_COLOR` is set or
  the program forced a level; supports-color does not read `NO_COLOR`;
- `COLORTERM=24bit` is truecolor, as `COLORTERM=truecolor` is;
- it reads no argv (the program passes its flags as `force`) and has no
  Windows branch.

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
closed, so each proof in `PROOF.bend` is `{==}`: the checker runs the decoder, and
`bend PROOF.bend` prints `ALL PROOFS CHECK`. Change `Up` to `Down` in
`Tty.letter.a` and it prints `SOME PROOFS FAIL` with the expected and
observed terms. Both import the pure files alone: importing `tty_io.bend`,
or any file with foreign code, fails the verdict. A claim
over every byte (32..126 decodes as itself) needs lemmas over `U32`, which
no library has yet.

`LAWS.bend` also states `Level.detect` on 56 environments a CLI meets:
plain terminals and pipes, `TERM` from `dumb` to `xterm-kitty`, every
`FORCE_COLOR` shape (`0`, `false`, `true`, empty, `007`, `9`, junk), the CI
providers, TeamCity versions, iTerm and Apple Terminal, `NO_COLOR` with and
without a force, and the program's overrides. Each expected level is the
one supports-color 11.0.0 (`index.js` at `4963567`) gives for those facts:
worked out by hand from its source, then confirmed by running it under bun
1.4.5 on every row (the program's override as its argv flag), with no
difference. The four rows where bend-tty differs on purpose give
supports-color's answer beside the law. They are closed claims too, so their proofs
are `{==}`.

`Color.at` has five laws over every level and colour (`color_basic`,
`color_default`, `color_truecolor`, `color_256`, and `color_idempotent`:
a colour already at the level is unchanged), and `color_none` says that at
`Level.None` no colour writes an escape, open or close. Samples pin the
conversions and the hex parser to ansi-styles 7.0.0's answers; beyond
them, `Rgb.to256` and `Ansi.to16` were compared with a port of
ansi-styles' `rgbToAnsi256` and `ansi256ToAnsi` on all 256 palette entries,
all 256 greys and 4096 RGB colours, natively and under bun, with no
difference.

`Style.paint` has two laws over every style and string: at `Level.None`
the answer is the string itself, so nothing styled sends an escape to a
pipe (`paint_none`), and `""` stays `""` at every level
(`paint_empty_all`). 24 samples pin it to chalk 6.0.1's output: nested
colours and modifiers (bold inside dim share 22, and both reopen), line
breaks (`
` and `
`, trailing ones included) and every colour model
at levels 1 to 3. Each is the output of chalk 6.0.1 run under bun 1.4.5 on
the same chain, with no difference.

The text laws pin `text.bend` to the libraries it follows: 91 samples
(30 widths, 13 strips, 15 slices, 20 wraps, 13 truncations) on ASCII,
accented letters, CJK, fullwidth forms, emoji (ZWJ sequences, flags,
skin tones, keycaps, VS15 and VS16), combining marks, Hangul jamo, Thai
and Devanagari, styles and links. Each is the answer string-width 9.0.0,
strip-ansi 7.2.0, slice-ansi 10.0.1, wrap-ansi 10.0.2 or cli-truncate
6.2.0 gave for the same string under bun 1.4.5, but one: wrap-ansi
reopens a link with BEL after a break, and bend-tty keeps the terminator
the link was written with (`r_link` says so). `text_styled_width` and
`text_styled_strip` say that painting a string changes neither its width
nor, stripped, its text; `text_wrap_fits` that wrapped lines are never
wider than the width, but for a single word longer than it in a soft
wrap; `text_truncate_zero` and `text_wrap_zero` (a width of 0 leaves the
string as it is) hold for every string.

`inline_escapes`, `inline_erase_lines` and `inline_link` pin the inline
escapes byte for byte, and `inline_link_text` says a link stripped is its
text, and as wide.

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
- `color.bend`, `text.bend`, `unicode.bend`, `Tty.isatty` and the inline
  escapes, on Linux (WSL, x86_64) with Bend 2.0.40 and bun 1.4.2, from a
  fresh clone: the proofs; every demo built and run on both lanes, piped
  and under a pty, in the environments below; the level of each
  environment as on macOS; `demos/colors.bend` and `demos/text.bend`
  piped, the 91 text samples, the Unicode table at every interval edge and
  the colour conversions, byte for byte the macOS output. bend-tui's
  three demos, driven by keys under an 80x24 pty, quit with 0 on both
  lanes.
- Verified on macOS (arm64) with Bend 2.0.40 and bun 1.4.5, natively and
  under bun: `Tty.isatty` on a pty and piped, and `demos/level.bend` under
  a pty and piped with `TERM=xterm-256color` (256 and none), `NO_COLOR=1`
  (none), `COLORTERM=truecolor` (truecolor), `TERM=dumb` (none),
  `FORCE_COLOR=3` (truecolor on both) and GitHub Actions (truecolor on a
  pty, none piped), each lane answering the same. `demos/colors.bend` writes
  the same bytes on both lanes, piped (no ESC byte in it) and under a pty
  with truecolor, every colour and style at every level. The 91 text
  samples give the same answers natively and under bun, and
  `demos/text.bend` writes the same bytes on both, piped (no ESC byte, also
  with `NO_COLOR=1`) and under a pty. So does `demos/inline.bend`: under a
  pty it redraws its frame in place 20 times; piped, or with `TERM=dumb`,
  it writes only the finished frame and the link as text, also with
  `FORCE_COLOR=3`.
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
    bend color.bend                      # Level.detect on sample environments
    bend demos/level.bend                # this terminal's level; | cat for a pipe
    bend demos/colors.bend               # every colour and style at every level; | cat shows the escapes
    bend demos/text.bend                 # width, slice, wrap and truncate on CJK and emoji
    bend demos/inline.bend               # a progress frame redrawn in place, then a link
    python3 tools/gen_unicode.py <ucd> > unicode.bend   # regenerate the tables from Unicode's files
    bend PROOF.bend                      # ALL PROOFS CHECK
    bend demos/keys.bend                 # interactive; or piped
    bend demos/counter.bend -o counter && ./counter
    bend demos/counter.bend -o counter.js && bun counter.js

`bend LAWS.bend` reports its 209 laws as TODOs (they are proven in
`PROOF.bend`). `--check-only` on `tty_io.bend` or a demo prints `SOME PROOFS
FAIL` and lists the effects as foreign code: that is expected for any file
that uses one, so their gate is a build with `-o` and a run. On Windows, run
everything in WSL.

## Contributing

Issues and pull requests are welcome. Before opening one, run
`bend PROOF.bend` (it must print `ALL PROOFS CHECK`) and, for a change to
an effect, build and run the demos on both lanes. A new behaviour comes with
its law in `LAWS.bend` and its proof in `PROOF.bend`.

## Related

- [chalk](https://github.com/chalk/chalk) and its family, which the colour
  and text files follow; `docs/grounding.md` compares them line by line.
- [Charm](https://github.com/charmbracelet)'s Go libraries, the second
  design read for the same problems.
- [Bend](https://bend-lang.com), the language.

## License

[MIT](LICENSE) © Caio Domingues
