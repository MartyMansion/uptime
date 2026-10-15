# Uptime — Assets

## Paper port (branch `paper-port`, current presentation)
Everything below this section is the **v0-pixel** art (tag `v0-pixel`). It is still in the repo because the
2D Location plan (stations, spots, solids) is the logic layer, but it is hidden at runtime.

All paper art is **original and procedural**: no third-party art, fonts (Godot default font only) or textures.
- **Characters** (`scripts/paper/paper_person.gd`): crude construction-paper cut-outs drawn with polygons at runtime
  (original designs; inspired by the *cut-out animation* look in general, nothing traced or copied). Flat shapes,
  3 px ink outline, a baked per-character wobble (stable, no frame-to-frame jitter), beady eyes, a "flip-top" head
  hinged at the back that opens on vowels, mitten hands, procedural walk cycle (feet lift, hands swing, body bob).
  Dan: hoodie + lanyard + eye bags. Jess: apron + bun. Lily: skirt + side bunches. June: star shirt + bow.
  Gary: tie, pocket pen, glasses and a three-strand comb-over with side fringe.
- **Cards** (`scripts/paper/paper_card.gd`, `shaders/card.gdshader`): each character renders into a 256x320
  SubViewport, shown on 5 stacked quads (art front/back + 3 kraft core layers) with a die-cut white border.
  Heights: Dan 1.62 m, Jess 1.54, Lily 1.06, June 0.9, Gary 1.7. Cards take ~38% of scene light (warm tint per set).
- **Sets** (`scripts/paper/diorama.gd`, `shaders/paper.gdshader`): built at runtime from each Location's plan
  (1 plan px = 5 cm): cardboard boxes with a paper-fibre shader, knee-high cut-away partitions, tall back/side
  walls, a stage lip with low foreground props, lettered `Label3D` signs, a live wall clock, time-of-day light.
  Town destinations (park, pharmacy, dental, diner, coffee) have their own small sets.
- **2D assets** (`tools/gen_paper.py`, Pillow): `assets/paper/town_board.png` (the town map as a papercraft board
  game, 1280x720), `assets/paper/drawings.png` (12 crayon fridge drawings, 4x3 of 64 px), `assets/paper/lifeos.png`.
- **UI**: cream paper panels, ink outlines, kraft top/bottom bars and buttons, terminal in a cardboard bezel.
- Palette: warm kraft `#CCA370`, paper `#FCF5DE`, ink `#211A1A`; set colours in `diorama.gd` (`FLOOR_COLS`).

All art is **original and generated programmatically** by `tools/gen_sprites.py` (Python + Pillow).
No third-party art, fonts or samples: license-clean, owned by the project (treat as CC0 placeholders).
Regenerate everything with `python3 tools/gen_sprites.py`. Every file can be swapped 1:1 for commissioned art
as long as it keeps the same size/layout (or update the code that slices it).

## Style guide
- **Grid:** 16 px. World is 320x200 px, rendered at 3x (nearest filter) in a 960x600 slot.
- **View:** top-down 3/4 ("Stardew-lite"). Characters are drawn facing the camera with feet at the sprite's bottom-center.
- **Outline:** 1 px, color `#221C28`, on all characters and props. Floors/tiles have no outline.
- **Palette:** warm, slightly desaturated; ~4-6 colors per sprite; one shade (x0.8) for depth. No pure black or white.
- **Characters:** 16x24 px frames. Adults use an 8 px head; kids a 7 px head on a shorter body (bigger-head ratio).
- **Text in art:** tiny 3x5 pixel font (in the generator) for signs only. All UI text is Godot's default font via the theme.
- **Tone:** cozy and readable; the satire lives in the text, not the art.

## Characters — `assets/sprites/characters/<name>.png` (64x96)
Sheet: 4 rows (down, left, right, up) x 4 columns (stand, step-L, step-R, idle "breath" bob).
In-engine: `walk_<dir>` = frames 1,0,2,0 @ 8 fps; `idle_<dir>` = frames 0,3 @ 1.5 fps (`scripts/actor.gd`).

| File | Character | Look | Source |
|---|---|---|---|
| dan.png | Dan Mercer (player) | brown hair, glasses, green hoodie, jeans | gen_sprites.py |
| jess.png | Jess Mercer | long dark hair, teal hospital scrubs | gen_sprites.py |
| lily.png | Lily (7) | blonde ponytail, purple shirt | gen_sprites.py |
| june.png | June (4) | red curls, yellow outfit | gen_sprites.py |
| gary.png | Gary Holt (boss) | balding, white shirt, red tie, khakis, wider build | gen_sprites.py |

## Portraits — `assets/portraits/<name>.png` (32x32, shown at 96x96)
dan, jess, lily, june, gary (head-and-shoulders from the front frame, 2x), lifeos (smug phone). Source: gen_sprites.py.

## Tiles — `assets/tiles/*.png` (16x16, repeated)
floor_wood, floor_kitchen, floor_carpet_pink, floor_office, asphalt, road_lane, sidewalk, grass, wall, wall_office. Source: gen_sprites.py.

## Props — `assets/props/*.png`
| File | Size | Used in |
|---|---|---|
| bed_double | 32x40 | House bedroom (Bed station) |
| bed_kid (x2) | 20x30 | Girls' room |
| kitchen_counter | 48x20 | Kitchen station |
| fridge (Lily's comic on it) | 16x30 | Kitchen |
| table | 32x20 | Kitchen |
| pc_desk | 32x20 | Living room (PC desk station) |
| couch, tv_stand, rug, door, plant, bookshelf, toys | various | House |
| office_desk, server_rack, water_cooler, printer, office_sign | various | TriCounty office |
| store_counter, beer_cooler, gas_pump, gas_sign, car | various | Gas-N-Sip |
| school_front, tree, car | various | Brookfield Elementary |
| store_front, phone | various | spare (not placed yet) |

## Locations — `scenes/locations/*.tscn` + `scripts/locations/*.gd`
house, office, gas_station, school. Each builds its tiles/props in code, defines stations (interaction rects + actions) and named spots (for cutscene staging).

## Replacing with commissioned art
1. Keep filenames and sizes, drop new PNGs in place → done.
2. Different sizes: characters → `Actor._frame()` and `offset`; props are placed by top-left and y-sorted by their bottom edge, so taller art just works.
3. Delete or stop running `gen_sprites.py` so it doesn't overwrite the new files.

## Desktop + garage (2026-10-15)
All original and procedural. The BrookOS wallpaper is drawn in code (hills, sun, ink lines), and the icons are Unicode glyphs. Garage furniture, boxes, rack and servers are cardboard slabs in `diorama.gd`. Shop names (PCEggo, RackBay, Kilowatt Kevin's) are original parodies that use no real logos or trademarks.
