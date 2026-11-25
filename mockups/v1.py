"""v1.0.0 mock-ups: header icon left of Lookup, grouping languages (default = client locale)."""
import os
from PIL import Image, ImageDraw
from common import *

OUT = os.path.join(HERE, "v1")
os.makedirs(OUT, exist_ok=True)
ASSETS = os.path.join(HERE, "assets")
SRC_GUIDE = os.path.join(ASSETS, "polestar-guide-window.png")

PW, PAD, ROW_H, OPT_H, BTN_COL = 340, 12, 42, 20, 84
MUTED, DIM, GREEN, AMBER = TEXT_MUTED, TEXT_DIM, SUCCESS, WARNING
BANNER = ("MAQUETTE — données d'exemple",
          "PSGroupFinder v1.0.0 · dessinée d'après UI.lua / Polestar.lua / Lang.lua, pas une capture du jeu")

KIND = {"k": "kill", "n": "élite nommé", "l": "loot", "g": "groupe"}
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


def bake_guide(name, fill):
    """Shift Skip / Nearby / AllSteps 24 CSS px left and draw our 24px two-person glyph."""
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

    # Two-person glyph (same geometry as Polestar.lua makeGlyph), centered on our button.
    cx, cy = P(OUR_CX), P(OUR_CY)
    overlay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)

    def rect(w, h, x, y):
        pw, ph = w * scale, h * scale
        px = cx + x * scale - pw / 2
        py = cy - y * scale - ph / 2  # WoW y is up; CSS/PIL y is down — makeGlyph y is offset in WoW (up)
        # In WoW SetPoint CENTER, x, y: y is upward. In the image, up is negative screen y.
        # makeGlyph: heads at y=+3.5 (up), bodies at y=-2 (down). PIL: subtract y.
        d.rectangle([px, py, px + pw - 1, py + ph - 1], fill=fill)

    rect(4, 4, -3.5, 3.5)
    rect(5, 6, -3.5, -2)
    rect(4, 4, 3.5, 3.5)
    rect(5, 6, 3.5, -2)
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
            f'{pbtn(PW-2*PAD-BTN_COL, 1, BTN_COL, "Chuchoter", h=19, size=11)}'
            f'{pbtn(PW-2*PAD-BTN_COL, ROW_H-20, BTN_COL, "Inviter", h=19, size=11)}</div>')


def panel(left, top, enabled=True, auto=True, header=True, active=False, quests=(),
          search_label="Chercher un groupe", search_off=False, channels=None, peers=(),
          options_btn=True, lang_summary="FR", extra=""):
    """Mirrors UI.Refresh() v1: 5 switches + language row, then buttons."""
    y = 34 + 5 * OPT_H + 22 + 8
    body = []
    body.append(f'<div class="t" style="left:{PAD}px;top:10px;font-size:15px;font-weight:600;color:{TEXT}">Recherche de groupe</div>')
    body.append(close_btn())
    checks = [
        ("Activer la recherche de groupe", enabled, True),
        ("Grouper automatiquement (même quête)", auto, enabled),
        ("Bouton dans l'en-tête de Polestar", header, True),
        ("Partager ma position sur la carte", True, enabled),
        ("Répondre aux recherches sur mes quêtes", True, enabled),
    ]
    for i, (lab, on, dis) in enumerate(checks):
        body.append(pcheck(PAD, 34 + i * OPT_H, lab, on and True, dis))
    ly = 34 + 5 * OPT_H + 2
    body.append(f'<div class="t" style="left:{PAD}px;top:{ly}px;font-size:11px;font-weight:500;color:{TEXT}">Langues de recherche</div>')
    body.append(f'<div class="t" style="left:{PAD+128}px;top:{ly}px;font-size:11px;font-weight:500;color:{MUTED}">{e(lang_summary)}</div>')
    body.append(pbtn(PAD, y, 168, search_label, search_off or not enabled))
    if active:
        body.append(pbtn(PAD + 168 + 6, y, 70, "Arrêter"))
    if options_btn:
        body.append(pbtn(PW - PAD - 64, y, 64, "Options"))
    y += 22 + 10
    if enabled:
        body.append(f'<div class="t" style="left:{PAD}px;top:{y}px;font-size:11px;font-weight:600;color:{MUTED}">Recherche en cours</div>')
        y += 14
        if active:
            for t, k in quests[:4]:
                body.append(f'<div class="t ell" style="left:{PAD+4}px;top:{y}px;width:{PW-2*PAD-4}px;font-size:11px;font-weight:500;color:{DIM}">{e(tag(k))}<span style="color:{TEXT}">{e(t)}</span></div>')
                y += 14
        else:
            body.append(f'<div class="t" style="left:{PAD+4}px;top:{y}px;font-size:11px;font-weight:500;color:{MUTED}">Aucune recherche en cours.</div>')
            y += 14
        y += 6
        body.append(f'<div class="t" style="left:{PAD}px;top:{y+4}px;font-size:11px;font-weight:500;color:{MUTED}">Canaux</div>')
        if channels:
            body.append(f'<div class="t" style="left:{PAD+46}px;top:{y+4}px;font-size:11px;font-weight:500">{channel_names(channels)}</div>')
        body.append(pbtn(PW - PAD - 56, y, 56, "Tester", off=not enabled, h=20, size=11))
        y += 22 + 6
        if not peers:
            body.append(f'<div class="t" style="left:{PAD+2}px;top:{y+2}px;width:{PW-2*PAD-4}px;white-space:normal;font-size:11px;font-weight:500;color:{MUTED}">Personne pour l\'instant. Cliquez sur Chercher un groupe.</div>')
            y += 38
        for p in peers[:6]:
            body.append(row(y, p))
            y += ROW_H
    H = y + PAD - 2
    return (f'<div class="abs pwin" style="left:{left}px;top:{top}px;width:{PW}px;height:{H}px">'
            + "".join(body) + extra + "</div>"), H


def launcher(dim=False, label="Chercher un groupe", wx=None):
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
         where="22 m", state="invité", scol=GREEN, rw=30),
    dict(name="Torvald Greaves", cls="WARRIOR", lvl=9, lang="FR",
         q=[("Kobold Camp Cleanup", "k")], where="48 m", state="en attente", scol=AMBER, rw=52),
    dict(name="Edric Vane", cls="ROGUE", lvl=9, lang="FR",
         q=[("Kobold Camp Cleanup", "k")], where="même zone", rw=52),
    dict(name="Mira Quillon", cls="PRIEST", lvl=7, lang="FR",
         q=[("Wolves Across the Border", "l")], where="déjà en groupe", rw=74),
]
CH = [("CHANNEL", "fail"), ("YELL", "ok"), ("SAY", "sent"), ("GUILD", "skip")]

LANGS = [
    ("Français", True),
    ("English", False),
    ("Deutsch", False),
    ("Español", False),
    ("Italiano", False),
    ("Português", False),
    ("Русский", False),
    ("한국어", False),
    ("简体中文", False),
    ("繁體中文", False),
]


def s1():
    px = WIN[0] + WIN[2] + 6
    p, H = panel(px, WIN[1], enabled=False, auto=False, header=True, channels=None, options_btn=True)
    body = guide("polestar-guide-header-off.png") + p
    body += caption(
        "État 1 · addon désactivé : l'icône (deux silhouettes) est dans l'en-tête, juste à gauche de la loupe, "
        "grisée (textMuted). Le bouton sous la fenêtre est masqué. Clic droit sur l'icône ouvre le panneau.",
        H=H)
    return page(body, BANNER)


def s2():
    px = WIN[0] + WIN[2] + 6
    p, H = panel(px, WIN[1], active=True, quests=QUESTS3, search_label="Relancer la recherche",
                 channels=CH, peers=P4)
    body = guide("polestar-guide-header-active.png") + p
    body += caption(
        "État 2 · recherche active : l'icône d'en-tête est colorée (accent). Les joueurs listés portent leur langue (FR). "
        "Par défaut seule la langue du jeu (ici Français) est cochée dans Langues de recherche ; « Toutes les langues » n'est pas cochée.",
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
    body += tooltip(tip_x, icon_bottom + 4, "Recherche de groupe",
                    [("Chercher un groupe pour mes quêtes (clic gauche)", "#c3cadd"),
                     ("Afficher ou masquer la recherche de groupe (clic droit)", "#c3cadd")], tip_w)
    body += caption(
        "État 3 · infobulle de l'icône d'en-tête (addon activé, pas de recherche en cours) : clic gauche cherche, clic droit ouvre ou ferme le panneau.",
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
    """Polestar options, one 'Search languages' section. all_on: Toutes greys the other switches."""
    L, T, W, Hh = 80, 28, 1120, 668
    side = ["Guide", "Quêtes", "Carte", "Qualité de vie", "Recherche de groupe", "Apparence", "Profils", "À propos"]
    h = [f'<div class="abs set" style="left:{L}px;top:{T}px;width:{W}px;height:{Hh}px">']
    h.append(f'<div class="t" style="left:16px;top:10px;font-size:15px;font-weight:600">Options de Polestar</div>')
    h.append('<div class="abs side" style="left:0;top:42px;width:200px">' +
             "".join(f'<div class="{"sel" if s=="Recherche de groupe" else ""}">{s}</div>' for s in side) + "</div>")
    cx, cw = 220, W - 240
    h.append(f'<div class="t" style="left:{cx}px;top:44px;font-size:15px;font-weight:600">Recherche de groupe</div>')
    h.append(f'<div class="abs card" style="left:{cx}px;top:74px;width:{cw}px;height:268px">')
    h.append(f'<div class="sec" style="top:8px">RECHERCHE DE GROUPE</div>')
    rows = [
        ("Activer la recherche de groupe", "Rejoint le canal caché, répond aux recherches sur vos quêtes communes. Désactivé : rien n'est envoyé.", True),
        ("Grouper automatiquement (même quête)", "Invite ou accepte sans clic après votre recherche. L'autre joueur doit l'avoir aussi.", False),
        ("Bouton dans l'en-tête de Polestar", "Place une petite icône juste à gauche de la loupe : clic gauche pour chercher, clic droit pour le panneau. Désactivé : le bouton reste sous la fenêtre de guide.", True),
        ("Partager ma position sur la carte", None, True),
        ("Répondre aux recherches sur mes quêtes", None, True),
    ]
    y = 28
    for lab, hp, on in rows:
        h.append(f'<div class="rowl" style="top:{y}px">{e(lab)}</div>')
        if hp:
            h.append(f'<div class="help" style="top:{y+16}px">{e(hp)}</div>')
        h.append(sw(cw - 14 - 34, y, on))
        y += 44 if hp else 28
    h.append(f'<div class="rowl" style="top:{y+3}px">Chercher un groupe pour mes quêtes</div>'
             f'<div class="key" style="left:{cw-14-120}px;top:{y}px">Non assigné</div>')
    y += 28
    h.append(f'<div class="rowl" style="top:{y+3}px">Afficher ou masquer la recherche de groupe</div>'
             f'<div class="key" style="left:{cw-14-120}px;top:{y}px">Non assigné</div>')
    h.append("</div>")
    # One section: search languages (Toutes first, then each language).
    ly, ch = 354, 300
    h.append(f'<div class="abs card" style="left:{cx}px;top:{ly}px;width:{cw}px;height:{ch}px">')
    h.append(f'<div class="sec" style="top:8px">LANGUES DE RECHERCHE</div>')
    y = 28
    h.append(f'<div class="rowl" style="top:{y}px">Toutes les langues</div>')
    h.append(f'<div class="help" style="top:{y+16}px;right:54px">Cochée, elle grise les autres cases et affiche tous les joueurs. Décochée par défaut.</div>')
    h.append(sw(cw - 14 - 34, y, all_on))
    y += 40
    for lab, on in LANGS:
        dim = all_on
        # Saved tick (Français) stays visible but greyed when Toutes is on.
        h.append(f'<div class="rowl" style="top:{y}px;{"opacity:.45" if dim else ""}">{lab}</div>')
        h.append(sw(cw - 14 - 34, y, on, dim=dim))
        y += 24
    h.append("</div></div>")
    body = "".join(h)
    if all_on:
        cap = ("État 5 · options Polestar, « Toutes les langues » cochée : les autres langues sont grisées "
               "(et désactivées). Le payload reste la langue du client (ici FR). APPROXIMATION visuelle.")
    else:
        cap = ("État 4 · options Polestar (approximation). Client frFR : seule Français est cochée dans "
               "Langues de recherche ; « Toutes les langues » est décochée. Bouton d'en-tête activé par défaut.")
    body += f'<div class="caption" style="left:{L}px;top:{T+Hh+4}px;width:1120px">{cap}</div>'
    return page(body, BANNER, OPT_CSS)


def s4():
    return options_page(all_on=False)


def s5():
    return options_page(all_on=True)


def lang_picker(panel_left, panel_top, all_on=False):
    """Single-column picker, matching UI.ToggleLangPicker geometry."""
    box_l = panel_left + 8
    box_t = panel_top + (34 + 5 * OPT_H + 22)
    box_w = PW - 16
    box_h = 24 + 11 * 18 + 16
    h = [f'<div class="abs" style="left:{box_l}px;top:{box_t}px;width:{box_w}px;height:{box_h}px;z-index:10;background:#181d2d;box-shadow:0 0 0 1px rgba(0,0,5,.42),inset 0 0 0 1px rgba(255,255,255,.10),0 8px 18px rgba(0,0,5,.55);overflow:hidden">']
    h.append(f'<div class="t" style="left:8px;top:8px;font-size:11px;font-weight:600;color:{MUTED}">Langues de recherche</div>')
    h.append(pcheck(6, 24, "Toutes les langues", all_on))
    for i, (lab, on) in enumerate(LANGS):
        h.append(pcheck(6, 42 + i * 18, lab, on, enabled=not all_on))
    h.append("</div>")
    return "".join(h)


def s7():
    px = WIN[0] + WIN[2] + 6
    p, H = panel(px, WIN[1], enabled=True, auto=False, header=True, channels=CH, peers=[], options_btn=True)
    body = guide("polestar-guide-header-idle.png") + p + lang_picker(px, WIN[1], all_on=False)
    body += caption(
        "État 7 · sélecteur « Langues de recherche » du panneau (client frFR). Français est coché ; "
        "« Toutes les langues » est décochée par défaut.",
        y=WIN[1] + 34 + 5 * OPT_H + 22 + (24 + 11 * 18 + 16) + 16)
    return page(body, BANNER)


def s8():
    px = WIN[0] + WIN[2] + 6
    p, H = panel(px, WIN[1], enabled=True, auto=False, header=True, channels=CH, peers=[], options_btn=True,
                 lang_summary="Toutes")
    body = guide("polestar-guide-header-idle.png") + p + lang_picker(px, WIN[1], all_on=True)
    body += caption(
        "État 8 · même sélecteur, « Toutes les langues » cochée : les autres cases sont grisées et désactivées. "
        "Tous les joueurs apparaissent, y compris un peer v0.2 sans langue.",
        y=WIN[1] + 34 + 5 * OPT_H + 22 + (24 + 11 * 18 + 16) + 16)
    return page(body, BANNER)


def s6():
    px = WIN[0] + WIN[2] + 6
    p, H = panel(px, WIN[1], enabled=True, auto=False, header=False, channels=CH, peers=[], options_btn=True)
    body = guide_window(WIN[0] - 6, WIN[1] - 6) + launcher() + p
    body += caption(
        "État 6 · option « Bouton dans l'en-tête » décochée : l'icône quitte la barre (Skip / Nearby / AllSteps reprennent leur place à gauche de la loupe) "
        "et le bouton « Chercher un groupe » réapparaît sous la fenêtre (repli si l'accroche d'en-tête échoue aussi).",
        H=H)
    return page(body, BANNER)


if __name__ == "__main__":
    bake_guide("polestar-guide-header-off.png", MUTED_RGBA)
    bake_guide("polestar-guide-header-idle.png", ICON)
    bake_guide("polestar-guide-header-active.png", ACCENT_RGBA)
    for n, f in (
        ("01-etat1-bouton-entete-desactive", s1),
        ("02-etat2-bouton-entete-recherche-active", s2),
        ("03-etat3-infobulle-bouton-entete", s3),
        ("04-etat4-options-polestar-langues", s4),
        ("05-etat5-options-toutes-langues", s5),
        ("06-etat6-bouton-sous-la-fenetre", s6),
        ("07-etat7-selecteur-langues", s7),
        ("08-etat8-selecteur-toutes-langues", s8),
    ):
        path = render(n, f(), OUT)
        print(path)
