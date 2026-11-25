# bend-tty: the host effects Base lacks, raw mode, the window size, a
# timed read of stdin and whether a descriptor is a terminal, and the
# colour level gathered from them. The pure half is tty.bend (escapes,
# Key and the decoder) and color.bend (levels); a program imports what
# it names.
#
# Every effect is a def whose body is a .c and a .js import, and each
# file registers it with io_eff(CID(Tty.x), ..). The C side is the
# native lane (Linux, macOS); the JS side runs under bun on POSIX,
# where bun:ffi reaches select and read.

import Base
import ./color.bend as C

# raw mode on or off: no echo, no line buffering, Ctrl-C as byte 3.
# Restored at exit and on SIGTERM, SIGHUP, SIGINT. A no-op when stdin
# is not a terminal
def Tty.raw(on: Bool) -> IO(Unit):
  import "./effs/tty_raw.c"
  import "./effs/tty_raw.js"

# the program draws in the normal screen, not the alternate one: until
# off, the exit and SIGTERM, SIGHUP, SIGINT show the cursor and reset
# the styles even with raw mode off, and no restore leaves the
# alternate screen (that escape can move the cursor on the normal one)
def Tty.inline(on: Bool) -> IO(Unit):
  import "./effs/tty_raw.c"
  import "./effs/tty_raw.js"

# the terminal's columns and rows; 80 x 24 when unknown
def Tty.size() -> IO(U32 & U32):
  import "./effs/tty_size.c"
  import "./effs/tty_size.js"

# the bytes stdin has within ms milliseconds, at most max of them:
# Some{[]} on a timeout (or when another computation drained the
# terminal first), None at the end of a pipe or on an error. Waits on
# a helper thread (C) or a parked fd (JS), so other computations keep
# running
def Tty.read(ms: U32, max: U32) -> IO(Maybe<&2, List<&2, U32>>):
  import "./effs/tty_read.c"
  import "./effs/tty_read.js"

# is the descriptor a terminal: 0 stdin, 1 stdout, 2 stderr
def Tty.isatty(fd: U32) -> IO(Bool):
  import "./effs/tty_isatty.c"
  import "./effs/tty_isatty.js"

def Tty.var.of(r: Result<&1, &1, U32 & String, String>) -> Maybe<&2, String>:
  match r:
    case Done{v}:
      Some{v}
    case Fail{e}:
      None{}

def Tty.vars(names: List<&2, String>) -> IO(List<&2, C.Var>):
  match names:
    case Nil{}:
      IO.pure(List<&2, C.Var>, Nil{})
    case +n <> t:
      do IO<List<&2, C.Var>>:
        r : Result<&1, &1, U32 & String, String> <- IO.get_env(n)
        rest : List<&2, C.Var> <- Tty.vars(t)
        return C.Var{n, Tty.var.of(r)} <> rest

# the facts C.Level.detect reads, for the stream on fd, with no
# override from the program (C.Facts.forced sets one)
def Tty.facts(fd: U32) -> IO(C.Facts):
  do IO<C.Facts>:
    tty : Bool <- Tty.isatty(fd)
    env : List<&2, C.Var> <- Tty.vars(C.Facts.names())
    return C.Facts{tty, None{}, env}

# what the stream on fd can show
def Tty.level(fd: U32) -> IO(C.Level):
  do IO<C.Level>:
    f : C.Facts <- Tty.facts(fd)
    return C.Level.detect(f)
