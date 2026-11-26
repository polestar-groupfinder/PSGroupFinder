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
BANNER = ("MOCK-UP — sample data",
          "PSGroupFinder v1.0.0 · drawn from UI.lua / Hooks.lua / Leave.lua and the description of in-game captures, not a game screenshot")
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
    # Same geometry as Hooks.lua: 14x14 eye (Media/icon-eye), not the two silhouettes.
    filt = f'filter:brightness(0) saturate(100%) invert(79%) sepia(28%) saturate(708%) hue-rotate(352deg) brightness(96%);' if hot else ''
    return (f'<div class="qb{" hot" if hot else ""}" style="left:{x}px;top:{y}px">'
            f'<img src="../assets/psgf-icon-eye.png" width="14" height="14" '
            f'style="display:block;width:14px;height:14px;{filt}"></div>')


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
        html_.append(f'<div id="ours" style="font-size:11px;color:{YELLOW};line-height:14px;margin-top:2px">Alt-click: see the players on this quest</div>')
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
    note = (f'<div class="note" style="left:{zx}px;top:{zy-20}px">Zoom ×1.75: “players on this quest” button under the bag icon, to the left of the sub-line</div>')
    ring = ""
    cap = caption("Entry 1 · Polestar guide window: a small button (monochrome eye, 14×14) under the icon of each quest-linked objective, "
                  "to the left of the sub-line. Click: list of players on that quest. On a row with no sub-line (a single line), it sits to the left of the checkbox. "
                  "Diagram: the Polestar window is not reproduced pixel for pixel.", WIN[1] + 90 + y + 40)
    return wrap(win + ring + note + zoom + cap)


# ---------------------------------------------------------------- 2: tooltip
def m2():
    rows, y = "", 0
    r, h = goal_row_html(y, True, ["Kill Timber Wolf or Young Wolf for", "Tough Wolf Meat 0/8"], "Found all over this area: 14 spots"); rows += r; y += h
    win = guide_window_html(WIN[0], WIN[1], rows, 90 + y + 40)
    tip = tooltip_html(WIN[0] + 120, WIN[1] + 90 + 36, 310)
    mark = (f'<div class="note" style="left:{WIN[0]+120+322}px;top:{WIN[1]+90+36+176}px">◀ added by PSGroupFinder (same colour as the other tips)</div>')
    mark2 = (f'<div class="note" style="left:{WIN[0]+120+322}px;top:{WIN[1]+90+36+196}px;color:{TEXT_DIM};font-weight:500">Alt + left click on the row = opens the list for this quest<br>(normal click, middle click, Shift-click and right click stay with Polestar)</div>')
    cap = caption("Entry 2 · Polestar objective tooltip: one more help line after Polestar’s own. It comes from wrapping "
                  "Polestar.QuestClickTips (internal function, called by name on every tooltip); Alt-click from Polestar.QuestRowClick. Without those functions, neither the line nor Alt-click (the button remains).",
                  WIN[1] + 90 + 36 + 250)
    return wrap(win + tip + mark + mark2 + cap)


# ---------------------------------------------------------------- 3: Forever quest log
def log_row(y, lvl, title, obj, check, on=True, btn_x=None):
    bx = 300
    r = (f'<div class="abs" style="left:10px;top:{y}px;width:330px;height:40px">'
         f'<div class="abs" style="left:2px;top:6px;width:18px;height:18px;border-radius:9px;background:#3a3320;box-shadow:inset 0 0 0 1px #8a7440"></div>'
         f'<div class="t ell" style="left:28px;top:3px;width:{bx-24-28-6}px;font-size:12px;font-weight:600;color:{YELLOW}">[{lvl}] {e(title)}</div>'
         f'<div class="t" style="left:28px;top:20px;font-size:11px;color:{DIM}">- {e(obj)}</div>'
         f'<div class="abs" style="left:{bx-24}px;top:6px;width:18px;height:18px;border-radius:3px;background:rgba(255,255,255,.07);box-shadow:inset 0 0 0 1px rgba(255,255,255,.3)">'
         + ('<svg viewBox="0 0 18 18" width="18" height="18"><path d="M4.5 9.5l3.2 3.3L13.5 5.5" fill="none" stroke="#ffd100" stroke-width="2"/></svg>' if check else '') + '</div>'
         f'{qbtn(bx-2, 8, hot=btn_x == "hot")}</div>')
    return r


def m3():
    X, Y, W, H = 90, 60, 860, 520
    frame = (f'<div class="abs" style="left:{X}px;top:{Y}px;width:{W}px;height:{H}px;background:#161310;box-shadow:0 0 0 2px #6b5a35,0 8px 24px rgba(0,0,0,.6)"></div>'
             f'<div class="t" style="left:{X+16}px;top:{Y+10}px;font-size:14px;font-weight:600;color:{YELLOW}">Map & Quest Log</div>')
    mapbox = (f'<div class="abs" style="left:{X+14}px;top:{Y+40}px;width:490px;height:{H-56}px;background:linear-gradient(135deg,#2a3a2a,#1d2a22);'
              f'box-shadow:inset 0 0 0 1px #4a4a3a"><div class="t" style="left:14px;top:14px;font-size:12px;color:#8fa58f">World map (not reproduced)</div></div>')
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
    note = f'<div class="note" style="left:{zoom_x}px;top:{Y+40}px">Zoom ×2.6: tracking checkbox, then our button</div>'
    ring = f'<div class="ring" style="left:{lx+10+296}px;top:{Y+40+34+4}px;width:20px;height:22px"></div>'
    cap = caption("Entry 3 · in-game quest log (Map & Quest Log, Forever): one eye button per quest, always to the right of the tracking checkbox "
                  "(3 px, vertically centred), including for a quest in another zone (here Elwynn Forest). If there is no checkbox, the button stays in the same right-hand column. "
                  "The title is shortened so it does not run under the button. Child of the title button: it moves and hides with it, even when the log recycles its rows. "
                  "Diagram: the game’s art is not reproduced.", Y + H + 14)
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
            f'{V.pbtn(PW-2*PAD-BTN_COL, 1, BTN_COL, "Whisper", h=19, size=11)}'
            f'{V.pbtn(PW-2*PAD-BTN_COL, ROW_H-20, BTN_COL, "Invite", h=19, size=11)}</div>')


def quest_panel(left, top, players, searching=False, cd=0):
    body = [f'<img src="../assets/psgf-icon-eye.png" class="abs" style="left:{PAD}px;top:10px;width:16px;height:16px">',f'<div class="t" style="left:{PAD+22}px;top:10px;font-size:15px;font-weight:600;color:{TEXT}">Players on this quest</div>', V.close_btn(),
            f'<div class="t" style="left:{PAD}px;top:34px;font-size:13px;font-weight:600;color:{YELLOW}">Kobold Camp Cleanup</div>',
            f'<div class="t" style="left:{PAD}px;top:52px;font-size:11px;font-weight:500;color:{MUTED}">Votre progression : 30 %</div>',
            V.pbtn(PAD, 72, 70, "Back"),
            V.pbtn(PAD + 76, 72, 190, f"Search for this quest" if not cd else f"Search for this quest ({cd})", off=bool(cd))]
    y = 102
    if not players:
        body.append(f'<div class="t" style="left:{PAD+2}px;top:{y+2}px;width:{PW-2*PAD-4}px;white-space:normal;font-size:11px;font-weight:500;color:{MUTED}">'
                    + ("Searching… no player has this quest yet." if searching else "No one yet. Press Search for this quest.") + '</div>')
        y += 38
    for p in players:
        body.append(qrow(y, p)); y += ROW_H
    H = y + PAD - 2
    return (f'<div class="abs pwin" style="left:{left}px;top:{top}px;width:{PW}px;height:{H}px">' + "".join(body) + '</div>'), H


QP = [
    dict(name="Lyra Ashdown", cls="MAGE", lvl=8, lang="FR", zone="Northshire Valley", prog="80 %", right="22 m", rw=36),
    dict(name="Torvald Greaves", cls="WARRIOR", lvl=9, lang="FR", zone="Elwynn Forest", prog="ready to turn in", pcol=GREEN, right="other zone", rw=62),
    dict(name="Edric Vane", cls="ROGUE", lvl=9, lang="FR", zone="Goldshire", prog="progress unknown", right="other zone", rw=62),
    dict(name="Mira Quillon", cls="PRIEST", lvl=7, lang="FR", zone="Northshire Valley", prog="10 %", right="in a group", rw=80),
]


def m4(empty=False):
    px = WIN[0] + WIN[2] + 6
    rows, y = "", 0
    r, h = goal_row_html(y, True, ["Kill Timber Wolf or Young Wolf for", "Tough Wolf Meat 0/8"], "Found all over this area: 14 spots", hot=True); rows += r; y += h
    win = guide_window_html(WIN[0], WIN[1], rows, 90 + y + 40)
    p, H = quest_panel(px, WIN[1], [] if empty else QP, searching=empty, cd=0 if not empty else 12)
    if empty:
        cap = caption("State 5 · a search has started, nobody has answered yet. The button is greyed during the pause between two quest searches (15 s), "
                      "so the channels are not flooded; the ticked languages and send limits are the same as for a regular search.", WIN[1] + max(H, 90 + y + 40) + 20)
    else:
        cap = caption("Entry 4 · the per-quest list (same row layout as the regular list): name, level, class, language (FR), the player’s zone, progress, "
                      "on the right the distance or “other zone” / “in a group”, Whisper and Invite (only on your click). “Search for this quest” queries every player "
                      "for that quest id, wherever they are (they answer if the quest is in their log, regardless of zone). Back returns to the regular panel.",
                      WIN[1] + max(H, 90 + y + 40) + 20)
    return wrap(win + p + cap)


# ---------------------------------------------------------------- 6: leave popup
def m6():
    X, Y = 470, 150
    box = (f'<div class="abs pwin" style="left:{X}px;top:{Y}px;width:320px;height:130px">'
           f'<div class="t" style="left:{PAD}px;top:10px;font-size:15px;font-weight:600;color:{TEXT}">Quests done</div>'
           f'<div class="t" style="left:{PAD}px;top:34px;width:{320-2*PAD}px;white-space:normal;font-size:12px;font-weight:500;color:{TEXT};line-height:15px">'
           f'Every quest you grouped for is done. Leave the group?</div>'
           f'<div class="t ell" style="left:{PAD}px;top:76px;width:{320-2*PAD}px;font-size:11px;font-weight:500;color:{MUTED}">Will say in /p: “Thanks for the group, have fun!”</div>'
           f'{V.pbtn(PAD, 130-PAD-24, 120, "Leave", h=24)}{V.pbtn(320-PAD-120, 130-PAD-24, 120, "Stay", h=24)}</div>')
    box2 = (f'<div class="abs pwin" style="left:{X}px;top:{Y+190}px;width:320px;height:110px">'
            f'<div class="t" style="left:{PAD}px;top:10px;font-size:15px;font-weight:600;color:{TEXT}">Quests done</div>'
            f'<div class="t" style="left:{PAD}px;top:34px;width:{320-2*PAD}px;white-space:normal;font-size:12px;font-weight:500;color:{TEXT};line-height:15px">'
            f'Every quest you grouped for is done. Leave the group?</div>'
            f'{V.pbtn(PAD, 110-PAD-24, 120, "Leave", h=24)}{V.pbtn(320-PAD-120, 110-PAD-24, 120, "Stay", h=24)}</div>')
    chat = (f'<div class="abs" style="left:{X+360}px;top:{Y}px;width:330px;padding:8px 10px;background:rgba(0,0,0,.55);border-radius:3px;font-size:12px;line-height:17px">'
            f'<div style="color:#aaaaff">[Party] <span style="color:{CLASS["MAGE"]}">You</span> : Thanks for the group, have fun!</div>'
            f'<div style="color:#ffd100">Group Finder <span style="color:#fff">You left the group.</span></div></div>')
    cap = [
        caption("Leave offer · window that opens when every quest you grouped for through the addon is done (objectives filled, ready to turn in, or turned in). "
                "With the “message in /p” option on, the “Will say in /p” line reminds you of the text; without it, the line is hidden (lower window).", Y - 70, left=X - 400, w=1100),
        f'<div class="note" style="left:{X+360}px;top:{Y-20}px">After the click on “Leave” (never before)</div>',
        f'<div class="note" style="left:{X+360}px;top:{Y+62}px;color:{TEXT_DIM};font-weight:500;width:330px;white-space:normal">The /p message and LeaveParty both happen in the click on “Leave”, '
        f'never automatically. “Stay” closes the window and does not ask again for this group. A group joined by hand is never offered.</div>',
    ]
    return wrap(box + box2 + chat + "".join(cap))


# ---------------------------------------------------------------- 7: panel + options
def panel7(left, top, msg_on=True):
    body = [f'<div class="t" style="left:{PAD}px;top:10px;font-size:15px;font-weight:600;color:{TEXT}">Group Finder</div>', V.close_btn()]
    checks = [("Enable the group finder", True), ("Group automatically (same quest)", False), ("Button in the Polestar header", True),
              ("Share my map position", True), ("Answer searches for my quests", True),
              ("Offer to leave once the quests are done", True), ("Say a message in /p before leaving", msg_on)]
    for i, (lab, on) in enumerate(checks):
        body.append(V.pcheck(PAD, 34 + i * OPT_H, lab, on, True))
    my = 34 + 7 * OPT_H
    body.append(f'<div class="t ell" style="left:{PAD+22}px;top:{my+3}px;width:216px;font-size:11px;font-weight:500;color:{MUTED};opacity:{1 if msg_on else .5}">Message: Thanks for the group, have fun!</div>')
    body.append(V.pbtn(PW - PAD - 70, my, 70, "Edit…", h=18, size=11))
    ly = my + 22 + 2
    body.append(f'<div class="t" style="left:{PAD}px;top:{ly}px;font-size:11px;font-weight:500;color:{TEXT}">Search languages</div>')
    body.append(f'<div class="t" style="left:{PAD+128}px;top:{ly}px;font-size:11px;font-weight:500;color:{MUTED}">EN</div>')
    by = my + 22 + 8 + 22
    body.append(V.pbtn(PAD, my + 22 + 30, 168, "Find a group")); body.append(V.pbtn(PW - PAD - 64, my + 22 + 30, 64, "Options"))
    H = my + 22 + 30 + 22 + 14
    return f'<div class="abs pwin" style="left:{left}px;top:{top}px;width:{PW}px;height:{H}px">' + "".join(body) + '</div>', H


def editor(x, y):
    return (f'<div class="abs pwin" style="left:{x}px;top:{y}px;width:330px;height:112px">'
            f'<div class="t" style="left:{PAD}px;top:10px;font-size:15px;font-weight:600">Message when leaving</div>'
            f'<div class="abs" style="left:{PAD+4}px;top:36px;width:{330-2*PAD-8}px;height:22px;background:rgba(255,255,255,.07);box-shadow:inset 0 0 0 1px rgba(255,255,255,.28);border-radius:3px">'
            f'<div class="t" style="left:6px;top:4px;font-size:12px;color:{TEXT}">Thanks for the group, have fun!<span style="color:{ACCENT}">|</span></div></div>'
            f'{V.pbtn(PAD, 112-PAD-22, 96, "Save", h=22)}{V.pbtn(PAD+102, 112-PAD-22, 96, "Default", h=22)}{V.pbtn(330-PAD-96, 112-PAD-22, 96, "Cancel", h=22)}</div>')


def options_card():
    L, T, W = 560, 28, 680
    cx, cw = 16, W - 32
    rows = [("Offer to leave once the quests are done", "When every quest you grouped for through the finder is done, a window offers to leave. Nothing happens without your click.", True),
            ("Say a message in /p before leaving", "Only when you click Leave: the message goes to the party, then you leave. Never automatic.", False)]
    h = [f'<div class="abs set" style="left:{L}px;top:{T}px;width:{W}px;height:300px">',
         f'<div class="t" style="left:16px;top:10px;font-size:15px;font-weight:600">Polestar Options · Group Finder</div>',
         f'<div class="abs card" style="left:{cx}px;top:44px;width:{cw}px;height:236px"><div class="sec" style="top:8px">LEAVE THE GROUP</div>']
    y = 28
    for lab, hp, on in rows:
        h.append(f'<div class="rowl" style="top:{y}px">{e(lab)}</div><div class="help" style="top:{y+16}px">{e(hp)}</div>' + V.sw(cw - 14 - 34, y, on))
        y += 52
    h.append(f'<div class="rowl" style="top:{y+3}px">Message when leaving…</div><div class="key" style="left:{cw-14-120}px;top:{y}px;color:{TEXT}">Edit the message</div>')
    h.append('</div></div>')
    return "".join(h)


def m7():
    px = 60
    p, H = panel7(px, 60)
    ed = editor(px, 60 + H + 20)
    opt = options_card()
    css = V.OPT_CSS
    cap = caption("Options · on the left the panel (two extra switches + the message line; “Edit…” opens the small input window below); "
                  "on the right the Polestar page: the same two switches and a button that opens the same window (Polestar has no text field in its options). "
                  "Defaults: the offer is on, the message is off; default text follows the client language (FR: “Merci pour le groupe, bon jeu !”, EN: “Thanks for the group, have fun!”).",
                  60 + H + 20 + 130, left=60, w=1160)
    return wrap(p + ed + opt + cap, css)




# ---------------------------------------------------------------- 8: options sidebar icon
def nav_icon(src, x, y, s=16):
    return f'<img class="abs" src="../assets/{src}" style="left:{x}px;top:{y}px;width:{s}px;height:{s}px">'

def m8():
    """Polestar options, Guiding group, our Group Finder row with its 16px icon."""
    L, T, W, Hh = 80, 36, 1120, 540
    side_w = 220
    pages = [
        ("icon-window.png", "Guide", False),
        ("icon-map.png", "Map", False),
        ("icon-accept.png", "Questing", False),
        ("icon-search.png", "Discovery", False),
        ("psgf-icon-eye.png", "Group Finder", True),
    ]
    body = [f'<div class="abs set" style="left:{L}px;top:{T}px;width:{W}px;height:{Hh}px">']
    body.append(f'<div class="t" style="left:16px;top:10px;font-size:15px;font-weight:600">Polestar Options</div>')
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
        "Polestar options sidebar (grouped page, Guiding section): the Group Finder entry uses the same eye "
        "as the header button (Media/icon-eye), 16×16, monochrome like Guide (window), Map (compass), Questing (“!”) and Discovery (magnifying glass). "
        "Fallback if the file is missing: the two silhouettes (Media/icon-group). Diagram: the Polestar window is not reproduced pixel for pixel.",
        T + Hh + 12, left=L, w=1100)
    return wrap("".join(body) + cap, V.OPT_CSS)


def m9():
    """Header button: our monochrome eye, three states, left of Lookup."""
    states = [
        ("polestar-guide-header-off.png", "Disabled", "dimmed eye, still clickable"),
        ("polestar-guide-header-idle.png", "Idle", "same tint as the other header icons"),
        ("polestar-guide-header-active.png", "Search in progress", "accent tint"),
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
    body.append(f'<div class="note" style="left:{bx+34}px;top:{by+4}px">eye (14 px), to the left of the magnifying glass</div>')
    cap = caption(
        "Header button: our monochrome eye icon (Media/icon-eye.tga), to the left of Polestar’s magnifying glass. "
        "Idle, hover (iconHover, not shown) and an active search follow the tints of the other header icons; "
        "with the addon off, the eye is dimmed but stays clickable. Fallback if the file is missing: the two silhouettes from the sidebar. "
        "The same eye is used in the options sidebar, the panel title, the quest-log buttons and the details view.",
        gy + 318 + 16, left=48, w=1100)
    return wrap("".join(body) + cap, EXTRA)


def m10():
    """Search languages unfolded (All off)."""
    return V.s4()


def m11():
    """Search languages folded (All on): the list is hidden, the section shrinks."""
    return V.s5()



def m12():
    """Forever map + quest details: our eye to the left of Back."""
    X, Y, W, H = 70, 48, 980, 520
    frame = (f'<div class="abs" style="left:{X}px;top:{Y}px;width:{W}px;height:{H}px;background:#161310;box-shadow:0 0 0 2px #6b5a35,0 8px 24px rgba(0,0,0,.6)"></div>'
             f'<div class="t" style="left:{X+16}px;top:{Y+10}px;font-size:14px;font-weight:600;color:{YELLOW}">Map & Quest Log</div>')
    mapbox = (f'<div class="abs" style="left:{X+14}px;top:{Y+40}px;width:470px;height:{H-56}px;background:linear-gradient(135deg,#2a3a2a,#1d2a22);'
              f'box-shadow:inset 0 0 0 1px #4a4a3a"><div class="t" style="left:14px;top:14px;font-size:12px;color:#8fa58f">World map (not reproduced)</div></div>')
    dx, dy, dw, dh = X + 500, Y + 40, 466, H - 56
    # details pane
    pane = f'<div class="abs" style="left:{dx}px;top:{dy}px;width:{dw}px;height:{dh}px;background:#1e1a14;box-shadow:inset 0 0 0 1px #4a3f28"></div>'
    # Back at top right, our eye immediately to its left
    back_w, back_h = 70, 22
    back_x = dw - 14 - back_w
    back_y = 10
    eye_x = back_x - 4 - 14
    eye_y = back_y + (back_h - 14) // 2
    back = (f'<div class="abs" style="left:{dx+back_x}px;top:{dy+back_y}px;width:{back_w}px;height:{back_h}px;'
            f'background:#3a3320;box-shadow:inset 0 0 0 1px #8a7440;color:{YELLOW};font-size:11px;font-weight:600;'
            f'line-height:{back_h}px;text-align:center">Back</div>')
    eye = qbtn(dx + eye_x, dy + eye_y, hot=True)
    ring = f'<div class="ring" style="left:{dx+eye_x-4}px;top:{dy+eye_y-4}px;width:22px;height:22px"></div>'
    note = f'<div class="note" style="left:{dx+eye_x-210}px;top:{dy+eye_y-1}px">our eye, to the left of Back</div>'
    title = (f'<div class="t" style="left:{dx+14}px;top:{dy+42}px;font-size:15px;font-weight:600;color:{YELLOW}">Kobold Camp Cleanup</div>'
             f'<div class="t" style="left:{dx+14}px;top:{dy+66}px;font-size:12px;color:{DIM}">Kill 10 Kobold Vermin</div>'
             f'<div class="t" style="left:{dx+14}px;top:{dy+96}px;font-size:12px;font-weight:600;color:{TEXT}">Description</div>'
             f'<div class="t" style="left:{dx+14}px;top:{dy+116}px;width:{dw-28}px;white-space:normal;font-size:11px;color:{MUTED};line-height:15px">'
             f'You have been tasked with clearing the kobolds out of the mine. Return to Marshal McBride when you are done.</div>'
             f'<div class="t" style="left:{dx+14}px;top:{dy+170}px;font-size:12px;font-weight:600;color:{TEXT}">Rewards</div>'
             f'<div class="abs" style="left:{dx+14}px;top:{dy+192}px;width:36px;height:36px;background:#3a3320;box-shadow:inset 0 0 0 1px #8a7440"></div>')
    # bottom bar
    by = dy + dh - 36
    def dbtn(x, lab, off=False):
        col = "color:#6a6250;" if off else f"color:{YELLOW};"
        return (f'<div class="abs" style="left:{dx+x}px;top:{by}px;width:90px;height:22px;background:#3a3320;'
                f'box-shadow:inset 0 0 0 1px #8a7440;{col}font-size:11px;font-weight:600;line-height:22px;text-align:center">{lab}</div>')
    bar = dbtn(14, "Abandon") + dbtn(114, "Share", True) + dbtn(dw - 14 - 90, "Track")
    cap = caption(
        "Map & Quest Log details view (Forever, Retail-style): the eye button hooks to the left of Back, at the top right of the pane. "
        "Click: list of players for the displayed quest (a second click closes the pane). Fallback: to the right of Track, at the bottom. "
        "Tooltip identical to the quest-log one. Diagram: the game’s art is not reproduced.",
        Y + H + 14, left=X, w=1100)
    return wrap(frame + mapbox + pane + back + eye + ring + note + title + bar + cap)


if __name__ == "__main__":
    for n, f in (("01-entry1-polestar-guide-goal-row", m1), ("02-entry2-tooltip-alt-click", m2),
                 ("03-entry3-forever-quest-log", m3), ("04-players-on-this-quest", m4),
                 ("05-players-on-this-quest-searching", lambda: m4(True)), ("06-leave-the-group-popup", m6),
                 ("07-options-leave-the-group", m7), ("08-options-sidebar-icon", m8),
                 ("09-header-eye-icon", m9),
                 ("10-languages-unfolded", m10),
                 ("11-languages-folded", m11),
                 ("12-map-and-quest-log-details", m12)):
        print(render(n, f(), OUT))
