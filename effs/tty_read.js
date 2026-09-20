// Tty
// ===

// Tty.read(ms, max): parks until stdin is readable or ms pass (a wait
// with both an fd and a deadline), then reads what is there without
// blocking: a zero-timeout poll first, so a timeout answers [].
function tty_read(ms, max, k) {
  const sys = io_sys();
  const more = () => {
    const p = Int32Array.of(0, 1);
    sys.poll(sys.ptr(p), 1, 0);
    if ((p[1] >>> 16) === 0) {
      return { $: "Nil" };
    }
    const len = Math.min(Number(max), 2147483647);
    const b = new Uint8Array(Math.max(len, 1));
    const n = Number(sys.read(0, sys.ptr(b), len));
    let xs = { $: "Nil" };
    for (let i = n; i > 0; i -= 1) {
      xs = { $: "Con", head: b[i - 1], tail: xs };
    }
    return xs;
  };
  globalThis.BEND_IO.waits.push({ fd: 0, out: false,
    at: performance.now() + Number(ms), k: k, more: more });
  return undefined;
}
