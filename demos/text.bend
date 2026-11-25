# text: width, wrap, slice and truncate on ASCII, accented letters, CJK
# and emoji, styled at the level stdout can show. Each sample is printed
# with its width, its first 6 columns and its truncation to 7, at the
# end, the start and the middle; then a styled paragraph wrapped to 24
# and to 12 columns, framed so the columns line up.
#
#   bend demos/text.bend
#   bend demos/text.bend | cat
import Base
import ../color.bend as C
import ../text.bend as X
import ../tty_io.bend as IOT

def pad(n: Nat, s: String) -> String:
  match n:
    case 0n:
      s
    case 1n+p:
      pad(p, s ++ " ")

# s padded with spaces to w columns
def fill(+s: String, +w: U32) -> String:
  pad(U32.to_nat((w - U32.min(X.Ansi.width(s), w) : U32)), s)

def samples() -> List<&2, String>:
  ["plain ascii text", "café crème brûlée", "日本語のテキスト",
   "emoji 👍🏽 ❤️ 🇧🇷", "👨‍👩‍👧 family", "mixed 中文 and 😀"]

def sample(+l: C.Level, +s: String) -> String:
  +hi = C.Style.fg(C.Color.cyan(), C.Style.plain())
  fill(s, 20) ++ " | " ++ fill(U32.show(X.Ansi.width(s)), 2) ++ " | "
    ++ fill(C.Style.paint(l, hi, X.Ansi.slice(s, 0, 6)), 6) ++ " | "
    ++ fill(X.Ansi.truncate(s, 7, X.Cut.End{}), 7) ++ " | " ++ fill(X.Ansi.truncate(s, 7, X.Cut.Start{}), 7) ++ " | "
    ++ X.Ansi.truncate(s, 7, X.Cut.Middle{}) ++ "\n"

def table(+l: C.Level, ss: List<&2, String>) -> String:
  match ss:
    case Nil{}:
      ""
    case s <> t:
      sample(l, s) ++ table(l, t)

# a paragraph with nested styles, a link and wide characters
def para(+l: C.Level) -> String:
  +p = C.Style.plain()
  "Bend " ++ C.Style.paint(l, C.Style.bold(C.Style.fg(C.Color.green(), p)), "programs run on " ++ C.Style.paint(l, C.Style.fg(C.Color.yellow(), p), "CPUs and GPUs") ++ " alike")
    ++ ", 日本語 and 中文 take two columns each, and 👍🏽 is one emoji."

def framed.go(ls: List<&2, String>, +w: U32) -> String:
  match ls:
    case Nil{}:
      ""
    case r <> t:
      "|" ++ fill(r, w) ++ "|\n" ++ framed.go(t, w)

def framed(+s: String, +w: U32) -> String:
  framed.go(X.Str.pieces(s, 10), w)

def page(+l: C.Level) -> String:
  "level: " ++ C.Level.show(l) ++ "\n\n"
    ++ fill("text", 20) ++ " | w  | 0..6   | end     | start   | middle\n"
    ++ table(l, samples()) ++ "\nwrapped to 24:\n" ++ framed(X.Ansi.wrap(para(l), 24, False{}), 24)
    ++ "\nwrapped to 12, hard:\n" ++ framed(X.Ansi.wrap(para(l), 12, True{}), 12)

def main() -> IO(Unit):
  do IO<Unit>:
    l : C.Level <- IOT.Tty.level(1)
    IO.write(page(l))
