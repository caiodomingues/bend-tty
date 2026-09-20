// Tty
// ===

// Tty.raw(on): raw mode on (no echo, no line buffering, no signals:
// Ctrl-C arrives as byte 3, Enter as 13) or off. Restored at exit and
// on SIGTERM, SIGHUP and SIGINT (the signal is re-raised); a fail-stop
// of the runtime (_exit) leaves the terminal as it was. A no-op when
// stdin is not a terminal, so a piped program still runs.

#include <termios.h>
#include <signal.h>

static struct termios tty_raw_saved;
static volatile int   tty_raw_live = 0;
static int            tty_raw_hook = 0;

static void tty_raw_restore(void) {
  if (tty_raw_live) {
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &tty_raw_saved);
    tty_raw_live = 0;
  }
}

static void tty_raw_signal(int sig) {
  tty_raw_restore();
  signal(sig, SIG_DFL);
  raise(sig);
}

Term tty_raw_run(Env e, Term* f, IoWork* w) {
  int on = term_aux(f[0]) == CID_TRUE;
  if (on && !tty_raw_live && isatty(STDIN_FILENO)
      && tcgetattr(STDIN_FILENO, &tty_raw_saved) == 0) {
    struct termios t = tty_raw_saved;
    t.c_iflag &= ~(tcflag_t)(ICRNL | IXON);
    t.c_lflag &= ~(tcflag_t)(ICANON | ECHO | ISIG | IEXTEN);
    t.c_cc[VMIN]  = 0;
    t.c_cc[VTIME] = 0;
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &t);
    tty_raw_live = 1;
    if (!tty_raw_hook) {
      atexit(tty_raw_restore);
      signal(SIGTERM, tty_raw_signal);
      signal(SIGHUP, tty_raw_signal);
      signal(SIGINT, tty_raw_signal);
      tty_raw_hook = 1;
    }
  } else if (!on) {
    tty_raw_restore();
  }
  return term_pak(CID_UNIT, 0);
}

static void __attribute__((constructor)) tty_raw_use(void) {
  io_eff(CID_TTY_RAW, tty_raw_run, 0);
}
