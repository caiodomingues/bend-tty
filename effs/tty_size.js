// Tty
// ===

function tty_size() {
  return io_tup(process.stdout.columns || 80, process.stdout.rows || 24);
}

io_eff(CID(Tty.size), tty_size);
