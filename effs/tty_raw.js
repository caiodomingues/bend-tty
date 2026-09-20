// Tty
// ===

// Tty.raw(on): raw mode through the host's tty stream; restored at exit.
// A Bool crosses into JS as a boolean.
function tty_raw(on) {
  const want = on === true;
  if (process.stdin.isTTY) {
    process.stdin.setRawMode(want);
    if (want && !globalThis.BEND_TTY_HOOK) {
      globalThis.BEND_TTY_HOOK = true;
      process.on("exit", () => { try { process.stdin.setRawMode(false); } catch (e) {} });
    }
  }
  return { $: "Unit" };
}
