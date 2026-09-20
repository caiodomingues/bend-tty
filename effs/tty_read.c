// Tty
// ===

// Tty.read(ms, max): the bytes stdin has within ms, at most max: [] on
// a timeout or an error. The wait is a poll on a helper thread
// (io_work), so the event loop and the other computations go on.

#include <poll.h>

static void tty_read_call(IoWork* w) {
  struct pollfd p = { STDIN_FILENO, POLLIN, 0 };
  int r = poll(&p, 1, (int)w->made);
  if (r > 0) {
    w->size = io_sys_end(w, read(STDIN_FILENO, w->data, w->word));
  } else {
    w->size = 0;
    w->code = r < 0 ? (u32)errno : 0;
  }
}

static Term tty_read_pack(Env e, IoWork* w) {
  Term xs = term_pak(CID_NIL, 0);
  for (u64 i = w->code ? 0 : w->size; i > 0; i -= 1) {
    xs = io_node(e, CID_CON, ((uint8_t*)w->data)[i - 1], xs, IO_HOTS & 16);
  }
  free(w->data);
  return xs;
}

Term tty_read_run(Env e, Term* f, IoWork* w) {
  w->made = (intptr_t)(f[0] < INT32_MAX ? f[0] : INT32_MAX);
  w->word = f[1] < INT32_MAX ? (u32)f[1] : INT32_MAX;
  w->data = io_mem(malloc(w->word + 1));
  return io_work(w, tty_read_call, tty_read_pack);
}

static void __attribute__((constructor)) tty_read_use(void) {
  io_eff(CID_TTY_READ, tty_read_run, 0);
}
