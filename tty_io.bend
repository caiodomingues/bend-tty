# bend-tty: the three host effects Base lacks, raw mode, the window
# size and a timed read of stdin. The pure half (escapes, Key and the
# decoder) is tty.bend; a program imports both.
#
# Every effect is a def whose body is a .c and a .js import, and each
# file registers it with io_eff(CID(Tty.x), ..). The C side is the
# native lane (Linux, macOS); the JS side runs under bun on POSIX,
# where bun:ffi reaches select and read.

import Base

# raw mode on or off: no echo, no line buffering, Ctrl-C as byte 3.
# Restored at exit and on SIGTERM, SIGHUP, SIGINT. A no-op when stdin
# is not a terminal
def Tty.raw(on: Bool) -> IO(Unit):
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
