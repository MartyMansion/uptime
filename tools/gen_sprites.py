#!/usr/bin/env python3
"""Procedural pixel-art generator for Uptime placeholder-but-real art.
Original, license-clean (CC0 by the project). Re-run: python3 tools/gen_sprites.py
Style: 16px grid, top-down 3/4 view, 1px dark outline, max ~6 colors per sprite,
rendered in-engine at 3x with nearest filtering."""
from PIL import Image
import os, random

OUT = os.path.join(os.path.dirname(__file__), "..", "assets")
OUTLINE = (34, 28, 40, 255)
SKIN = {"a": (236, 188, 150, 255), "b": (198, 140, 100, 255), "c": (150, 98, 66, 255)}

def img(w, h): return Image.new("RGBA", (w, h), (0, 0, 0, 0))
def rect(im, x, y, w, h, c):
    for i in range(x, x + w):
        for j in range(y, y + h):
            if 0 <= i < im.width and 0 <= j < im.height: im.putpixel((i, j), c)
def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height: im.putpixel((x, y), c)
def shade(c, f): return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (255,)
def outline(im):
    src = im.copy()
    for x in range(im.width):
        for y in range(im.height):
            if src.getpixel((x, y))[3] == 0:
                for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                    nx, ny = x+dx, y+dy
                    if 0 <= nx < im.width and 0 <= ny < im.height and src.getpixel((nx, ny))[3] and src.getpixel((nx, ny)) != OUTLINE:
                        im.putpixel((x, y), OUTLINE); break
    return im
def save(im, *path):
    p = os.path.join(OUT, *path); os.makedirs(os.path.dirname(p), exist_ok=True); im.save(p)

# ---------------------------------------------------------------- characters
CHARS = {
    # name: skin, hair, hair style, shirt, pants, kid?, extras
    "dan":  dict(skin="a", hair=(110, 72, 40), style="short", shirt=(70, 140, 90), pants=(60, 80, 130), kid=False, glasses=True),
    "jess": dict(skin="b", hair=(40, 30, 30), style="long", shirt=(70, 170, 170), pants=(60, 140, 140), kid=False),
    "lily": dict(skin="a", hair=(220, 180, 90), style="pony", shirt=(150, 90, 190), pants=(80, 70, 120), kid=True),
    "june": dict(skin="a", hair=(200, 90, 50), style="curly", shirt=(240, 200, 70), pants=(240, 200, 70), kid=True),
    "gary": dict(skin="a", hair=(170, 170, 170), style="bald", shirt=(235, 235, 240), pants=(180, 160, 120), kid=False, tie=(190, 50, 50), wide=True),
}
DIRS = ["down", "left", "right", "up"]

def draw_char(spec, d, frame):
    im = img(16, 24)
    sk = SKIN[spec["skin"]]; hair = spec["hair"] + (255,); shirt = spec["shirt"] + (255,); pants = spec["pants"] + (255,)
    kid = spec["kid"]
    hy = 9 if kid else 2          # head top
    hh = 7 if kid else 8
    by = hy + hh                  # body top
    bh = 5 if kid else 8
    ly = by + bh                  # legs top
    lh = 24 - 1 - ly
    bw = 10 if spec.get("wide") else 8
    bx = 8 - bw // 2
    side = d in ("left", "right")
    # legs (walk cycle)
    step = [0, 1, -1][frame]
    shoe = OUTLINE
    if side:
        a, b = (6, 9) if step == 0 else ((5, 10) if step else (7, 8))
        for lx in {a, b}:
            rect(im, lx, ly, 2, lh, pants); rect(im, lx, ly + lh - 1, 2, 1, shoe)
    else:
        l1 = lh - (1 if step == 1 else 0); l2 = lh - (1 if step == -1 else 0)
        rect(im, 5, ly, 3, l1, pants); rect(im, 5, ly + l1 - 1, 3, 1, shoe)
        rect(im, 8, ly, 3, l2, pants); rect(im, 8, ly + l2 - 1, 3, 1, shoe)
    # body + arms
    rect(im, bx, by, bw, bh, shirt)
    rect(im, bx, by + bh - 1, bw, 1, shade(shirt, 0.8))
    if not side:
        sw = [0, 1, -1][frame]
        rect(im, bx - 1, by + 1 + max(0, sw), 1, bh - 2, shirt); px(im, bx - 1, by + bh - 1 + max(0, sw) - 1, sk)
        rect(im, bx + bw, by + 1 + max(0, -sw), 1, bh - 2, shirt); px(im, bx + bw, by + bh - 1 + max(0, -sw) - 1, sk)
    else:
        ax = 8 + [0, 1, -1][frame] * (1 if d == "right" else -1)
        rect(im, ax - 1, by + 1, 2, bh - 2, shade(shirt, 0.85)); px(im, ax - 1, by + bh - 1, sk)
    if spec.get("tie") and d == "down":
        rect(im, 7, by, 2, bh - 2, spec["tie"] + (255,))
    # head
    rect(im, 4, hy, 8, hh, sk)
    st = spec["style"]
    if d == "up":
        rect(im, 4, hy, 8, hh - 1, hair)
        if st == "bald": rect(im, 5, hy, 6, 2, sk)
    else:
        if st != "bald": rect(im, 4, hy, 8, 2, hair)
        else: rect(im, 4, hy + 2, 1, 3, hair); rect(im, 11, hy + 2, 1, 3, hair)
        if st in ("long",) and not side: rect(im, 4, hy, 1, hh + 3, hair); rect(im, 11, hy, 1, hh + 3, hair)
        if st == "curly": [px(im, x, hy - 1, hair) for x in (5, 7, 9)]; rect(im, 4, hy, 1, 4, hair); rect(im, 11, hy, 1, 4, hair)
        if st == "pony" and not side: rect(im, 12, hy + 1, 2, 4, hair)
        if side:
            back = 11 if d == "left" else 4
            if st != "bald": rect(im, back - (0 if d == "left" else 0), hy, 1, hh - 2 + (3 if st == "long" else 0), hair)
            if st == "pony": rect(im, 12 if d == "left" else 2, hy + 1, 2, 4, hair)
    ey = hy + (4 if not kid else 3)
    if d == "down":
        px(im, 6, ey, OUTLINE); px(im, 9, ey, OUTLINE)
        px(im, 7, ey + 2, shade(sk, 0.75)); px(im, 8, ey + 2, shade(sk, 0.75))
        if spec.get("glasses"): rect(im, 5, ey - 1, 2, 1, OUTLINE); rect(im, 9, ey - 1, 2, 1, OUTLINE); px(im, 8, ey - 1, OUTLINE)
    elif side:
        ex = 5 if d == "left" else 10
        px(im, ex, ey, OUTLINE)
        if spec.get("glasses"): px(im, ex, ey - 1, OUTLINE); px(im, ex + (1 if d == "left" else -1), ey - 1, OUTLINE)
    return outline(im)

def gen_characters():
    for name, spec in CHARS.items():
        # columns: 0 stand, 1 step-L, 2 step-R, 3 idle "breath" (upper body bobs 1px)
        sheet = img(16 * 4, 24 * 4)
        for r, d in enumerate(DIRS):
            for f in range(3):
                sheet.paste(draw_char(spec, d, f), (f * 16, r * 24))
            base = draw_char(spec, d, 0)
            cut = 16 if spec["kid"] else 17
            bob = base.copy(); rect(bob, 0, 0, 16, cut + 1, (0, 0, 0, 0))
            bob.alpha_composite(base.crop((0, 0, 16, cut)), (0, 1))
            sheet.paste(bob, (48, r * 24))
        save(sheet, "sprites", "characters", f"{name}.png")
        # portrait: head and shoulders, 2x, on a soft badge
        fr = draw_char(spec, "down", 0)
        top = 7 if spec["kid"] else 0
        crop = fr.crop((0, top, 16, top + 16)).resize((32, 32), Image.NEAREST)
        p = img(32, 32); rect(p, 0, 0, 32, 32, (58, 62, 84, 255)); rect(p, 1, 1, 30, 30, (78, 84, 112, 255))
        p.alpha_composite(crop)
        save(p, "portraits", f"{name}.png")
    # LifeOS "portrait": a smug phone
    p = img(32, 32); rect(p, 0, 0, 32, 32, (58, 62, 84, 255)); rect(p, 9, 3, 14, 26, OUTLINE); rect(p, 10, 5, 12, 20, (120, 220, 200, 255))
    rect(p, 13, 11, 2, 2, OUTLINE); rect(p, 18, 11, 2, 2, OUTLINE); rect(p, 13, 17, 7, 1, OUTLINE); px(p, 12, 16, OUTLINE); px(p, 20, 16, OUTLINE)
    save(p, "portraits", "lifeos.png")

# ---------------------------------------------------------------- tiny 3x5 font for signs
GLYPHS = {
 "A":"010101111101101","B":"110101110101110","C":"011100100100011","D":"110101101101110","E":"111100110100111",
 "G":"011100101101011","H":"101101111101101","I":"111010010010111","L":"100100100100111","M":"101111111101101",
 "N":"101111111111101","O":"010101101101010","P":"110101110100100","R":"110101110101101","S":"011100010001110",
 "T":"111010010010010","U":"101101101101111","Y":"101101010010010","K":"101101110101101","F":"111100110100100",
 "-":"000000111000000"," ":"000000000000000","W":"101101111111101",
}
def text(im, x, y, s, c):
    for ch in s:
        g = GLYPHS.get(ch, GLYPHS[" "])
        for i, b in enumerate(g):
            if b == "1": px(im, x + i % 3, y + i // 3, c)
        x += 4

# ---------------------------------------------------------------- tiles
def noise_tile(base, spots, seed, n=10):
    random.seed(seed); t = img(16, 16); rect(t, 0, 0, 16, 16, base)
    for _ in range(n): px(t, random.randrange(16), random.randrange(16), spots)
    return t
def gen_tiles():
    wood = img(16, 16); rect(wood, 0, 0, 16, 16, (150, 105, 65, 255))
    for y in (3, 7, 11, 15): rect(wood, 0, y, 16, 1, (120, 82, 50, 255))
    for x, y in ((5, 0), (12, 4), (2, 8), (9, 12)): rect(wood, x, y, 1, 3, (120, 82, 50, 255))
    save(wood, "tiles", "floor_wood.png")
    kt = img(16, 16)
    for i in range(2):
        for j in range(2): rect(kt, i*8, j*8, 8, 8, (230, 225, 210, 255) if (i+j) % 2 == 0 else (180, 190, 200, 255))
    save(kt, "tiles", "floor_kitchen.png")
    save(noise_tile((220, 160, 180, 255), (240, 200, 210, 255), 1), "tiles", "floor_carpet_pink.png")
    save(noise_tile((90, 100, 120, 255), (110, 120, 140, 255), 2, 18), "tiles", "floor_office.png")
    save(noise_tile((60, 62, 68, 255), (80, 82, 88, 255), 3, 14), "tiles", "asphalt.png")
    side = img(16, 16); rect(side, 0, 0, 16, 16, (180, 180, 175, 255)); rect(side, 0, 15, 16, 1, (150, 150, 145, 255)); rect(side, 15, 0, 1, 16, (150, 150, 145, 255))
    save(side, "tiles", "sidewalk.png")
    save(noise_tile((90, 160, 80, 255), (70, 135, 65, 255), 4, 20), "tiles", "grass.png")
    w = img(16, 16); rect(w, 0, 0, 16, 16, (225, 210, 180, 255)); rect(w, 0, 12, 16, 4, (160, 130, 100, 255)); rect(w, 0, 0, 16, 1, (200, 185, 155, 255))
    save(w, "tiles", "wall.png")
    ow = img(16, 16); rect(ow, 0, 0, 16, 16, (200, 205, 210, 255)); rect(ow, 0, 13, 16, 3, (120, 125, 135, 255))
    save(ow, "tiles", "wall_office.png")
    lane = img(16, 16); rect(lane, 0, 0, 16, 16, (60, 62, 68, 255)); rect(lane, 0, 7, 8, 2, (230, 200, 60, 255))
    save(lane, "tiles", "road_lane.png")

# ---------------------------------------------------------------- props
def prop(name, w, h, fn):
    im = img(w, h); fn(im); outline(im); save(im, "props", name + ".png")
def gen_props():
    def bed(im, sheet=(110, 120, 200, 255)):
        rect(im, 1, 1, im.width - 2, im.height - 2, (120, 80, 50, 255)); rect(im, 3, 3, im.width - 6, 8, (240, 240, 240, 255))
        rect(im, 2, 12, im.width - 4, im.height - 14, sheet); rect(im, 2, 12, im.width - 4, 1, shade(sheet, 0.8))
    prop("bed_double", 32, 40, bed)
    prop("bed_kid", 20, 30, lambda im: bed(im, (240, 150, 190, 255)))
    def counter(im):
        rect(im, 0, 0, 48, 20, (200, 200, 205, 255)); rect(im, 0, 0, 48, 4, (240, 240, 240, 255))
        rect(im, 30, 5, 14, 10, (60, 60, 65, 255)); [rect(im, 32 + 6*i, 7, 4, 3, (110, 110, 115, 255)) for i in range(2)]
        rect(im, 4, 6, 10, 7, (150, 190, 220, 255))
    prop("kitchen_counter", 48, 20, counter)
    def fridge(im):
        rect(im, 0, 0, 16, 30, (230, 235, 240, 255)); rect(im, 0, 10, 16, 1, (170, 175, 180, 255)); rect(im, 13, 3, 1, 5, (150, 150, 155, 255))
        rect(im, 3, 13, 8, 9, (255, 250, 220, 255)); rect(im, 4, 15, 3, 3, (90, 140, 220, 255)); rect(im, 7, 18, 3, 2, (230, 90, 90, 255))  # Lily's comic
    prop("fridge", 16, 30, fridge)
    def table(im):
        rect(im, 0, 2, 32, 18, (170, 120, 70, 255)); rect(im, 0, 2, 32, 2, (195, 145, 90, 255)); rect(im, 6, 8, 6, 4, (240, 240, 240, 255)); rect(im, 20, 9, 5, 5, (230, 180, 60, 255))
    prop("table", 32, 20, table)
    def desk(im, mon=(80, 200, 255, 255)):
        rect(im, 0, 8, im.width, 12, (130, 90, 60, 255)); rect(im, 0, 8, im.width, 2, (160, 115, 80, 255))
        rect(im, 6, 0, 14, 10, (40, 40, 48, 255)); rect(im, 7, 1, 12, 7, mon); rect(im, 12, 10, 2, 1, (40, 40, 48, 255)); rect(im, 22, 11, 6, 3, (220, 220, 220, 255))
    prop("pc_desk", 32, 20, desk)
    prop("office_desk", 32, 20, lambda im: desk(im, (120, 230, 140, 255)))
    def couch(im):
        rect(im, 0, 0, 48, 20, (90, 110, 160, 255)); rect(im, 0, 0, 48, 6, (70, 90, 135, 255)); rect(im, 0, 0, 4, 20, (70, 90, 135, 255)); rect(im, 44, 0, 4, 20, (70, 90, 135, 255))
        rect(im, 23, 7, 1, 12, (70, 90, 135, 255))
    prop("couch", 48, 20, couch)
    def tv(im): rect(im, 0, 4, 32, 6, (100, 70, 50, 255)); rect(im, 4, 0, 24, 5, (30, 30, 35, 255)); rect(im, 20, 6, 4, 2, (60, 60, 60, 255))
    prop("tv_stand", 32, 10, tv)
    def door(im): rect(im, 0, 0, 20, 30, (140, 95, 60, 255)); rect(im, 2, 2, 16, 26, (165, 115, 75, 255)); rect(im, 15, 15, 2, 2, (230, 200, 80, 255))
    prop("door", 20, 30, door)
    def toys(im):
        rect(im, 0, 4, 6, 6, (230, 80, 80, 255)); rect(im, 8, 6, 5, 5, (80, 160, 230, 255)); rect(im, 15, 2, 4, 8, (250, 210, 70, 255)); px(im, 3, 2, (90, 200, 90, 255))
    prop("toys", 20, 12, toys)
    def plant(im): rect(im, 4, 10, 8, 6, (180, 100, 60, 255)); rect(im, 2, 1, 12, 9, (70, 150, 70, 255)); rect(im, 5, 0, 6, 3, (90, 180, 90, 255))
    prop("plant", 16, 16, plant)
    def rug(im): rect(im, 0, 0, 48, 28, (170, 70, 70, 255)); rect(im, 3, 3, 42, 22, (200, 110, 90, 255)); rect(im, 8, 8, 32, 12, (230, 190, 120, 255))
    prop("rug", 48, 28, rug)
    def rack(im):
        rect(im, 0, 0, 16, 32, (40, 42, 50, 255))
        for y in range(3, 30, 4):
            rect(im, 2, y, 12, 3, (70, 72, 82, 255)); px(im, 3, y + 1, (80, 230, 100, 255)); px(im, 5, y + 1, (240, 180, 60, 255) if y % 8 == 3 else (80, 230, 100, 255))
    prop("server_rack", 16, 32, rack)
    def cooler(im): rect(im, 3, 10, 10, 18, (220, 220, 225, 255)); rect(im, 4, 0, 8, 11, (150, 200, 240, 255)); rect(im, 6, 15, 4, 2, (60, 120, 220, 255))
    prop("water_cooler", 16, 28, cooler)
    def printer(im): rect(im, 0, 4, 20, 12, (210, 210, 210, 255)); rect(im, 3, 0, 14, 5, (240, 240, 240, 255)); rect(im, 14, 7, 3, 2, (230, 60, 60, 255))
    prop("printer", 20, 16, printer)
    def car(im):
        rect(im, 2, 0, 28, 46, (60, 100, 170, 255)); rect(im, 5, 8, 22, 9, (150, 200, 230, 255)); rect(im, 5, 32, 22, 6, (150, 200, 230, 255))
        rect(im, 4, 18, 24, 13, (70, 115, 190, 255))
        for x, y in ((0, 5), (30, 5), (0, 35), (30, 35)): rect(im, x, y, 2, 7, (30, 30, 30, 255))
        rect(im, 6, 0, 4, 2, (255, 240, 170, 255)); rect(im, 22, 0, 4, 2, (255, 240, 170, 255))
    prop("car", 32, 46, car)
    def pump(im):
        rect(im, 1, 4, 14, 26, (210, 60, 60, 255)); rect(im, 3, 7, 10, 6, (40, 40, 40, 255)); text(im, 4, 8, "GA", (120, 255, 140, 255))
        rect(im, 3, 16, 10, 2, (240, 240, 240, 255)); rect(im, 0, 0, 16, 5, (240, 240, 240, 255))
    prop("gas_pump", 16, 30, pump)
    def store(im):
        rect(im, 0, 10, 112, 54, (220, 205, 170, 255)); rect(im, 0, 0, 112, 12, (200, 50, 50, 255)); text(im, 38, 3, "GAS-N-SIP", (255, 240, 120, 255))
        rect(im, 6, 20, 40, 26, (140, 200, 230, 255)); rect(im, 66, 20, 40, 26, (140, 200, 230, 255)); rect(im, 48, 26, 16, 38, (90, 70, 60, 255))
        rect(im, 10, 34, 10, 10, (240, 180, 60, 255)); rect(im, 72, 30, 12, 12, (90, 200, 120, 255))
    prop("store_front", 112, 64, store)
    def cooler_b(im):
        rect(im, 0, 0, 40, 32, (200, 210, 220, 255)); rect(im, 2, 2, 36, 28, (160, 220, 240, 255))
        for i in range(6): rect(im, 4 + i * 6, 6, 4, 9, [(200, 150, 50, 255), (60, 120, 60, 255)][i % 2]); rect(im, 4 + i * 6, 18, 4, 9, (180, 60, 60, 255))
    prop("beer_cooler", 40, 32, cooler_b)
    def ccounter(im):
        rect(im, 0, 6, 40, 16, (150, 110, 80, 255)); rect(im, 0, 6, 40, 3, (180, 140, 100, 255)); rect(im, 26, 0, 10, 7, (40, 40, 40, 255)); rect(im, 27, 1, 8, 4, (120, 255, 140, 255))
        for i in range(4): rect(im, 3 + i * 5, 0, 4, 6, [(80, 180, 230, 255), (230, 230, 240, 255)][i % 2])  # tins
    prop("store_counter", 40, 22, ccounter)
    def school(im):
        rect(im, 0, 12, 128, 52, (190, 90, 70, 255)); rect(im, 0, 8, 128, 6, (150, 70, 55, 255)); rect(im, 34, 0, 60, 14, (230, 225, 210, 255)); text(im, 38, 4, "BROOKFIELD EL", OUTLINE)
        for x in (8, 26, 92, 110): rect(im, x, 22, 12, 12, (150, 200, 230, 255))
        rect(im, 54, 34, 20, 30, (110, 70, 50, 255)); rect(im, 63, 34, 1, 30, (80, 50, 35, 255))
    prop("school_front", 128, 64, school)
    def office_front(im):
        rect(im, 0, 0, 96, 20, (70, 80, 110, 255)); text(im, 12, 7, "TRICOUNTY MANAGED", (230, 230, 240, 255))
    prop("office_sign", 96, 20, office_front)
    def gas_sign(im): rect(im, 0, 0, 64, 16, (200, 50, 50, 255)); text(im, 14, 5, "GAS-N-SIP", (255, 240, 120, 255))
    prop("gas_sign", 64, 16, gas_sign)
    def phone(im): rect(im, 0, 0, 10, 18, OUTLINE); rect(im, 1, 2, 8, 13, (120, 220, 200, 255))
    prop("phone", 10, 18, phone)
    def bookshelf(im):
        rect(im, 0, 0, 24, 30, (120, 80, 50, 255))
        for y in (2, 11, 20):
            rect(im, 2, y, 20, 8, (90, 60, 40, 255))
            for i in range(5): rect(im, 3 + i * 4, y + 1, 3, 7, [(200, 80, 80, 255), (80, 140, 210, 255), (230, 200, 80, 255), (120, 190, 120, 255), (190, 120, 200, 255)][(i + y) % 5])
    prop("bookshelf", 24, 30, bookshelf)
    def tree(im): rect(im, 12, 22, 6, 10, (110, 75, 45, 255)); rect(im, 2, 2, 26, 22, (60, 140, 70, 255)); rect(im, 6, 0, 18, 6, (80, 165, 85, 255))
    prop("tree", 30, 32, tree)

if __name__ == "__main__":
    gen_characters(); gen_tiles(); gen_props()
    print("assets written to", os.path.abspath(OUT))
