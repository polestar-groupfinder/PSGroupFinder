"""v0.2.0 mock-ups, laid out from the v0.2 UI.lua / Polestar.lua / Locales.lua (working tree)."""
import html, os
from common import *

OUT = os.path.join(HERE, "v0.2")
os.makedirs(OUT, exist_ok=True)
PW, PAD, ROW_H, OPT_H, BTN_COL = 340, 12, 42, 20, 84
MUTED, DIM, GREEN, AMBER = TEXT_MUTED, TEXT_DIM, SUCCESS, WARNING
BANNER = ("MAQUETTE — données d'exemple", "Polestar_GroupFinder v0.2.0 · dessinée d'après UI.lua / Polestar.lua, pas une capture du jeu")

KIND = {"k": "kill", "n": "élite nommé", "l": "loot", "g": "groupe"}

def e(s): return html.escape(s)

def pbtn(x, y, w, label, off=False, h=22, size=12, weight=500):
    return (f'<div class="abs pbtn{" off" if off else ""}" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px;'
            f'line-height:{h}px;font-size:{size}px;font-weight:{weight}">{e(label)}</div>')

def pcheck(x, y, label, checked, enabled=True):
    # Theme.Skin(frame, "checkbox"): approximation of Polestar's box (18x18).
    op = 1 if enabled else .5
    edge = ACCENT if checked else "rgba(255,255,255,.28)"
    tick = (f'<svg viewBox="0 0 18 18" width="18" height="18" style="position:absolute;left:0;top:0"><path d="M4.5 9.5l3.2 3.3L13.5 5.5" '
            f'fill="none" stroke="{ACCENT}" stroke-width="2"/></svg>') if checked else ""
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

def tag(kind): return f'({KIND[kind]}) ' if kind else ''

def row(y, p):
    cc = CLASS[p["cls"]]
    right, rcol = p.get("state") or p["where"], p.get("scol", MUTED)
    rw = p.get("rw", 52)
    name_w = (PW - 2*PAD) - (BTN_COL + 8) - rw - 6
    first = p["q"][0]
    more = f'&nbsp;&nbsp;<span style="color:{MUTED}">+{len(p["q"])-1}</span>' if len(p["q"]) > 1 else ""
    return (f'<div class="abs" style="left:{PAD}px;top:{y}px;width:{PW-2*PAD}px;height:{ROW_H}px">'
            f'<div class="t ell" style="left:0;top:2px;width:{name_w}px;font-size:13px;font-weight:500">'
            f'<span style="color:{cc}">{e(p["name"])}</span>&nbsp;&nbsp;<span style="color:{MUTED}">{p["lvl"]}</span></div>'
            f'<div class="t" style="right:{BTN_COL+8}px;top:4px;font-size:11px;font-weight:500;color:{rcol};text-align:right">{e(right)}</div>'
            f'<div class="t ell" style="left:0;top:21px;width:{PW-2*PAD-BTN_COL-8}px;font-size:11px;font-weight:500;color:{DIM}">'
            f'{e(tag(first[1]))}<span style="color:{TEXT}">{e(first[0])}</span>{more}</div>'
            f'{pbtn(PW-2*PAD-BTN_COL, 1, BTN_COL, "Chuchoter", h=19, size=11)}{pbtn(PW-2*PAD-BTN_COL, ROW_H-20, BTN_COL, "Inviter", h=19, size=11)}</div>')

def panel(left, top, enabled=True, auto=True, active=False, quests=(), search_label="Chercher un groupe", search_off=False,
          channels=None, peers=(), options_btn=True, standalone=False, extra=""):
    """Mirrors UI.Refresh()'s layout, y in WoW units from the panel's top."""
    h = []
    y = 34 + 4 * OPT_H + 8
    body = []
    body.append(f'<div class="t" style="left:{PAD}px;top:10px;font-size:15px;font-weight:600;color:{TEXT}">Recherche de groupe</div>')
    body.append(close_btn())
    for i, (lab, on, dis) in enumerate([("Activer la recherche de groupe", enabled, True),
                                        ("Grouper automatiquement (même quête)", auto, enabled),
                                        ("Partager ma position sur la carte", True, enabled),
                                        ("Répondre aux recherches sur mes quêtes", True, enabled)]):
        body.append(pcheck(PAD, 34 + i * OPT_H, lab, on and True, dis))
    body.append(pbtn(PAD, y, 168, search_label, search_off or not enabled))
    if active: body.append(pbtn(PAD + 168 + 6, y, 70, "Arrêter"))
    if options_btn: body.append(pbtn(PW - PAD - 64, y, 64, "Options"))
    y += 22 + 10
    if enabled:
        body.append(f'<div class="t" style="left:{PAD}px;top:{y}px;font-size:11px;font-weight:600;color:{MUTED}">Recherche en cours</div>')
        y += 14
        if active:
            for i, (t, k) in enumerate(quests[:4]):
                body.append(f'<div class="t ell" style="left:{PAD+4}px;top:{y}px;width:{PW-2*PAD-4}px;font-size:11px;font-weight:500;color:{DIM}">{e(tag(k))}<span style="color:{TEXT}">{e(t)}</span></div>')
                y += 14
        else:
            body.append(f'<div class="t" style="left:{PAD+4}px;top:{y}px;font-size:11px;font-weight:500;color:{MUTED}">Aucune recherche en cours.</div>')
            y += 14
        y += 6
        body.append(f'<div class="t" style="left:{PAD}px;top:{y+4}px;font-size:11px;font-weight:500;color:{MUTED}">Canaux</div>')
        if enabled and channels:
            body.append(f'<div class="t" style="left:{PAD+46}px;top:{y+4}px;font-size:11px;font-weight:500">{channel_names(channels)}</div>')
        body.append(pbtn(PW - PAD - 56, y, 56, "Tester", off=not enabled, h=20, size=11))
        y += 22 + 6
        if enabled and not peers:
            body.append(f'<div class="t" style="left:{PAD+2}px;top:{y+2}px;width:{PW-2*PAD-4}px;white-space:normal;font-size:11px;font-weight:500;color:{MUTED}">Personne pour l\'instant. Cliquez sur Chercher un groupe.</div>')
            y += 38

    if enabled:
        for p in peers[:6]:
            body.append(row(y, p)); y += ROW_H
    H = y + PAD - 2
    cls = "pwin" if not standalone else "sa"
    return (f'<div class="abs {cls}" style="left:{left}px;top:{top}px;width:{PW}px;height:{H}px">' + "".join(body) + extra + '</div>'), H

def launcher(dim=False, label="Chercher un groupe", wx=None):
    x = (WIN[0] if wx is None else wx) + WIN[2] - 132
    y = WIN[1] + WIN[3] + 2
    b = pbtn(x, y, 132, label, h=20, size=11, weight=600)
    return b.replace('class="abs pbtn"', f'class="abs pbtn" data-x="1"').replace('style="', f'style="opacity:{0.55 if dim else 1};', 1)

def caption(text, y=None, H=0):
    return f'<div class="caption" style="left:{WIN[0]}px;top:{y or max(WIN[1]+WIN[3]+32, WIN[1]+H+16)}px;width:1100px">{e(text)}</div>'

def chat(lines, left=20, top=520):
    h = f'<div class="abs" style="left:{left}px;top:{top}px;width:560px;padding:8px 10px;background:rgba(0,0,0,.45);border:1px solid rgba(255,255,255,.12);border-radius:3px;font-size:12px;line-height:17px;font-weight:500">'
    for l in lines:
        h += f'<div><span style="color:#ffd100">Polestar GF</span> <span style="color:#fff">{e(l)}</span></div>'
    return h + '</div>'

QUESTS3 = [("Kobold Camp Cleanup", "k"), ("Wolves Across the Border", "l"), ("Wanted: Hogger", "n")]
P4 = [
    dict(name="Lyra Ashdown", cls="MAGE", lvl=8, q=[("Kobold Camp Cleanup", "k"), ("Wolves Across the Border", "l")], where="22 m", state="invité", scol=GREEN, rw=30),
    dict(name="Torvald Greaves", cls="WARRIOR", lvl=9, q=[("Kobold Camp Cleanup", "k")], where="48 m", state="en attente", scol=AMBER, rw=52),
    dict(name="Edric Vane", cls="ROGUE", lvl=9, q=[("Kobold Camp Cleanup", "k")], where="même zone", rw=52),
    dict(name="Mira Quillon", cls="PRIEST", lvl=7, q=[("Wolves Across the Border", "l")], where="déjà en groupe", rw=74),
]
CH = [("CHANNEL", "fail"), ("YELL", "ok"), ("SAY", "sent"), ("GUILD", "skip")]

def base(wx=None):
    return guide_window((WIN[0] if wx is None else wx) - 6, WIN[1] - 6)

def s1():
    px = WIN[0] + WIN[2] + 6
    p, H = panel(px, WIN[1], enabled=False, auto=False, channels=None, options_btn=True)
    body = base() + launcher(dim=True) + p
    body += caption("État 1 · addon désactivé : bouton grisé sous la fenêtre (un clic ouvre seulement le panneau) et panneau réduit à ses 4 cases (hauteur dynamique, %d au lieu de 434)." % H, H=H)
    return page(body, BANNER)

def s2():
    px = WIN[0] + WIN[2] + 6
    p, H = panel(px, WIN[1], active=True, quests=QUESTS3, search_label="Relancer la recherche", search_off=False, channels=CH, peers=P4)
    body = base() + launcher() + p
    body += caption("État 2 · recherche active sur 3 quêtes, 4 joueurs : Lyra invitée automatiquement, Torvald en attente de son invitation (hauteur %d)." % H, H=H)
    return page(body, BANNER)

def s3():
    px = WIN[0] + WIN[2] + 6
    p, H = panel(px, WIN[1], active=True, quests=QUESTS3[1:], search_label="Chercher un groupe (14)", search_off=True, channels=CH,
                 peers=[P4[0].__class__(P4[0], q=[P4[0]["q"][1]], state=None, where="22 m", rw=30), P4[3]])
    body = base() + launcher() + p
    body += chat(["Objectif terminé, retiré de la recherche : Kobold Camp Cleanup.", "Recherche mise à jour : 2 quête(s) restante(s)."], left=WIN[0], top=WIN[1] + WIN[3] + 52)
    body += caption("État 3 · « Kobold Camp Cleanup » terminée : elle sort de la recherche et de la liste (Torvald, Edric partent), la recherche continue sur les 2 autres.", H=H)
    return page(body, BANNER)

def s3b():
    px = WIN[0] + WIN[2] + 6
    p, H = panel(px, WIN[1], active=False, search_label="Chercher un groupe", channels=CH, peers=[])
    body = base() + launcher() + p
    body += chat(["Objectif terminé, retiré de la recherche : Wolves Across the Border.", "Tous les objectifs sont terminés : recherche arrêtée."], left=WIN[0], top=WIN[1] + WIN[3] + 52)
    body += caption("État 4 · dernière quête terminée : la recherche s'arrête (message X aux autres), panneau vide et compact (hauteur %d)." % H, H=H)
    return page(body, BANNER)

def s4():
    px = WIN[0] + WIN[2] + 6
    p, H = panel(px, WIN[1], active=False, search_label="Chercher un groupe (14)", search_off=True,
                 channels=[("CHANNEL", "fail"), ("YELL", "sent"), ("SAY", "?"), ("GUILD", "skip")], peers=[])
    body = base() + launcher() + p
    body += caption("État 5 · aucune recherche en cours, aucun joueur, cooldown de 20 s sur le bouton (hauteur %d)." % H, H=H)
    return page(body, BANNER)

def tooltip(x, y, title, lines, w=250):
    t = "".join(f'<div style="font-size:11px;color:{c};line-height:14px;margin-top:3px">{e(l)}</div>' for l, c in lines)
    return (f'<div class="abs" style="left:{x}px;top:{y}px;width:{w}px;padding:8px 10px;background:rgba(16,16,28,.96);border:1px solid #8a8a96;'
            f'border-radius:3px;box-shadow:0 0 0 1px #000"><div style="font-size:12px;font-weight:600;color:#fff">{e(title)}</div>{t}</div>')

def s5():
    px = WIN[0] + WIN[2] + 6
    p, H = panel(px, WIN[1], active=True, quests=QUESTS3, search_label="Relancer la recherche", search_off=False, channels=CH, peers=P4)
    # Tooltip above the second switch, as UI.lua's tip() does (ANCHOR_TOP): the label stays readable.
    body = base() + launcher() + p
    body += tooltip(px + 6, WIN[1] + 54 - 4 - 104, "Grouper automatiquement (même quête)",
        [("Après le lancement d'une recherche, invite les joueurs qui partagent votre quête (ou accepte leur invitation) sans clic. Il faut que l'autre joueur l'ait aussi activé. Désactivé : vous invitez à la main.", "#ffd100")], 300)
    body += caption("État 6 · infobulle de « Grouper automatiquement » : elle s'ouvre au-dessus de la case, le libellé reste lisible (en v0.1 elle le recouvrait).", H=H)
    return page(body, BANNER)

def s6():
    wx = 900 - WIN[2]            # guide window near the right screen edge: not enough room on the right
    p, H = panel(wx - 6 - PW, WIN[1], active=True, quests=QUESTS3, search_label="Relancer la recherche", search_off=False, channels=CH, peers=P4[:3])
    body = base(wx) + launcher(wx=wx) + p
    body += f'<div class="caption" style="left:{wx-6-PW}px;top:{WIN[1]+H+16}px;width:1000px">État 7 · fenêtre de guide près du bord droit de l\'écran : le panneau se place à gauche (TOPRIGHT → TOPLEFT, −6, 0) au lieu d\'être poussé sur la fenêtre.</div>'
    return page(body, BANNER)

# --- Polestar settings window, our page (approximation of the settings window's look)
OPT_CSS = f"""
.set{{background:rgba({BG},.97);box-shadow:0 0 0 1px rgba(0,0,5,.5),inset 0 0 0 1px rgba(255,255,255,.10),0 10px 30px rgba(0,0,5,.6)}}
.side div{{height:30px;line-height:30px;padding-left:14px;font-size:12px;font-weight:500;color:{DIM}}}
.side div.sel{{background:rgba(230,186,102,.14);color:{TEXT};box-shadow:inset 2px 0 0 {ACCENT}}}
.card{{background:rgba(255,255,255,.04);box-shadow:inset 0 0 0 1px rgba(255,255,255,.08);border-radius:4px}}
.rowl{{position:absolute;left:14px;font-size:12px;font-weight:500;color:{TEXT}}}
.help{{position:absolute;left:14px;font-size:11px;color:{MUTED}}}
.sw{{position:absolute;width:34px;height:18px;border-radius:9px}}
.sw i{{position:absolute;top:2px;width:14px;height:14px;border-radius:7px;background:#fff}}
.key{{position:absolute;width:120px;height:22px;line-height:22px;text-align:center;font-size:11px;color:{DIM};background:{PANEL_ALT};box-shadow:inset 0 0 0 1px rgba(255,255,255,.10);border-radius:3px}}
"""

def sw(x, y, on):
    bg = ACCENT if on else "rgba(255,255,255,.18)"
    kx = 18 if on else 2
    return f'<div class="sw" style="left:{x}px;top:{y}px;background:{bg}"><i style="left:{kx}px"></i></div>'

def s7():
    L, T, W, Hh = 190, 70, 900, 560
    side = ["Guide", "Quêtes", "Carte", "Qualité de vie", "Recherche de groupe", "Apparence", "Profils", "À propos"]
    h = [f'<div class="abs set" style="left:{L}px;top:{T}px;width:{W}px;height:{Hh}px">']
    h.append(f'<div class="t" style="left:16px;top:12px;font-size:15px;font-weight:600">Options de Polestar</div>')
    h.append('<div class="abs side" style="left:0;top:50px;width:190px">' + "".join(f'<div class="{"sel" if s=="Recherche de groupe" else ""}">{s}</div>' for s in side) + '</div>')
    cx, cw = 210, W - 230
    h.append(f'<div class="t" style="left:{cx}px;top:54px;font-size:15px;font-weight:600">Recherche de groupe</div>')
    h.append(f'<div class="abs card" style="left:{cx}px;top:90px;width:{cw}px;height:300px">')
    h.append(f'<div class="t" style="left:14px;top:10px;font-size:12px;font-weight:600;color:{MUTED}">RECHERCHE DE GROUPE</div>')
    rows = [("Activer la recherche de groupe", "Rejoint le canal caché, répond aux recherches sur vos quêtes communes. Désactivé : rien n'est envoyé.", True),
            ("Grouper automatiquement (même quête)", "Invite ou accepte sans clic après votre recherche. L'autre joueur doit l'avoir aussi.", False),
            ("Partager ma position sur la carte", None, True),
            ("Répondre aux recherches sur mes quêtes", None, True)]
    y = 38
    for lab, hp, on in rows:
        h.append(f'<div class="rowl" style="top:{y}px">{e(lab)}</div>')
        if hp: h.append(f'<div class="help" style="top:{y+17}px">{e(hp)}</div>')
        h.append(sw(cw - 14 - 34, y, on))
        y += 46 if hp else 30
    h.append(f'<div class="rowl" style="top:{y+4}px">Chercher un groupe pour mes quêtes</div><div class="key" style="left:{cw-14-120}px;top:{y}px">Non assigné</div>'); y += 32
    h.append(f'<div class="rowl" style="top:{y+4}px">Afficher ou masquer la recherche de groupe</div><div class="key" style="left:{cw-14-120}px;top:{y}px">Non assigné</div>'); y += 32
    h.append(pbtn(14, y + 2, 130, "Tester les canaux") + pbtn(152, y + 2, 230, "Ouvrir le panneau de recherche de groupe"))
    h.append('</div></div>')
    body = "".join(h)
    body += f'<div class="caption" style="left:{L}px;top:{T+Hh+10}px;width:1000px">État 8 · page « Recherche de groupe » des options de Polestar (Polestar.RegisterOptions). APPROXIMATION : le style exact des lignes, cartes et interrupteurs de Polestar n\'est pas reproduit.</div>'
    return page(body, BANNER, OPT_CSS)

SA_CSS = """
.sa{background:rgba(13,13,20,.92);box-shadow:0 0 0 1px #8b8b96,inset 0 0 0 2px #3b3b46,0 8px 24px rgba(0,0,0,.6);border-radius:6px}
.sa *{font-family:'Alegreya Sans','Inter',sans-serif}
"""

def s8():
    # Standalone: same geometry, the game's own look (UICheckButtonTemplate 22x22, UIPanelButtonTemplate, backdrop) approximated.
    p, H = panel(640 + 200, 120, active=True, quests=QUESTS3[:2], search_label="Relancer la recherche", search_off=False, channels=CH, peers=P4[:3], options_btn=False, standalone=True)
    p = p.replace(f'style="left:{ACCENT}', 'style="left:').replace('class="abs pbtn', 'class="abs wb').replace('pbtn off', 'wb off')
    css = SA_CSS + ".wb{background:linear-gradient(#7a1b12,#4a0d08);box-shadow:inset 0 0 0 1px #c9a23a,0 0 0 1px #000;color:#ffd100;text-align:center;border-radius:3px;white-space:nowrap}.wb.off{background:linear-gradient(#444,#2a2a2a);color:#808080}"
    body = p + f'<div class="caption" style="left:380px;top:{120+H+14}px;width:700px">État 9 · sans Polestar : même mise en page (boutons, cases et polices du jeu : approximation, polices Blizzard non reproduites).</div>'
    return page(body, ("MAQUETTE — données d'exemple", "Polestar_GroupFinder v0.2.0 · sans Polestar · approximation visuelle du style natif"), css)

if __name__ == "__main__":
    for n, f in (("01-etat1-addon-desactive", s1), ("02-etat2-recherche-3-quetes-groupage-auto", s2),
                 ("03-etat3-objectif-termine-quete-retiree", s3), ("04-etat4-recherche-terminee", s3b),
                 ("05-etat5-vide-cooldown", s4), ("06-etat6-infobulle-groupage-auto", s5),
                 ("07-etat7-panneau-a-gauche-bord-ecran", s6), ("08-etat8-options-polestar", s7),
                 ("09-etat9-fenetre-autonome", s8)):
        print(render(n, f(), OUT))
