// Tty
// ===

function tty_size() {
  return io_tup(process.stdout.columns || 80, process.stdout.rows || 24);
}
