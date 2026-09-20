// Tty
// ===

// Tty.read(ms, max): the bytes stdin has within ms, at most max:
// Some{[]} on a timeout, None at the end of the input or on an error.
// The wait is a poll on a helper thread (io_work), so the event loop
// and the other computations go on.

#include <poll.h>

// w->code: 0 with bytes or a timeout, 1 at the end of the input, errno
// on an error. A read of nothing is the end of a pipe or file, but on
// a terminal in raw mode (VMIN 0) it only means no byte is pending, as
// when another computation drained the same descriptor; EAGAIN says
// the same on a non-blocking one. Both are a timeout. EINTR retries,
// as the runtime's own poll does.
static void tty_read_call(IoWork* w) {
  struct pollfd p = { STDIN_FILENO, POLLIN, 0 };
  int r;
  do {
    r = poll(&p, 1, (int)w->made);
  } while (r < 0 && errno == EINTR);
  w->size = 0;
  w->code = 0;
  if (r > 0) {
    ssize_t n;
    do {
      n = read(STDIN_FILENO, w->data, w->word);
    } while (n < 0 && errno == EINTR);
    if (n > 0) {
      w->size = (u64)n;
    } else if (n == 0) {
      w->code = isatty(STDIN_FILENO) ? 0 : 1;
    } else if (errno != EAGAIN && errno != EWOULDBLOCK) {
      w->code = (u32)errno;
    }
  } else if (r < 0) {
    w->code = (u32)errno;
  }
}

static Term tty_read_pack(Env e, IoWork* w) {
  Term r;
  if (w->code != 0) {
    r = term_pak(CID_NONE, 0);
  } else {
    Term xs = term_pak(CID_NIL, 0);
    for (u64 i = w->size; i > 0; i -= 1) {
      xs = io_node(e, CID_CON, ((uint8_t*)w->data)[i - 1], xs, IO_HOTS & 16);
    }
    r = io_box(e, CID_SOME, xs, IO_HOTS & 32);
  }
  free(w->data);
  return r;
}

Term tty_read_run(Env e, Term* f, IoWork* w) {
  w->made = (intptr_t)(f[0] < INT32_MAX ? f[0] : INT32_MAX);
  w->word = f[1] == 0 ? 1 : f[1] < INT32_MAX ? (u32)f[1] : INT32_MAX;
  w->data = io_mem(malloc(w->word + 1));
  return io_work(w, tty_read_call, tty_read_pack);
}

static void __attribute__((constructor)) tty_read_use(void) {
  io_eff(CID_TTY_READ, tty_read_run, 0);
}
