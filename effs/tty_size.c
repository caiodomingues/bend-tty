// Tty
// ===

// Tty.size(): the terminal's columns and rows, 80 x 24 when stdout is
// not a terminal.

#include <sys/ioctl.h>

Term tty_size_run(Env e, Term* f, IoWork* w) {
  struct winsize ws;
  u32 cols = 80;
  u32 rows = 24;
  if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0 && ws.ws_row > 0) {
    cols = ws.ws_col;
    rows = ws.ws_row;
  }
  return io_tup(e, (Term)cols, (Term)rows);
}

static void __attribute__((constructor)) tty_size_use(void) {
  io_eff(CID_TTY_SIZE, tty_size_run, 0);
}
