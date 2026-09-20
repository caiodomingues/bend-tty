// Tty
// ===

// Tty.read(ms, max): parks until stdin is readable or ms pass (a wait
// with both an fd and a deadline), then reads what is there without
// blocking: a zero-timeout poll first, so a timeout answers Some{[]}.
// A read of nothing is the end of a pipe (None), but on a terminal it
// only means no byte is pending, as does EAGAIN: a timeout.
function tty_read(ms, max, k) {
  const sys = io_sys();
  const more = () => {
    const p = Int32Array.of(0, 1);
    sys.poll(sys.ptr(p), 1, 0);
    if ((p[1] >>> 16) === 0) {
      return { $: "Some", value: { $: "Nil" } };
    }
    const len = Math.max(1, Math.min(Number(max), 2147483647));
    const b = new Uint8Array(len);
    const n = Number(sys.read(0, sys.ptr(b), len));
    if (n < 0) {
      const code = sys.errno();
      return code === 11 || code === 35 || code === 4
        ? { $: "Some", value: { $: "Nil" } } : { $: "None" };
    }
    if (n === 0) {
      return process.stdin.isTTY ? { $: "Some", value: { $: "Nil" } } : { $: "None" };
    }
    let xs = { $: "Nil" };
    for (let i = n; i > 0; i -= 1) {
      xs = { $: "Con", head: b[i - 1], tail: xs };
    }
    return { $: "Some", value: xs };
  };
  globalThis.BEND_IO.waits.push({ fd: 0, out: false,
    at: performance.now() + Number(ms), k: k, more: more });
  return undefined;
}
