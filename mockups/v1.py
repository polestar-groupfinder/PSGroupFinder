"""v1.0.0 mock-ups: header icon left of Lookup, grouping languages (default = client locale)."""
import os, math
from PIL import Image, ImageDraw
from common import *

OUT = os.path.join(HERE, "v1")
os.makedirs(OUT, exist_ok=True)
ASSETS = os.path.join(HERE, "assets")
SRC_GUIDE = os.path.join(ASSETS, "polestar-guide-window.png")

PW, PAD, ROW_H, OPT_H, BTN_COL = 340, 12, 42, 20, 84
MUTED, DIM, GREEN, AMBER = TEXT_MUTED, TEXT_DIM, SUCCESS, WARNING
BANNER = ("MOCK-UP — sample data",
          "PSGroupFinder v1.0.0 · drawn from UI.lua / Polestar.lua / Lang.lua, not a game screenshot")

KIND = {"k": "kill", "n": "named", "l": "loot", "g": "group"}
ICON = (int(0.85 * 255), int(0.88 * 255), int(0.95 * 255), 255)  # Theme.Color("icon")
ACCENT_RGBA = (0xe6, 0xba, 0x66, 255)
MUTED_RGBA = (0x9b, 0xa2, 0xb9, int(255 * 0.55))  # textMuted at 0.55

# CSS coordinates inside the 353x318 guide crop (1 CSS px = 1 WoW unit).
LOUPE_CX, LOUPE_CY = 301.5, 58.5
BTN = 24
OUR_CX, OUR_CY = LOUPE_CX - BTN, LOUPE_CY  # 277.5, 58.5 — immediately left of Lookup
LOUPE_LEFT = LOUPE_CX - BTN / 2  # 289.5


def e(s):
    return html.escape(s)


def tint_icon(src, fill, size):
    """White-on-transparent glyph, tinted with a Theme colour (idle / accent / muted)."""
    im = Image.open(src).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    r, g, b, a = fill if len(fill) == 4 else (*fill, 255)
    px = im.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            _, _, _, aa = px[x, y]
            px[x, y] = (r, g, b, int(aa * (a / 255.0)))
    return im


def bake_guide(name, fill):
    """Shift Skip / Nearby / AllSteps 24 CSS px left and draw our 14px monochrome eye."""
    im = Image.open(SRC_GUIDE).convert("RGBA")
    scale = im.size[0] / 353.0  # asset is 2x
    def P(css):
        return css * scale

    cut_l, cut_r = P(185), P(LOUPE_LEFT)
    cut_t, cut_b = P(46.0), P(70.5)
    src = im.crop((int(round(cut_l)), int(round(cut_t)), int(round(cut_r)), int(round(cut_b))))
    dest_l = int(round(cut_l - P(24)))
    dest_t = int(round(cut_t))
    # Cover the original strip (including the vacated 24 px just left of the loupe)
    # with a slice of empty nav bar, then paste the shifted icons.
    patch = im.crop((int(round(P(150))), int(round(cut_t)), int(round(P(184))), int(round(cut_b))))
    x = int(round(cut_l))
    right = int(round(cut_r))
    while x < right:
        w = min(patch.size[0], right - x)
        im.paste(patch.crop((0, 0, w, patch.size[1])), (x, dest_t))
        x += w
    im.paste(src, (dest_l, dest_t))

    # Our monochrome eye, at IconButton's 14 px glyph size, tinted like the other header icons.
    cx, cy = P(OUR_CX), P(OUR_CY)
    eye_src = os.path.join(ASSETS, "psgf-icon-eye.png")
    glyph = int(round(14 * scale))
    icon = tint_icon(eye_src, fill, glyph)
    overlay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    px = int(round(cx - icon.size[0] / 2))
    py = int(round(cy - icon.size[1] / 2))
    overlay.paste(icon, (px, py), icon)
    im = Image.alpha_composite(im, overlay)
    path = os.path.join(ASSETS, name)
    im.save(path)
    return path


def guide(src_name, x=None, y=None):
    gx = (WIN[0] if x is None else x) - 6
    gy = (WIN[1] if y is None else y) - 6
    return (f'<img class="guide" src="../assets/{src_name}" '
            f'style="left:{gx}px;top:{gy}px;width:353px;height:318px">')


def pbtn(x, y, w, label, off=False, h=22, size=12, weight=500):
    return (f'<div class="abs pbtn{" off" if off else ""}" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px;'
            f'line-height:{h}px;font-size:{size}px;font-weight:{weight}">{e(label)}</div>')


def pcheck(x, y, label, checked, enabled=True):
    op = 1 if enabled else .5
    edge = ACCENT if checked else "rgba(255,255,255,.28)"
    tick = (f'<svg viewBox="0 0 18 18" width="18" height="18" style="position:absolute;left:0;top:0">'
            f'<path d="M4.5 9.5l3.2 3.3L13.5 5.5" fill="none" stroke="{ACCENT}" stroke-width="2"/></svg>') if checked else ""
    return (f'<div class="abs" style="left:{x}px;top:{y}px;opacity:{op}"><div class="abs" style="width:18px;height:18px;border-radius:3px;'
            f'background:rgba(255,255,255,.07);box-shadow:inset 0 0 0 1px {edge}">{tick}</div>'
            f'<div class="t" style="left:22px;top:2px;font-size:12px;font-weight:500;color:{TEXT}">{e(label)}</div></div>')


def close_btn():
    return (f'<div class="abs" style="left:{PW-8-18}px;top:8px;width:18px;height:18px;border-radius:3px;background:rgba(245,115,115,.22);'
            f'box-shadow:inset 0 0 0 1px rgba(245,115,115,.6)"><svg viewBox="0 0 18 18" width="18" height="18"><path d="M5.5 5.5l7 7M12.5 5.5l-7 7" '
            f'stroke="{TEXT}" stroke-width="1.6" fill="none"/></svg></div>')


COL = {"ok": "#40ff40", "sent": "#ffd100", "fail": "#ff5050", "skip": "#909090", "?": "#aaaaaa"}


def channel_names(states):
    return "&nbsp;&nbsp;".join(f'<span style="color:{COL[s]}">{n}</span>' for n, s in states)


def tag(kind):
    return f'({KIND[kind]}) ' if kind else ''


def row(y, p):
    cc = CLASS[p["cls"]]
    right, rcol = p.get("state") or p["where"], p.get("scol", MUTED)
    rw = p.get("rw", 52)
    lang = p.get("lang") or "FR"
    name_w = (PW - 2 * PAD) - (BTN_COL + 8) - rw - 6
    first = p["q"][0]
    more = f'&nbsp;&nbsp;<span style="color:{MUTED}">+{len(p["q"])-1}</span>' if len(p["q"]) > 1 else ""
    return (f'<div class="abs" style="left:{PAD}px;top:{y}px;width:{PW-2*PAD}px;height:{ROW_H}px">'
            f'<div class="t ell" style="left:0;top:2px;width:{name_w}px;font-size:13px;font-weight:500">'
            f'<span style="color:{cc}">{e(p["name"])}</span>&nbsp;&nbsp;<span style="color:{MUTED}">{p["lvl"]}</span>'
            f'&nbsp;&nbsp;<span style="color:{MUTED}">{e(lang)}</span></div>'
            f'<div class="t" style="right:{BTN_COL+8}px;top:4px;font-size:11px;font-weight:500;color:{rcol};text-align:right">{e(right)}</div>'
            f'<div class="t ell" style="left:0;top:21px;width:{PW-2*PAD-BTN_COL-8}px;font-size:11px;font-weight:500;color:{DIM}">'
            f'{e(tag(first[1]))}<span style="color:{TEXT}">{e(first[0])}</span>{more}</div>'
            f'{pbtn(PW-2*PAD-BTN_COL, 1, BTN_COL, "Whisper", h=19, size=11)}'
            f'{pbtn(PW-2*PAD-BTN_COL, ROW_H-20, BTN_COL, "Invite", h=19, size=11)}</div>')


def panel(left, top, enabled=True, auto=True, header=True, active=False, quests=(),
          search_label="Find a group", search_off=False, channels=None, peers=(),
          options_btn=True, lang_summary="EN", extra=""):
    """Mirrors UI.Refresh() v1: 5 switches + language row, then buttons."""
    y = 34 + 5 * OPT_H + 22 + 8
    body = []
    body.append(f'<div class="t" style="left:{PAD}px;top:10px;font-size:15px;font-weight:600;color:{TEXT}">Group Finder</div>')
    body.append(close_btn())
    checks = [
        ("Enable the group finder", enabled, True),
        ("Group automatically (same quest)", auto, enabled),
        ("Button in the Polestar header", header, True),
        ("Share my map position", True, enabled),
        ("Answer searches for my quests", True, enabled),
    ]
    for i, (lab, on, dis) in enumerate(checks):
        body.append(pcheck(PAD, 34 + i * OPT_H, lab, on and True, dis))
    ly = 34 + 5 * OPT_H + 2
    body.append(f'<div class="t" style="left:{PAD}px;top:{ly}px;font-size:11px;font-weight:500;color:{TEXT}">Search languages</div>')
    body.append(f'<div class="t" style="left:{PAD+128}px;top:{ly}px;font-size:11px;font-weight:500;color:{MUTED}">{e(lang_summary)}</div>')
    body.append(pbtn(PAD, y, 168, search_label, search_off or not enabled))
    if active:
        body.append(pbtn(PAD + 168 + 6, y, 70, "Stop"))
    if options_btn:
        body.append(pbtn(PW - PAD - 64, y, 64, "Options"))
    y += 22 + 10
    if enabled:
        body.append(f'<div class="t" style="left:{PAD}px;top:{y}px;font-size:11px;font-weight:600;color:{MUTED}">Search in progress</div>')
        y += 14
        if active:
            for t, k in quests[:4]:
                body.append(f'<div class="t ell" style="left:{PAD+4}px;top:{y}px;width:{PW-2*PAD-4}px;font-size:11px;font-weight:500;color:{DIM}">{e(tag(k))}<span style="color:{TEXT}">{e(t)}</span></div>')
                y += 14
        else:
            body.append(f'<div class="t" style="left:{PAD+4}px;top:{y}px;font-size:11px;font-weight:500;color:{MUTED}">No search in progress.</div>')
            y += 14
        y += 6
        body.append(f'<div class="t" style="left:{PAD}px;top:{y+4}px;font-size:11px;font-weight:500;color:{MUTED}">Channels</div>')
        if channels:
            body.append(f'<div class="t" style="left:{PAD+46}px;top:{y+4}px;font-size:11px;font-weight:500">{channel_names(channels)}</div>')
        body.append(pbtn(PW - PAD - 56, y, 56, "Test", off=not enabled, h=20, size=11))
        y += 22 + 6
        if not peers:
            body.append(f'<div class="t" style="left:{PAD+2}px;top:{y+2}px;width:{PW-2*PAD-4}px;white-space:normal;font-size:11px;font-weight:500;color:{MUTED}">No one yet. Press Find a group.</div>')
            y += 38
        for p in peers[:6]:
            body.append(row(y, p))
            y += ROW_H
    H = y + PAD - 2
    return (f'<div class="abs pwin" style="left:{left}px;top:{top}px;width:{PW}px;height:{H}px">'
            + "".join(body) + extra + "</div>"), H


def launcher(dim=False, label="Find a group", wx=None):
    x = (WIN[0] if wx is None else wx) + WIN[2] - 132
    y = WIN[1] + WIN[3] + 2
    b = pbtn(x, y, 132, label, h=20, size=11, weight=600)
    return b.replace("style=\"", f'style="opacity:{0.55 if dim else 1};', 1)


def caption(text, y=None, H=0, left=None):
    return (f'<div class="caption" style="left:{left or WIN[0]}px;top:{y or max(WIN[1]+WIN[3]+32, WIN[1]+H+16)}px;'
            f'width:1100px">{e(text)}</div>')


def tooltip(x, y, title, lines, w=280):
    t = "".join(f'<div style="font-size:11px;color:{c};line-height:14px;margin-top:3px">{e(l)}</div>' for l, c in lines)
    return (f'<div class="abs" style="left:{x}px;top:{y}px;width:{w}px;padding:8px 10px;background:rgba(16,16,28,.96);'
            f'border:1px solid #8a8a96;border-radius:3px;box-shadow:0 0 0 1px #000">'
            f'<div style="font-size:12px;font-weight:600;color:#fff">{e(title)}</div>{t}</div>')


QUESTS3 = [("Kobold Camp Cleanup", "k"), ("Wolves Across the Border", "l"), ("Wanted: Hogger", "n")]
P4 = [
    dict(name="Lyra Ashdown", cls="MAGE", lvl=8, lang="FR",
         q=[("Kobold Camp Cleanup", "k"), ("Wolves Across the Border", "l")],
         where="22 yd", state="invited", scol=GREEN, rw=30),
    dict(name="Torvald Greaves", cls="WARRIOR", lvl=9, lang="FR",
         q=[("Kobold Camp Cleanup", "k")], where="48 yd", state="pending", scol=AMBER, rw=52),
    dict(name="Edric Vane", cls="ROGUE", lvl=9, lang="FR",
         q=[("Kobold Camp Cleanup", "k")], where="same zone", rw=52),
    dict(name="Mira Quillon", cls="PRIEST", lvl=7, lang="FR",
         q=[("Wolves Across the Border", "l")], where="in a group", rw=74),
]
CH = [("CHANNEL", "fail"), ("YELL", "ok"), ("SAY", "sent"), ("GUILD", "skip")]

LANGS = [
    ("French", False),
    ("English", True),
    ("German", False),
    ("Spanish", False),
    ("Italian", False),
    ("Portuguese", False),
    ("Russian", False),
    ("Korean", False),
    ("Chinese (Simplified)", False),
    ("Chinese (Traditional)", False),
]


def s1():
    px = WIN[0] + WIN[2] + 6
    p, H = panel(px, WIN[1], enabled=False, auto=False, header=True, channels=None, options_btn=True)
    body = guide("polestar-guide-header-off.png") + p
    body += caption(
        "State 1 · addon disabled: the eye icon is in the header, immediately to the left of the magnifying glass, "
        "dimmed (textMuted). The button under the window is hidden. Right-clicking the icon opens the panel.",
        H=H)
    return page(body, BANNER)


def s2():
    px = WIN[0] + WIN[2] + 6
    p, H = panel(px, WIN[1], active=True, quests=QUESTS3, search_label="Search again",
                 channels=CH, peers=P4)
    body = guide("polestar-guide-header-active.png") + p
    body += caption(
        "State 2 · active search: the header icon is tinted (accent). Listed players show their language (FR). "
        "By default only the game language (here English) is ticked in Search languages; “All languages” is not ticked.",
        H=H)
    return page(body, BANNER)


def s3():
    # Tooltip under the header icon (ANCHOR_BOTTOM in Polestar.lua).
    gx, gy = WIN[0] - 6, WIN[1] - 6
    icon_left = gx + (OUR_CX - 12)
    icon_bottom = gy + (OUR_CY + 12)
    px = WIN[0] + WIN[2] + 6
    p, H = panel(px, WIN[1], enabled=True, auto=False, header=True, channels=CH, peers=[], options_btn=True)
    body = guide("polestar-guide-header-idle.png") + p
    # ANCHOR_BOTTOM, kept over the guide (not over the panel on the right).
    tip_w = 250
    panel_left = WIN[0] + WIN[2] + 6
    tip_x = min(gx + OUR_CX - tip_w / 2, panel_left - 8 - tip_w)
    body += tooltip(tip_x, icon_bottom + 4, "Group Finder",
                    [("Find a group for my quests (left click)", "#c3cadd"),
                     ("Show or hide the group finder (right click)", "#c3cadd")], tip_w)
    body += caption(
        "State 3 · header-icon tooltip (addon on, no search running): left click searches, right click opens or closes the panel.",
        H=H)
    return page(body, BANNER)


OPT_CSS = f"""
.set{{background:rgba({BG},.97);box-shadow:0 0 0 1px rgba(0,0,5,.5),inset 0 0 0 1px rgba(255,255,255,.10),0 10px 30px rgba(0,0,5,.6)}}
.side div{{height:28px;line-height:28px;padding-left:14px;font-size:12px;font-weight:500;color:{DIM}}}
.side div.sel{{background:rgba(230,186,102,.14);color:{TEXT};box-shadow:inset 2px 0 0 {ACCENT}}}
.card{{background:rgba(255,255,255,.04);box-shadow:inset 0 0 0 1px rgba(255,255,255,.08);border-radius:4px}}
.rowl{{position:absolute;left:14px;font-size:12px;font-weight:500;color:{TEXT}}}
.help{{position:absolute;left:14px;font-size:11px;color:{MUTED};right:60px}}
.sw{{position:absolute;width:34px;height:18px;border-radius:9px}}
.sw i{{position:absolute;top:2px;width:14px;height:14px;border-radius:7px;background:#fff}}
.key{{position:absolute;width:120px;height:22px;line-height:22px;text-align:center;font-size:11px;color:{DIM};background:{PANEL_ALT};box-shadow:inset 0 0 0 1px rgba(255,255,255,.10);border-radius:3px}}
.sec{{position:absolute;left:14px;font-size:11px;font-weight:600;color:{MUTED};letter-spacing:.3px}}
"""


def sw(x, y, on, dim=False):
    bg = ACCENT if on else "rgba(255,255,255,.18)"
    kx = 18 if on else 2
    op = "opacity:.45;" if dim else ""
    return f'<div class="sw" style="left:{x}px;top:{y}px;{op}background:{bg}"><i style="left:{kx}px"></i></div>'


def options_page(all_on=False):
    """Polestar options, one 'Search languages' section. all_on: the language list is folded and hidden."""
    L, T, W, Hh = 80, 28, 1120, 668
    side = ["Guide", "Quests", "Map", "Quality of Life", "Group Finder", "Appearance", "Profiles", "About"]
    h = [f'<div class="abs set" style="left:{L}px;top:{T}px;width:{W}px;height:{Hh}px">']
    h.append(f'<div class="t" style="left:16px;top:10px;font-size:15px;font-weight:600">Polestar Options</div>')
    h.append('<div class="abs side" style="left:0;top:42px;width:200px">' +
             "".join(f'<div class="{"sel" if s=="Group Finder" else ""}">{s}</div>' for s in side) + "</div>")
    cx, cw = 220, W - 240
    h.append(f'<div class="t" style="left:{cx}px;top:44px;font-size:15px;font-weight:600">Group Finder</div>')
    h.append(f'<div class="abs card" style="left:{cx}px;top:74px;width:{cw}px;height:268px">')
    h.append(f'<div class="sec" style="top:8px">GROUP FINDER</div>')
    rows = [
        ("Enable the group finder", "Master switch. Off: the addon sends nothing and does not answer anyone.", True),
        ("Group automatically (same quest)", "Invites and accepts on its own a player who shares a quest with you. Off: you choose in the list.", False),
        ("Button in the Polestar header", "Shows the eye icon to the left of the magnifying glass: left click searches, right click opens the panel.", True),
        ("Share my map position", None, True),
        ("Answer searches for my quests", None, True),
    ]
    y = 28
    for lab, hp, on in rows:
        h.append(f'<div class="rowl" style="top:{y}px">{e(lab)}</div>')
        if hp:
            h.append(f'<div class="help" style="top:{y+16}px">{e(hp)}</div>')
        h.append(sw(cw - 14 - 34, y, on))
        y += 44 if hp else 28
    h.append(f'<div class="rowl" style="top:{y+3}px">Find a group for my quests</div>'
             f'<div class="key" style="left:{cw-14-120}px;top:{y}px">Unbound</div>')
    y += 28
    h.append(f'<div class="rowl" style="top:{y+3}px">Show or hide the group finder</div>'
             f'<div class="key" style="left:{cw-14-120}px;top:{y}px">Unbound</div>')
    first_h = y + 28
    h.append("</div>")
    # Search languages: folded (only "All languages") or unfolded (one language per row).
    ly = 74 + first_h + 16
    y_langs = 28 + 40
    ch = (y_langs + 16) if all_on else (y_langs + math.ceil(len(LANGS) / 2) * 24 + 16)
    h.append(f'<div class="abs card" style="left:{cx}px;top:{ly}px;width:{cw}px;height:{ch}px">')
    h.append(f'<div class="sec" style="top:8px">SEARCH LANGUAGES</div>')
    y = 28
    h.append(f'<div class="rowl" style="top:{y}px">All languages</div>')
    h.append(f'<div class="help" style="top:{y+16}px;right:54px">When ticked, it folds the list and searches among everyone. Off by default.</div>')
    h.append(sw(cw - 14 - 34, y, all_on))
    if not all_on:
        y = y_langs
        col_w = cw // 2
        for i, (lab, on) in enumerate(LANGS):
            col, row = i % 2, i // 2
            yy = y + row * 24
            h.append(f'<div class="rowl" style="left:{14 + col * col_w}px;top:{yy}px">{lab}</div>')
            h.append(sw(col * col_w + col_w - 14 - 34, yy, on))
    h.append("</div></div>")
    body = "".join(h)
    if all_on:
        cap = ("State 5 · Polestar options, “All languages” ticked: the language list is folded and hidden "
               "(no more greying). The section shrinks, with no gap. The payload stays the client language (here EN).")
    else:
        cap = ("State 4 · Polestar options, list unfolded. In game: one language per row (the window scrolls if needed); "
               "here two columns to show them all. enUS client: only English is ticked. Tooltip on hover of every setting.")
    body += f'<div class="caption" style="left:{L}px;top:{T+Hh+4}px;width:1120px">{cap}</div>'
    return page(body, BANNER, OPT_CSS)


def s4():
    return options_page(all_on=False)


def s5():
    return options_page(all_on=True)


def lang_picker_height(all_on=False):
    rows = 1 if all_on else 1 + math.ceil(len(LANGS) / 2)
    return 24 + rows * 18 + 16


def lang_picker(panel_left, panel_top, all_on=False):
    """Language picker: folded when All is on; two columns when unfolded."""
    box_l = panel_left + 8
    box_t = panel_top + (34 + 5 * OPT_H + 22)
    box_w = PW - 16
    box_h = lang_picker_height(all_on)
    h = [f'<div class="abs" style="left:{box_l}px;top:{box_t}px;width:{box_w}px;height:{box_h}px;z-index:10;background:#181d2d;box-shadow:0 0 0 1px rgba(0,0,5,.42),inset 0 0 0 1px rgba(255,255,255,.10),0 8px 18px rgba(0,0,5,.55);overflow:hidden">']
    h.append(f'<div class="t" style="left:8px;top:8px;font-size:11px;font-weight:600;color:{MUTED}">Search languages</div>')
    h.append(pcheck(6, 24, "All languages", all_on))
    if not all_on:
        col_w = box_w // 2
        for i, (lab, on) in enumerate(LANGS):
            col, row = i % 2, i // 2
            h.append(pcheck(6 + col * col_w, 42 + row * 18, lab, on))
    h.append("</div>")
    return "".join(h)


def s7():
    px = WIN[0] + WIN[2] + 6
    p, H = panel(px, WIN[1], enabled=True, auto=False, header=True, channels=CH, peers=[], options_btn=True)
    body = guide("polestar-guide-header-idle.png") + p + lang_picker(px, WIN[1], all_on=False)
    body += caption(
        "State 7 · panel “Search languages” picker, list unfolded in two columns (enUS client). "
        "English is ticked; “All languages” is off by default.",
        y=WIN[1] + 34 + 5 * OPT_H + 22 + lang_picker_height(False) + 16)
    return page(body, BANNER)


def s8():
    px = WIN[0] + WIN[2] + 6
    p, H = panel(px, WIN[1], enabled=True, auto=False, header=True, channels=CH, peers=[], options_btn=True,
                 lang_summary="All")
    body = guide("polestar-guide-header-idle.png") + p + lang_picker(px, WIN[1], all_on=True)
    body += caption(
        "State 8 · the same picker, “All languages” ticked: the language list is folded and hidden "
        "(the frame shrinks, with no gap). Every player appears, including a v0.2 peer with no language.",
        y=WIN[1] + 34 + 5 * OPT_H + 22 + lang_picker_height(True) + 16)
    return page(body, BANNER)


def s6():
    px = WIN[0] + WIN[2] + 6
    p, H = panel(px, WIN[1], enabled=True, auto=False, header=False, channels=CH, peers=[], options_btn=True)
    body = guide_window(WIN[0] - 6, WIN[1] - 6) + launcher() + p
    body += caption(
        "State 6 · “Button in the Polestar header” unticked: the icon leaves the bar (Skip / Nearby / AllSteps take their place back to the left of the magnifying glass) "
        "and the “Find a group” button reappears under the window (also the fallback if the header hook fails).",
        H=H)
    return page(body, BANNER)


if __name__ == "__main__":
    bake_guide("polestar-guide-header-off.png", MUTED_RGBA)
    bake_guide("polestar-guide-header-idle.png", ICON)
    bake_guide("polestar-guide-header-active.png", ACCENT_RGBA)
    for n, f in (
        ("01-state1-header-button-disabled", s1),
        ("02-state2-header-button-search-active", s2),
        ("03-state3-header-button-tooltip", s3),
        ("04-state4-polestar-options-languages", s4),
        ("05-state5-options-all-languages", s5),
        ("06-state6-button-under-the-window", s6),
        ("07-state7-language-picker", s7),
        ("08-state8-language-picker-all", s8),
    ):
        path = render(n, f(), OUT)
        print(path)
