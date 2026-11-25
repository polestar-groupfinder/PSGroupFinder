"""Shared pieces for the Polestar_GroupFinder mock-ups (HTML/CSS rendered by headless Chrome).
Units: 1 CSS px = 1 WoW UI unit; PNGs are rendered at 2x. Colours are Polestar's default
"Dusk" scheme (docs/skins/reference.md, Tokens). Window art is Polestar's own generated preview
(docs/preview/guide.svg, GPL-3.0), not a Blizzard asset."""
import html, subprocess, os

HERE = os.path.dirname(os.path.abspath(__file__))
STAGE_W, STAGE_H = 1280, 720

# Polestar "Dusk" tokens
BG = "24,29,45"          # #181d2d
PANEL_ALT = "#232a3f"
TEXT = "#f7f8fd"
TEXT_DIM = "#c3cadd"
TEXT_MUTED = "#9ba2b9"
SUCCESS = "#6bd999"
WARNING = "#fabf4d"
DANGER = "#f57373"
ACCENT = "#e6ba66"
QUEST = "#ffd673"

CLASS = {"MAGE": "#3FC7EB", "WARRIOR": "#C69B6D", "PRIEST": "#FFFFFF", "ROGUE": "#FFF468",
         "DRUID": "#FF7C0A", "HUNTER": "#AAD372", "PALADIN": "#F48CBA", "SHAMAN": "#0070DD",
         "WARLOCK": "#8788EE"}

CSS = f"""
*{{box-sizing:border-box;margin:0;padding:0}}
html,body{{width:{STAGE_W}px;height:{STAGE_H}px;overflow:hidden;background:#121418}}
body{{font-family:'Inter',sans-serif;color:{TEXT};position:relative;
  background:radial-gradient(ellipse 80% 80% at 50% 38%,#2a2e36 0%,#121418 100%)}}
.abs{{position:absolute}}
.banner{{position:absolute;left:0;top:0;width:100%;height:24px;background:rgba(250,191,77,.14);
  border-bottom:1px solid rgba(250,191,77,.45);color:#fabf4d;font-size:12px;font-weight:600;
  line-height:23px;padding-left:12px;letter-spacing:.2px;z-index:99}}
.banner span{{color:#c3cadd;font-weight:500;margin-left:10px}}
.caption{{position:absolute;color:{TEXT_MUTED};font-size:12px;font-weight:500}}
/* Polestar window kind=window */
.pwin{{background:rgba({BG},.94);box-shadow:0 0 0 1px rgba(0,0,5,.42),inset 0 0 0 1px rgba(255,255,255,.10),0 6px 18px rgba(0,0,5,.6)}}
/* Polestar kind=button, text button */
.pbtn{{background:{PANEL_ALT};box-shadow:inset 0 0 0 1px rgba(255,255,255,.10);color:{TEXT};
  text-align:center;white-space:nowrap}}
.pbtn.off{{background:rgba(35,42,63,.6);color:{TEXT_MUTED};opacity:.75}}
.t{{position:absolute;white-space:nowrap}}
.ell{{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}}
.guide{{position:absolute}}
"""

def page(body, banner, extra_css=""):
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>{CSS}{extra_css}</style></head>
<body><div class="banner">{html.escape(banner[0])}<span>{html.escape(banner[1])}</span></div>{body}</body></html>"""

def guide_window(x, y):
    """Polestar's own guide window render (340x305 at (x+6, y+6) inside a 353x318 crop)."""
    return f'<img class="guide" src="../assets/polestar-guide-window.png" style="left:{x}px;top:{y}px;width:353px;height:318px">'

WIN = (86, 96, 340, 305)   # window left, top, width, height on the stage

def render(name, html_text, out_dir):
    src = os.path.join(HERE, "src", name + ".html")
    open(src, "w").write(html_text)
    png = os.path.join(out_dir, name + ".png")
    subprocess.run(["google-chrome", "--headless", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                    "--force-device-scale-factor=2", f"--window-size={STAGE_W},{STAGE_H}",
                    "--virtual-time-budget=2000", f"--screenshot={png}", "file://" + src],
                   check=True, capture_output=True)
    return png
