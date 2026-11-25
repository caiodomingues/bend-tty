// Tty
// ===

// Tty.isatty(fd): is the descriptor a terminal. A closed or invalid fd
// is not.

Term tty_isatty_run(Env e, Term* f, IoWork* w) {
  return term_pak(isatty((int)(u32)f[0]) ? CID(True) : CID(False), 0);
}

static void __attribute__((constructor)) tty_isatty_use(void) {
  io_eff(CID(Tty.isatty), tty_isatty_run);
}
