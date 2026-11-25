"""v1.1.0 mock-ups: players per quest (3 entry points + the quest list) and the "leave the group?" offer.
Drawn from UI.lua / Hooks.lua / Leave.lua and from the owner's description of his in-game captures
(the captures themselves were not available to this tool). Neither the game's art nor Polestar's
window is reproduced pixel for pixel: boxes and labels show where things go."""
import os
from common import *
import v1 as V

OUT = os.path.join(HERE, "v1.0")
os.makedirs(OUT, exist_ok=True)
e = V.e
PW, PAD, ROW_H, OPT_H, BTN_COL = V.PW, V.PAD, V.ROW_H, V.OPT_H, V.BTN_COL
MUTED, DIM, GREEN, AMBER = V.MUTED, V.DIM, V.GREEN, V.AMBER
ICON_C = "#d9e0f2"
BANNER = ("MAQUETTE — données d'exemple",
          "PSGroupFinder v1.0.0 · dessinée d'après UI.lua / Hooks.lua / Leave.lua et la description des captures, pas une capture du jeu")
YELLOW = "#ffd100"

EXTRA = f"""
.qb{{position:absolute;width:14px;height:14px;border-radius:2px;background:rgba(255,255,255,.07);box-shadow:inset 0 0 0 1px rgba(255,255,255,.25)}}
.qb i{{position:absolute;background:{ICON_C}}}
.qb.hot{{box-shadow:inset 0 0 0 1px {ACCENT};background:rgba(230,186,102,.18)}}
.qb.hot i{{background:{ACCENT}}}
.gr{{position:absolute;left:0;width:100%}}
.ring{{position:absolute;border:1.5px dashed {ACCENT};border-radius:5px;pointer-events:none}}
.note{{position:absolute;font-size:11px;font-weight:600;color:{ACCENT}}}
"""


def qbtn(x, y, hot=False):
    # Same geometry as Hooks.lua: two heads 3x3, two bodies 4x5 around the centre of a 14x14 button.
    return (f'<div class="qb{" hot" if hot else ""}" style="left:{x}px;top:{y}px">'
            '<i style="left:3px;top:2px;width:3px;height:3px"></i><i style="left:2.5px;top:7px;width:4px;height:5px"></i>'
            '<i style="left:8px;top:2px;width:3px;height:3px"></i><i style="left:7.5px;top:7px;width:4px;height:5px"></i></div>')


def wrap(body, extra=""):
    return page(body, BANNER, EXTRA + extra)


def caption(text, y, left=60, w=1160):
    return f'<div class="caption" style="left:{left}px;top:{y}px;width:{w}px;line-height:16px">{e(text)}</div>'


def bag(x, y, s=20):
    return (f'<div class="abs" style="left:{x}px;top:{y}px;width:{s}px;height:{s}px;border-radius:3px;background:rgba(255,255,255,.07);'
            f'box-shadow:inset 0 0 0 1px rgba(255,255,255,.22)"><svg viewBox="0 0 20 20" width="{s}" height="{s}">'
            f'<path d="M6 7h8l1.5 9h-11z" fill="#8b6a3d" stroke="#d6b27a" stroke-width="1"/><path d="M7.5 7c0-3 5-3 5 0" fill="none" stroke="#d6b27a" stroke-width="1.2"/></svg></div>')


def ptick(x, y, on=False):
    edge = ACCENT if on else "rgba(255,255,255,.3)"
    return (f'<div class="abs" style="left:{x}px;top:{y}px;width:16px;height:16px;border-radius:3px;background:rgba(255,255,255,.07);'
            f'box-shadow:inset 0 0 0 1px {edge}"></div>')


def retry(x, y):
    return (f'<svg class="abs" style="left:{x}px;top:{y}px" viewBox="0 0 16 16" width="16" height="16"><path d="M12.5 8a4.5 4.5 0 1 1-1.4-3.2M12.5 2.5v3h-3" '
            f'fill="none" stroke="{TEXT_DIM}" stroke-width="1.5"/></svg>')


def goal_row_html(top, with_btn, title_lines, sub, hot=False):
    """A Polestar goal row (340 wide). Icon at x=10..30, text from x=38, ↻ and tick at the right."""
    h = 8 + 15 * len(title_lines) + 17 + 6
    t = "".join(f'<div class="t" style="left:38px;top:{6+15*i}px;font-size:12px;font-weight:500;color:{TEXT}">{e(l)}</div>' for i, l in enumerate(title_lines))
    sub_y = 6 + 15 * len(title_lines) + 1
    s = f'<div class="t" style="left:38px;top:{sub_y}px;font-size:11px;font-weight:500;color:{MUTED}">{e(sub)}</div>'
    b = qbtn(14, 31, hot) if with_btn else ""
    return (f'<div class="gr" style="top:{top}px;height:{h}px">{bag(10, 8)}{t}{s}{retry(PW-50, 8)}{ptick(PW-28, 7)}{b}</div>'), h


def guide_window_html(x, y, rows_html, height, title="Wolves"):
    nav = (f'<div class="abs" style="left:0;top:0;width:{PW}px;height:34px;border-bottom:1px solid rgba(255,255,255,.08)"></div>'
           f'<div class="t" style="left:12px;top:9px;font-size:12px;font-weight:600;color:{TEXT}">&lt; 7 / 41 &gt;</div>'
           f'<div class="t" style="left:90px;top:9px;font-size:12px;color:{TEXT_DIM}">Elwynn Forest</div>')
    head = (f'<div class="t" style="left:12px;top:44px;font-size:15px;font-weight:600;color:{QUEST}">{e(title)}</div>'
            f'<div class="t" style="left:12px;top:64px;font-size:11px;color:{MUTED}">Marshal McBride · Northshire Abbey</div>')
    return (f'<div class="abs pwin" style="left:{x}px;top:{y}px;width:{PW}px;height:{height}px">{nav}{head}'
            f'<div class="abs" style="left:0;top:90px;width:{PW}px">{rows_html}</div></div>')


def tooltip_html(x, y, w=300, ours=True):
    lines = [
        ("Quest #33 · Item #750", MUTED), ("Location: Elwynn Forest, 38.2, 61.5", MUTED), ("Progress: 0 / 8", TEXT_DIM),
        ("Wolves roam all over this area (14 spots).", TEXT_DIM),
    ]
    helps = [("Click to point the arrow here", YELLOW),
             ("Middle-click: show in quest log. Shift-click: link in chat.", YELLOW),
             ("Right-click to tick it done or skip this quest", YELLOW)]
    html_ = [f'<div style="font-size:12px;font-weight:600;color:#fff">Kill Timber Wolf or Young Wolf</div>',
             f'<div style="font-size:11px;color:{QUEST};margin-top:2px">for "Wolves Across the Border"</div>']
    for t, c in lines:
        html_.append(f'<div style="font-size:11px;color:{c};line-height:14px;margin-top:3px">{e(t)}</div>')
    html_.append('<div style="height:6px"></div>')
    for t, c in helps:
        html_.append(f'<div style="font-size:11px;color:{c};line-height:14px;margin-top:2px">{e(t)}</div>')
    hi = ""
    if ours:
        html_.append(f'<div id="ours" style="font-size:11px;color:{YELLOW};line-height:14px;margin-top:2px">Alt-clic : voir les joueurs sur cette quête</div>')
    body = "".join(html_)
    return (f'<div class="abs" style="left:{x}px;top:{y}px;width:{w}px;padding:8px 10px;background:rgba(16,16,28,.96);'
            f'border:1px solid #8a8a96;border-radius:3px;box-shadow:0 0 0 1px #000">{body}</div>')


# ---------------------------------------------------------------- 1: guide window goal row
def m1():
    rows, y = "", 0
    r, h = goal_row_html(y, False, ["Talk to Marshal McBride"], "Northshire Abbey"); rows += r; y += h + 6
    r, h = goal_row_html(y, True, ["Kill Timber Wolf or Young Wolf for", "Tough Wolf Meat 0/8"], "Found all over this area: 14 spots", hot=True); rows += r
    target_top = 90 + y
    y += h + 6
    r, h = goal_row_html(y, True, ["Turn in Wolves Across the Border"], "Marshal McBride"); rows += r; y += h
    win = guide_window_html(WIN[0], WIN[1], rows, 90 + y + 14)
    # Callouts: zoom on the row's left part (3x).
    zx, zy = 560, 130
    inner = goal_row_html(0, True, ["Kill Timber Wolf or Young Wolf for", "Tough Wolf Meat 0/8"], "Found all over this area: 14 spots", hot=True)[0]
    zoom = (f'<div class="abs pwin" style="left:{zx}px;top:{zy}px;width:600px;height:200px;overflow:hidden">'
            f'<div style="position:absolute;left:6px;top:6px;width:{PW}px;height:70px;transform-origin:0 0;transform:scale(1.75)">'
            f'<div style="position:relative;width:{PW}px;height:70px">{inner}</div></div></div>')
    note = (f'<div class="note" style="left:{zx}px;top:{zy-20}px">Zoom ×1,75 : bouton « joueurs sur cette quête » sous l\'icône du sac, à gauche de la sous-ligne</div>')
    ring = ""
    cap = caption("Emplacement 1 · fenêtre de guide Polestar : un petit bouton (deux silhouettes, 14×14) sous l'icône de chaque objectif lié à une quête, "
                  "à gauche de la sous-ligne. Clic : liste des joueurs de la quête. Sur une ligne sans sous-ligne (une seule ligne), il se place à gauche de la case à cocher. "
                  "Schéma : la fenêtre Polestar n'est pas reproduite à l'identique.", WIN[1] + 90 + y + 40)
    return wrap(win + ring + note + zoom + cap)


# ---------------------------------------------------------------- 2: tooltip
def m2():
    rows, y = "", 0
    r, h = goal_row_html(y, True, ["Kill Timber Wolf or Young Wolf for", "Tough Wolf Meat 0/8"], "Found all over this area: 14 spots"); rows += r; y += h
    win = guide_window_html(WIN[0], WIN[1], rows, 90 + y + 40)
    tip = tooltip_html(WIN[0] + 120, WIN[1] + 90 + 36, 310)
    mark = (f'<div class="note" style="left:{WIN[0]+120+322}px;top:{WIN[1]+90+36+176}px">◀ ajouté par PSGroupFinder (même couleur que les autres aides)</div>')
    mark2 = (f'<div class="note" style="left:{WIN[0]+120+322}px;top:{WIN[1]+90+36+196}px;color:{TEXT_DIM};font-weight:500">Alt + clic gauche sur la ligne = ouvre la liste de cette quête<br>(le clic normal, le clic milieu, Maj-clic et le clic droit restent à Polestar)</div>')
    cap = caption("Emplacement 2 · infobulle d'un objectif Polestar : une ligne d'aide de plus à la suite de celles de Polestar. Elle vient de l'enveloppe de "
                  "Polestar.QuestClickTips (fonction interne, appelée par nom à chaque infobulle) ; le Alt-clic de Polestar.QuestRowClick. Sans ces fonctions, ni la ligne ni le Alt-clic (le bouton reste).",
                  WIN[1] + 90 + 36 + 250)
    return wrap(win + tip + mark + mark2 + cap)


# ---------------------------------------------------------------- 3: Forever quest log
def log_row(y, lvl, title, obj, check, on=True, btn_x=None):
    bx = 300
    r = (f'<div class="abs" style="left:10px;top:{y}px;width:330px;height:40px">'
         f'<div class="abs" style="left:2px;top:6px;width:18px;height:18px;border-radius:9px;background:#3a3320;box-shadow:inset 0 0 0 1px #8a7440"></div>'
         f'<div class="t" style="left:28px;top:3px;font-size:12px;font-weight:600;color:{YELLOW}">[{lvl}] {e(title)}</div>'
         f'<div class="t" style="left:28px;top:20px;font-size:11px;color:{DIM}">- {e(obj)}</div>'
         f'<div class="abs" style="left:{bx-24}px;top:6px;width:18px;height:18px;border-radius:3px;background:rgba(255,255,255,.07);box-shadow:inset 0 0 0 1px rgba(255,255,255,.3)">'
         + ('<svg viewBox="0 0 18 18" width="18" height="18"><path d="M4.5 9.5l3.2 3.3L13.5 5.5" fill="none" stroke="#ffd100" stroke-width="2"/></svg>' if check else '') + '</div>'
         f'{qbtn(bx-2, 8, hot=btn_x == "hot")}</div>')
    return r


def m3():
    X, Y, W, H = 90, 60, 860, 520
    frame = (f'<div class="abs" style="left:{X}px;top:{Y}px;width:{W}px;height:{H}px;background:#161310;box-shadow:0 0 0 2px #6b5a35,0 8px 24px rgba(0,0,0,.6)"></div>'
             f'<div class="t" style="left:{X+16}px;top:{Y+10}px;font-size:14px;font-weight:600;color:{YELLOW}">Carte et journal de quêtes</div>')
    mapbox = (f'<div class="abs" style="left:{X+14}px;top:{Y+40}px;width:490px;height:{H-56}px;background:linear-gradient(135deg,#2a3a2a,#1d2a22);'
              f'box-shadow:inset 0 0 0 1px #4a4a3a"><div class="t" style="left:14px;top:14px;font-size:12px;color:#8fa58f">Carte du monde (non reproduite)</div></div>')
    lx = X + 520
    rows = (f'<div class="abs" style="left:{lx}px;top:{Y+40}px;width:330px;height:{H-56}px;background:#1e1a14;box-shadow:inset 0 0 0 1px #4a3f28">'
            f'<div class="t" style="left:10px;top:8px;font-size:13px;font-weight:600;color:#f5d58a">▾ Northshire Valley</div>'
            + log_row(34, 2, "Kobold Camp Cleanup", "0/10 Kobold Vermin slain", True, btn_x="hot")
            + log_row(80, 3, "Investigate Echo Ridge", "0/8 Kobold Worker slain", False)
            + f'<div class="t" style="left:10px;top:130px;font-size:13px;font-weight:600;color:#f5d58a">▾ Elwynn Forest</div>'
            + log_row(156, 4, "Wolves Across the Border", "1/8 Tough Wolf Meat", True)
            + '</div>')
    zoom_x = X + W + 20
    zoom = (f'<div class="abs" style="left:{zoom_x}px;top:{Y+60}px;width:230px;height:84px;overflow:hidden;background:#1e1a14;box-shadow:inset 0 0 0 1px #4a3f28">'
            f'<div style="position:absolute;left:-{270*2.6}px;top:-{4*2.6}px;transform-origin:0 0;transform:scale(2.6);width:340px;height:60px">'
            + log_row(0, 2, "Kobold Camp Cleanup", "0/10 Kobold Vermin slain", True, btn_x="hot") + '</div></div>')
    note = f'<div class="note" style="left:{zoom_x}px;top:{Y+40}px">Zoom ×2,6 : case de suivi puis notre bouton</div>'
    ring = f'<div class="ring" style="left:{lx+10+296}px;top:{Y+40+34+4}px;width:20px;height:22px"></div>'
    cap = caption("Emplacement 3 · journal de quêtes du jeu (Carte et journal de quêtes, Forever) : un bouton par quête, à droite de la case de suivi, "
                  "y compris pour une quête d'une autre zone (ici Elwynn Forest). Il est enfant du bouton de titre : il se déplace et se cache avec lui, même quand le journal recycle ses lignes. "
                  "S'il n'y a pas de place à droite de la case, il se met juste à sa gauche. Schéma : l'art du jeu n'est pas reproduit.", Y + H + 14)
    return wrap(frame + mapbox + rows + zoom + note + ring + cap)


# ---------------------------------------------------------------- 4/5: the quest list
def qrow(y, p):
    cc = CLASS[p["cls"]]
    rw = p.get("rw", 52)
    name_w = (PW - 2 * PAD) - (BTN_COL + 8) - rw - 6
    return (f'<div class="abs" style="left:{PAD}px;top:{y}px;width:{PW-2*PAD}px;height:{ROW_H}px">'
            f'<div class="t ell" style="left:0;top:2px;width:{name_w}px;font-size:13px;font-weight:500">'
            f'<span style="color:{cc}">{e(p["name"])}</span>&nbsp;&nbsp;<span style="color:{MUTED}">{p["lvl"]}</span>&nbsp;&nbsp;<span style="color:{MUTED}">{p["lang"]}</span></div>'
            f'<div class="t" style="right:{BTN_COL+8}px;top:4px;font-size:11px;font-weight:500;color:{p.get("scol", MUTED)};text-align:right">{e(p["right"])}</div>'
            f'<div class="t ell" style="left:0;top:21px;width:{PW-2*PAD-BTN_COL-8}px;font-size:11px;font-weight:500">'
            f'<span style="color:{DIM}">{e(p["zone"])}</span>&nbsp;&nbsp;<span style="color:{p.get("pcol", MUTED)}">{e(p["prog"])}</span></div>'
            f'{V.pbtn(PW-2*PAD-BTN_COL, 1, BTN_COL, "Chuchoter", h=19, size=11)}'
            f'{V.pbtn(PW-2*PAD-BTN_COL, ROW_H-20, BTN_COL, "Inviter", h=19, size=11)}</div>')


def quest_panel(left, top, players, searching=False, cd=0):
    body = [f'<div class="t" style="left:{PAD}px;top:10px;font-size:15px;font-weight:600;color:{TEXT}">Joueurs sur cette quête</div>', V.close_btn(),
            f'<div class="t" style="left:{PAD}px;top:34px;font-size:13px;font-weight:600;color:{YELLOW}">Kobold Camp Cleanup</div>',
            f'<div class="t" style="left:{PAD}px;top:52px;font-size:11px;font-weight:500;color:{MUTED}">Votre progression : 30 %</div>',
            V.pbtn(PAD, 72, 70, "Retour"),
            V.pbtn(PAD + 76, 72, 190, f"Rechercher pour cette quête" if not cd else f"Rechercher pour cette quête ({cd})", off=bool(cd))]
    y = 102
    if not players:
        body.append(f'<div class="t" style="left:{PAD+2}px;top:{y+2}px;width:{PW-2*PAD-4}px;white-space:normal;font-size:11px;font-weight:500;color:{MUTED}">'
                    + ("Recherche en cours… aucun joueur n'a cette quête pour l'instant." if searching else "Personne pour l'instant. Appuyez sur Rechercher pour cette quête.") + '</div>')
        y += 38
    for p in players:
        body.append(qrow(y, p)); y += ROW_H
    H = y + PAD - 2
    return (f'<div class="abs pwin" style="left:{left}px;top:{top}px;width:{PW}px;height:{H}px">' + "".join(body) + '</div>'), H


QP = [
    dict(name="Lyra Ashdown", cls="MAGE", lvl=8, lang="FR", zone="Northshire Valley", prog="80 %", right="22 m", rw=36),
    dict(name="Torvald Greaves", cls="WARRIOR", lvl=9, lang="FR", zone="Elwynn Forest", prog="prête à rendre", pcol=GREEN, right="autre zone", rw=62),
    dict(name="Edric Vane", cls="ROGUE", lvl=9, lang="FR", zone="Goldshire", prog="progression inconnue", right="autre zone", rw=62),
    dict(name="Mira Quillon", cls="PRIEST", lvl=7, lang="FR", zone="Northshire Valley", prog="10 %", right="déjà en groupe", rw=80),
]


def m4(empty=False):
    px = WIN[0] + WIN[2] + 6
    rows, y = "", 0
    r, h = goal_row_html(y, True, ["Kill Timber Wolf or Young Wolf for", "Tough Wolf Meat 0/8"], "Found all over this area: 14 spots", hot=True); rows += r; y += h
    win = guide_window_html(WIN[0], WIN[1], rows, 90 + y + 40)
    p, H = quest_panel(px, WIN[1], [] if empty else QP, searching=empty, cd=0 if not empty else 12)
    if empty:
        cap = caption("État 5 · recherche lancée, personne n'a répondu pour l'instant. Le bouton est grisé pendant la pause entre deux recherches de quête (15 s), "
                      "pour ne pas saturer les canaux ; les langues cochées et les limites d'envoi sont les mêmes que pour la recherche habituelle.", WIN[1] + max(H, 90 + y + 40) + 20)
    else:
        cap = caption("Emplacement 4 · la liste par quête (même rangée que la liste habituelle) : nom, niveau, classe, langue (FR), zone du joueur, progression, "
                      "à droite la distance ou « autre zone » / « déjà en groupe », Chuchoter et Inviter (sur votre clic seulement). « Rechercher pour cette quête » interroge tous les joueurs "
                      "sur l'identifiant de la quête, où qu'ils soient (réponse si la quête est dans leur journal, quelle que soit la zone). Retour revient au panneau habituel.",
                      WIN[1] + max(H, 90 + y + 40) + 20)
    return wrap(win + p + cap)


# ---------------------------------------------------------------- 6: leave popup
def m6():
    X, Y = 470, 150
    box = (f'<div class="abs pwin" style="left:{X}px;top:{Y}px;width:320px;height:130px">'
           f'<div class="t" style="left:{PAD}px;top:10px;font-size:15px;font-weight:600;color:{TEXT}">Quêtes terminées</div>'
           f'<div class="t" style="left:{PAD}px;top:34px;width:{320-2*PAD}px;white-space:normal;font-size:12px;font-weight:500;color:{TEXT};line-height:15px">'
           f'Toutes les quêtes pour lesquelles vous vous êtes groupé sont terminées. Quitter le groupe ?</div>'
           f'<div class="t ell" style="left:{PAD}px;top:76px;width:{320-2*PAD}px;font-size:11px;font-weight:500;color:{MUTED}">Dira dans /p : “Merci pour le groupe, bon jeu !”</div>'
           f'{V.pbtn(PAD, 130-PAD-24, 120, "Quitter", h=24)}{V.pbtn(320-PAD-120, 130-PAD-24, 120, "Rester", h=24)}</div>')
    box2 = (f'<div class="abs pwin" style="left:{X}px;top:{Y+190}px;width:320px;height:110px">'
            f'<div class="t" style="left:{PAD}px;top:10px;font-size:15px;font-weight:600;color:{TEXT}">Quêtes terminées</div>'
            f'<div class="t" style="left:{PAD}px;top:34px;width:{320-2*PAD}px;white-space:normal;font-size:12px;font-weight:500;color:{TEXT};line-height:15px">'
            f'Toutes les quêtes pour lesquelles vous vous êtes groupé sont terminées. Quitter le groupe ?</div>'
            f'{V.pbtn(PAD, 110-PAD-24, 120, "Quitter", h=24)}{V.pbtn(320-PAD-120, 110-PAD-24, 120, "Rester", h=24)}</div>')
    chat = (f'<div class="abs" style="left:{X+360}px;top:{Y}px;width:330px;padding:8px 10px;background:rgba(0,0,0,.55);border-radius:3px;font-size:12px;line-height:17px">'
            f'<div style="color:#aaaaff">[Groupe] <span style="color:{CLASS["MAGE"]}">Vous</span> : Merci pour le groupe, bon jeu !</div>'
            f'<div style="color:#ffd100">Group Finder <span style="color:#fff">Vous avez quitté le groupe.</span></div></div>')
    cap = [
        caption("Offre de quitter · fenêtre qui s'ouvre quand toutes les quêtes pour lesquelles vous vous êtes groupé via l'addon sont finies (objectifs remplis, prêtes à rendre ou rendues). "
                "Avec l'option « message dans /p » cochée, la ligne « Dira dans /p » rappelle le texte ; sans, elle disparaît (fenêtre du bas).", Y - 70, left=X - 400, w=1100),
        f'<div class="note" style="left:{X+360}px;top:{Y-20}px">Après le clic sur « Quitter » (jamais avant)</div>',
        f'<div class="note" style="left:{X+360}px;top:{Y+62}px;color:{TEXT_DIM};font-weight:500;width:330px;white-space:normal">Le message dans /p puis LeaveParty se font dans le clic sur « Quitter », '
        f'jamais automatiquement. « Rester » ferme la fenêtre et ne redemande pas pour ce groupe. Un groupe formé à la main n\'est jamais proposé.</div>',
    ]
    return wrap(box + box2 + chat + "".join(cap))


# ---------------------------------------------------------------- 7: panel + options
def panel7(left, top, msg_on=True):
    body = [f'<div class="t" style="left:{PAD}px;top:10px;font-size:15px;font-weight:600;color:{TEXT}">Recherche de groupe</div>', V.close_btn()]
    checks = [("Activer la recherche de groupe", True), ("Grouper automatiquement (même quête)", False), ("Bouton dans l'en-tête de Polestar", True),
              ("Partager ma position sur la carte", True), ("Répondre aux recherches sur mes quêtes", True),
              ("Proposer de quitter quand les quêtes sont finies", True), ("Dire un message dans /p avant de quitter", msg_on)]
    for i, (lab, on) in enumerate(checks):
        body.append(V.pcheck(PAD, 34 + i * OPT_H, lab, on, True))
    my = 34 + 7 * OPT_H
    body.append(f'<div class="t ell" style="left:{PAD+22}px;top:{my+3}px;width:216px;font-size:11px;font-weight:500;color:{MUTED};opacity:{1 if msg_on else .5}">Message : Merci pour le groupe, bon jeu !</div>')
    body.append(V.pbtn(PW - PAD - 70, my, 70, "Modifier…", h=18, size=11))
    ly = my + 22 + 2
    body.append(f'<div class="t" style="left:{PAD}px;top:{ly}px;font-size:11px;font-weight:500;color:{TEXT}">Langues de recherche</div>')
    body.append(f'<div class="t" style="left:{PAD+128}px;top:{ly}px;font-size:11px;font-weight:500;color:{MUTED}">FR</div>')
    by = my + 22 + 8 + 22
    body.append(V.pbtn(PAD, my + 22 + 30, 168, "Chercher un groupe")); body.append(V.pbtn(PW - PAD - 64, my + 22 + 30, 64, "Options"))
    H = my + 22 + 30 + 22 + 14
    return f'<div class="abs pwin" style="left:{left}px;top:{top}px;width:{PW}px;height:{H}px">' + "".join(body) + '</div>', H


def editor(x, y):
    return (f'<div class="abs pwin" style="left:{x}px;top:{y}px;width:330px;height:112px">'
            f'<div class="t" style="left:{PAD}px;top:10px;font-size:15px;font-weight:600">Message en quittant</div>'
            f'<div class="abs" style="left:{PAD+4}px;top:36px;width:{330-2*PAD-8}px;height:22px;background:rgba(255,255,255,.07);box-shadow:inset 0 0 0 1px rgba(255,255,255,.28);border-radius:3px">'
            f'<div class="t" style="left:6px;top:4px;font-size:12px;color:{TEXT}">Merci pour le groupe, bon jeu !<span style="color:{ACCENT}">|</span></div></div>'
            f'{V.pbtn(PAD, 112-PAD-22, 96, "Enregistrer", h=22)}{V.pbtn(PAD+102, 112-PAD-22, 96, "Par défaut", h=22)}{V.pbtn(330-PAD-96, 112-PAD-22, 96, "Annuler", h=22)}</div>')


def options_card():
    L, T, W = 560, 28, 680
    cx, cw = 16, W - 32
    rows = [("Proposer de quitter quand les quêtes sont finies", "Quand toutes les quêtes pour lesquelles vous vous êtes groupé via la recherche sont finies, une fenêtre propose de quitter. Rien sans votre clic.", True),
            ("Dire un message dans /p avant de quitter", "Seulement quand vous cliquez sur Quitter : le message part dans le groupe, puis vous quittez. Jamais automatique.", False)]
    h = [f'<div class="abs set" style="left:{L}px;top:{T}px;width:{W}px;height:300px">',
         f'<div class="t" style="left:16px;top:10px;font-size:15px;font-weight:600">Options de Polestar · Recherche de groupe</div>',
         f'<div class="abs card" style="left:{cx}px;top:44px;width:{cw}px;height:236px"><div class="sec" style="top:8px">QUITTER LE GROUPE</div>']
    y = 28
    for lab, hp, on in rows:
        h.append(f'<div class="rowl" style="top:{y}px">{e(lab)}</div><div class="help" style="top:{y+16}px">{e(hp)}</div>' + V.sw(cw - 14 - 34, y, on))
        y += 52
    h.append(f'<div class="rowl" style="top:{y+3}px">Message en quittant…</div><div class="key" style="left:{cw-14-120}px;top:{y}px;color:{TEXT}">Modifier le message</div>')
    h.append('</div></div>')
    return "".join(h)


def m7():
    px = 60
    p, H = panel7(px, 60)
    ed = editor(px, 60 + H + 20)
    opt = options_card()
    css = V.OPT_CSS
    cap = caption("Options · à gauche le panneau (deux interrupteurs de plus + la ligne du message, « Modifier… » ouvre la petite fenêtre de saisie en dessous) ; "
                  "à droite la page Polestar : mêmes deux interrupteurs et un bouton qui ouvre la même fenêtre (Polestar n'a pas de champ de texte dans ses options). "
                  "Par défaut : proposition activée, message désactivé ; texte par défaut selon la langue du client (FR : « Merci pour le groupe, bon jeu ! », EN : « Thanks for the group, have fun! »).",
                  60 + H + 20 + 130, left=60, w=1160)
    return wrap(p + ed + opt + cap, css)




# ---------------------------------------------------------------- 8: options sidebar icon
def nav_icon(src, x, y, s=16):
    return f'<img class="abs" src="../assets/{src}" style="left:{x}px;top:{y}px;width:{s}px;height:{s}px">'

def m8():
    """Polestar options, Guiding group, our Group Finder row with its 16px icon."""
    L, T, W, Hh = 80, 36, 1120, 650
    side_w = 220
    pages = [
        ("icon-window.png", "Guide", False),
        ("icon-map.png", "Map", False),
        ("icon-accept.png", "Questing", False),
        ("icon-search.png", "Discovery", False),
        ("psgf-icon-group.png", "Group Finder", True),
    ]
    body = [f'<div class="abs set" style="left:{L}px;top:{T}px;width:{W}px;height:{Hh}px">']
    body.append(f'<div class="t" style="left:16px;top:10px;font-size:15px;font-weight:600">Options de Polestar</div>')
    body.append(f'<div class="abs" style="left:0;top:42px;width:{side_w}px;bottom:0;border-right:1px solid rgba(255,255,255,.08)">')
    body.append(f'<div class="t" style="left:16px;top:8px;font-size:11px;font-weight:600;color:{MUTED};letter-spacing:.3px">GUIDING</div>')
    y = 32
    for src, label, on in pages:
        bg = f'background:rgba(230,186,102,.14);box-shadow:inset 2px 0 0 {ACCENT};' if on else ''
        body.append(f'<div class="abs" style="left:0;top:{y}px;width:{side_w-1}px;height:32px;{bg}"></div>')
        body.append(nav_icon(src, 28, y + 8))
        col = TEXT if on else DIM
        body.append(f'<div class="t" style="left:52px;top:{y+8}px;font-size:12px;font-weight:500;color:{col}">{e(label)}</div>')
        y += 32
    body.append('</div>')  # side
    # right: the Group Finder page, abbreviated
    cx = side_w + 24
    body.append(f'<div class="t" style="left:{cx}px;top:48px;font-size:15px;font-weight:600">Group Finder</div>')
    body.append(f'<div class="abs card" style="left:{cx}px;top:78px;width:{W-cx-24}px;height:280px">')
    body.append(f'<div class="sec" style="top:8px">GROUP FINDER</div>')
    rows = [("Enable the group finder", True), ("Group automatically (same quest)", False),
            ("Button in the Polestar header", True), ("All languages", False)]
    ry = 32
    for lab, on in rows:
        body.append(f'<div class="rowl" style="top:{ry}px">{e(lab)}</div>' + V.sw(W-cx-24-14-34, ry, on))
        ry += 36
    body.append('</div></div>')
    cap = caption(
        "Barre latérale des options Polestar (page groupée, section Guiding) : l'entrée Group Finder porte l'icône "
        "à deux silhouettes (Media/icon-group), 16×16, monochrome comme Guide (fenêtre), Map (boussole), Questing (« ! ») et Discovery (loupe). "
        "L'icône d'en-tête du guide, elle, est l'œil. Schéma : la fenêtre Polestar n'est pas reproduite à l'identique.",
        T + Hh + 12, left=L, w=1100)
    return wrap("".join(body) + cap, V.OPT_CSS)


def m9():
    """Header button: our monochrome eye, three states, left of Lookup."""
    states = [
        ("polestar-guide-header-off.png", "Désactivé", "œil atténué, encore cliquable"),
        ("polestar-guide-header-idle.png", "Repos", "même teinte que les autres icônes d'en-tête"),
        ("polestar-guide-header-active.png", "Recherche en cours", "teinte accent"),
    ]
    body = []
    x, y = 48, 36
    for src, title, note in states:
        body.append(f'<div class="abs" style="left:{x}px;top:{y}px;width:353px;height:80px;overflow:hidden;'
                    f'box-shadow:0 0 0 1px rgba(255,255,255,.12),0 8px 18px rgba(0,0,5,.45)">')
        body.append(f'<img src="../assets/{src}" style="width:353px;height:318px;display:block">')
        body.append('</div>')
        body.append(f'<div class="t" style="left:{x}px;top:{y+88}px;font-size:13px;font-weight:600">{title}</div>')
        body.append(f'<div class="t" style="left:{x}px;top:{y+106}px;width:353px;font-size:11px;color:{MUTED}">{note}</div>')
        x += 353 + 24
    # One full idle window for context, with a mark on the eye.
    gx, gy = 48, 160
    body.append(V.guide("polestar-guide-header-idle.png", x=gx+6, y=gy+6))
    # ring around the 24px button: OUR_CX, OUR_CY are in the 353x318 guide; guide() places it at gx, gy.
    # guide() subtracts 6 from x,y if we pass WIN, but we passed gx+6 so the img is at gx, gy.
    bx = gx + V.OUR_CX - 12
    by = gy + V.OUR_CY - 12
    body.append(f'<div class="ring" style="left:{bx-3}px;top:{by-3}px;width:30px;height:30px"></div>')
    body.append(f'<div class="note" style="left:{bx+34}px;top:{by+4}px">œil (14 px), à gauche de la loupe</div>')
    cap = caption(
        "Bouton d'en-tête : notre icône œil monochrome (Media/icon-eye.tga), à gauche de la loupe de Polestar. "
        "Repos, survol (iconHover, non montré) et recherche active suivent les teintes des autres icônes d'en-tête ; "
        "addon désactivé, l'œil est atténué mais reste cliquable. Repli si le fichier manque : les deux silhouettes de la barre latérale. "
        "L'icône de la barre latérale des options n'est pas changée.",
        gy + 318 + 16, left=48, w=1100)
    return wrap("".join(body) + cap, EXTRA)


def m10():
    """Search languages unfolded (All off)."""
    return V.s4()


def m11():
    """Search languages folded (All on): the list is hidden, the section shrinks."""
    return V.s5()


if __name__ == "__main__":
    for n, f in (("01-emplacement1-fenetre-guide-objectif", m1), ("02-emplacement2-infobulle-alt-clic", m2),
                 ("03-emplacement3-journal-de-quetes-forever", m3), ("04-liste-par-quete", m4),
                 ("05-liste-par-quete-recherche-en-cours", lambda: m4(True)), ("06-quitter-le-groupe-popup", m6),
                 ("07-options-quitter-le-groupe", m7), ("08-options-barre-laterale-icone", m8),
                 ("09-entete-icone-oeil", m9),
                 ("10-langues-depliees", m10),
                 ("11-langues-repliees", m11)):
        print(render(n, f(), OUT))
