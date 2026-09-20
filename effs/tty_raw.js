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
      const off = () => {
        try { process.stdin.setRawMode(false); } catch (e) {}
        try { process.stdout.write("[0m[?25h[?1049l"); } catch (e) {}
      };
      process.on("exit", off);
      for (const sig of ["SIGTERM", "SIGHUP", "SIGINT"]) {
        process.on(sig, () => { off(); process.exit(128 + (sig === "SIGINT" ? 2 : sig === "SIGTERM" ? 15 : 1)); });
      }
    }
  }
  return { $: "Unit" };
}
