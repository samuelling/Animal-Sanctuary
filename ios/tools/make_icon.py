#!/usr/bin/env python3
"""Animal Sanctuary's app icon: the game's own Puffbun sprite on a dusk hill, drawn on the 16-bit pixel grid.

Usage: python3 ios/tools/make_icon.py   (writes ios/AnimalSanctuary/Assets.xcassets/AppIcon.appiconset/AppIcon.png)
The sprite rows and palette are read straight from index.html, so the icon always matches the game. Needs Pillow.
"""
import pathlib, re, random
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'ios' / 'AnimalSanctuary' / 'Assets.xcassets' / 'AppIcon.appiconset' / 'AppIcon.png'
SIZE, CELL = 1024, 32          # a 32 x 32 grid of chunky pixels
N = SIZE // CELL

src = (ROOT / 'index.html').read_text(encoding='utf-8')
pal = dict(re.findall(r"(\w):'(#[0-9a-fA-F]{6})'", src[src.index('const PAL={'):src.index('};', src.index('const PAL={'))]))
OUTLINE = re.search(r"const OUT='(#[0-9a-fA-F]{6})'", src).group(1)
rows = re.search(r'puffbun:(\[[^\]]+\])', src).group(1)
rows = re.findall(r'"([^"]*)"', rows)

img = Image.new('RGB', (SIZE, SIZE))
d = ImageDraw.Draw(img)
px = lambda i, j, col, c=CELL: d.rectangle([i * c, j * c, i * c + c - 1, j * c + c - 1], fill=col)

# dusk sky in bands, a few stars, a low sun
sky = ['#2a1e4a', '#2a1e4a', '#3a2a62', '#4a3478', '#5a3e8a', '#6a4cb8', '#8a5cc0', '#b06cb8', '#d07aa8', '#f08a98', '#f6a08c', '#f9b880', '#fcd078', '#ffd860']
for j in range(N):
    band = sky[min(len(sky) - 1, j * len(sky) // 22)]
    for i in range(N):
        px(i, j, band)
rnd = random.Random(7)
for _ in range(14):
    i, j = rnd.randrange(N), rnd.randrange(9)
    px(i, j, '#fff8e8' if rnd.random() < .6 else '#ffd860')
for i in range(N):
    for j in range(N):
        if (i - 27) ** 2 + (j - 19) ** 2 <= 6:
            px(i, j, '#fffbc8')

# rolling hill with a lighter rim and a few flowers
for i in range(N):
    top = int(21 + 2.2 * __import__('math').sin((i + 3) / 6.0))
    for j in range(top, N):
        px(i, j, pal['g'] if j == top else pal['G'])
for i, j, col in [(3, 25, pal['y']), (6, 28, pal['p']), (27, 26, pal['w']), (29, 29, pal['y']), (2, 30, pal['w'])]:
    px(i, j, col)

# Puffbun, with the game's dark outline, each sprite pixel drawn 50 px wide, standing on the hill
h, w = len(rows), max(len(r) for r in rows)
on = lambda i, j: 0 <= i < w and 0 <= j < h and i < len(rows[j]) and rows[j][i] != '.'
S = 50
ox = (SIZE - (w + 2) * S) // 2
oy = SIZE - (h + 2) * S - 70
for j in range(-1, h + 1):
    for i in range(-1, w + 1):
        if on(i, j):
            col = pal.get(rows[j][i], '#ff00ff')
        elif on(i - 1, j) or on(i + 1, j) or on(i, j - 1) or on(i, j + 1):
            col = OUTLINE
        else:
            continue
        x, y = ox + (i + 1) * S, oy + (j + 1) * S
        d.rectangle([x, y, x + S - 1, y + S - 1], fill=col)

# a couple of sparkles
for x, y in [(150, 300), (860, 360), (810, 170)]:
    for dx, dy in [(0, 0), (-16, 0), (16, 0), (0, -16), (0, 16)]:
        d.rectangle([x + dx, y + dy, x + dx + 15, y + dy + 15], fill='#fff8e8')

OUT.parent.mkdir(parents=True, exist_ok=True)
img.save(OUT)
print('wrote', OUT.relative_to(ROOT))
