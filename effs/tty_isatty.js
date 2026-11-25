// Tty
// ===

// Tty.isatty(fd): is the descriptor a terminal. A closed or invalid fd
// is not. A Bool crosses back as a JS boolean.
function tty_isatty(fd) {
  try {
    return require("tty").isatty(fd);
  } catch (e) {
    return false;
  }
}

io_eff(CID(Tty.isatty), tty_isatty);
