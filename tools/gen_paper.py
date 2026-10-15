#!/usr/bin/env python3
"""Original procedural art for the paper port (no external assets):
- assets/paper/drawings.png : 12 crayon fridge drawings (4x3 grid of 64px)
- assets/paper/town_board.png : the town map as a papercraft board game (1280x720)
Run: python3 tools/gen_paper.py"""
import math, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont
random.seed(7)
INK = (31, 26, 26)
OUT = "assets/paper/"

def wob(pts, a=2.0):
    return [(x + random.uniform(-a, a), y + random.uniform(-a, a)) for x, y in pts]

def crayon_line(d, pts, col, w=3):
    for i in range(len(pts) - 1):
        d.line([pts[i], pts[i + 1]], fill=col, width=w)

def drawings():
    im = Image.new("RGBA", (256, 192), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    papers = [(255, 252, 235), (235, 248, 255), (255, 240, 245), (240, 255, 235)]
    for i in range(12):
        ox, oy = (i % 4) * 64, (i // 4) * 64
        d.polygon(wob([(ox + 4, oy + 4), (ox + 60, oy + 5), (ox + 59, oy + 60), (ox + 5, oy + 59)], 1.5), fill=papers[i % 4], outline=(200, 190, 170))
        cx, cy = ox + 32, oy + 34
        k = i % 12
        if k == 0:   # sun
            d.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(255, 210, 40))
            for a in range(8):
                t = a * math.pi / 4
                d.line([(cx + 13 * math.cos(t), cy + 13 * math.sin(t)), (cx + 20 * math.cos(t), cy + 20 * math.sin(t))], fill=(255, 170, 30), width=3)
        elif k == 1:  # house
            d.rectangle([cx - 14, cy - 4, cx + 14, cy + 18], fill=(230, 80, 70))
            d.polygon([(cx - 18, cy - 4), (cx, cy - 20), (cx + 18, cy - 4)], fill=(120, 80, 60))
            d.rectangle([cx - 4, cy + 6, cx + 4, cy + 18], fill=(90, 60, 40))
        elif k == 2:  # family stick figures
            for j, col in enumerate([(70, 90, 140), (90, 160, 110), (230, 110, 150), (240, 190, 50)]):
                x = ox + 12 + j * 13; h = 20 if j < 2 else 13
                d.ellipse([x - 4, cy + 14 - h - 8, x + 4, cy + 14 - h], outline=col, width=2)
                crayon_line(d, [(x, cy + 14 - h), (x, cy + 8), (x - 4, cy + 16)], col, 2)
                crayon_line(d, [(x, cy + 8), (x + 4, cy + 16)], col, 2)
            d.text((ox + 8, oy + 8), "US", fill=(200, 40, 70))
        elif k == 3:  # DAD heart
            d.polygon([(cx, cy + 16), (cx - 18, cy - 2), (cx - 10, cy - 14), (cx, cy - 6), (cx + 10, cy - 14), (cx + 18, cy - 2)], fill=(240, 90, 120))
            d.text((cx - 11, cy - 6), "DAD", fill=(255, 255, 255))
        elif k == 4:  # rainbow
            for j, col in enumerate([(230, 60, 60), (250, 160, 40), (250, 220, 60), (90, 190, 90), (70, 130, 220)]):
                r = 24 - j * 4
                d.arc([cx - r, cy - r + 8, cx + r, cy + r + 8], 180, 360, fill=col, width=3)
        elif k == 5:  # tomato named Server
            d.ellipse([cx - 14, cy - 10, cx + 14, cy + 14], fill=(230, 60, 40))
            d.polygon([(cx - 6, cy - 10), (cx, cy - 18), (cx + 6, cy - 10)], fill=(60, 150, 60))
            d.text((ox + 8, oy + 48), "SERVER", fill=INK)
        elif k == 6:  # dad at computer, frowny
            d.rectangle([cx - 4, cy - 14, cx + 22, cy + 4], fill=(60, 60, 70)); d.rectangle([cx - 1, cy - 11, cx + 19, cy + 1], fill=(90, 220, 120))
            d.ellipse([cx - 22, cy - 12, cx - 8, cy + 2], outline=(70, 90, 140), width=2)
            d.arc([cx - 19, cy - 4, cx - 11, cy + 2], 200, 340, fill=INK, width=2)
        elif k == 7:  # dog (we don't have a dog)
            d.ellipse([cx - 16, cy - 4, cx + 10, cy + 10], fill=(170, 120, 70)); d.ellipse([cx + 4, cy - 12, cx + 18, cy + 2], fill=(170, 120, 70))
            d.text((ox + 6, oy + 6), "PLS?", fill=(70, 130, 220))
        elif k == 8:  # dragon (Lily)
            d.polygon(wob([(cx - 20, cy + 10), (cx - 4, cy - 14), (cx + 6, cy - 2), (cx + 20, cy - 10), (cx + 12, cy + 12)], 1), fill=(90, 180, 110))
            d.polygon([(cx + 20, cy - 10), (cx + 28, cy - 14), (cx + 26, cy - 4)], fill=(250, 140, 40))
        elif k == 9:  # flower
            for a in range(5):
                t = a * 2 * math.pi / 5
                d.ellipse([cx + 9 * math.cos(t) - 6, cy - 6 + 9 * math.sin(t) - 6, cx + 9 * math.cos(t) + 6, cy - 6 + 9 * math.sin(t) + 6], fill=(240, 120, 200))
            d.ellipse([cx - 4, cy - 10, cx + 4, cy - 2], fill=(255, 220, 60)); d.line([(cx, cy - 2), (cx, cy + 20)], fill=(60, 150, 60), width=3)
        elif k == 10:  # mom & dad holding hands
            for x, col in [(cx - 10, (70, 90, 140)), (cx + 10, (90, 160, 110))]:
                d.ellipse([x - 5, cy - 18, x + 5, cy - 8], outline=col, width=2); crayon_line(d, [(x, cy - 8), (x, cy + 10)], col, 2)
            crayon_line(d, [(cx - 10, cy), (cx + 10, cy)], (230, 80, 120), 2)
            d.polygon([(cx, cy - 26), (cx - 4, cy - 30), (cx, cy - 24), (cx + 4, cy - 30)], fill=(230, 60, 90))
        else:  # big question mark (June)
            d.text((cx - 6, cy - 14), "?", fill=(200, 40, 70), font=ImageFont.load_default())
            d.arc([cx - 12, cy - 18, cx + 12, cy + 6], 180, 90, fill=(200, 40, 70), width=4); d.ellipse([cx - 3, cy + 12, cx + 3, cy + 18], fill=(200, 40, 70))
    im.save(OUT + "drawings.png")

def board():
    W, H = 1280, 720
    im = Image.new("RGB", (W, H), (176, 136, 92))
    d = ImageDraw.Draw(im)
    # corrugated cardboard texture
    for y in range(0, H, 6):
        d.line([(0, y), (W, y)], fill=(168, 128, 86) if (y // 6) % 2 else (182, 142, 98), width=3)
    for i in range(5000):
        x, y = random.randrange(W), random.randrange(H)
        d.point((x, y), fill=(150, 112, 74))
    # felt land (construction paper), with torn edge
    land = wob([(40, 40), (1240, 36), (1244, 684), (36, 688)], 6)
    d.polygon(land, fill=(128, 176, 102), outline=INK)
    # river (paper strip)
    river = [(0, 560), (200, 520), (420, 600), (640, 560), (860, 650), (1280, 600)]
    d.line(river, fill=(90, 150, 210), width=46)
    d.line(river, fill=(130, 185, 235), width=20)
    # roads: cream paper strips with ink dashes
    roads = [[(80, 470), (380, 300), (740, 300), (1180, 300)], [(380, 300), (430, 560), (760, 470), (1100, 560)], [(740, 300), (740, 470)], [(1020, 160), (1020, 300)], [(120, 240), (380, 300)]]
    for r in roads:
        d.line(r, fill=INK, width=40); d.line(r, fill=(238, 228, 200), width=32)
        for i in range(len(r) - 1):
            (x0, y0), (x1, y1) = r[i], r[i + 1]
            n = int(math.hypot(x1 - x0, y1 - y0) / 30)
            for k in range(n):
                if k % 2 == 0:
                    t0, t1 = k / n, (k + 0.5) / n
                    d.line([(x0 + (x1 - x0) * t0, y0 + (y1 - y0) * t0), (x0 + (x1 - x0) * t1, y0 + (y1 - y0) * t1)], fill=(220, 170, 60), width=3)
    # trees: lollipop cut-outs
    for i in range(70):
        x, y = random.randrange(60, 1220), random.randrange(60, 670)
        if any(abs(y - (300 if x > 380 else 470 - (x - 80) * 0.57)) < 34 for _ in [0]): continue
        r = random.randint(9, 15)
        d.ellipse([x - r + 3, y - r + 4, x + r + 3, y + r + 4], fill=(80, 110, 60))
        d.ellipse([x - r, y - r, x + r, y + r], fill=random.choice([(70, 140, 70), (90, 160, 80), (60, 125, 75)]), outline=INK, width=2)
    # buildings at the map anchors (anchor = top-centre of the button: building sits just above it)
    places = {"home": (0.125, 0.72, (240, 200, 120), "house"), "school": (0.344, 0.33, (210, 100, 80), "school"), "gas": (0.578, 0.62, (240, 110, 60), "gas"),
              "park": (0.353, 0.77, (90, 170, 90), "park"), "pharmacy": (0.094, 0.33, (220, 240, 230), "rx"), "dental": (0.844, 0.78, (200, 225, 245), "tooth"),
              "diner": (0.5, 0.39, (230, 90, 90), "pie"), "coffee": (0.797, 0.222, (150, 110, 80), "cup"), "office": (0.906, 0.39, (150, 160, 175), "office")}
    for k, (fx, fy, col, kind) in places.items():
        x, y = fx * W, fy * H - 34
        if kind == "park":
            d.ellipse([x - 52, y - 26, x + 52, y + 26], fill=(110, 185, 105), outline=INK, width=3)
            d.ellipse([x - 22, y - 12, x + 18, y + 10], fill=(110, 170, 225), outline=INK, width=2)
            continue
        w, h = (70, 44) if kind not in ("school", "office") else (96, 54)
        d.polygon(wob([(x - w / 2 + 6, y - h / 2 + 8), (x + w / 2 + 6, y - h / 2 + 8), (x + w / 2 + 6, y + h / 2 + 8), (x - w / 2 + 6, y + h / 2 + 8)], 1), fill=(90, 66, 44))  # drop shadow
        d.polygon(wob([(x - w / 2, y - h / 2), (x + w / 2, y - h / 2), (x + w / 2, y + h / 2), (x - w / 2, y + h / 2)], 1.5), fill=col, outline=INK)
        d.polygon(wob([(x - w / 2 - 6, y - h / 2), (x, y - h / 2 - 22), (x + w / 2 + 6, y - h / 2)], 1.5), fill=tuple(int(c * 0.7) for c in col), outline=INK)
        d.rectangle([x - 7, y + h / 2 - 18, x + 7, y + h / 2], fill=(80, 55, 40), outline=INK)
        # icon
        if kind == "house": d.polygon([(x + 14, y - 8), (x + 24, y - 8), (x + 24, y + 2), (x + 14, y + 2)], fill=(150, 210, 240), outline=INK)
        if kind == "rx": d.rectangle([x - 4, y - 14, x + 4, y + 6], fill=(220, 50, 50)); d.rectangle([x - 12, y - 8, x + 12, y], fill=(220, 50, 50))
        if kind == "gas": d.rectangle([x + 22, y - 6, x + 30, y + 18], fill=(220, 50, 40), outline=INK)
        if kind == "cup": d.rectangle([x - 8, y - 10, x + 8, y + 6], fill=(255, 255, 255), outline=INK); d.arc([x + 4, y - 6, x + 14, y + 2], 270, 90, fill=INK, width=2)
        if kind == "pie": d.polygon([(x - 14, y + 6), (x + 14, y + 6), (x + 4, y - 14)], fill=(240, 190, 90), outline=INK); d.line([(x - 14, y + 6), (x + 4, y - 14)], fill=(170, 90, 50), width=4)
        if kind == "tooth": d.polygon([(x - 9, y - 10), (x + 9, y - 10), (x + 6, y + 8), (x, y + 2), (x - 6, y + 8)], fill=(255, 255, 255), outline=INK)
        if kind == "office":
            for i in range(3):
                for j in range(2): d.rectangle([x - 34 + i * 26, y - 18 + j * 18, x - 20 + i * 26, y - 8 + j * 18], fill=(160, 210, 240), outline=INK)
        if kind == "school": d.rectangle([x - 2, y - 52, x, y - 26], fill=INK); d.polygon([(x, y - 52), (x + 18, y - 46), (x, y - 40)], fill=(230, 60, 60))
    # board-game touches: compass, title tag, dice, pins
    d.ellipse([1150, 600, 1230, 680], fill=(238, 228, 200), outline=INK, width=3)
    d.polygon([(1190, 606), (1198, 640), (1190, 674), (1182, 640)], fill=(220, 60, 60), outline=INK)
    d.polygon(wob([(52, 640), (330, 636), (334, 690), (48, 694)], 2), fill=(250, 245, 228), outline=INK)
    try:
        f = ImageFont.truetype("DejaVuSans-Bold.ttf", 30)
    except Exception:
        f = ImageFont.load_default()
    d.text((70, 646), "BROOKFIELD: THE GAME", fill=INK, font=f)
    d.rectangle([1050, 640, 1090, 680], fill=(250, 250, 245), outline=INK, width=3)
    for px, py in [(1060, 650), (1080, 670), (1070, 660)]: d.ellipse([px - 3, py - 3, px + 3, py + 3], fill=INK)
    im = im.filter(ImageFilter.SMOOTH)
    im.save(OUT + "town_board.png")

if __name__ == "__main__":
    drawings(); board(); print("ok")

def lifeos():
    im = Image.new("RGBA", (96, 96), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.polygon(wob([(22, 6), (74, 8), (76, 90), (20, 88)], 1.5), fill=(76, 86, 108), outline=INK)
    d.rectangle([28, 16, 68, 74], fill=(158, 218, 240), outline=INK, width=2)
    d.ellipse([36, 32, 44, 40], fill=INK); d.ellipse([52, 32, 60, 40], fill=INK)
    d.arc([36, 40, 60, 60], 20, 160, fill=INK, width=3)
    d.ellipse([45, 79, 51, 85], fill=(220, 220, 210))
    im.save(OUT + "lifeos.png")

lifeos()
