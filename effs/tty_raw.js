// Tty
// ===

// Tty.raw(on): raw mode through the host's tty stream. At exit while
// it is on, it is turned off, the cursor shown and the alternate screen
// left. A Bool crosses into JS as a boolean.
//
// Tty.inline(on): the program draws in the normal screen. Until it is
// turned off, the exit shows the cursor and resets the styles even with
// raw mode off, and no restore leaves the alternate screen (on the
// normal screen that escape restores a saved cursor position in some
// terminals). Both live here: they share the hook.
//
// No signal is hooked: the runtime's loop never yields to bun's event
// loop, so a process.on(signal) listener never runs, and registering
// one removes the default action: SIGINT and SIGTERM would be ignored.
function tty_hooks() {
  const g = globalThis;
  if (g.BEND_TTY_HOOK) return;
  g.BEND_TTY_HOOK = true;
  const off = () => {
    const inl = g.BEND_TTY_INLINE === true;
    if (g.BEND_TTY_RAW === true) {
      g.BEND_TTY_RAW = false;
      try { process.stdin.setRawMode(false); } catch (e) {}
      try { process.stdout.write(inl ? "\x1b[0m\x1b[?25h" : "\x1b[0m\x1b[?25h\x1b[?1049l"); } catch (e) {}
    } else if (inl && process.stdout.isTTY) {
      g.BEND_TTY_INLINE = false;
      try { process.stdout.write("\x1b[0m\x1b[?25h"); } catch (e) {}
    }
  };
  process.on("exit", off);
}

function tty_raw(on) {
  const want = on === true;
  if (process.stdin.isTTY) {
    process.stdin.setRawMode(want);
    globalThis.BEND_TTY_RAW = want;
    if (want) tty_hooks();
  }
  return { $: CID(Unit) };
}

function tty_inline(on) {
  globalThis.BEND_TTY_INLINE = on === true;
  if (on === true) tty_hooks();
  return { $: CID(Unit) };
}

io_eff(CID(Tty.raw), tty_raw);
io_eff(CID(Tty.inline), tty_inline);
