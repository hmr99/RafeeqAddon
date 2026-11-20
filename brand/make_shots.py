#!/usr/bin/env python3
"""Generate CurseForge promo images for Rafeeq (1920x1080 PNG) via SVG + rsvg-convert."""
import base64, subprocess, html, math

W, H = 1920, 1080
LOGO = "data:image/png;base64," + base64.b64encode(open("logo_512.png", "rb").read()).decode()
EN = "Noto Sans"
AR = "Noto Naskh Arabic"
GOLD, CYAN, TEXT, MUTED = "#f0c35a", "#45cdf6", "#e9eef5", "#93a3b8"

def esc(s): return html.escape(s, quote=True)

def t(x, y, s, size=28, color=TEXT, weight=400, font=EN, anchor="start", extra=""):
    direction = ""
    return (f'<text x="{x}" y="{y}" font-family="{font}" font-size="{size}" font-weight="{weight}" '
            f'fill="{color}" text-anchor="{anchor}"{direction} {extra}>{esc(s)}</text>')

def panel(x, y, w, h, title=None, title_ar=False):
    s = (f'<g filter="url(#shadow)"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="#0b1422" fill-opacity="0.92" '
         f'stroke="{CYAN}" stroke-opacity="0.45" stroke-width="2"/></g>')
    if title:
        s += f'<rect x="{x}" y="{y}" width="{w}" height="46" rx="14" fill="{CYAN}" fill-opacity="0.13"/>'
        s += f'<rect x="{x}" y="{y+32}" width="{w}" height="14" fill="{CYAN}" fill-opacity="0.13"/>'
        if title_ar:
            s += t(x + w - 18, y + 33, title, 26, CYAN, 700, AR, "end")
        else:
            s += t(x + 18, y + 31, title, 22, CYAN, 700)
    return s

def frame(n, title, title_ar, bullets, visual):
    parts = [f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<defs>
  <radialGradient id="bg" cx="70%" cy="40%" r="85%">
    <stop offset="0" stop-color="#183554"/><stop offset="0.55" stop-color="#0b1626"/><stop offset="1" stop-color="#05090f"/>
  </radialGradient>
  <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe7a3"/><stop offset="1" stop-color="#c8902a"/></linearGradient>
  <filter id="shadow" x="-10%" y="-10%" width="120%" height="130%"><feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#000" flood-opacity="0.55"/></filter>
  <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="6" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
  <pattern id="grid" width="60" height="60" patternUnits="userSpaceOnUse"><path d="M60 0 H0 V60" fill="none" stroke="{CYAN}" stroke-opacity="0.05" stroke-width="1"/></pattern>
</defs>
<rect width="{W}" height="{H}" fill="url(#bg)"/>
<rect width="{W}" height="{H}" fill="url(#grid)"/>
<image href="{LOGO}" x="80" y="64" width="96" height="96"/>
''',
        t(196, 108, "Rafeeq", 44, TEXT, 800),
        t(198, 146, "Quest & leveling companion", 22, MUTED, 400),
        t(W - 80, 116, "رفيق", 52, GOLD, 700, AR, "end"),
        t(80, 300, title, 66, TEXT, 800),
        t(780, 380, title_ar, 46, GOLD, 700, AR, "end"),
        f'<rect x="80" y="410" width="120" height="6" rx="3" fill="url(#gold)"/>',
    ]
    y = 490
    for en, ar in bullets:
        parts.append(f'<circle cx="94" cy="{y-10}" r="7" fill="{CYAN}"/>')
        parts.append(t(118, y, en, 30, TEXT, 600))
        parts.append(t(780, y + 44, ar, 28, MUTED, 400, AR, "end"))
        y += 112
    parts.append(visual)
    parts.append(t(80, H - 46, "Illustrative preview of the addon UI", 18, "#5d6d82", 400))
    parts.append(t(W - 80, H - 46, f"{n}/5", 20, "#5d6d82", 600, EN, "end"))
    parts.append("</svg>")
    svg = "\n".join(parts)
    name = f"Rafeeq-{n}.svg"
    open(name, "w", encoding="utf-8").write(svg)
    subprocess.run(["rsvg-convert", "-w", str(W), "-h", str(H), name, "-o", f"Rafeeq-feature-{n}.png"], check=True)

# ---------------------------------------------------------------- 1 tracker
def tracker_visual():
    x, y, w = 1060, 170, 700
    s = panel(x, y, w, 690)
    s += f'<rect x="{x}" y="{y}" width="{w}" height="56" rx="14" fill="{CYAN}" fill-opacity="0.14"/>'
    s += t(x + w - 22, y + 40, "المهام", 32, CYAN, 700, AR, "end")
    s += t(x + 22, y + 38, "7/25", 24, "#b9dcff", 700)
    s += f'<rect x="{x+92}" y="{y+16}" width="40" height="26" rx="5" fill="{CYAN}" fill-opacity="0.3"/>' + t(x + 112, y + 36, "EN", 16, TEXT, 700, EN, "middle")
    rows = [
        (">> ", "[12] The Defias Brotherhood", "1,450 xp", "#ffff40", [("Defias Messenger slain: 3/5", False)]),
        ("", "[11] Red Leather Bandanas", "850 xp", "#ffff40", [("Red Leather Bandana: 15/15", True)]),
        ("", "[13] Furlbrow's Deed", "975 xp", "#ff9a40", None),
        (">> ", "[10] Patrolling Westfall", "780 xp", "#40c040", [("Harvest Golem slain: 7/10", False), ("Murloc Raider slain: 10/10", True)]),
        ("", "[12] Westfall Stew", "1,100 xp", "#ffff40", [("Stringy Vulture Meat: 2/3", False), ("Goretusk Snout: 3/3", True)]),
    ]
    yy = y + 100
    for mark, title, xp, col, objs in rows:
        if mark:
            s += t(x + 22, yy, ">>", 24, "#44ff66", 800)
            s += t(x + 58, yy, title, 25, col, 700)
        else:
            s += t(x + 22, yy, title, 25, col, 700)
        s += t(x + w - 22, yy, xp, 21, "#8cc8ff", 700, EN, "end")
        yy += 34
        if objs is None:
            s += t(x + w - 46, yy, "جاهزة للتسليم", 24, "#5cff7a", 700, AR, "end")
            yy += 40
        else:
            for txt, done in objs:
                s += t(x + 46, yy, "- " + txt, 21, "#74d874" if done else "#d8d8d8", 500)
                yy += 30
            yy += 12
    s += f'<line x1="{x+20}" y1="{y+590}" x2="{x+w-20}" y2="{y+590}" stroke="{CYAN}" stroke-opacity="0.2"/>'
    s += t(x + w - 22, y + 628, "اللفل الجاي بعد 42 دقيقة", 22, "#c0c0c0", 500, AR, "end")
    s += t(x + w - 22, y + 664, "خبرة المهام الجاهزة: 1,950", 24, "#8cc8ff", 700, AR, "end")
    return s

frame(1, "Smart quest tracker", "متتبع مهام ذكي",
      [("XP for every quest + XP waiting to turn in", "الخبرة لكل مهمة، وكم خبرة تنتظرك عند التسليم"),
       ("Time to next level and XP per hour", "الوقت المتوقع للفل الجاي وكم خبرة تجمع في الساعة"),
       (">> marks quests you can finish right here", "علامة >> على المهام اللي تقدر تخلصها وأنت مكانك"),
       ("Color-coded by difficulty, collapsible", "ألوان حسب الصعوبة، وتقدر تطوي أي مهمة")],
      tracker_visual())

# ---------------------------------------------------------------- 2 suggestions
def suggest_visual():
    x, y, w = 1060, 170, 700
    s = panel(x, y, w, 690)
    s += t(x + w - 22, y + 52, "قريبة منك - خلصها الحين", 30, CYAN, 700, AR, "end")
    yy = y + 104
    for title, d in [("Patrolling Westfall", "38yd"), ("The Defias Brotherhood", "64yd"), ("Westfall Stew", "121yd")]:
        s += f'<rect x="{x+16}" y="{yy-30}" width="{w-32}" height="44" rx="8" fill="#44ff66" fill-opacity="0.06"/>'
        s += t(x + 30, yy, title, 25, "#6dff8c", 700) + t(x + w - 110, yy, d, 22, "#8cc8ff", 700, EN, "end")
        s += f'<circle cx="{x+w-60}" cy="{yy-8}" r="15" fill="#44ff66" fill-opacity="0.2" stroke="#44ff66"/>'
        s += f'<path d="M{x+w-68} {yy-8} l6 7 l11 -13" fill="none" stroke="#44ff66" stroke-width="4" stroke-linecap="round"/>'
        yy += 58
    yy += 28
    s += t(x + w - 22, yy, "مهام متاحة في المنطقة", 30, CYAN, 700, AR, "end")
    yy += 54
    for title, d in [("[11] The Forgotten Heirloom", "210yd"), ("[12] Poor Old Blanchy", "260yd"),
                     ("[13] The Coastal Menace", "480yd"), ("[14] Keeper of the Flame", "655yd")]:
        s += t(x + 30, yy, title, 25, "#ffd24a", 700) + t(x + w - 130, yy, d, 22, "#8cc8ff", 700, EN, "end")
        s += f'<circle cx="{x+w-92}" cy="{yy-8}" r="15" fill="#44ff66" fill-opacity="0.15" stroke="#44ff66"/>'
        s += f'<path d="M{x+w-100} {yy-8} l6 7 l11 -13" fill="none" stroke="#44ff66" stroke-width="4" stroke-linecap="round"/>'
        s += f'<circle cx="{x+w-50}" cy="{yy-8}" r="15" fill="#ff5050" fill-opacity="0.15" stroke="#ff6060"/>'
        s += f'<path d="M{x+w-57} {yy-15} l14 14 M{x+w-43} {yy-15} l-14 14" stroke="#ff6060" stroke-width="4" stroke-linecap="round"/>'
        yy += 58
    s += t(x + w / 2, y + 660, "Do it  /  Skip", 22, MUTED, 600, EN, "middle")
    return s

frame(2, "Finish what is nearby", "خلص اللي حولك قبل ما تمشي",
      [("Nearby: quests you can finish within 150 yards", "قريبة منك: مهامك اللي أهدافها في حدود 150 ياردة"),
       ("Best new quests in the zone, sorted for you", "أفضل المهام الجديدة في المنطقة، مرتبة على حسبك"),
       ("Do it = guide me there, Skip = hide it", "Do = وجّهني لها، Skip = اخفها"),
       ("Knows what you finished, what you have", "يعرف شو خلصت وشو في سجلك تلقائياً")],
      suggest_visual())

# ---------------------------------------------------------------- 3 map + arrow
def map_visual():
    x, y, w, h = 1000, 170, 820, 690
    s = f'<g filter="url(#shadow)"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="16" fill="#2b3a2a" stroke="{GOLD}" stroke-opacity="0.6" stroke-width="3"/></g>'
    s += f'<clipPath id="mapclip"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="16"/></clipPath><g clip-path="url(#mapclip)">'
    # terrain
    s += f'<path d="M{x} {y+470} C {x+200} {y+420}, {x+260} {y+560}, {x+480} {y+520} S {x+760} {y+600}, {x+w} {y+560} V {y+h} H {x} Z" fill="#23506a" fill-opacity="0.85"/>'
    s += f'<path d="M{x+60} {y+80} C {x+200} {y+40}, {x+330} {y+140}, {x+300} {y+260} S {x+120} {y+330}, {x+80} {y+220} Z" fill="#3c4d2d"/>'
    s += f'<path d="M{x+500} {y+60} C {x+640} {y+30}, {x+790} {y+120}, {x+760} {y+260} S {x+560} {y+300}, {x+520} {y+200} Z" fill="#46562f"/>'
    s += f'<path d="M{x+40} {y+640} C {x+260} {y+360}, {x+520} {y+420}, {x+780} {y+120}" fill="none" stroke="#c9a46a" stroke-opacity="0.55" stroke-width="10"/>'
    # route dashed
    s += f'<path d="M{x+330} {y+430} C {x+380} {y+340}, {x+470} {y+330}, {x+560} {y+250}" fill="none" stroke="{CYAN}" stroke-width="5" stroke-dasharray="4 14" stroke-linecap="round"/>'
    def pin(px, py, kind):
        out = f'<g filter="url(#glow)"><circle cx="{px}" cy="{py}" r="17" fill="#0b1422" stroke="{GOLD}" stroke-width="3"/>'
        if kind == "kill":
            out += f'<circle cx="{px}" cy="{py-2}" r="8" fill="#e8e8e8"/><rect x="{px-5}" y="{py+3}" width="10" height="6" fill="#e8e8e8"/><circle cx="{px-3}" cy="{py-3}" r="2.4" fill="#0b1422"/><circle cx="{px+3}" cy="{py-3}" r="2.4" fill="#0b1422"/>'
        elif kind == "loot":
            out += f'<path d="M{px-8} {py-3} h16 l-2 12 h-12 z" fill="#f0c35a"/><path d="M{px-5} {py-3} q5 -8 10 0" fill="none" stroke="#f0c35a" stroke-width="2.5"/>'
        elif kind == "turn":
            out += t(px, py + 9, "?", 26, "#ffd24a", 900, EN, "middle")
        else:
            out += t(px, py + 9, "!", 26, "#ffd24a", 900, EN, "middle")
        return out + "</g>"
    for px, py in [(560, 250), (600, 220), (640, 270), (590, 300)]:
        s += pin(x + px, y + py, "kill")
    for px, py in [(220, 150), (260, 200), (180, 220)]:
        s += pin(x + px, y + py, "loot")
    s += pin(x + 690, y + 420, "turn") + pin(x + 140, y + 420, "avail") + pin(x + 430, y + 600, "avail")
    # player
    s += f'<g transform="translate({x+330} {y+430}) rotate(35)"><path d="M0 -20 L13 14 L0 6 L-13 14 Z" fill="#ffffff" stroke="#000" stroke-width="2"/></g>'
    s += "</g>"
    # guide arrow widget
    ax, ay = x + 640, y + 40
    s += f'<g filter="url(#shadow)"><rect x="{ax}" y="{ay}" width="160" height="170" rx="14" fill="#0b1422" fill-opacity="0.9" stroke="{CYAN}" stroke-opacity="0.5" stroke-width="2"/></g>'
    s += f'<g transform="translate({ax+80} {ay+62}) rotate(30)" filter="url(#glow)"><path d="M0 -42 L26 28 L0 12 L-26 28 Z" fill="#4cff6a"/></g>'
    s += t(ax + 80, ay + 132, "142 yd", 26, TEXT, 800, EN, "middle")
    s += t(ax + 80, ay + 158, "Harvest Golems", 16, "#ffd24a", 600, EN, "middle")
    # legend
    lx, ly = x + 24, y + h - 64
    s += f'<rect x="{lx}" y="{ly}" width="560" height="46" rx="10" fill="#0b1422" fill-opacity="0.85"/>'
    s += t(lx + 18, ly + 31, "Kill   Loot   ? Turn in   ! New quest", 22, TEXT, 600)
    return s

frame(3, "Guide arrow + map pins", "سهم يوجّهك وعلامات على الخريطة",
      [("Arrow to the nearest objective, then the turn-in", "السهم يوديك لأقرب هدف، وبعدها للـ NPC اللي تسلمه"),
       ("Green when you face it, red when it's behind you", "يتلون أخضر لما تكون متجه صح، وأحمر لما يكون الهدف وراك"),
       ("Kill / loot / turn-in / new quest pins", "علامات القتل واللوت والتسليم والمهام الجديدة"),
       ("World map and minimap", "على الخريطة الكبيرة والميني ماب")],
      map_visual())

# ---------------------------------------------------------------- 4 macros
def macro_visual():
    s = ""
    cards = [("RF_ST", "Single target", ["#showtooltip", "/startattack", "/cast Victory Rush", "/cast Execute",
                                          "/cast Overpower", "/cast Mortal Strike", "/cast Heroic Strike"]),
             ("RF_AOE", "AoE", ["#showtooltip", "/startattack", "/cast Thunder Clap", "/cast Whirlwind",
                                "/cast Demoralizing Shout", "/cast Cleave"]),
             ("RF_CD", "Cooldowns > 7 sec", ["#showtooltip", "/startattack", "/cast Recklessness", "/cast Death Wish",
                                             "/cast Bloodrage", "/cast Mortal Strike", "/cast Intercept"])]
    for i, (name, sub, lines) in enumerate(cards):
        x, y = 960 + i * 300, 200 + (i % 2) * 40
        s += panel(x, y, 280, 560)
        s += f'<rect x="{x+20}" y="{y+22}" width="64" height="64" rx="10" fill="#1d2b3f" stroke="{GOLD}" stroke-width="2"/>'
        s += t(x + 52, y + 66, "?", 34, GOLD, 900, EN, "middle")
        s += t(x + 100, y + 52, name, 28, GOLD, 800) + t(x + 100, y + 80, sub, 17, MUTED, 600)
        yy = y + 136
        for ln in lines:
            col = "#7fb2d9" if ln.startswith("#") or ln.startswith("/startattack") else TEXT
            s += t(x + 22, yy, ln, 18, col, 500, "Noto Sans")
            yy += 34
        s += f'<rect x="{x+20}" y="{y+500}" width="240" height="36" rx="8" fill="{CYAN}" fill-opacity="0.18" stroke="{CYAN}" stroke-opacity="0.5"/>'
        s += t(x + 140, y + 524, "Save macro", 18, TEXT, 700, EN, "middle")
    return s

frame(4, "Auto macro maker", "صانع الماكرو التلقائي",
      [("Builds Single-target, AoE and Cooldown macros", "يسوي لك ماكرو للهدف الواحد، وللضرب الجماعي، وللكول داون"),
       ("Only spells you know, in priority order", "بس السكلات اللي تعرفها، ومرتبة حسب الأولوية"),
       ("Spells on cooldown are skipped by the game itself", "اللعبة نفسها تتخطى السكل اللي على كول داون"),
       ("Edit before saving; 255-char safe", "تقدر تعدّل قبل الحفظ، وما يتعدى 255 حرف")],
      macro_visual())

# ---------------------------------------------------------------- 5 language + QoL
def qol_visual():
    x, y = 1040, 170
    s = panel(x, y, 720, 250)
    s += t(x + 360, y + 62, "اختر لغة الإضافة - تقدر تغيرها أي وقت", 28, TEXT, 700, AR, "middle")
    s += t(x + 360, y + 98, "Choose the addon language - change it any time", 20, MUTED, 500, EN, "middle")
    s += f'<rect x="{x+400}" y="{y+140}" width="240" height="70" rx="12" fill="{CYAN}" fill-opacity="0.35" stroke="{CYAN}"/>'
    s += t(x + 520, y + 188, "العربية", 34, TEXT, 700, AR, "middle")
    s += f'<rect x="{x+80}" y="{y+140}" width="240" height="70" rx="12" fill="{CYAN}" fill-opacity="0.12" stroke="{CYAN}" stroke-opacity="0.5"/>'
    s += t(x + 200, y + 186, "English", 30, TEXT, 700, EN, "middle")
    y2 = y + 300
    s += panel(x, y2, 720, 390, "Chat")
    lines = [("Rafeeq:", " Selling 6 grey items for 4s 85c"), ("Rafeeq:", " Repaired for 1g 12s 40c"),
             ("Rafeeq:", " Updated 4 action bar spells to their highest rank"),
             ("Rafeeq:", " Level 14 - visit your class trainer for new spells"),
             ("Rafeeq:", " Quest has a reward choice - pick it yourself")]
    yy = y2 + 100
    for a, b in lines:
        s += t(x + 24, yy, a, 22, CYAN, 800) + t(x + 118, yy, b, 22, TEXT, 500)
        yy += 56
    return s

frame(5, "Language + QoL", "لغتك وتسهيلات يومية",
      [("Full Arabic UI with proper connected letters", "واجهة عربية كاملة والحروف موصولة صح"),
       ("Auto-sell greys and auto-repair (guild bank optional)", "بيع الرمادي والتصليح تلقائياً، ومن بنك القيلد إذا تبي"),
       ("Bar spells kept on their highest rank", "سكلات البار تتحدث لأعلى رتبة تلقائياً"),
       ("Auto accept / turn-in, never picks rewards for you", "قبول وتسليم تلقائي، وما يختار الجائزة بدالك")],
      qol_visual())
print("done")
