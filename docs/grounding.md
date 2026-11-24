# Grounding

What bend-tty copies from the Node libraries that make a CLI look good
(chalk and its family), what it takes from Charm's Go libraries as a second
design, and where it differs. Every source below was read in this session
from a shallow clone of its default branch on 2026-11-24, at the commit
given; nothing was run. Two references below were not read in this session
and are marked *(remembered)*: the no-color.org convention and Node's
`tty.getColorDepth`.

| source | version | commit |
| --- | --- | --- |
| chalk/supports-color | 11.0.0 | `4963567` |
| chalk/ansi-styles | 7.0.0 | `8cf247a` |
| chalk/chalk | 6.0.1 | `7211001` |
| chalk/ansi-regex | 6.6.0 | `7e21a3e` |
| chalk/strip-ansi | 7.2.0 | `622cca7` |
| sindresorhus/string-width | 9.0.0 | `3082bff` |
| sindresorhus/get-east-asian-width | 1.7.0 | `a1b1c31` |
| chalk/wrap-ansi | 10.0.2 | `7f07de3` |
| chalk/slice-ansi | 10.0.1 | `9043bde` |
| sindresorhus/cli-truncate | 6.2.0 | `c47518c` |
| muesli/termenv | | `368a357` |
| charmbracelet/colorprofile | | `51fafca` |
| charmbracelet/x (`ansi/`) | | `8aab43e` |
| charmbracelet/lipgloss | v2 | `7d3aa33` |

## What each does

- **supports-color**: decides a level, 0 (none) to 3 (truecolor), from
  `FORCE_COLOR`, the `--color` flags in argv, whether the stream is a TTY,
  `TERM`, `COLORTERM`, `TERM_PROGRAM`, CI variables and the Windows build.
- **ansi-styles**: the SGR codes, each style with its own closing code, and
  the conversions RGB to 256 and 256 to 16.
- **chalk**: styles strings at a level. Nesting works by replacing, inside
  the string, every closing code of a style with that close followed by the
  style's open again; a newline is wrapped in close-all and open-all.
- **ansi-regex / strip-ansi**: recognise CSI, OSC (BEL or ST), DCS/SOS/PM/
  APC strings and two-byte escapes; strip removes them.
- **string-width**: display columns of a string, per grapheme cluster
  (`Intl.Segmenter`), with emoji (`\p{RGI_Emoji}`), zero-width classes
  (Default_Ignorable, Cc, Mn, Me, Cf) and East Asian Width from
  get-east-asian-width (Unicode 18.0.0 tables).
- **wrap-ansi**: word-wraps to a width, words split on U+0020, tabs to
  8-column stops, a long word overflowing unless `hard`; afterwards it
  closes every active SGR and OSC 8 link before each line break and reopens
  it after.
- **slice-ansi**: cuts by columns; styles active before the cut are opened
  at the start, every open one closed at the end; a wide character that
  crosses either edge is dropped whole.
- **cli-truncate**: truncates to a width with `…` at the end, start or
  middle; the ellipsis inherits the style at the cut.
- **termenv / colorprofile**: detect a profile (Ascii, ANSI, ANSI256,
  TrueColor; colorprofile adds NoTTY), with `NO_COLOR`, `CLICOLOR`,
  `CLICOLOR_FORCE`, terminfo and tmux probing; downsample by nearest colour
  in HSLuv.
- **x/ansi / lipgloss**: grapheme width, truncate, wrap and strip in Go;
  lipgloss carries styles over line breaks with a reset and reapply, and
  downsamples at write time, by rewriting the SGR of rendered text.

## Rules bend-tty copies

**Detection** (`Level.detect`) is supports-color's `_supportsColor`, in its
order, with `sniffFlags` off:

1. `FORCE_COLOR`: `true` or empty is "forced at least 1"; `false` is 0;
   digits are that level, at most 3 (`007` is 3); anything else is unset.
   Forced 0 answers none, before everything else.
2. A numeric `FORCE_COLOR` answers its level at once.
3. `TF_BUILD` and `AGENT_NAME` both set: 16 colours, even off a TTY.
4. Not a TTY and not forced: none.
5. `min` is 1 if forced, else 0. `TERM=dumb` answers `min`.
6. `CI` set (an empty value counts): `GITHUB_ACTIONS`, `GITEA_ACTIONS`,
   `CIRCLECI` give truecolor; `TRAVIS`, `APPVEYOR`, `GITLAB_CI`,
   `BUILDKITE`, `DRONE` or `CI_NAME=codeship` give 16; otherwise `min`.
   Nothing after this step runs when `CI` is set.
7. `TEAMCITY_VERSION`: 16 if it matches `^(9\.0*[1-9]\d*\.|\d{2,}\.)`,
   else none.
8. `COLORTERM=truecolor`, or `TERM` exactly `xterm-kitty`,
   `xterm-ghostty` or `wezterm`: truecolor.
9. `TERM_PROGRAM=iTerm.app`: truecolor if the major of
   `TERM_PROGRAM_VERSION` is 3 or more, else 256; `Apple_Terminal`: 256.
10. `TERM` ending in `-256` or `-256color` (any case): 256.
11. `TERM` starting with `screen`, `xterm`, `vt100`, `vt220` or `rxvt`, or
    containing `color`, `ansi`, `cygwin` or `linux` (any case): 16.
12. `COLORTERM` set to anything: 16. Otherwise `min`.

**Colours** are ansi-styles': the 16 basic as 30-37 and 90-97 (40-47 and
100-107 behind), 256 as `38;5;n`, RGB as `38;2;r;g;b`, closing 39 and 49.
Downsampling is chalk's per level: RGB at 256 is `rgbToAnsi256`, RGB or 256
at 16 is `ansi256ToAnsi` (through 256 for RGB); a basic colour is never
changed. Both formulas use `Math.round` on exact fractions; in integers they
are `round(5v/255) = (10v + 255) / 510` and `round(24(v-8)/247) =
(48(v - 8) + 247) / 494`, which never meet a tie, so the integer forms give
the same answers on every input.

**Styles** use ansi-styles' pairs: bold 1/22, dim 2/22, italic 3/23,
underline 4/24, inverse 7/27, hidden 8/28, strikethrough 9/29, fg x/39,
bg x/49. Painting is chalk's `applyStyle`: an empty string or level none
answers the string unchanged; otherwise each closing code found inside is
followed by that style's opening code again; each `\n` (or `\r\n`) becomes
close-all, the break, open-all; then open-all, the text, close-all.

**Strip** recognises what ansi-regex does in 7-bit form: CSI, OSC ended by
BEL or `ESC \`, DCS/SOS/PM/APC ended by `ESC \`, and the two-byte escapes.

**Width** follows string-width's cluster rules (below), with the East Asian
Wide and Fullwidth ranges of Unicode 18.0.0, ambiguous as narrow, controls
and tabs as 0.

**Wrap** is wrap-ansi's `exec` with `trim` and `wordWrap` on: words split on
U+0020, tabs to 8-column stops, a word too long overflows its own line, or,
with `hard`, is split at the column (a wide character that does not fit
moves down whole). Active SGR styles and OSC 8 links are closed before each
break and reopened after; trailing spaces are trimmed.

**Slice** is slice-ansi's: columns, a wide character crossing either edge
dropped whole, active styles reopened at the start and closed at the end in
reverse order.

**Truncate** is cli-truncate's for `end`, `start` and `middle` with `…`,
`space` and `preferTruncationOnSpace` off; width 1 answers the ellipsis.

## Where bend-tty differs, and why

Proposed, pending the owner's review of the API sketch; this section is
amended with the decisions.

- **NO_COLOR.** supports-color and chalk do not read it at all (no match in
  either repo). bend-tty honours it as no-color.org says *(remembered)*: any
  non-empty value means none; an empty one is unset. A `FORCE_COLOR` that is
  set (`1`, `true` or empty) still wins, as in Node's `tty.getColorDepth`
  *(remembered)*; `NO_COLOR` is read before `TF_BUILD`. With `NO_COLOR` unset
  the answer is supports-color's.
- **COLORTERM=24bit.** supports-color tests only `COLORTERM === 'truecolor'`
  for level 3 (`24bit` falls to step 12, 16 colours); termenv and
  colorprofile take both. bend-tty takes `24bit` as truecolor too.
- **No argv sniffing.** supports-color reads `--color`, `--no-color` and
  `--color=256` from the process's argv. A library should not claim its
  program's flags; the caller passes its own override instead (the same as
  supports-color with `sniffFlags: false`).
- **No Windows branch.** The Windows build rule is not reproduced: Bend has
  no native Windows host, and under WSL the process is Linux.
- **No grapheme segmenter.** string-width leans on `Intl.Segmenter` and the
  engine's `\p{RGI_Emoji}`; Bend has neither. bend-tty measures with a state
  machine over code points that covers what a CLI meets: a ZWJ joins the next
  pictograph at no width; two regional indicators are one flag; VS16 makes a
  narrow pictograph 2 and VS15 makes an emoji 1; an emoji modifier after a
  base adds 0; combining marks and other zero-width classes add 0; Hangul
  jamo vowels and trailing consonants after a leading one add 0. Indic
  conjuncts and other complex clusters are summed per code point, which can
  differ from string-width by a column. Its tables are generated from
  Unicode 18.0.0's data files by a script in the repo.
- **No NFC.** wrap-ansi normalises text to NFC first; without the
  composition tables bend-tty wraps the code points as given. A decomposed
  accent still measures right (the mark is 0 wide).
- **Hyperlinks.** OSC 8 is written with `ESC \` (ST), where wrap-ansi
  re-emits links with BEL; ST is the standard terminator and BEL is read
  too. Like wrap-ansi, no C1 (8-bit) introducers are produced or tracked.
- **Charm's downsampling is not used.** termenv and x/ansi pick the nearest
  colour by HSLuv distance, which disagree with each other and need float
  colour science; bend-tty follows ansi-styles so that a level-2 or level-1
  terminal shows what chalk would show.
- **One level, not two.** colorprofile separates "no colour but bold" from
  "no escapes at all". bend-tty keeps supports-color's single scale, and at
  level none nothing is styled, so no escape reaches a pipe.
