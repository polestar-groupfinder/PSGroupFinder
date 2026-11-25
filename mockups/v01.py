"""v0.1.0 mock-ups, laid out from UI.lua / Polestar.lua / Locales.lua as committed (7062c5d)."""
import html, os, sys
from common import *

OUT = os.path.join(HERE, "v0.1")
os.makedirs(OUT, exist_ok=True)
PW, ROW_H, ROWS = 300, 38, 7
PH = 168 + ROWS * ROW_H  # 434, fixed

# Example data (invented). e: name, class, level, size, quests [(title, kind)], dist
PEERS = [
    dict(name="Lyra Ashdown", cls="MAGE", lvl=8, size=0, q=[("Kobold Camp Cleanup", "kill"), ("Wolves Across the Border", "loot")], where="22 m"),
    dict(name="Torvald Greaves", cls="WARRIOR", lvl=9, size=0, q=[("Kobold Camp Cleanup", "kill")], where="48 m"),
    dict(name="Edric Vane", cls="ROGUE", lvl=9, size=0, q=[("Kobold Camp Cleanup", "kill")], where="même zone"),
    dict(name="Mira Quillon", cls="PRIEST", lvl=7, size=2, q=[("Wolves Across the Border", "loot")], where="130 m"),
]

def box(checked, enabled=True, themed=True):
    # Blizzard UICheckButtonTemplate is not themed by Polestar: a gold-trimmed dark box (approximation).
    col = "#b8993e" if enabled else "#6b6b6b"
    tick = f'<svg viewBox="0 0 22 22" width="22" height="22" style="position:absolute;left:0;top:0"><path d="M5 11.5l4 4.2L17 6.5" fill="none" stroke="{"#ffd100" if enabled else "#808080"}" stroke-width="2.6"/></svg>' if checked else ""
    return (f'<div class="abs" style="width:22px;height:22px;border:2px solid {col};border-radius:3px;'
            f'background:#0c0c10;box-shadow:inset 0 0 0 1px #000">{tick}</div>')

def check(x, y, label, checked, enabled=True):
    c = "#ffffff" if enabled else "#808080"
    return (f'<div class="abs" style="left:{x}px;top:{y}px;width:22px;height:22px">{box(checked, enabled)}</div>'
            f'<div class="t" style="left:{x+24}px;top:{y+4}px;font-size:12px;font-weight:500;color:{c}">{html.escape(label)}</div>')

def pbtn(x, y, w, label, off=False, h=22, size=12, weight=500):
    return (f'<div class="abs pbtn{" off" if off else ""}" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px;'
            f'line-height:{h}px;font-size:{size}px;font-weight:{weight}">{html.escape(label)}</div>')

def close_btn():
    # UIPanelCloseButton 32x32 at TOPRIGHT (2, 2): Blizzard art, not themed (approximation drawn here).
    return ('<div class="abs" style="left:%dpx;top:-2px;width:32px;height:32px;border-radius:4px;background:#3a1612;'
            'box-shadow:inset 0 0 0 2px #b8993e;"><svg viewBox="0 0 32 32" width="32" height="32"><path d="M10 10l12 12M22 10L10 22" '
            'stroke="#e8c447" stroke-width="2.6" fill="none"/></svg></div>' % (PW - 30))

def channel_line(states):
    col = {"ok": "#40ff40", "sent": "#ffd100", "fail": "#ff5050", "skip": "#909090", "?": "#aaaaaa"}
    parts = [f'<span style="color:{col[s]}">{n}</span>' for n, s in states]
    return "&nbsp;&nbsp;".join(parts)

def row(i, e, top0):
    y = top0 + (i) * ROW_H
    cc = CLASS[e["cls"]]
    grouped = ' <span style="color:#aaa">· déjà en groupe</span>' if e["size"] > 0 else ""
    qs = []
    for k, (t, kind) in enumerate(e["q"]):
        qs.append(f'{t} ({kind})')
    line = ", ".join(qs) + " · " + e["where"]
    return (f'<div class="abs" style="left:12px;top:{y}px;width:280px;height:{ROW_H}px">'
            f'<div class="t ell" style="left:0;top:2px;width:160px;font-size:13px;font-weight:500;color:#fff">'
            f'<span style="color:{cc}">{e["name"]}</span>&nbsp;&nbsp;<span style="color:#aaa">{e["lvl"]}</span>{grouped}</div>'
            f'<div class="t ell" style="left:0;top:20px;width:160px;font-size:11px;font-weight:500;color:#fff">{html.escape(line)}</div>'
            f'{pbtn(160, 8, 60, "Chuchoter")}{pbtn(224, 8, 56, "Inviter")}</div>')

def panel_v01(left, top, enabled, search_label, search_off, channels, peers, empty=False, tooltip=False, hl=None):
    h = [f'<div class="abs pwin" style="left:{left}px;top:{top}px;width:{PW}px;height:{PH}px">']
    h.append(f'<div class="t" style="left:12px;top:10px;font-size:15px;font-weight:600;color:{TEXT}">Recherche de groupe</div>')
    h.append(close_btn())
    h.append(check(10, 32, "Activer la recherche de groupe", enabled))
    h.append(check(10, 52, "Partager ma position sur la carte", True, enabled))
    h.append(check(10, 72, "Répondre aux recherches sur mes quêtes", True, enabled))
    h.append(pbtn(12, 100, 160, search_label, search_off))
    h.append(pbtn(178, 100, 110, "Tester les canaux", not enabled))
    if channels:
        h.append(f'<div class="t" style="left:12px;top:128px;font-size:11px;font-weight:500">{channel_line(channels)}</div>')
    top0 = 150
    for i, e in enumerate(peers):
        h.append(row(i, e, top0))
    if empty:
        h.append('<div class="t" style="left:12px;top:154px;width:276px;white-space:normal;font-size:12px;font-weight:400;'
                 'color:#fff;line-height:15px">Personne pour l\'instant. Cliquez sur Chercher un groupe.</div>')
    h.append('</div>')
    return "".join(h)

def launcher(label="Chercher un groupe"):
    x = WIN[0] + WIN[2] - 132
    y = WIN[1] + WIN[3] + 2
    return pbtn(x, y, 132, label, h=20, size=11, weight=600)

def tooltip_html(x, y, title, line, w=240):
    return (f'<div class="abs" style="left:{x}px;top:{y}px;width:{w}px;padding:9px 11px;background:rgba(16,16,28,.96);'
            f'border:1px solid #8a8a96;border-radius:3px;box-shadow:0 0 0 1px #000">'
            f'<div style="font-size:13px;font-weight:600;color:#fff;margin-bottom:3px">{html.escape(title)}</div>'
            f'<div style="font-size:12px;color:#ffd100;line-height:15px">{html.escape(line)}</div></div>')

BANNER = ("MAQUETTE — données d'exemple", "Polestar_GroupFinder v0.1.0 · dessinée d'après UI.lua / Polestar.lua, pas une capture du jeu")

def s1():
    body = guide_window(WIN[0] - 6, WIN[1] - 6) + launcher()
    body += f'<div class="caption" style="left:{WIN[0]}px;top:{WIN[1]+WIN[3]+30}px">État 1 · addon désactivé : le bouton « Chercher un groupe » est accroché sous la fenêtre de guide (TOPRIGHT → BOTTOMRIGHT, 0, -2 ; 132×20)</div>'
    return page(body, BANNER)

def s2():
    px = WIN[0] + WIN[2] + 6; py = WIN[1]
    body = guide_window(WIN[0] - 6, WIN[1] - 6) + launcher("Chercher un groupe")
    body += panel_v01(px, py, True, "Chercher un groupe (18)", True,
                      [("CHANNEL", "fail"), ("YELL", "ok"), ("SAY", "sent"), ("GUILD", "skip")], PEERS)
    body += f'<div class="caption" style="left:{WIN[0]}px;top:{WIN[1]+WIN[3]+30}px">État 2 · après une recherche : 4 joueurs trouvés, panneau collé à droite (TOPLEFT → TOPRIGHT, +6, 0 ; 300×434)</div>'
    return page(body, BANNER)

def s3():
    px = WIN[0] + WIN[2] + 6; py = WIN[1]
    body = guide_window(WIN[0] - 6, WIN[1] - 6) + launcher()
    body += panel_v01(px, py, True, "Chercher un groupe (14)", True,
                      [("CHANNEL", "fail"), ("YELL", "sent"), ("SAY", "?"), ("GUILD", "skip")], [], empty=True)
    body += f'<div class="caption" style="left:{WIN[0]}px;top:{WIN[1]+WIN[3]+30}px">État 3 · aucun joueur : texte vide + cooldown de 20 s sur le bouton de recherche</div>'
    return page(body, BANNER)

def s4():
    px = WIN[0] + WIN[2] + 6; py = WIN[1]
    body = guide_window(WIN[0] - 6, WIN[1] - 6) + launcher()
    body += panel_v01(px, py, False, "Chercher un groupe", True, None, [])
    body += tooltip_html(px + 40, py + 60, "Activer la recherche de groupe",
        "Rejoint le canal caché de recherche, répond aux recherches des autres joueurs sur vos quêtes communes et vous permet de chercher. Désactivé : rien n'est envoyé ni écouté.", 270)
    body += f'<div class="caption" style="left:{WIN[0]}px;top:{WIN[1]+WIN[3]+30}px">État 4 · options (addon désactivé, infobulle de « Activer ») : les deux autres cases et les boutons sont grisés</div>'
    return page(body, BANNER)

# --- standalone (no Polestar): backdrop tooltip window, Blizzard buttons and fonts (approximation)
SA_CSS = """
.sa{background:rgba(13,13,20,.92);border:3px solid transparent;border-image:none;box-shadow:0 0 0 1px #8b8b96,inset 0 0 0 2px #3b3b46,0 8px 24px rgba(0,0,0,.6);border-radius:6px}
.sa *{font-family:'Alegreya Sans','Inter',sans-serif}
.wbtn{background:linear-gradient(#7a1b12,#4a0d08);box-shadow:inset 0 0 0 1px #c9a23a,0 0 0 1px #000;color:#ffd100;text-align:center;border-radius:3px;white-space:nowrap}
.wbtn.off{background:linear-gradient(#444,#2a2a2a);color:#808080;box-shadow:inset 0 0 0 1px #666,0 0 0 1px #000}
"""

def wbtn(x, y, w, label, off=False):
    return f'<div class="abs wbtn{" off" if off else ""}" style="left:{x}px;top:{y}px;width:{w}px;height:22px;line-height:21px;font-size:12px">{html.escape(label)}</div>'

def srow(i, e, top0):
    y = top0 + i * ROW_H
    cc = CLASS[e["cls"]]
    grouped = ' <span style="color:#aaa">· déjà en groupe</span>' if e["size"] > 0 else ""
    line = ", ".join(f'{t} ({k})' for t, k in e["q"]) + " · " + e["where"]
    return (f'<div class="abs" style="left:12px;top:{y}px;width:280px;height:{ROW_H}px">'
            f'<div class="t ell" style="left:0;top:2px;width:160px;font-size:14px;color:#ffd100"><span style="color:{cc}">{e["name"]}</span>&nbsp;&nbsp;<span style="color:#aaa">{e["lvl"]}</span>{grouped}</div>'
            f'<div class="t ell" style="left:0;top:20px;width:160px;font-size:11px;color:#fff">{html.escape(line)}</div>'
            f'{wbtn(160, 8, 60, "Chuchoter")}{wbtn(224, 8, 56, "Inviter")}</div>')

def s5():
    left, top = 640 + 260 - PW // 2, 360 - 60 - PH // 2
    h = [f'<div class="abs sa" style="left:{left}px;top:{top}px;width:{PW}px;height:{PH}px">']
    h.append('<div class="t" style="left:12px;top:9px;font-size:18px;color:#ffd100">Recherche de groupe</div>')
    h.append(close_btn())
    h.append(check(10, 32, "Activer la recherche de groupe", True).replace("font-weight:500", "font-weight:400").replace("font-size:12px", "font-size:13px"))
    h.append(check(10, 52, "Partager ma position sur la carte", True).replace("font-size:12px", "font-size:13px"))
    h.append(check(10, 72, "Répondre aux recherches sur mes quêtes", True).replace("font-size:12px", "font-size:13px"))
    h.append(wbtn(12, 100, 160, "Chercher un groupe (18)", True))
    h.append(wbtn(178, 100, 110, "Tester les canaux"))
    h.append(f'<div class="t" style="left:12px;top:128px;font-size:11px">{channel_line([("CHANNEL","fail"),("YELL","ok"),("SAY","sent"),("GUILD","skip")])}</div>')
    for i, e in enumerate(PEERS[:3]):
        h.append(srow(i, e, 150))
    h.append('</div>')
    body = "".join(h)
    body += f'<div class="caption" style="left:{left-200}px;top:{top+PH+14}px;width:700px">État 5 · sans Polestar : fenêtre autonome (CENTER, +260, +60), fond d\'infobulle, boutons et police du jeu — approximation (polices Blizzard non reproduites)</div>'
    return page(body, ("MAQUETTE — données d'exemple", "Polestar_GroupFinder v0.1.0 · sans Polestar · approximation visuelle du style natif du jeu"), SA_CSS)

if __name__ == "__main__":
    for n, f in (("01-etat1-bouton-addon-desactive", s1), ("02-etat2-panneau-resultats", s2),
                 ("03-etat3-panneau-vide-cooldown", s3), ("04-etat4-options-desactive", s4),
                 ("05-etat5-fenetre-autonome", s5)):
        print(render(n, f(), OUT))
