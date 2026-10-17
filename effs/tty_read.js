// Tty
// ===

// Tty.read(ms, max): parks until stdin is readable or ms pass (a wait
// with both an fd and a deadline), then reads what is there without
// blocking: a zero-timeout select first, so a timeout answers Some{[]}.
// A read of nothing is the end of a pipe (None), but on a terminal it
// only means no byte is pending, as does EAGAIN: a timeout.
function tty_read(ms, max, k) {
  const sys = io_sys();
  const empty = () => ({ $: CID(Some), value: { $: CID(Nil) } });
  const more = () => {
    // a whole fd_set and a zero timeval, sized for Linux and macOS
    const set = new Uint8Array(128);
    set[0] = 1;
    const tv = new BigInt64Array(2);
    if (sys.select(1, sys.ptr(set), null, null, sys.ptr(tv)) <= 0 || (set[0] & 1) === 0) {
      return empty();
    }
    const len = Math.max(1, Math.min(Number(max), 2147483647));
    const b = new Uint8Array(len);
    const n = Number(sys.read(0, sys.ptr(b), len));
    if (n < 0) {
      const code = sys.errno();
      return code === 11 || code === 35 || code === 4 ? empty() : { $: CID(None) };
    }
    if (n === 0) {
      return process.stdin.isTTY ? empty() : { $: CID(None) };
    }
    let xs = { $: CID(Nil) };
    for (let i = n; i > 0; i -= 1) {
      xs = { $: CID(Con), head: b[i - 1], tail: xs };
    }
    return { $: CID(Some), value: xs };
  };
  io_park_on(0, false, k, more, performance.now() + Number(ms));
  return undefined;
}

io_eff(CID(Tty.read), tty_read);
