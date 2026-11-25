# bend-tty: text as a terminal shows it, pure: escapes stripped, display
# width in columns, and slicing, wrapping and truncating by columns with
# the styles kept open and closed. The rules are strip-ansi's,
# string-width's, slice-ansi's, wrap-ansi's and cli-truncate's;
# docs/grounding.md says where they differ. The character classes come
# from unicode.bend, generated from the Unicode Character Database.
#
#   bend text.bend       # checks; main measures a few samples

import Base
import ./unicode.bend as U

# Escapes
# -------
# The string is first cut into characters and complete escape sequences,
# the 7-bit forms ansi-regex matches: CSI (ESC [ .. final), OSC (ESC ] ..
# ended by BEL or ESC \), DCS, SOS, PM and APC strings (ESC P, X, ^, _, k
# .. ended by ESC \) and the short escapes (ESC 7, ESC ( 0, ESC c ..). A
# sequence that never completes is text, except ESC P and ESC k, which
# ansi-regex then strips as a two-byte escape. Each character carries its
# Unicode flags, looked up once.

type Tx is Data:
  Tx.Ch{c: U32, f: U32}
  Tx.Esc{s: String}

# the sequence in progress, its characters so far reversed
type Ts is Data:
  Ts.Plain{}
  Ts.Esc{}
  Ts.Csi{acc: String}
  Ts.Inter{acc: String}
  Ts.Osc{acc: String}
  Ts.OscEsc{acc: String}
  Ts.Str{acc: String}
  Ts.StrEsc{acc: String}

# what one character gives: the units it completes, and the next state
type Tn is Data:
  Tn{out: List<&2, Tx>, next: Ts}

def Tn.out(r: Tn) -> List<&2, Tx>:
  match r:
    case Tn{o, n}:
      o

def Tn.next(r: Tn) -> Ts:
  match r:
    case Tn{o, n}:
      n

def Tx.ch(+c: U32) -> Tx:
  Tx.Ch{c, U.Uni.flags(c)}

# characters as text
def Tx.raw(s: String) -> List<&2, Tx>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{Chr{+c}, t}:
      Tx.ch(c) <> Tx.raw(t)

def Tx.in(+c: U32, lo: U32, hi: U32) -> Bool:
  Bool.and(U32.is_ge(c, lo), U32.is_le(c, hi))

# a character a string sequence may not hold: CAN, SUB, or a C1 control
def Tx.stop(+c: U32) -> Bool:
  Bool.or(Bool.or(U32.is_eq(c, 24), U32.is_eq(c, 26)), Tx.in(c, 128, 159))

# ESC then one of [\dA-PR-TZcf-oq-uy=><~|}] is a whole escape
def Tx.short(+c: U32) -> Bool:
  Bool.or(Bool.or(Bool.or(Tx.in(c, 48, 57), Tx.in(c, 65, 80)), Bool.or(Tx.in(c, 82, 84), U32.is_eq(c, 90))),
          Bool.or(Bool.or(Bool.or(U32.is_eq(c, 99), Tx.in(c, 102, 111)), Bool.or(Tx.in(c, 113, 117), U32.is_eq(c, 121))),
                  Bool.or(Bool.or(Tx.in(c, 60, 62), U32.is_eq(c, 126)), Bool.or(U32.is_eq(c, 124), U32.is_eq(c, 125)))))

def Tx.esc1(+c: U32) -> String:
  SCon{Chr{27}, SCon{Chr{c}, SNil{}}}

def Tx.done(+c: U32, acc: String) -> List<&2, Tx>:
  [Tx.Esc{String.reverse(SCon{Chr{c}, acc})}]

def Tx.then(pre: List<&2, Tx>, r: Tn) -> Tn:
  match r:
    case Tn{o, n}:
      Tn{List.append(&2, Tx, pre, o), n}

def Tx.tail(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{h, t}:
      t

def Tx.head2(s: String) -> Char:
  match s:
    case SCon{a, SCon{b, t}}:
      b
    case _:
      Chr{0}

# what an unfinished string sequence leaves, given its characters in
# order: ESC P and ESC k strip as a two-byte escape, the rest is text
def Tx.fail.two(+s: String, two: Bool) -> List<&2, Tx>:
  match two:
    case True{}:
      Tx.Esc{Tx.esc1(Char.to_u32(Tx.head2(s)))} <> Tx.raw(Tx.tail(Tx.tail(s)))
    case False{}:
      Tx.raw(s)

def Tx.fail.str(+s: String) -> List<&2, Tx>:
  Tx.fail.two(s, Bool.or(U32.is_eq(Char.to_u32(Tx.head2(s)), 80), U32.is_eq(Char.to_u32(Tx.head2(s)), 107)))

# Plain
def Tx.step.plain(+c: U32) -> Tn:
  Bool.pick(Tn, U32.is_eq(c, 27), Tn{Nil{}, Ts.Esc{}}, Tn{[Tx.ch(c)], Ts.Plain{}})

# after ESC: [ ] P X ^ _ k open a sequence, an intermediate starts one, a
# short escape is whole, a second ESC leaves the first as text
def Tx.esc.f(+c: U32, esc: Bool) -> Tn:
  match esc:
    case True{}:
      Tn{[Tx.ch(27)], Ts.Esc{}}
    case False{}:
      Tx.then([Tx.ch(27)], Tx.step.plain(c))

def Tx.esc.e(+c: U32, short: Bool) -> Tn:
  match short:
    case True{}:
      Tn{[Tx.Esc{Tx.esc1(c)}], Ts.Plain{}}
    case False{}:
      Tx.esc.f(c, U32.is_eq(c, 27))

def Tx.esc1r(+c: U32) -> String:
  SCon{Chr{c}, SCon{Chr{27}, SNil{}}}

def Tx.esc.d(+c: U32, inter: Bool) -> Tn:
  match inter:
    case True{}:
      Tn{Nil{}, Ts.Inter{Tx.esc1r(c)}}
    case False{}:
      Tx.esc.e(c, Tx.short(c))

def Tx.esc.c(+c: U32, str: Bool) -> Tn:
  match str:
    case True{}:
      Tn{Nil{}, Ts.Str{Tx.esc1r(c)}}
    case False{}:
      Tx.esc.d(c, Tx.in(c, 32, 47))

def Tx.esc.b(+c: U32, osc: Bool) -> Tn:
  match osc:
    case True{}:
      Tn{Nil{}, Ts.Osc{Tx.esc1r(c)}}
    case False{}:
      Tx.esc.c(c, Bool.or(Bool.or(U32.is_eq(c, 80), U32.is_eq(c, 88)), Bool.or(Bool.or(U32.is_eq(c, 94), U32.is_eq(c, 95)), U32.is_eq(c, 107))))

def Tx.esc.a(+c: U32, csi: Bool) -> Tn:
  match csi:
    case True{}:
      Tn{Nil{}, Ts.Csi{Tx.esc1r(c)}}
    case False{}:
      Tx.esc.b(c, U32.is_eq(c, 93))

def Tx.step.esc(+c: U32) -> Tn:
  Tx.esc.a(c, U32.is_eq(c, 91))

# ESC [: parameters and intermediates, then a final byte
def Tx.csi.b(acc: String, +c: U32, fin: Bool) -> Tn:
  match fin:
    case True{}:
      Tn{Tx.done(c, acc), Ts.Plain{}}
    case False{}:
      Tx.then(Tx.raw(String.reverse(acc)), Tx.step.plain(c))

def Tx.step.csi(acc: String, +c: U32, mid: Bool) -> Tn:
  match mid:
    case True{}:
      Tn{Nil{}, Ts.Csi{SCon{Chr{c}, acc}}}
    case False{}:
      Tx.csi.b(acc, c, Tx.in(c, 64, 126))

# ESC and intermediates, then a final byte
def Tx.inter.b(acc: String, +c: U32, fin: Bool) -> Tn:
  match fin:
    case True{}:
      Tn{Tx.done(c, acc), Ts.Plain{}}
    case False{}:
      Tx.then(Tx.raw(String.reverse(acc)), Tx.step.plain(c))

def Tx.step.inter(acc: String, +c: U32, mid: Bool) -> Tn:
  match mid:
    case True{}:
      Tn{Nil{}, Ts.Inter{SCon{Chr{c}, acc}}}
    case False{}:
      Tx.inter.b(acc, c, Tx.in(c, 48, 126))

# ESC ]: anything but the stops, up to BEL or ESC \
def Tx.osc.c(acc: String, +c: U32, stop: Bool) -> Tn:
  match stop:
    case True{}:
      Tx.then(Tx.raw(String.reverse(acc)), Tx.step.plain(c))
    case False{}:
      Tn{Nil{}, Ts.Osc{SCon{Chr{c}, acc}}}

def Tx.osc.b(acc: String, +c: U32, esc: Bool) -> Tn:
  match esc:
    case True{}:
      Tn{Nil{}, Ts.OscEsc{SCon{Chr{c}, acc}}}
    case False{}:
      Tx.osc.c(acc, c, Tx.stop(c))

def Tx.step.osc(acc: String, +c: U32, bel: Bool) -> Tn:
  match bel:
    case True{}:
      Tn{Tx.done(c, acc), Ts.Plain{}}
    case False{}:
      Tx.osc.b(acc, c, U32.is_eq(c, 27))

# ESC ] .. ESC: a \ ends it; anything else leaves it as text, and the
# last ESC starts over
def Tx.step.oscesc(acc: String, +c: U32, st: Bool) -> Tn:
  match st:
    case True{}:
      Tn{Tx.done(c, acc), Ts.Plain{}}
    case False{}:
      Tx.then(Tx.raw(String.reverse(Tx.tail(acc))), Tx.step.esc(c))

# ESC P, X, ^, _ or k: anything but the stops, up to ESC \
def Tx.str.b(acc: String, +c: U32, stop: Bool) -> Tn:
  match stop:
    case True{}:
      Tx.then(Tx.fail.str(String.reverse(acc)), Tx.step.plain(c))
    case False{}:
      Tn{Nil{}, Ts.Str{SCon{Chr{c}, acc}}}

def Tx.step.str(acc: String, +c: U32, esc: Bool) -> Tn:
  match esc:
    case True{}:
      Tn{Nil{}, Ts.StrEsc{SCon{Chr{c}, acc}}}
    case False{}:
      Tx.str.b(acc, c, Tx.stop(c))

def Tx.step.stresc(acc: String, +c: U32, st: Bool) -> Tn:
  match st:
    case True{}:
      Tn{Tx.done(c, acc), Ts.Plain{}}
    case False{}:
      Tx.then(Tx.fail.str(String.reverse(Tx.tail(acc))), Tx.step.esc(c))

def Tx.step(st: Ts, +c: U32) -> Tn:
  match st:
    case Ts.Plain{}:
      Tx.step.plain(c)
    case Ts.Esc{}:
      Tx.step.esc(c)
    case Ts.Csi{acc}:
      Tx.step.csi(acc, c, Tx.in(c, 32, 63))
    case Ts.Inter{acc}:
      Tx.step.inter(acc, c, Tx.in(c, 32, 47))
    case Ts.Osc{acc}:
      Tx.step.osc(acc, c, U32.is_eq(c, 7))
    case Ts.OscEsc{acc}:
      Tx.step.oscesc(acc, c, U32.is_eq(c, 92))
    case Ts.Str{acc}:
      Tx.step.str(acc, c, U32.is_eq(c, 27))
    case Ts.StrEsc{acc}:
      Tx.step.stresc(acc, c, U32.is_eq(c, 92))

# what a sequence still open at the end leaves
def Tx.flush(st: Ts) -> List<&2, Tx>:
  match st:
    case Ts.Plain{}:
      Nil{}
    case Ts.Esc{}:
      [Tx.ch(27)]
    case Ts.Csi{acc}:
      Tx.raw(String.reverse(acc))
    case Ts.Inter{acc}:
      Tx.raw(String.reverse(acc))
    case Ts.Osc{acc}:
      Tx.raw(String.reverse(acc))
    case Ts.OscEsc{acc}:
      Tx.raw(String.reverse(acc))
    case Ts.Str{acc}:
      Tx.fail.str(String.reverse(acc))
    case Ts.StrEsc{acc}:
      List.append(&2, Tx, Tx.fail.str(String.reverse(Tx.tail(acc))), [Tx.ch(27)])

def Tx.go(s: String, +st: Ts) -> List<&2, Tx>:
  match s:
    case SNil{}:
      Tx.flush(st)
    case SCon{Chr{+c}, t}:
      +r = Tx.step(st, c)
      List.append(&2, Tx, Tn.out(r), Tx.go(t, Tn.next(r)))

def Tx.of(s: String) -> List<&2, Tx>:
  Tx.go(s, Ts.Plain{})

# Clusters
# --------
# What takes columns together: a character with the zero-width ones after
# it (combining marks, variation selectors, ZWJ), and, joined into one,
# an emoji ZWJ sequence (pictograph ZWJ pictograph), an emoji and its skin
# tone, two regional indicators (a flag), and a Hangul syllable written in
# jamo. A cluster's width is its first character's: 0 if it has none, 2
# if East Asian Wide or Fullwidth or a regional indicator, else 1; VS16
# makes a narrow emoji 2, VS15 makes a presentation emoji of the BMP 1.

type Un is Data:
  Un.Cl{s: String, w: U32}
  Un.Esc{s: String}

# the cluster in progress: is there one, its width, its base's flags, and
# whether a ZWJ or a lone regional indicator waits for a partner
type Ws is Data:
  Ws{has: Bool, w: U32, f: U32, zwj: Bool, ri: Bool}

type UnR is Data:
  UnR{acc: List<&2, Un>, st: Ws}

def Ws.none() -> Ws:
  Ws{False{}, 0, 0, False{}, False{}}

def Un.is(+f: U32, bit: U32) -> Bool:
  U32.is_ne(U32.and(f, bit), 0)

# a control character (C0, DEL, C1) is a cluster of its own: nothing
# joins it and it joins nothing
def Un.ctl(+c: U32) -> Bool:
  Bool.or(U32.is_lt(c, 32), Tx.in(c, 127, 159))

def Un.cont(+has: Bool, +sf: U32, +zwj: Bool, +ri: Bool, +f: U32, +c: U32) -> Bool:
  Bool.and(Bool.and(has, Bool.not(Un.ctl(c))), Bool.or(Bool.or(Un.is(f, U.Uni.zero()), Bool.and(zwj, Bool.and(Un.is(f, U.Uni.pict()), Un.is(sf, U.Uni.pict())))),
                        Bool.or(Bool.and(Un.is(f, U.Uni.emod()), Un.is(sf, U.Uni.emodbase())),
                                Bool.or(Bool.and(Un.is(f, U.Uni.ri()), ri), Bool.and(Un.is(f, U.Uni.hvt()), Un.is(sf, U.Uni.hangul()))))))

# the width after a joining character: VS16 (FE0F) and VS15 (FE0E) may
# change it, nothing else does
def Un.vs(+c: U32, +sf: U32, +w: U32) -> U32:
  Bool.pick(U32, U32.is_eq(c, 65039), Bool.pick(U32, Bool.and(Un.is(sf, U.Uni.emoji()), U32.is_eq(w, 1)), 2, w),
    Bool.pick(U32, U32.is_eq(c, 65038), Bool.pick(U32, Bool.and(Un.is(sf, U.Uni.epres()), U32.is_eq(w, 2)), 1, w), w))

def Un.fresh(+f: U32) -> U32:
  Bool.pick(U32, Un.is(f, U.Uni.zero()), 0, Bool.pick(U32, Bool.or(Un.is(f, U.Uni.ri()), Un.is(f, U.Uni.wide())), 2, 1))

def Un.join(k: Bool, acc: List<&2, Un>, +c: U32, +w: U32) -> List<&2, Un>:
  match k acc:
    case True{} Un.Cl{s, x} <> t:
      Un.Cl{SCon{Chr{c}, s}, w} <> t
    case _ other:
      Un.Cl{SCon{Chr{c}, SNil{}}, w} <> other

def Un.step(acc: List<&2, Un>, st: Ws, +c: U32, +f: U32) -> UnR:
  match st:
    case Ws{+has, +w, +sf, +zwj, +ri}:
      +k = Un.cont(has, sf, zwj, ri, f, c)
      +nw = Bool.pick(U32, k, Bool.pick(U32, Un.is(f, U.Uni.zero()), Un.vs(c, sf, w), w), Un.fresh(f))
      UnR{Un.join(k, acc, c, nw),
          Ws{Bool.not(Un.ctl(c)), nw, Bool.pick(U32, Bool.and(k, Un.is(f, U.Uni.zero())), sf, f), U32.is_eq(c, 8205),
             Bool.pick(Bool, k, Bool.and(Un.is(f, U.Uni.zero()), ri), Un.is(f, U.Uni.ri()))}}

def UnR.acc(r: UnR) -> List<&2, Un>:
  match r:
    case UnR{a, s}:
      a

def UnR.st(r: UnR) -> Ws:
  match r:
    case UnR{a, s}:
      s

def Un.go(ts: List<&2, Tx>, acc: List<&2, Un>, st: Ws) -> List<&2, Un>:
  match ts:
    case Nil{}:
      acc
    case Tx.Esc{s} <> t:
      Un.go(t, Un.Esc{s} <> acc, Ws.none())
    case Tx.Ch{+c, +f} <> t:
      +r = Un.step(acc, st, c, f)
      Un.go(t, UnR.acc(r), UnR.st(r))

# the units in order, each cluster's characters in order
def Un.fin(acc: List<&2, Un>, out: List<&2, Un>) -> List<&2, Un>:
  match acc:
    case Nil{}:
      out
    case Un.Cl{s, w} <> t:
      Un.fin(t, Un.Cl{String.reverse(s), w} <> out)
    case Un.Esc{s} <> t:
      Un.fin(t, Un.Esc{s} <> out)

def Ansi.units(s: String) -> List<&2, Un>:
  Un.fin(Un.go(Tx.of(s), Nil{}, Ws.none()), Nil{})

def Un.width(us: List<&2, Un>) -> U32:
  match us:
    case Nil{}:
      0
    case Un.Cl{s, w} <> t:
      (w + Un.width(t) : U32)
    case Un.Esc{s} <> t:
      Un.width(t)

def Un.text(us: List<&2, Un>) -> String:
  match us:
    case Nil{}:
      ""
    case Un.Cl{s, w} <> t:
      s ++ Un.text(t)
    case Un.Esc{s} <> t:
      Un.text(t)

# Strip and width
# ---------------

# s without its escape sequences
def Ansi.strip(s: String) -> String:
  Un.text(Ansi.units(s))

# the columns s takes on a terminal; escapes take none
def Ansi.width(s: String) -> U32:
  Un.width(Ansi.units(s))

# Active styles
# -------------
# What slice and wrap carry over a cut or a line break: the SGR parts in
# force, in the order they were set, and the OSC 8 link in force. An SGR
# escape (ESC [ digits ; : m) is cut into parameters, an extended colour
# (38, 48 or 58 then 5;n or 2;r;g;b) kept as one; each sets a part, ends
# the parts it closes, or (0, or nothing) ends them all.

# a part: the key it replaces by, its opening parameters, its closing code
type Act is Data:
  Act{key: U32, open: String, close: U32}

def Str.split.cur(semi: Bool, +c: U32, cur: String) -> String:
  match semi:
    case True{}:
      SNil{}
    case False{}:
      SCon{Chr{c}, cur}

# the pieces between semicolons, each finished when its semicolon is seen
def Str.split.step(semi: Bool, +c: U32, cur: String, rest: List<&2, String>) -> List<&2, String>:
  match semi:
    case True{}:
      String.reverse(cur) <> rest
    case False{}:
      rest

def Str.split.go(s: String, +cur: String) -> List<&2, String>:
  match s:
    case SNil{}:
      [String.reverse(cur)]
    case SCon{Chr{+c}, t}:
      Str.split.step(U32.is_eq(c, 59), c, cur, Str.split.go(t, Str.split.cur(U32.is_eq(c, 59), c, cur)))

def Str.num.go(s: String, +acc: U32) -> U32:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{+c}, t}:
      Bool.pick(U32, Bool.and(U32.is_ge(c, 48), U32.is_le(c, 57)), Str.num.go(t, U32.min((acc * 10 + (c - 48) : U32), 100000)), acc)

# the number a parameter starts with; "" is 0
def Str.num(s: String) -> U32:
  Str.num.go(s, 0)

# the parameters of an SGR escape: the body of ESC [ body m, if it is one
def Sgr.body.ok(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(Bool.or(Bool.and(U32.is_ge(c, 48), U32.is_le(c, 59)), False{}), Sgr.body.ok(t))

def Sgr.body.go(+s: String, ok: Bool) -> Maybe<&2, String>:
  match ok:
    case True{}:
      Some{s}
    case False{}:
      None{}

def Sgr.body.at(rest: String) -> Maybe<&2, String>:
  match rest:
    case SNil{}:
      None{}
    case SCon{Chr{109}, +b}:
      Sgr.body.go(String.reverse(b), Sgr.body.ok(b))
    case _:
      None{}

def Sgr.body(s: String) -> Maybe<&2, String>:
  match s:
    case SCon{Chr{27}, SCon{Chr{91}, t}}:
      Sgr.body.at(String.reverse(t))
    case _:
      None{}

# the parameters grouped: 38;5;n and 38;2;r;g;b are one
type Grp is Data:
  Grp.None{}
  Grp.Ext{acc: String, need: Nat}

def Grp.ext(+n: U32) -> Bool:
  Bool.or(Bool.or(U32.is_eq(n, 38), U32.is_eq(n, 48)), U32.is_eq(n, 58))

def Grp.need(+p: String) -> Nat:
  Bool.pick(Nat, String.eq(p, "5"), 1n, Bool.pick(Nat, String.eq(p, "2"), 3n, 0n))

def Grp.out(st: Grp, +p: String) -> List<&2, String>:
  match st:
    case Grp.None{}:
      Bool.pick(List<&2, String>, Grp.ext(Str.num(p)), Nil{}, [p])
    case Grp.Ext{acc, 0n}:
      Bool.pick(List<&2, String>, Nat.is_eq(Grp.need(p), 0n), [acc ++ ";" ++ p], Nil{})
    case Grp.Ext{acc, 1n+0n}:
      [acc ++ ";" ++ p]
    case Grp.Ext{acc, n}:
      Nil{}

def Grp.next(st: Grp, +p: String) -> Grp:
  match st:
    case Grp.None{}:
      Bool.pick(Grp, Grp.ext(Str.num(p)), Grp.Ext{p, 0n}, Grp.None{})
    case Grp.Ext{acc, 0n}:
      Bool.pick(Grp, Nat.is_eq(Grp.need(p), 0n), Grp.None{}, Grp.Ext{acc ++ ";" ++ p, Grp.need(p)})
    case Grp.Ext{acc, 1n+0n}:
      Grp.None{}
    case Grp.Ext{acc, 1n+1n+m}:
      Grp.Ext{acc ++ ";" ++ p, 1n+m}

def Grp.flush(st: Grp) -> List<&2, String>:
  match st:
    case Grp.None{}:
      Nil{}
    case Grp.Ext{acc, n}:
      [acc]

def Grp.go(ps: List<&2, String>, +st: Grp) -> List<&2, String>:
  match ps:
    case Nil{}:
      Grp.flush(st)
    case +p <> t:
      List.append(&2, String, Grp.out(st, p), Grp.go(t, Grp.next(st, p)))

def Sgr.params(body: String) -> List<&2, String>:
  Grp.go(Str.split.go(body, SNil{}), Grp.None{})

# the closing code of an opening parameter; 0 when none is known
def Sgr.close(+n: U32) -> U32:
  Bool.pick(U32, Bool.or(Tx.in(n, 30, 38), Tx.in(n, 90, 97)), 39,
  Bool.pick(U32, Bool.or(Tx.in(n, 40, 48), Tx.in(n, 100, 107)), 49,
  Bool.pick(U32, U32.is_eq(n, 58), 59,
  Bool.pick(U32, Tx.in(n, 1, 2), 22,
  Bool.pick(U32, Tx.in(n, 3, 4), (n + 20 : U32),
  Bool.pick(U32, Tx.in(n, 7, 9), (n + 20 : U32),
  Bool.pick(U32, U32.is_eq(n, 53), 55, 0)))))))

# a closing code: one that ends the parts it closes
def Sgr.is_close(+n: U32) -> Bool:
  Bool.or(Bool.or(Tx.in(n, 22, 24), Tx.in(n, 27, 29)), Bool.or(Bool.or(U32.is_eq(n, 39), U32.is_eq(n, 49)), Bool.or(U32.is_eq(n, 59), U32.is_eq(n, 55))))

# the key a part replaces by: wrap-ansi keys colours by family and every
# modifier apart (by family); slice-ansi keys every part by its closing
# code, so dim replaces bold there
def Sgr.key(+n: U32, by_close: Bool) -> U32:
  match by_close:
    case True{}:
      Sgr.close(n)
    case False{}:
      Bool.pick(U32, Bool.or(Bool.or(U32.is_eq(Sgr.close(n), 39), U32.is_eq(Sgr.close(n), 49)), U32.is_eq(Sgr.close(n), 59)), (Sgr.close(n) + 1000 : U32), n)

def Act.keep(gone: Bool, a: Act, rest: List<&2, Act>) -> List<&2, Act>:
  match gone:
    case True{}:
      rest
    case False{}:
      a <> rest

def Act.drop(acts: List<&2, Act>, +key: U32) -> List<&2, Act>:
  match acts:
    case Nil{}:
      Nil{}
    case Act{+k, o, c} <> t:
      Act.keep(U32.is_eq(k, key), Act{k, o, c}, Act.drop(t, key))

def Act.end(acts: List<&2, Act>, +code: U32) -> List<&2, Act>:
  match acts:
    case Nil{}:
      Nil{}
    case Act{k, o, +c} <> t:
      Act.keep(U32.is_eq(c, code), Act{k, o, c}, Act.end(t, code))

def Act.param.go(acts: List<&2, Act>, +p: String, +n: U32, +by_close: Bool, reset: Bool, close: Bool) -> List<&2, Act>:
  match reset close:
    case True{} _:
      Nil{}
    case False{} True{}:
      Act.end(acts, n)
    case False{} False{}:
      List.append(&2, Act, Act.drop(acts, Sgr.key(n, by_close)), [Act{Sgr.key(n, by_close), p, Sgr.close(n)}])

def Act.param(acts: List<&2, Act>, +p: String, +by_close: Bool) -> List<&2, Act>:
  Act.param.go(acts, p, Str.num(p), by_close, U32.is_eq(Str.num(p), 0), Sgr.is_close(Str.num(p)))

def Act.params(ps: List<&2, String>, acts: List<&2, Act>, +by_close: Bool) -> List<&2, Act>:
  match ps:
    case Nil{}:
      acts
    case p <> t:
      Act.params(t, Act.param(acts, p, by_close), by_close)

# does an SGR escape only end parts (each parameter 0 or a close)
def Sgr.ends(ps: List<&2, String>) -> Bool:
  match ps:
    case Nil{}:
      True{}
    case +p <> t:
      Bool.and(Bool.or(U32.is_eq(Str.num(p), 0), Sgr.is_close(Str.num(p))), Sgr.ends(t))

def Act.opens(acts: List<&2, Act>) -> String:
  match acts:
    case Nil{}:
      ""
    case Act{k, o, c} <> t:
      SCon{Chr{27}, SCon{Chr{91}, o ++ "m"}} ++ Act.opens(t)

def Act.closes(acts: List<&2, Act>) -> String:
  match acts:
    case Nil{}:
      ""
    case Act{k, o, c} <> t:
      Act.closes(t) ++ SCon{Chr{27}, SCon{Chr{91}, U32.show(c) ++ "m"}}

# OSC 8: ESC ] 8 ; params ; uri, ended by BEL or ESC \. The open link is
# kept as its escape; an empty uri closes it
def Link.uri.go(s: String, +semis: U32) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, t}:
      Bool.pick(Bool, U32.is_eq(semis, 2), Bool.not(Bool.or(Bool.or(U32.is_eq(c, 7), U32.is_eq(c, 27)), U32.is_eq(c, 92))),
        Link.uri.go(t, Bool.pick(U32, U32.is_eq(c, 59), (semis + 1 : U32), semis)))

def Str.starts(p: String, s: String) -> Bool:
  match p s:
    case SNil{} _:
      True{}
    case SCon{a, pt} SNil{}:
      False{}
    case SCon{a, pt} SCon{b, st}:
      Bool.and(Char.is_eq(a, b), Str.starts(pt, st))

# is the escape an OSC 8, and does it open (a non-empty uri)
def Link.is(+s: String) -> Bool:
  Str.starts(SCon{Chr{27}, "]8;"}, s)

def Link.opens(+s: String) -> Bool:
  Link.uri.go(s, 0)

def Str.ends(p: String, s: String) -> Bool:
  Str.starts(String.reverse(p), String.reverse(s))

def Link.st(+s: String) -> Bool:
  Str.ends(SCon{Chr{27}, "\\"}, s)

def Link.close(+open: String) -> String:
  SCon{Chr{27}, "]8;;"} ++ Bool.pick(String, Link.st(open), SCon{Chr{27}, "\\"}, SCon{Chr{7}, SNil{}})

def Link.after(+s: String, link: Maybe<&2, String>, osc8: Bool) -> Maybe<&2, String>:
  match osc8:
    case True{}:
      Bool.pick(Maybe<&2, String>, Link.opens(s), Some{s}, None{})
    case False{}:
      link

def Link.open(link: Maybe<&2, String>) -> String:
  match link:
    case None{}:
      ""
    case Some{s}:
      s

def Link.shut(link: Maybe<&2, String>) -> String:
  match link:
    case None{}:
      ""
    case Some{s}:
      Link.close(s)

# the state after an escape: its SGR parameters applied, its link taken
def Pen.sgr(b: Maybe<&2, String>, acts: List<&2, Act>, +by_close: Bool) -> List<&2, Act>:
  match b:
    case None{}:
      acts
    case Some{body}:
      Act.params(Sgr.params(body), acts, by_close)

type Pen is Data:
  Pen{acts: List<&2, Act>, link: Maybe<&2, String>}

def Pen.none() -> Pen:
  Pen{Nil{}, None{}}

def Pen.after(p: Pen, +s: String, +by_close: Bool) -> Pen:
  match p:
    case Pen{acts, link}:
      Pen{Pen.sgr(Sgr.body(s), acts, by_close), Link.after(s, link, Link.is(s))}

def Pen.opens(p: Pen) -> String:
  match p:
    case Pen{acts, link}:
      Act.opens(acts) ++ Link.open(link)

def Pen.closes(p: Pen) -> String:
  match p:
    case Pen{acts, link}:
      Link.shut(link) ++ Act.closes(acts)

# Slice
# -----
# slice-ansi: the clusters from column a up to column b, by display
# width. The styles and link in force at a are opened first, every one
# in force at the end is closed; a wide character across either edge is
# left out whole, so the slice may be a column short. An escape past b is
# kept only if it only ends parts; one that opens parts with no text after
# it before the cut is taken back.

# where the slice is: before a, inside, or past b
type Sl is Data:
  Sl{pos: U32, mode: U32, pen: Pen, out: String, ck: Maybe<&2, Ck>}

# the output and pen to go back to if nothing visible follows
type Ck is Data:
  Ck{out: String, pen: Pen}

def Sl.back(ck: Maybe<&2, Ck>, +pos: U32, +out: String, +pen: Pen) -> Sl:
  match ck:
    case None{}:
      Sl{pos, 2, pen, out, None{}}
    case Some{Ck{o, p}}:
      Sl{pos, 2, p, o, None{}}

def Sl.rev(+s: String, out: String) -> String:
  String.append(String.reverse(s), out)

def Sl.cl.go(+mode: U32, +pos: U32, +pen: Pen, +out: String, +ck: Maybe<&2, Ck>, +s: String, +w: U32, +a: U32, stop: Bool) -> Sl:
  match stop:
    case True{}:
      Bool.pick(Sl, U32.is_eq(mode, 1), Sl.back(ck, pos, out, pen), Sl{pos, mode, pen, out, None{}})
    case False{}:
      Bool.pick(Sl, U32.is_ge(pos, a),
        Sl{(pos + w : U32), 1, pen, Sl.rev(s, Bool.pick(String, U32.is_eq(mode, 0), Sl.rev(Pen.opens(pen), out), out)), None{}},
        Sl{(pos + w : U32), mode, pen, out, ck})

# a cluster of width w at the current column
def Sl.cl(st: Sl, +s: String, +w: U32, +a: U32, +b: U32) -> Sl:
  match st:
    case Sl{+pos, +mode, +pen, +out, ck}:
      Sl.cl.go(mode, pos, pen, out, ck, s, w, a, Bool.or(U32.is_eq(mode, 2), Bool.or(U32.is_ge(pos, b), U32.is_gt((pos + w : U32), b))))

def Sl.esc.past(+pos: U32, +pen2: Pen, +pen: Pen, +out: String, +s: String, ends: Bool) -> Sl:
  match ends:
    case True{}:
      Sl{pos, 2, pen2, Sl.rev(s, out), None{}}
    case False{}:
      Sl{pos, 2, pen, out, None{}}

def Sl.sgr(b: Maybe<&2, String>) -> Bool:
  match b:
    case None{}:
      False{}
    case Some{body}:
      Sgr.ends(Sgr.params(body))

def Sl.opens(b: Maybe<&2, String>) -> Bool:
  match b:
    case None{}:
      False{}
    case Some{body}:
      Bool.not(Sgr.ends(Sgr.params(body)))

def Sl.ck(ck: Maybe<&2, Ck>, +out: String, +pen: Pen, opens: Bool) -> Maybe<&2, Ck>:
  match ck opens:
    case None{} True{}:
      Some{Ck{out, pen}}
    case other _:
      other

def Sl.esc.go(+mode: U32, +pos: U32, +pen2: Pen, +pen: Pen, +out: String, +ck: Maybe<&2, Ck>, +s: String, past: Bool) -> Sl:
  match past:
    case True{}:
      Bool.pick(Sl, U32.is_eq(mode, 0), Sl{pos, 0, pen2, out, None{}},
        Sl.esc.past(pos, pen2, pen, out, s, Sl.sgr(Sgr.body(s))))
    case False{}:
      Bool.pick(Sl, U32.is_eq(mode, 1),
        Sl{pos, 1, pen2, Sl.rev(s, out), Sl.ck(ck, out, pen, Sl.opens(Sgr.body(s)))},
        Sl{pos, mode, pen2, out, ck})

# an escape: tracked always; written while inside; past b only if it ends
def Sl.esc(st: Sl, +s: String, +b: U32) -> Sl:
  match st:
    case Sl{+pos, +mode, +pen, +out, ck}:
      Sl.esc.go(mode, pos, Pen.after(pen, s, True{}), pen, out, ck, s, Bool.or(U32.is_eq(mode, 2), U32.is_ge(pos, b)))

def Sl.go(us: List<&2, Un>, st: Sl, +a: U32, +b: U32) -> Sl:
  match us:
    case Nil{}:
      st
    case Un.Cl{s, w} <> t:
      Sl.go(t, Sl.cl(st, s, w, a, b), a, b)
    case Un.Esc{s} <> t:
      Sl.go(t, Sl.esc(st, s, b), a, b)

def Sl.fin(st: Sl) -> String:
  match st:
    case Sl{pos, mode, pen, out, ck}:
      Bool.pick(String, U32.is_eq(mode, 0), "", String.reverse(out) ++ Pen.closes(pen))

# the columns a up to b of s, styles kept; "" when b <= a
def Ansi.slice(s: String, +a: U32, +b: U32) -> String:
  Bool.pick(String, U32.is_le(b, a), "", Sl.fin(Sl.go(Ansi.units(s), Sl{0, 0, Pen.none(), "", None{}}, a, b)))

def S.of(cs: List<&2, U32>) -> String:
  match cs:
    case Nil{}:
      SNil{}
    case c <> t:
      SCon{Chr{c}, S.of(t)}

def Un.all(us: List<&2, Un>) -> String:
  match us:
    case Nil{}:
      ""
    case Un.Cl{s, w} <> t:
      s ++ Un.all(t)
    case Un.Esc{s} <> t:
      s ++ Un.all(t)

def Un.is_sgr(+s: String) -> Bool:
  Maybe.is_some(&2, String, Sgr.body(s))

# Truncate
# --------
# cli-truncate: s cut to cols columns with an ellipsis (…, one column) at
# the end, the start or the middle. Width 0 is "", a string that fits is
# itself, width 1 is the ellipsis alone. At the end and the start the
# ellipsis goes inside the SGR escapes at the cut, so it takes the style
# of the text beside it.

type Cut is Data:
  Cut.End{}
  Cut.Start{}
  Cut.Middle{}

def Tr.dots() -> String:
  SCon{Chr{8230}, SNil{}}

# the units of a string, reversed, split into the run of SGR escapes it
# ends with and what comes before them
def Tr.split(us: List<&2, Un>, +trail: Bool, +pre: String, +suf: String) -> String:
  match us:
    case Nil{}:
      pre ++ Tr.dots() ++ suf
    case Un.Esc{+e} <> t:
      Tr.split(t, Bool.and(trail, Un.is_sgr(e)), Bool.pick(String, Bool.and(trail, Un.is_sgr(e)), pre, e ++ pre),
        Bool.pick(String, Bool.and(trail, Un.is_sgr(e)), e ++ suf, suf))
    case Un.Cl{+s, w} <> t:
      Tr.split(t, False{}, s ++ pre, suf)

def Tr.end(s: String) -> String:
  Tr.split(List.reverse(&2, Un, Ansi.units(s)), True{}, "", "")

def Tr.lead(us: List<&2, Un>, +lead: Bool, +pre: String, +rest: String) -> String:
  match us:
    case Nil{}:
      pre ++ Tr.dots() ++ rest
    case Un.Esc{+e} <> t:
      Tr.lead(t, Bool.and(lead, Un.is_sgr(e)), Bool.pick(String, Bool.and(lead, Un.is_sgr(e)), pre ++ e, pre),
        Bool.pick(String, Bool.and(lead, Un.is_sgr(e)), rest, rest ++ e))
    case Un.Cl{+s, w} <> t:
      Tr.lead(t, False{}, pre, rest ++ s)

def Tr.start(s: String) -> String:
  Tr.lead(Ansi.units(s), True{}, "", "")

def Tr.cut(+s: String, +cols: U32, +len: U32, cut: Cut) -> String:
  match cut:
    case Cut.End{}:
      Tr.end(Ansi.slice(s, 0, (cols - 1 : U32)))
    case Cut.Start{}:
      Tr.start(Ansi.slice(s, U32.add(U32.sub(len, cols), 1), len))
    case Cut.Middle{}:
      Ansi.slice(s, 0, U32.div(cols, 2)) ++ Tr.dots() ++ Ansi.slice(s, U32.add(U32.sub(len, U32.sub(cols, U32.div(cols, 2))), 1), len)

def Tr.go(+s: String, +cols: U32, +len: U32, cut: Cut, fits: Bool) -> String:
  match fits:
    case True{}:
      s
    case False{}:
      Bool.pick(String, U32.is_eq(cols, 1), Tr.dots(), Tr.cut(s, cols, len, cut))

# s in at most cols columns, an ellipsis where it was cut
def Ansi.truncate(+s: String, +cols: U32, cut: Cut) -> String:
  Bool.pick(String, U32.is_eq(cols, 0), "", Tr.go(s, cols, Ansi.width(s), cut, U32.is_le(Ansi.width(s), cols)))

# Wrap
# ----
# wrap-ansi with its defaults (trim, word wrap) and its hard option. Each
# line is wrapped alone: tabs to the next multiple of 8 columns, words cut
# at spaces, a word that does not fit to the next row; one wider than the
# width alone on its rows (soft), or cut at the width (hard, a wide
# character that does not fit moving down whole). Trailing spaces are
# trimmed. Then every SGR part and link in force at a line break is
# closed before it and opened again after it.

# the pieces of s between characters k, in order
def Str.pieces.go(s: String, +k: U32, +cur: String) -> List<&2, String>:
  match s:
    case SNil{}:
      [String.reverse(cur)]
    case SCon{Chr{+c}, t}:
      Str.split.step(U32.is_eq(c, k), c, cur, Str.pieces.go(t, k, Bool.pick(String, U32.is_eq(c, k), SNil{}, SCon{Chr{c}, cur})))

def Str.pieces(s: String, +k: U32) -> List<&2, String>:
  Str.pieces.go(s, k, SNil{})

def Str.join(ps: List<&2, String>, +sep: String) -> String:
  match ps:
    case Nil{}:
      ""
    case p <> Nil{}:
      p
    case p <> t:
      p ++ sep ++ Str.join(t, sep)

def Str.spaces(n: Nat) -> String:
  match n:
    case 0n:
      ""
    case 1n+p:
      SCon{Chr{32}, Str.spaces(p)}

# a line with \r\n's \r gone
def Str.uncr(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{13}, SNil{}}:
      SNil{}
    case SCon{h, t}:
      SCon{h, Str.uncr(t)}

# tabs to spaces up to the next multiple of 8, as wrap-ansi counts: from
# the width of the text since the previous tab
def Wr.tabs(ps: List<&2, String>) -> String:
  match ps:
    case Nil{}:
      ""
    case p <> Nil{}:
      p
    case +p <> t:
      p ++ Str.spaces(U32.to_nat(U32.sub(8, U32.mod(Ansi.width(p), 8)))) ++ Wr.tabs(t)

def Wr.blank(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(Bool.or(Bool.or(U32.is_eq(c, 32), Tx.in(c, 9, 13)), U32.is_eq(c, 160)), Wr.blank(t))

def Wr.words.cut(sp: Bool, cur: List<&2, Un>, rest: List<&2, List<&2, Un>>) -> List<&2, List<&2, Un>>:
  match sp:
    case True{}:
      List.reverse(&2, Un, cur) <> rest
    case False{}:
      rest

# the words of a line: its units between spaces
def Wr.words.go(us: List<&2, Un>, +cur: List<&2, Un>) -> List<&2, List<&2, Un>>:
  match us:
    case Nil{}:
      [List.reverse(&2, Un, cur)]
    case Un.Cl{+s, +w} <> t:
      Wr.words.cut(String.eq(s, " "), cur, Wr.words.go(t, Bool.pick(List<&2, Un>, String.eq(s, " "), Nil{}, Un.Cl{s, w} <> cur)))
    case Un.Esc{s} <> t:
      Wr.words.go(t, Un.Esc{s} <> cur)

# the rows so far: those done (last first), the one being filled and its
# width, and whether a word has been placed
type Wr is Data:
  Wr{done: List<&2, String>, cur: String, len: U32, first: Bool}

# wrap-ansi's wrapWord: a word cut at the width, unit by unit
type Ww is Data:
  Ww{done: List<&2, String>, cur: String, vis: U32}

def Ww.unit.c2(+done: List<&2, String>, +cur: String, +vis: U32, +cols: U32, +more: Bool) -> Ww:
  Bool.pick(Ww, Bool.and(U32.is_eq(vis, cols), more), Ww{cur <> done, "", 0}, Ww{done, cur, vis})

def Ww.unit.c(+done: List<&2, String>, +s: String, +w: U32, +cols: U32, +more: Bool) -> Ww:
  Ww.unit.c2(done, s, w, cols, more)

def Ww.unit.b(down: Bool, +done: List<&2, String>, +cur: String, +vis: U32, +s: String, +w: U32, +cols: U32, +more: Bool) -> Ww:
  match down:
    case True{}:
      Ww.unit.c(cur <> done, s, w, cols, more)
    case False{}:
      Ww.unit.c2(done, cur ++ s, (vis + w : U32), cols, more)

def Ww.unit(st: Ww, +s: String, +w: U32, +cols: U32, +more: Bool) -> Ww:
  match st:
    case Ww{+done, +cur, +vis}:
      Ww.unit.b(Bool.and(Bool.and(U32.is_gt(w, 0), U32.is_gt(vis, 0)), U32.is_gt((vis + w : U32), cols)), done, cur, vis, s, w, cols, more)

def Ww.go(us: List<&2, Un>, st: Ww, +cols: U32) -> Ww:
  match us:
    case Nil{}:
      st
    case Un.Cl{s, w} <> +t:
      Ww.go(t, Ww.unit(st, s, w, cols, Bool.not(List.is_empty(&2, Un, t))), cols)
    case Un.Esc{s} <> +t:
      Ww.go(t, Ww.unit(st, s, 0, cols, Bool.not(List.is_empty(&2, Un, t))), cols)

def Ww.fin.b(back: Bool, done: List<&2, String>, +cur: String) -> Wr:
  match back done:
    case True{} +p <> t:
      Wr{t, p ++ cur, Ansi.width(p ++ cur), False{}}
    case _ d:
      Wr{d, cur, Ansi.width(cur), False{}}

# a row left holding only escapes goes back onto the one before it
def Ww.fin(st: Ww) -> Wr:
  match st:
    case Ww{+done, +cur, +vis}:
      Ww.fin.b(Bool.and(Bool.and(U32.is_eq(vis, 0), Bool.not(String.is_empty(cur))), Bool.not(List.is_empty(&2, String, done))), done, cur)

def Wr.hard.b(fresh: Bool, +done: List<&2, String>, +cur: String, +len: U32, us: List<&2, Un>, +cols: U32) -> Wr:
  match fresh:
    case True{}:
      Ww.fin(Ww.go(us, Ww{cur <> done, "", 0}, cols))
    case False{}:
      Ww.fin(Ww.go(us, Ww{done, cur, len}, cols))

def Wr.hard(st: Wr, us: List<&2, Un>, +ww: U32, +cols: U32) -> Wr:
  match st:
    case Wr{+done, +cur, +len, first}:
      Wr.hard.b(U32.is_lt(U32.div(U32.sub(ww, 1), cols), U32.add(1, U32.div(U32.sub(U32.add(ww, len), U32.add(cols, 1)), cols))), done, cur, len, us, cols)

def Wr.soft.b(down: Bool, +done: List<&2, String>, +cur: String, +len: U32, +word: String, +ww: U32) -> Wr:
  match down:
    case True{}:
      Wr{cur <> done, word, ww, False{}}
    case False{}:
      Wr{done, cur ++ word, (len + ww : U32), False{}}

def Wr.soft(st: Wr, us: List<&2, Un>, +ww: U32, +cols: U32) -> Wr:
  match st:
    case Wr{+done, +cur, +len, first}:
      Wr.soft.b(Bool.and(Bool.and(U32.is_gt((len + ww : U32), cols), U32.is_gt(len, 0)), U32.is_gt(ww, 0)), done, cur, len, Un.all(us), ww)

# a space before every word but the first, when the row has text
def Wr.space(st: Wr) -> Wr:
  match st:
    case Wr{+done, +cur, +len, +first}:
      Bool.pick(Wr, Bool.and(Bool.not(first), U32.is_gt(len, 0)), Wr{done, cur ++ " ", (len + 1 : U32), False{}}, Wr{done, cur, len, False{}})

def Wr.word.c(cut: Bool, st: Wr, us: List<&2, Un>, +ww: U32, +cols: U32) -> Wr:
  match cut:
    case True{}:
      Wr.hard(st, us, ww, cols)
    case False{}:
      Wr.soft(st, us, ww, cols)

def Wr.word.b(st: Wr, +us: List<&2, Un>, +ww: U32, +cols: U32, +hard: Bool) -> Wr:
  Wr.word.c(Bool.and(hard, U32.is_gt(ww, cols)), st, us, ww, cols)

def Wr.word(st: Wr, +us: List<&2, Un>, +cols: U32, +hard: Bool) -> Wr:
  Wr.word.b(Wr.space(st), us, Un.width(us), cols, hard)

def Wr.words(ws: List<&2, List<&2, Un>>, st: Wr, +cols: U32, +hard: Bool) -> Wr:
  match ws:
    case Nil{}:
      st
    case w <> t:
      Wr.words(t, Wr.word(st, w, cols, hard), cols, hard)

# trailing spaces off a row; escapes after them stay
def Wr.trim.go(us: List<&2, Un>, +trim: Bool) -> String:
  match us:
    case Nil{}:
      ""
    case Un.Esc{s} <> t:
      Wr.trim.go(t, trim) ++ s
    case Un.Cl{+s, w} <> t:
      Wr.trim.go(t, Bool.and(trim, String.eq(s, " "))) ++ Bool.pick(String, Bool.and(trim, String.eq(s, " ")), "", s)

def Wr.trim(s: String) -> String:
  Wr.trim.go(List.reverse(&2, Un, Ansi.units(s)), True{})

def Wr.rows(rs: List<&2, String>) -> List<&2, String>:
  match rs:
    case Nil{}:
      Nil{}
    case r <> t:
      Wr.trim(r) <> Wr.rows(t)

def Wr.done(st: Wr) -> String:
  match st:
    case Wr{done, cur, len, first}:
      Str.join(Wr.rows(List.reverse(&2, String, cur <> done)), "\n")

def Wr.line(+line: String, +cols: U32, +hard: Bool) -> String:
  Bool.pick(String, Wr.blank(line), "", Wr.done(Wr.words(Wr.words.go(Ansi.units(line), Nil{}), Wr{Nil{}, "", 0, True{}}, cols, hard)))

def Wr.lines(ls: List<&2, String>, +cols: U32, +hard: Bool) -> List<&2, String>:
  match ls:
    case Nil{}:
      Nil{}
    case l <> t:
      Wr.line(Wr.tabs(Str.pieces(Str.uncr(l), 9)), cols, hard) <> Wr.lines(t, cols, hard)

def Rs.lead.pen(apply: Bool, p: Pen, +s: String) -> Pen:
  match apply:
    case True{}:
      Pen.after(p, s, False{})
    case False{}:
      p

# the pen a row starts with: the one in force, less what the escapes at
# the very start of the row only end (wrap-ansi does not reopen a part
# the row closes before any text)
def Rs.lead(us: List<&2, Un>, p: Pen, +going: Bool) -> Pen:
  match us:
    case Nil{}:
      p
    case Un.Esc{+s} <> t:
      Rs.lead(t, Rs.lead.pen(Bool.and(going, Sl.sgr(Sgr.body(s))), p, s), Bool.and(going, Sl.sgr(Sgr.body(s))))
    case Un.Cl{s, w} <> t:
      Rs.lead(t, p, False{})

def Rs.nl(+s: String) -> Bool:
  String.eq(s, "\n")

# does a row with text follow
def Rs.next(us: List<&2, Un>) -> Bool:
  match us:
    case Nil{}:
      False{}
    case Un.Cl{s, w} <> t:
      Bool.not(Rs.nl(s))
    case Un.Esc{s} <> t:
      True{}

def Rs.brk.open(next: Bool, p: Pen) -> String:
  match next:
    case True{}:
      Pen.opens(p)
    case False{}:
      ""

def Rs.brk(+had: Bool, +p: Pen, +t: List<&2, Un>) -> String:
  Bool.pick(String, had, Pen.closes(p), "") ++ "\n" ++ Rs.brk.open(Rs.next(t), Rs.lead(t, p, True{}))

def Rs.piece(nl: Bool, +s: String, +had: Bool, +p: Pen, t: List<&2, Un>) -> String:
  match nl:
    case True{}:
      Rs.brk(had, p, t)
    case False{}:
      s

def Rs.go(us: List<&2, Un>, +p: Pen, +had: Bool) -> String:
  match us:
    case Nil{}:
      ""
    case Un.Esc{+s} <> t:
      s ++ Rs.go(t, Pen.after(p, s, False{}), True{})
    case Un.Cl{+s, w} <> +t:
      Rs.piece(Rs.nl(s), s, had, p, t) ++ Rs.go(t, p, Bool.not(Rs.nl(s)))

# s wrapped to cols columns; hard cuts words wider than cols
def Ansi.wrap(s: String, +cols: U32, +hard: Bool) -> String:
  Rs.go(Ansi.units(Str.join(Wr.lines(Str.pieces(s, 10), cols, hard), "\n")), Pen.none(), False{})

def Wr.widest(ls: List<&2, String>) -> U32:
  match ls:
    case Nil{}:
      0
    case l <> t:
      U32.max(Ansi.width(l), Wr.widest(t))

# the width of the widest line of s
def Ansi.widest(s: String) -> U32:
  Wr.widest(Str.pieces(s, 10))

def main() -> List<&2, String>:
  +red = S.of([27]) ++ "[31m"
  +off = S.of([27]) ++ "[39m"
  [Ansi.wrap("the quick brown fox jumps", 10, False{}), Ansi.wrap(red ++ "the quick brown" ++ off, 10, False{}),
   Ansi.wrap("abcdefghijkl xy", 5, True{}), Ansi.wrap("abcdefghijkl xy", 5, False{}), Ansi.wrap("a	b", 20, False{}),
   Ansi.truncate("unicorns rainbow", 7, Cut.End{}), Ansi.truncate("unicorns rainbow", 7, Cut.Start{}), Ansi.truncate("unicorns rainbow", 7, Cut.Middle{}),
   Ansi.truncate(red ++ "unicorns" ++ off, 5, Cut.End{}), Ansi.truncate("中文中文", 5, Cut.End{})]
