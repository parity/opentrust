#!/usr/bin/env python3
"""Generates the merchants illustration, twice:
  public/merchants-scene-still.svg  the everyday wallpaper (no motion, so nothing repaints behind every page)
  public/merchants-scene.svg        the animated version shown when the window is closed
Needs Pillow (see scripts/build_brand_assets.py) to embed the mascot from app/assets/images/logo/opentrust-mark.png.
Run: python3 scripts/build_scene.py
After regenerating, bump the ?v=N on the two url(...) lines in app/assets/tailwind/application.css so browsers fetch the new files."""
import base64, io, math, random, re
from PIL import Image
import wordmark_path  # "OpenTrust" outlined in Nunito Sans Black (scripts/outline_wordmark.py)

# The logo bird, shrunk and palette-reduced so it adds ~25 KB, embedded as a data URI (a background-image SVG can't load files).
_mark = Image.open("app/assets/images/logo/opentrust-mark.png").convert("RGBA")
_mark = _mark.resize((200, round(_mark.height * 200 / _mark.width)), Image.LANCZOS).quantize(colors=96, method=Image.Quantize.FASTOCTREE)
_buf = io.BytesIO(); _mark.save(_buf, "PNG", optimize=True)
MASCOT_URI = "data:image/png;base64," + base64.b64encode(_buf.getvalue()).decode()
MASCOT_RATIO = _mark.height / _mark.width  # height / width

def build(animated):
    random.seed(7)
    out = []
    def add(s): out.append(s)

    def mascot(cx, feet_y, height, flip=False):
        """The OpenTrust bird standing with its feet at (cx, feet_y). The logo faces right; flip=True makes it face left."""
        w = height / MASCOT_RATIO
        flip_t = f' transform="translate({cx*2:.1f} 0) scale(-1 1)"' if flip else ""
        add(f'<g filter="url(#paper)"{flip_t}><g class="mascot"><image href="{MASCOT_URI}" x="{cx - w/2:.1f}" y="{feet_y - height:.1f}" width="{w:.1f}" height="{height:.1f}"/></g></g>')

    W, H = 1600, 900
    BRAND = ["#F0A020", "#1F7A46", "#F54E00", "#B62AD9", "#1D4AFF"]
    SKIN = ["#E9B98F", "#C98B5E", "#A8693F", "#8A5232", "#F2CBA5"]

    add(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" preserveAspectRatio="xMidYMax slice" role="img" aria-label="Illustration of merchants running neighbouring stalls under a shared tree, linked by bunting">')
    add('''<defs>
      <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7FB391"/><stop offset=".55" stop-color="#B7D3A0"/><stop offset="1" stop-color="#EAE3B0"/></linearGradient>
      <linearGradient id="ground" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9CBF74"/><stop offset="1" stop-color="#6E9B58"/></linearGradient>
      <radialGradient id="sun" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#FFF3B8" stop-opacity=".95"/><stop offset=".45" stop-color="#FBE08A" stop-opacity=".45"/><stop offset="1" stop-color="#FBE08A" stop-opacity="0"/></radialGradient>
      <linearGradient id="vig" x1="0" y1="0" x2="0" y2="1"><stop offset=".7" stop-color="#1c3a22" stop-opacity="0"/><stop offset="1" stop-color="#1c3a22" stop-opacity=".28"/></linearGradient>
      <filter id="paper" x="-10%" y="-10%" width="120%" height="130%"><feDropShadow dx="0" dy="3" stdDeviation="2.5" flood-color="#17331c" flood-opacity=".28"/></filter>
      <style>
    .cloud{animation:drift 60s ease-in-out infinite alternate}
    .cloud.b{animation-duration:85s}
    .birds{animation:fly 48s linear infinite}
    .bob{animation:bob 1.9s ease-in-out infinite alternate}
    .glow{transform-box:fill-box;transform-origin:center;animation:breathe 7s ease-in-out infinite alternate}
    .sway{transform-box:fill-box;transform-origin:50% 0;animation:sway 3.2s ease-in-out infinite alternate}
    .flagwave{transform-box:fill-box;transform-origin:0 50%;animation:flag 2.2s ease-in-out infinite alternate}
    .wave{transform-box:fill-box;transform-origin:0 100%;animation:wave .9s ease-in-out infinite alternate}
    .mascot{transform-box:fill-box;transform-origin:50% 100%;animation:tilt 3.4s ease-in-out infinite alternate}
    @keyframes drift{from{transform:translateX(-140px)}to{transform:translateX(230px)}}
    @keyframes fly{from{transform:translateX(0)}to{transform:translateX(-2000px)}}
    @keyframes bob{from{transform:translateY(-7px)}to{transform:translateY(7px)}}
    @keyframes breathe{from{opacity:.8;transform:scale(1)}to{opacity:1;transform:scale(1.07)}}
    @keyframes sway{from{transform:rotate(-2.4deg)}to{transform:rotate(2.4deg)}}
    @keyframes flag{from{transform:skewY(-3deg) scaleX(.95)}to{transform:skewY(3deg) scaleX(1)}}
    @keyframes tilt{from{transform:rotate(-3.5deg)}to{transform:rotate(3.5deg)}}
    @keyframes wave{from{transform:rotate(-12deg)}to{transform:rotate(16deg)}}
    @media (prefers-reduced-motion:reduce){.cloud,.birds,.bob,.glow,.sway,.flagwave,.wave,.mascot{animation:none}}
  </style>
    </defs>''')

    # sky, sun, clouds, birds
    add(f'<rect width="{W}" height="{H}" fill="url(#sky)"/>')
    add('<circle class="glow" cx="1180" cy="190" r="230" fill="url(#sun)"/><circle cx="1180" cy="190" r="62" fill="#FCE58F"/>')
    def cloud(x, y, s, cls):
        add(f'<g filter="url(#paper)" opacity=".92" transform="translate({x} {y}) scale({s})"><g class="cloud {cls}" fill="#F6F3E2"><ellipse cx="0" cy="0" rx="70" ry="22"/><ellipse cx="-34" cy="-14" rx="38" ry="22"/><ellipse cx="18" cy="-24" rx="44" ry="28"/><ellipse cx="52" cy="-8" rx="30" ry="18"/></g></g>')
    cloud(340, 150, 1.1, "a"); cloud(780, 100, .8, "b"); cloud(1420, 280, .9, "a")
    add('<g class="birds"><g class="bob">')
    for bx, by, s_ in [(1750, 210, 1), (1810, 180, .8), (1700, 250, .7), (1880, 230, .6)]:
        add(f'<path d="M{bx} {by} q{8*s_} {-9*s_} {16*s_} 0 q{8*s_} {-9*s_} {16*s_} 0" fill="none" stroke="#2c4a35" stroke-width="2" stroke-linecap="round"/>')
    add('</g></g>')

    # hills (paper-cut layers)
    def hill(color, base, amp, phase, op=1):
        pts = " ".join(f"L{x} {base - amp*math.sin(x/230 + phase) - amp*.5*math.sin(x/97 + phase*2):.1f}" for x in range(0, W+40, 40))
        add(f'<path d="M0 {H} {pts} L{W} {H} Z" fill="{color}" opacity="{op}" filter="url(#paper)"/>')
    hill("#86AE82", 470, 38, 0.4); hill("#74A072", 520, 34, 2.1); hill("#6A9868", 565, 26, 4.0)
    add(f'<rect y="560" width="{W}" height="{H-560}" fill="url(#ground)"/>')

    # path
    add('<path d="M800 905 C 760 800, 880 740, 800 640 C 770 600, 800 575, 800 560" fill="none" stroke="#E7D3A6" stroke-width="130" stroke-linecap="round" opacity=".9"/>')
    add('<path d="M800 640 C 640 660, 560 640, 440 640 M800 650 C 960 668, 1060 650, 1180 650" fill="none" stroke="#E7D3A6" stroke-width="46" stroke-linecap="round" opacity=".85"/>')

    # shared tree
    add('<g filter="url(#paper)"><path d="M770 650 q8 -110 -10 -170 l80 0 q-18 60 -10 170 z" fill="#8A5A3B"/>')
    for cx, cy, r, c in [(700,400,115,"#3E7B4D"),(900,410,120,"#3E7B4D"),(800,330,140,"#4C9160"),(640,470,80,"#3A7448"),(960,480,85,"#3A7448"),(800,440,110,"#57A06C")]:
        add(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{c}"/>')
    add('</g>')
    for _ in range(34):
        a = random.random() * 2 * math.pi; r = random.random() * 150
        add(f'<circle cx="{800 + r*math.cos(a)*1.25:.0f}" cy="{390 + r*math.sin(a)*.8:.0f}" r="{random.randint(4,8)}" fill="#7FBF8B" opacity=".55"/>')
    # shield sign on the tree
    # the sign: the logo's lettering (Nunito Sans Black, narrowed), as outlines because a background SVG can't load fonts
    _size = 27.5; _k = _size / wordmark_path.UPEM; _x0 = 800 - wordmark_path.WIDTH * _k / 2
    add('<g filter="url(#paper)"><rect x="722" y="545" width="156" height="52" rx="8" fill="#FFF8E6" stroke="#8A5A3B" stroke-width="4"/>'
        f'<path transform="translate({_x0:.2f} 580) scale({_k:.5f} {-_k:.5f})" fill="#182010" d="{wordmark_path.D}"/></g>')
    add('<path d="M752 545 v-26 M848 545 v-26" stroke="#8A5A3B" stroke-width="4"/>')
    mascot(800, 548, 142)  # the host, perched on top of the OpenTrust sign

    # stalls
    def shield(cx, cy, s, fill="#1F7A46"):
        add(f'<g transform="translate({cx} {cy}) scale({s})"><path d="M0 -14 L12 -9 V3 C12 10 6 14 0 17 C-6 14 -12 10 -12 3 V-9 Z" fill="{fill}" stroke="#fff" stroke-width="2.4"/><path d="M-5 1 l4 4 l7 -9" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/></g>')

    def stall(x, y, s, color, goods):
        w, h = 150*s, 92*s
        add(f'<g filter="url(#paper)"><rect x="{x-w/2}" y="{y-h}" width="{w}" height="{h}" rx="{6*s}" fill="#FFF4DA"/>')
        add(f'<rect x="{x-w/2+14*s}" y="{y-h+34*s}" width="{w-28*s}" height="{h-34*s}" fill="#E2C48E"/>')
        # goods on counter
        for i in range(goods):
            gx = x - w/2 + 26*s + i*((w-52*s)/max(goods-1,1))
            add(f'<rect x="{gx-9*s}" y="{y-h+44*s}" width="{18*s}" height="{18*s}" rx="{3*s}" fill="{random.choice(BRAND)}" opacity=".9"/>')
        add(f'<rect x="{x-w/2-8*s}" y="{y-h-6*s}" width="{w+16*s}" height="{12*s}" fill="#8A5A3B" rx="{3*s}"/>')
        n = 7
        for i in range(n):
            fx = x - w/2 - 12*s + i*((w+24*s)/n)
            add(f'<path d="M{fx} {y-h+6*s} h{(w+24*s)/n} v{34*s} q{-(w+24*s)/n/2} {10*s} {-(w+24*s)/n} 0 z" fill="{color if i%2==0 else "#FFF4DA"}"/>')
        add('</g>')
        shield(x, y - h*0.5 + 4*s, 1.0*s)

    def person(x, y, s, shirt, skin, wave=False, parcel=False):
        add(f'<g filter="url(#paper)" transform="translate({x} {y}) scale({s})">')
        add(f'<rect x="-13" y="-52" width="26" height="40" rx="12" fill="{shirt}"/><rect x="-10" y="-14" width="8" height="22" rx="3" fill="#2d3a46"/><rect x="2" y="-14" width="8" height="22" rx="3" fill="#2d3a46"/>')
        add(f'<circle cx="0" cy="-66" r="13" fill="{skin}"/><path d="M-13 -68 q13 -22 26 0 q-13 -8 -26 0" fill="#2b2118"/>')
        if wave: add(f'<path class="wave" d="M12 -44 q18 -6 22 -30" stroke="{skin}" stroke-width="7" stroke-linecap="round" fill="none"/>')
        if parcel: add('<rect x="-26" y="-40" width="26" height="22" rx="3" fill="#C9965B"/><path d="M-13 -40 v22" stroke="#F3E3B9" stroke-width="4"/>')
        add('</g>')

    stalls = [(150,660,1.05,BRAND[1],4),(400,610,.9,BRAND[0],3),(560,585,.72,BRAND[3],3),(1040,585,.72,BRAND[2],3),(1200,610,.9,BRAND[4],4),(1455,660,1.05,BRAND[0],4)]
    for x, y, s, c, g in sorted(stalls, key=lambda t: t[1]): stall(x, y, s, c, g)

    # bunting linking stalls and the tree
    def bunting(x1, y1, x2, y2, sag):
        mx, my = (x1+x2)/2, (y1+y2)/2 + sag
        add(f'<path d="M{x1} {y1} Q{mx} {my} {x2} {y2}" fill="none" stroke="#5B4636" stroke-width="2.2"/>')
        add('<g class="sway">')
        n = max(6, int(abs(x2-x1)/34))
        for i in range(1, n):
            t = i/n
            px = (1-t)**2*x1 + 2*(1-t)*t*mx + t**2*x2; py = (1-t)**2*y1 + 2*(1-t)*t*my + t**2*y2
            add(f'<path d="M{px-9:.1f} {py:.1f} h18 l-9 22 z" fill="{BRAND[i % len(BRAND)]}"/>')
        add('</g>')
    bunting(150, 560, 400, 548, 40); bunting(400, 548, 560, 528, 32); bunting(560, 528, 780, 470, 36)
    bunting(820, 470, 1040, 528, 36); bunting(1040, 528, 1200, 548, 32); bunting(1200, 548, 1455, 560, 40)

    # a tricolour flying over the market
    add('<g filter="url(#paper)"><rect x="1331" y="470" width="5" height="176" rx="2" fill="#8A5A3B"/><circle cx="1333.5" cy="468" r="5" fill="#F0A020"/>')
    add('<g class="flagwave"><rect x="1336" y="474" width="64" height="14" fill="#FF9933"/><rect x="1336" y="488" width="64" height="14" fill="#FFFFFF"/><rect x="1336" y="502" width="64" height="14" fill="#138808"/>')
    add('<circle cx="1368" cy="495" r="5.4" fill="none" stroke="#000080" stroke-width="1.1"/>' + ''.join(f'<line x1="{1368+1.4*math.cos(i*math.pi/12):.2f}" y1="{495+1.4*math.sin(i*math.pi/12):.2f}" x2="{1368+5.2*math.cos(i*math.pi/12):.2f}" y2="{495+5.2*math.sin(i*math.pi/12):.2f}" stroke="#000080" stroke-width=".5"/>' for i in range(24)))
    add('</g></g>')
    mascot(1333.5, 474, 78, flip=True)  # a small one on top of the flagpole, looking back at the market

    # merchants: neighbours greeting, and one handshake under the tree
    person(110, 700, 1.1, BRAND[0], SKIN[1], wave=True)
    person(215, 706, 1.05, "#F6F3E2", SKIN[0], parcel=True)
    person(420, 650, .95, BRAND[3], SKIN[2], wave=True)
    person(1180, 650, .95, BRAND[1], SKIN[3], parcel=True)
    person(1405, 706, 1.05, BRAND[2], SKIN[4], wave=True)
    person(1500, 700, 1.1, "#F6F3E2", SKIN[1])
    person(752, 700, 1.25, BRAND[4], SKIN[0])
    person(850, 700, 1.25, BRAND[0], SKIN[2])
    add('<path d="M771 668 q29 -8 58 0" stroke="#fff" stroke-width="9" stroke-linecap="round" fill="none"/><circle cx="800" cy="664" r="9" fill="#FCE58F"/>')

    # foreground: grass, marigolds, parcels
    for _ in range(150):
        x = random.randint(0, W); y = random.randint(600, 900)
        h = random.randint(14, 34) * (0.6 + (y-600)/450)
        c = random.choice(["#5E8A47", "#76A058", "#4F7A3C"])
        add(f'<path d="M{x} {y} q-3 {-h*.5:.0f} -7 {-h:.0f} M{x} {y} q1 {-h*.6:.0f} 1 {-h*1.1:.0f} M{x} {y} q4 {-h*.5:.0f} 8 {-h:.0f}" stroke="{c}" stroke-width="2.4" fill="none" stroke-linecap="round"/>')
    for _ in range(34):
        x = random.randint(0, W); y = random.randint(740, 890); r = random.randint(7, 11)
        c = random.choice(["#F0A020", "#F5B83A", "#F54E00"])
        add(f'<g><circle cx="{x}" cy="{y}" r="{r}" fill="{c}"/><circle cx="{x}" cy="{y}" r="{r*.45:.1f}" fill="#B3590F" opacity=".7"/></g>')
    for x, y, s in [(300, 790, 1), (1320, 800, 1.1), (610, 840, .8), (990, 845, .8)]:
        add(f'<g filter="url(#paper)" transform="translate({x} {y}) scale({s})"><rect x="-30" y="-26" width="60" height="42" rx="4" fill="#C9965B"/><path d="M0 -26 v42" stroke="#F3E3B9" stroke-width="7"/><rect x="-18" y="-50" width="36" height="26" rx="3" fill="#D7A86C"/><path d="M0 -50 v26" stroke="#F3E3B9" stroke-width="5"/></g>')

    add(f'<rect width="{W}" height="{H}" fill="url(#vig)"/>')
    add('</svg>')
    svg = "\n".join(out)
    if not animated:
        svg = re.sub(r"<style>.*?</style>", "", svg, flags=re.S)  # no keyframes: a still picture
    return svg

for animated, path in ((True, "public/merchants-scene.svg"), (False, "public/merchants-scene-still.svg")):
    svg = build(animated)
    open(path, "w").write(svg)
    print("wrote", path, round(len(svg)/1024, 1), "KB")
