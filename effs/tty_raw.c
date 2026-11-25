// Tty
// ===

// Tty.raw(on): raw mode on (no echo, no line buffering, no signals:
// Ctrl-C arrives as byte 3, Enter as 13) or off. Restored at exit and
// on SIGTERM, SIGHUP and SIGINT (the signal is re-raised), along with
// the cursor and the main screen, so a program that died on the
// alternate screen leaves the shell usable; a fail-stop of the runtime
// (_exit) leaves the terminal as it was. A no-op when stdin is not a
// terminal, so a piped program still runs.
//
// Tty.inline(on): the program draws in the normal screen. Until it is
// turned off, the exit and those signals show the cursor and reset the
// styles even with raw mode off, and no restore leaves the alternate
// screen: on the normal screen that escape restores a saved cursor
// position in some terminals, which would move an inline frame. Both
// effects live in this file because they share the restore.

#include <termios.h>
#include <signal.h>

static struct termios tty_raw_saved;
static volatile int   tty_raw_live = 0;
static volatile int   tty_inline_live = 0;
static int            tty_raw_hook = 0;

// styles off, the cursor shown, the main screen back
static const char tty_raw_reset[] = "\033[0m\033[?25h\033[?1049l";
static const char tty_inline_reset[] = "\033[0m\033[?25h";

static void tty_raw_say(int inl) {
  ssize_t r = inl ? write(STDOUT_FILENO, tty_inline_reset, sizeof(tty_inline_reset) - 1)
                  : write(STDOUT_FILENO, tty_raw_reset, sizeof(tty_raw_reset) - 1);
  (void)r;
}

static void tty_raw_restore(void) {
  if (tty_raw_live) {
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &tty_raw_saved);
    tty_raw_live = 0;
    tty_raw_say(tty_inline_live);
  } else if (tty_inline_live && isatty(STDOUT_FILENO)) {
    tty_inline_live = 0;
    tty_raw_say(1);
  }
}

static void tty_raw_signal(int sig) {
  tty_raw_restore();
  signal(sig, SIG_DFL);
  raise(sig);
}

static void tty_raw_hooks(void) {
  if (!tty_raw_hook) {
    atexit(tty_raw_restore);
    signal(SIGTERM, tty_raw_signal);
    signal(SIGHUP, tty_raw_signal);
    signal(SIGINT, tty_raw_signal);
    tty_raw_hook = 1;
  }
}

#ifdef CID(Tty.raw)

Term tty_raw_run(Env e, Term* f, IoWork* w) {
  int on = term_aux(f[0]) == CID(True);
  if (on && !tty_raw_live && isatty(STDIN_FILENO)
      && tcgetattr(STDIN_FILENO, &tty_raw_saved) == 0) {
    struct termios t = tty_raw_saved;
    t.c_iflag &= ~(tcflag_t)(ICRNL | IXON);
    t.c_lflag &= ~(tcflag_t)(ICANON | ECHO | ISIG | IEXTEN);
    t.c_cc[VMIN]  = 0;
    t.c_cc[VTIME] = 0;
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &t);
    tty_raw_live = 1;
    tty_raw_hooks();
  } else if (!on && tty_raw_live) {
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &tty_raw_saved);
    tty_raw_live = 0;
    tty_raw_say(tty_inline_live);
  }
  return term_pak(CID(Unit), 0);
}

static void __attribute__((constructor)) tty_raw_use(void) {
  io_eff(CID(Tty.raw), tty_raw_run);
}

#endif

#ifdef CID(Tty.inline)

Term tty_inline_run(Env e, Term* f, IoWork* w) {
  int on = term_aux(f[0]) == CID(True);
  tty_inline_live = on;
  if (on) {
    tty_raw_hooks();
  }
  return term_pak(CID(Unit), 0);
}

static void __attribute__((constructor)) tty_inline_use(void) {
  io_eff(CID(Tty.inline), tty_inline_run);
}

#endif
