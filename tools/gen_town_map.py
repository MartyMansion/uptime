"""Generates assets/map/town_map.png: a cozy top-down pixel-art town (Pelican-Town-ish).
Coordinates of places are mirrored in GameState.PLACES (normalized x,y)."""
import random
from PIL import Image, ImageDraw
W, H = 320, 180
random.seed(7)
im = Image.new("RGB", (W, H), (98, 160, 72))
px = im.load()
for y in range(H):
    for x in range(W):
        r = random.random()
        if r < 0.10: px[x, y] = (86, 146, 64)
        elif r < 0.16: px[x, y] = (112, 174, 82)
d = ImageDraw.Draw(im)
# river: wavy band from top-right to bottom
import math
for y in range(H):
    cx = 236 + int(10 * math.sin(y / 14.0)) - y // 6
    d.line([(cx - 9, y), (cx + 9, y)], fill=(64, 128, 196))
    d.point((cx - 10, y), fill=(196, 180, 120)); d.point((cx + 10, y), fill=(196, 180, 120))
    if y % 7 == 0: d.line([(cx - 4, y), (cx + 1, y)], fill=(120, 176, 228))
ROAD, EDGE = (178, 160, 128), (140, 124, 98)
def road(pts, w=7):
    d.line(pts, fill=EDGE, width=w + 2); d.line(pts, fill=ROAD, width=w)
road([(0, 96), (320, 96)])                 # Route 9
road([(70, 20), (70, 170)])               # Elm St
road([(150, 96), (150, 160)])
road([(70, 40), (196, 40)])
road([(196, 40), (196, 96)])
# bridge over the river on Route 9
for y in (90, 102): d.line([(214, y), (250, y)], fill=(120, 84, 52), width=2)
# pond in the park
d.ellipse([(96, 128), (130, 150)], fill=(64, 128, 196), outline=(196, 180, 120))
# trees
def tree(x, y):
    d.rectangle([(x, y + 3), (x + 1, y + 6)], fill=(96, 64, 40))
    d.ellipse([(x - 4, y - 5), (x + 5, y + 4)], fill=(44, 108, 52), outline=(30, 78, 38))
    d.point((x - 1, y - 2), fill=(76, 140, 72))
spots = [(random.randint(4, 316), random.randint(4, 176)) for _ in range(140)]
for (x, y) in spots:
    if abs(y - 96) < 12 or abs(x - 70) < 10 or (40 < x < 210 and abs(y - 40) < 10) or (150 - 9 < x < 150 + 9 and y > 90): continue
    cx = 236 + int(10 * math.sin(y / 14.0)) - y // 6
    if abs(x - cx) < 16: continue
    if any(abs(x - bx) < 20 and abs(y - by) < 16 for (bx, by, *_ ) in []): continue
    tree(x, y)
def building(x, y, w, h, wall, roof, label_color=None):
    d.rectangle([(x - w // 2 - 2, y - h // 2 - 2), (x + w // 2 + 2, y + h // 2 + 6)], fill=(98, 160, 72))
    d.rectangle([(x - w // 2, y - h // 2 + 4), (x + w // 2, y + h // 2)], fill=wall, outline=(60, 44, 36))
    d.polygon([(x - w // 2 - 2, y - h // 2 + 5), (x, y - h // 2 - 3), (x + w // 2 + 2, y - h // 2 + 5)], fill=roof, outline=(60, 44, 36))
    d.rectangle([(x - 1, y + h // 2 - 4), (x + 1, y + h // 2)], fill=(80, 52, 34))
    d.rectangle([(x - w // 2 + 3, y - 1), (x - w // 2 + 5, y + 1)], fill=(250, 230, 140))
    d.rectangle([(x + w // 2 - 5, y - 1), (x + w // 2 - 3, y + 1)], fill=(250, 230, 140))
# x, y must match GameState.PLACES (normalized by 320x180)
building(40, 130, 22, 16, (230, 214, 180), (196, 84, 72))      # home
building(110, 60, 30, 18, (232, 216, 160), (200, 64, 64))      # school
d.rectangle([(103, 72), (117, 78)], fill=(140, 96, 64))          # playground sand
building(290, 70, 30, 22, (170, 180, 196), (90, 100, 120))     # office
building(185, 112, 22, 14, (240, 240, 230), (220, 120, 40))    # gas-n-sip
d.rectangle([(176, 104), (196, 106)], fill=(220, 120, 40))
building(30, 60, 20, 14, (240, 244, 250), (60, 140, 120))      # pharmacy
building(270, 140, 22, 14, (232, 236, 244), (90, 150, 200))    # dental
building(160, 70, 22, 14, (244, 214, 200), (170, 60, 90))      # diner
# park: flowers
for _ in range(40):
    x, y = random.randint(84, 140), random.randint(118, 160)
    d.point((x, y), fill=random.choice([(240, 200, 80), (240, 120, 160), (250, 250, 250)]))
im = im.resize((W * 4, H * 4), Image.NEAREST)
im.save("/workspace/uptime/assets/map/town_map.png")
print("ok")
