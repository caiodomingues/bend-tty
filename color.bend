# bend-tty: what a terminal can show, pure. Level.detect answers the
# colour level from plain facts (is the stream a terminal, the
# environment), with supports-color's rules in supports-color's order;
# tty_io.bend gathers the facts. docs/grounding.md says where it differs.
#
#   bend color.bend      # checks; main shows the level of a few sample environments

import Base

# Levels
# ------

type Level is Data:
  Level.None{}        # no escapes at all
  Level.Basic{}       # the 16 colours
  Level.Ansi256{}
  Level.TrueColor{}

def Level.show(l: Level) -> String:
  match l:
    case Level.None{}:
      "none"
    case Level.Basic{}:
      "16"
    case Level.Ansi256{}:
      "256"
    case Level.TrueColor{}:
      "truecolor"

# Facts
# -----

# an environment variable: None when unset, Some{""} when set but empty
# (supports-color tells them apart: CI= counts as set, FORCE_COLOR= forces)
type Var is Data:
  Var{name: String, value: Maybe<&2, String>}

# tty: is the stream a terminal; force: the program's own override, the
# part of supports-color's --color flags a library leaves to its caller
# (Level.None is --no-color, Level.Basic --color, Ansi256 --color=256,
# TrueColor --color=16m); env: the variables Level.detect reads
type Facts is Data:
  Facts{tty: Bool, force: Maybe<&2, Level>, env: List<&2, Var>}

def Facts.forced(f: Facts, l: Level) -> Facts:
  match f:
    case Facts{tty, force, env}:
      Facts{tty, Some{l}, env}

# the variables Level.detect reads
def Facts.names() -> List<&2, String>:
  ["FORCE_COLOR", "NO_COLOR", "TF_BUILD", "AGENT_NAME", "TERM", "CI",
   "GITHUB_ACTIONS", "GITEA_ACTIONS", "CIRCLECI", "TRAVIS", "APPVEYOR",
   "GITLAB_CI", "BUILDKITE", "DRONE", "CI_NAME", "TEAMCITY_VERSION",
   "COLORTERM", "TERM_PROGRAM", "TERM_PROGRAM_VERSION"]

# Strings
# -------

def Env.first(c: Bool, v: Maybe<&2, String>, rest: Maybe<&2, String>) -> Maybe<&2, String>:
  match c:
    case True{}:
      v
    case False{}:
      rest

def Env.get(+name: String, vs: List<&2, Var>) -> Maybe<&2, String>:
  match vs:
    case Nil{}:
      None{}
    case Var{n, v} <> t:
      Env.first(String.eq(n, name), v, Env.get(name, t))

def Opt.set(m: Maybe<&2, String>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{v}:
      True{}

def Opt.full(m: Maybe<&2, String>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{v}:
      Bool.not(String.is_empty(v))

def Opt.is(m: Maybe<&2, String>, x: String) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{v}:
      String.eq(v, x)

def Opt.str(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      ""
    case Some{v}:
      v

def Str.lower.char(+c: U32, up: Bool) -> Char:
  match up:
    case True{}:
      Chr{(c + 32 : U32)}
    case False{}:
      Chr{c}

def Str.lower(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c}, t}:
      SCon{Str.lower.char(c, Bool.and(U32.is_ge(c, 65), U32.is_le(c, 90))), Str.lower(t)}

# p is a prefix of s
def Str.starts(p: String, s: String) -> Bool:
  match p s:
    case SNil{} _:
      True{}
    case SCon{a, pt} SNil{}:
      False{}
    case SCon{a, pt} SCon{b, st}:
      Bool.and(Char.is_eq(a, b), Str.starts(pt, st))

def Str.ends(p: String, s: String) -> Bool:
  Str.starts(String.reverse(p), String.reverse(s))

def Str.has(s: String, +p: String) -> Bool:
  match s:
    case SNil{}:
      String.is_empty(p)
    case SCon{+h, +t}:
      Bool.or(Str.starts(p, SCon{h, t}), Str.has(t, p))

def Str.digit(+c: U32) -> Bool:
  Bool.and(U32.is_ge(c, 48), U32.is_le(c, 57))

# the digits s starts with, and what follows them
def Str.lead.keep(c: Bool, +h: Char, rest: String) -> String:
  match c:
    case True{}:
      SCon{h, rest}
    case False{}:
      SNil{}

def Str.lead(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c}, t}:
      Str.lead.keep(Str.digit(c), Chr{c}, Str.lead(t))

def Str.after.pick(c: Bool, rest: String, whole: String) -> String:
  match c:
    case True{}:
      rest
    case False{}:
      whole

def Str.after(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c}, +t}:
      Str.after.pick(Str.digit(c), Str.after(t), SCon{Chr{c}, t})

def Str.tail(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{h, t}:
      t

# a digit 1..9 in s
def Str.nonzero(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, t}:
      Bool.or(Bool.and(U32.is_ge(c, 49), U32.is_le(c, 57)), Str.nonzero(t))

# the value of a string of digits, at most 1000; None if any char is not
# a digit. The empty string is Some{0}, as JS's Number("") is 0
def Str.nat.join(ok: Bool, +d: U32, rest: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match ok rest:
    case True{} Some{+v}:
      Some{U32.min((v + d : U32), 1000)}
    case _ _:
      None{}

def Str.nat.go(s: String, +scale: U32) -> Maybe<&2, U32>:
  match s:
    case SNil{}:
      Some{0}
    case SCon{Chr{+c}, t}:
      Str.nat.join(Str.digit(c), U32.min(U32.mul((c - 48 : U32), scale), 1000), Str.nat.go(t, U32.min((scale * 10 : U32), 1000)))

def Str.nat(s: String) -> Maybe<&2, U32>:
  Str.nat.go(String.reverse(s), 1)

# the characters before the first dot
def Str.major.cut(dot: Bool, +h: Char, rest: String) -> String:
  match dot:
    case True{}:
      SNil{}
    case False{}:
      SCon{h, rest}

def Str.major(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c}, t}:
      Str.major.cut(U32.is_eq(c, 46), Chr{c}, Str.major(t))

# FORCE_COLOR
# -----------

# what forces the level: nothing; off (FORCE_COLOR=0 or false, --no-color);
# on, at least 16 colours but still detected (FORCE_COLOR=true or empty,
# --color); or exactly a level (FORCE_COLOR=1..3, more is 3)
type Force is Data:
  Force.Unset{}
  Force.Off{}
  Force.On{}
  Force.At{l: Level}

def Force.num(m: Maybe<&2, U32>) -> Force:
  match m:
    case None{}:
      Force.Unset{}
    case Some{0}:
      Force.Off{}
    case Some{1}:
      Force.At{Level.Basic{}}
    case Some{2}:
      Force.At{Level.Ansi256{}}
    case Some{n}:
      Force.At{Level.TrueColor{}}

def Force.digits(+v: String, empty: Bool) -> Force:
  match empty:
    case True{}:
      Force.On{}
    case False{}:
      Force.num(Str.nat(v))

def Force.text(+v: String, t: Bool, f: Bool) -> Force:
  match t f:
    case True{} _:
      Force.On{}
    case False{} True{}:
      Force.Off{}
    case False{} False{}:
      Force.digits(v, String.is_empty(v))

# FORCE_COLOR, read as supports-color's envForceColor
def Force.env(m: Maybe<&2, String>) -> Force:
  match m:
    case None{}:
      Force.Unset{}
    case Some{+v}:
      Force.text(v, String.eq(v, "true"), String.eq(v, "false"))

# the program's override, as supports-color's flagForceColor: --no-color
# is off, --color on; --color=256 and --color=16m are read later
def Force.flag(m: Maybe<&2, Level>) -> Force:
  match m:
    case Some{Level.None{}}:
      Force.Off{}
    case Some{Level.Basic{}}:
      Force.On{}
    case _:
      Force.Unset{}

# FORCE_COLOR, when set, replaces the flag
def Force.pick(e: Force, f: Force) -> Force:
  match e:
    case Force.Unset{}:
      f
    case other:
      other

def Force.is_off(f: Force) -> Bool:
  match f:
    case Force.Off{}:
      True{}
    case _:
      False{}

def Force.is_unset(f: Force) -> Bool:
  match f:
    case Force.Unset{}:
      True{}
    case _:
      False{}

# min in supports-color: 16 colours when forced on, else none
def Force.min(f: Force) -> Level:
  match f:
    case Force.On{}:
      Level.Basic{}
    case _:
      Level.None{}

# TEAMCITY_VERSION, against ^(9\.0*[1-9]\d*\.|\d{2,}\.): two or more
# digits then a dot, or 9. then digits not all zero then a dot
def Tc.run(+r: String) -> Bool:
  Bool.and(Str.nonzero(Str.lead(r)), Str.starts(".", Str.after(r)))

def Tc.ok(+v: String) -> Bool:
  Bool.or(
    Bool.and(Nat.is_ge(String.length(Str.lead(v)), 2n), Str.starts(".", Str.after(v))),
    Bool.and(String.eq(Str.lead(v), "9"), Bool.and(Str.starts(".", Str.after(v)), Tc.run(Str.tail(Str.after(v))))))

# TERM, lowercased, against /-256(?:color)?$/i
def Term.is256(+t: String) -> Bool:
  Bool.or(Str.ends("-256", t), Str.ends("-256color", t))

# TERM, lowercased, against /^screen|^xterm|^vt100|^vt220|^rxvt|color|ansi|cygwin|linux/i
def Term.is16(+t: String) -> Bool:
  Bool.or(Bool.or(Bool.or(Str.starts("screen", t), Str.starts("xterm", t)),
                  Bool.or(Str.starts("vt100", t), Bool.or(Str.starts("vt220", t), Str.starts("rxvt", t)))),
          Bool.or(Bool.or(Str.has(t, "color"), Str.has(t, "ansi")), Bool.or(Str.has(t, "cygwin"), Str.has(t, "linux"))))

# iTerm.app's TERM_PROGRAM_VERSION is 3 or more: JS's Number of what
# precedes the first dot, where "" is 0 and anything not digits NaN
def Iterm.v3(m: Maybe<&2, U32>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{v}:
      U32.is_ge(v, 3)

# Detection
# ---------
# A chain of steps, each a def that matches the verdict its caller
# computed, in supports-color's order. Ctx is the facts with FORCE_COLOR
# and the flag already merged.

type Ctx is Data:
  Ctx{tty: Bool, prog: Maybe<&2, Level>, force: Force, env: List<&2, Var>}

def Ctx.get(c: Ctx, +name: String) -> Maybe<&2, String>:
  match c:
    case Ctx{tty, prog, force, env}:
      Env.get(name, env)

def Ctx.has(c: Ctx, +name: String) -> Bool:
  Opt.set(Ctx.get(c, name))

def Ctx.is(c: Ctx, +name: String, x: String) -> Bool:
  Opt.is(Ctx.get(c, name), x)

def Ctx.term(c: Ctx) -> String:
  Str.lower(Opt.str(Ctx.get(c, "TERM")))

def Ctx.force(c: Ctx) -> Force:
  match c:
    case Ctx{tty, prog, force, env}:
      force

def Ctx.tty(c: Ctx) -> Bool:
  match c:
    case Ctx{tty, prog, force, env}:
      tty

def Ctx.min(c: Ctx) -> Level:
  Force.min(Ctx.force(c))

def Det.pick(c: Bool, a: Level, b: Level) -> Level:
  match c:
    case True{}:
      a
    case False{}:
      b

def Det.colorterm(+c: Ctx, b: Bool) -> Level:
  match b:
    case True{}:
      Level.Basic{}
    case False{}:
      Ctx.min(c)

def Det.t16(+c: Ctx, b: Bool) -> Level:
  match b:
    case True{}:
      Level.Basic{}
    case False{}:
      Det.colorterm(c, Ctx.has(c, "COLORTERM"))

def Det.t256(+c: Ctx, b: Bool) -> Level:
  match b:
    case True{}:
      Level.Ansi256{}
    case False{}:
      Det.t16(c, Term.is16(Ctx.term(c)))

def Det.apple(+c: Ctx, b: Bool) -> Level:
  match b:
    case True{}:
      Level.Ansi256{}
    case False{}:
      Det.t256(c, Term.is256(Ctx.term(c)))

def Det.iterm(+c: Ctx, +v: String, b: Bool) -> Level:
  match b:
    case True{}:
      Det.pick(Iterm.v3(Str.nat(Str.major(Opt.str(Ctx.get(c, "TERM_PROGRAM_VERSION"))))), Level.TrueColor{}, Level.Ansi256{})
    case False{}:
      Det.apple(c, String.eq(v, "Apple_Terminal"))

def Det.program(+c: Ctx, p: Maybe<&2, String>) -> Level:
  match p:
    case None{}:
      Det.t256(c, Term.is256(Ctx.term(c)))
    case Some{+v}:
      Det.iterm(c, v, String.eq(v, "iTerm.app"))

def Det.terms(+c: Ctx, b: Bool) -> Level:
  match b:
    case True{}:
      Level.TrueColor{}
    case False{}:
      Det.program(c, Ctx.get(c, "TERM_PROGRAM"))

def Det.truecolor(+c: Ctx, b: Bool) -> Level:
  match b:
    case True{}:
      Level.TrueColor{}
    case False{}:
      Det.terms(c, Bool.or(Ctx.is(c, "TERM", "xterm-kitty"), Bool.or(Ctx.is(c, "TERM", "xterm-ghostty"), Ctx.is(c, "TERM", "wezterm"))))

def Det.teamcity(+c: Ctx, b: Bool) -> Level:
  match b:
    case True{}:
      Det.pick(Tc.ok(Opt.str(Ctx.get(c, "TEAMCITY_VERSION"))), Level.Basic{}, Level.None{})
    case False{}:
      Det.truecolor(c, Bool.or(Ctx.is(c, "COLORTERM", "truecolor"), Ctx.is(c, "COLORTERM", "24bit")))

def Det.ci16(+c: Ctx, b: Bool) -> Level:
  match b:
    case True{}:
      Level.Basic{}
    case False{}:
      Ctx.min(c)

def Det.ci(+c: Ctx, b: Bool) -> Level:
  match b:
    case True{}:
      Det.ci16(c, Bool.or(Bool.or(Ctx.has(c, "TRAVIS"), Ctx.has(c, "APPVEYOR")),
                          Bool.or(Bool.or(Ctx.has(c, "GITLAB_CI"), Ctx.has(c, "BUILDKITE")),
                                  Bool.or(Ctx.has(c, "DRONE"), Ctx.is(c, "CI_NAME", "codeship")))))
    case False{}:
      Det.teamcity(c, Ctx.has(c, "TEAMCITY_VERSION"))

def Det.cis(+c: Ctx, b: Bool) -> Level:
  match b:
    case True{}:
      Det.pick(Bool.or(Ctx.has(c, "GITHUB_ACTIONS"), Bool.or(Ctx.has(c, "GITEA_ACTIONS"), Ctx.has(c, "CIRCLECI"))),
               Level.TrueColor{}, Det.ci(c, True{}))
    case False{}:
      Det.ci(c, False{})

def Det.dumb(+c: Ctx, b: Bool) -> Level:
  match b:
    case True{}:
      Ctx.min(c)
    case False{}:
      Det.cis(c, Ctx.has(c, "CI"))

def Det.notty(+c: Ctx, b: Bool) -> Level:
  match b:
    case True{}:
      Level.None{}
    case False{}:
      Det.dumb(c, Ctx.is(c, "TERM", "dumb"))

def Det.azure(+c: Ctx, b: Bool) -> Level:
  match b:
    case True{}:
      Level.Basic{}
    case False{}:
      Det.notty(c, Bool.and(Bool.not(Ctx.tty(c)), Force.is_unset(Ctx.force(c))))

# NO_COLOR, not read by supports-color: a non-empty value is none,
# unless FORCE_COLOR or the program forced the level
def Det.nocolor(+c: Ctx, b: Bool) -> Level:
  match b:
    case True{}:
      Level.None{}
    case False{}:
      Det.azure(c, Bool.and(Ctx.has(c, "TF_BUILD"), Ctx.has(c, "AGENT_NAME")))

def Det.exact(+c: Ctx, f: Force) -> Level:
  match f:
    case Force.At{l}:
      l
    case _:
      Det.nocolor(c, Bool.and(Force.is_unset(Ctx.force(c)), Opt.full(Ctx.get(c, "NO_COLOR"))))

# --color=16m and --color=256 come before a numeric FORCE_COLOR
def Det.flag(+c: Ctx, p: Maybe<&2, Level>) -> Level:
  match p:
    case Some{Level.TrueColor{}}:
      Level.TrueColor{}
    case Some{Level.Ansi256{}}:
      Level.Ansi256{}
    case _:
      Det.exact(c, Ctx.force(c))

def Det.prog(c: Ctx) -> Maybe<&2, Level>:
  match c:
    case Ctx{tty, prog, force, env}:
      prog

def Det.off(+c: Ctx, b: Bool) -> Level:
  match b:
    case True{}:
      Level.None{}
    case False{}:
      Det.flag(c, Det.prog(c))

def Det.go(+c: Ctx) -> Level:
  Det.off(c, Force.is_off(Ctx.force(c)))

def Level.detect(f: Facts) -> Level:
  match f:
    case Facts{tty, +force, +env}:
      Det.go(Ctx{tty, force, Force.pick(Force.env(Env.get("FORCE_COLOR", env)), Force.flag(force)), env})

# Samples
# -------

def Var.set(name: String, value: String) -> Var:
  Var{name, Some{value}}

def main() -> List<&2, String>:
  [Level.show(Level.detect(Facts{True{}, None{}, [Var.set("TERM", "xterm-256color")]})),
   Level.show(Level.detect(Facts{True{}, None{}, [Var.set("TERM", "xterm-256color"), Var.set("COLORTERM", "truecolor")]})),
   Level.show(Level.detect(Facts{False{}, None{}, [Var.set("TERM", "xterm-256color")]})),
   Level.show(Level.detect(Facts{False{}, None{}, [Var.set("FORCE_COLOR", "2")]})),
   Level.show(Level.detect(Facts{True{}, None{}, [Var.set("TERM", "xterm-256color"), Var.set("NO_COLOR", "1")]})),
   Level.show(Level.detect(Facts{True{}, None{}, [Var.set("TERM", "dumb")]}))]
