#!/usr/bin/env python3
"""Generate all student (4) and boss (7) textures from the base character.png."""
from PIL import Image
import colorsys
import os

base = Image.open('mods/player/textures/character.png').convert('RGBA')
W, H = base.size  # 64x32

def classify_pixel(r, g, b, a, x, y):
    """Classify a pixel into a semantic category."""
    if a < 128:
        return 'transparent'
    h, s, v = colorsys.rgb_to_hsv(r/255, g/255, b/255)
    if v < 0.15:
        return 'black'       # outlines, shoes
    if s < 0.1 and v > 0.9:
        return 'white'       # eye whites
    if (h > 0.95 or h < 0.02) and s > 0.5 and v > 0.3:
        return 'red'         # mouth/lips
    if 0.2 < h < 0.45 and s > 0.2:
        return 'shirt'       # green shirt
    if 0.55 < h < 0.72 and s > 0.3:
        # Blue: could be pants or eyes depending on location
        # Head front face region: x=8-15, y=8-15
        # Head sides: x=0-7 or x=16-23, y=8-15
        if 8 <= y <= 15:
            return 'eyes'    # blue on face = eyes
        return 'pants'       # blue on body = pants
    # Brown-ish pixels
    if 0.0 <= h <= 0.15:
        if s > 0.4 and v < 0.5:
            return 'hair'    # dark brown, saturated hair
        if 0.15 <= s <= 0.35 and v > 0.7:
            return 'skin'    # light beige skin
    return 'other'

def build_class_map():
    """Build a classification map for the base image."""
    px = base.load()
    cmap = {}
    for y in range(H):
        for x in range(W):
            r, g, b, a = px[x, y]
            cmap[(x, y)] = classify_pixel(r, g, b, a, x, y)
    return cmap

CMAP = build_class_map()

def hsv_to_rgb(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r*255), int(g*255), int(b*255))

def make_variant(name, hair_color, eye_color, shirt_color, shirt_shade,
                 pants_color, pants_shade, skin_color=None, belt_rows=None,
                 long_hair=False, output_dir='mods/enemy/textures'):
    """
    Create a texture variant by recoloring classified pixel categories.
    Colors are (R, G, B) tuples. Shades are darker variants.
    belt_rows: if set, list of y-rows on body front to color as belt.
    long_hair: if True, extend hair color partway down body sides.
    """
    img = base.copy()
    px = img.load()
    base_px = base.load()

    # Default skin color (keep original)
    for y in range(H):
        for x in range(W):
            r, g, b, a = base_px[x, y]
            cat = CMAP[(x, y)]

            if cat == 'transparent':
                continue
            elif cat == 'hair':
                # Apply hair color, preserving relative brightness
                orig_h, orig_s, orig_v = colorsys.rgb_to_hsv(r/255, g/255, b/255)
                tgt_h, tgt_s, tgt_v = colorsys.rgb_to_hsv(
                    hair_color[0]/255, hair_color[1]/255, hair_color[2]/255)
                # Scale target value by original value ratio
                v_ratio = orig_v / 0.20 if orig_v > 0 else 1.0  # base hair v~0.20
                new_v = min(tgt_v * v_ratio, 1.0)
                nr, ng, nb = colorsys.hsv_to_rgb(tgt_h, tgt_s, new_v)
                px[x, y] = (int(nr*255), int(ng*255), int(nb*255), a)
            elif cat == 'eyes':
                px[x, y] = (eye_color[0], eye_color[1], eye_color[2], a)
            elif cat == 'shirt':
                orig_h, orig_s, orig_v = colorsys.rgb_to_hsv(r/255, g/255, b/255)
                tgt_h, tgt_s, tgt_v = colorsys.rgb_to_hsv(
                    shirt_color[0]/255, shirt_color[1]/255, shirt_color[2]/255)
                shade_h, shade_s, shade_v = colorsys.rgb_to_hsv(
                    shirt_shade[0]/255, shirt_shade[1]/255, shirt_shade[2]/255)
                # Use shade for darker original pixels
                if orig_v < 0.5:
                    nr, ng, nb = colorsys.hsv_to_rgb(shade_h, shade_s, shade_v * (orig_v / 0.5))
                else:
                    nr, ng, nb = colorsys.hsv_to_rgb(tgt_h, tgt_s, tgt_v * (orig_v / 0.8))
                px[x, y] = (int(nr*255), int(ng*255), int(nb*255), a)
            elif cat == 'pants':
                orig_h, orig_s, orig_v = colorsys.rgb_to_hsv(r/255, g/255, b/255)
                tgt_h, tgt_s, tgt_v = colorsys.rgb_to_hsv(
                    pants_color[0]/255, pants_color[1]/255, pants_color[2]/255)
                v_ratio = orig_v / 0.5 if orig_v > 0 else 1.0
                new_v = min(tgt_v * v_ratio, 1.0)
                nr, ng, nb = colorsys.hsv_to_rgb(tgt_h, tgt_s, new_v)
                px[x, y] = (int(nr*255), int(ng*255), int(nb*255), a)
            elif cat == 'skin' and skin_color:
                px[x, y] = (skin_color[0], skin_color[1], skin_color[2], a)
            # black, white, red, other: keep original

    # Belt overlay (for karate, gladiator, etc.)
    if belt_rows:
        for y_row in belt_rows:
            # Body front x=20-27
            for x in range(20, 28):
                r, g, b, a = px[x, y_row]
                if a > 128:
                    px[x, y_row] = (30, 30, 30, a)  # black belt
            # Body back x=32-39
            for x in range(32, 40):
                r, g, b, a = px[x, y_row]
                if a > 128:
                    px[x, y_row] = (30, 30, 30, a)
            # Body sides x=16-19, x=28-31
            for x in list(range(16, 20)) + list(range(28, 32)):
                r, g, b, a = px[x, y_row]
                if a > 128:
                    px[x, y_row] = (30, 30, 30, a)

    # Long hair: paint hair color on body sides and back top rows
    if long_hair:
        for y_row in range(20, 26):  # extend hair down 6 rows
            # Body right side x=16-19
            for x in range(16, 20):
                r, g, b, a = px[x, y_row]
                if a > 128:
                    tgt_h, tgt_s, tgt_v = colorsys.rgb_to_hsv(
                        hair_color[0]/255, hair_color[1]/255, hair_color[2]/255)
                    # Slightly vary brightness
                    v = tgt_v * (0.85 + 0.15 * ((y_row - 20) / 6))
                    nr, ng, nb = colorsys.hsv_to_rgb(tgt_h, tgt_s, v)
                    px[x, y_row] = (int(nr*255), int(ng*255), int(nb*255), a)
            # Body left side x=28-31
            for x in range(28, 32):
                r, g, b, a = px[x, y_row]
                if a > 128:
                    tgt_h, tgt_s, tgt_v = colorsys.rgb_to_hsv(
                        hair_color[0]/255, hair_color[1]/255, hair_color[2]/255)
                    v = tgt_v * (0.85 + 0.15 * ((y_row - 20) / 6))
                    nr, ng, nb = colorsys.hsv_to_rgb(tgt_h, tgt_s, v)
                    px[x, y_row] = (int(nr*255), int(ng*255), int(nb*255), a)
            # Body back top x=32-39
            for x in range(32, 40):
                r, g, b, a = px[x, y_row]
                if a > 128:
                    tgt_h, tgt_s, tgt_v = colorsys.rgb_to_hsv(
                        hair_color[0]/255, hair_color[1]/255, hair_color[2]/255)
                    v = tgt_v * (0.85 + 0.1 * ((y_row - 20) / 6))
                    nr, ng, nb = colorsys.hsv_to_rgb(tgt_h, tgt_s, v)
                    px[x, y_row] = (int(nr*255), int(ng*255), int(nb*255), a)

    os.makedirs(output_dir, exist_ok=True)
    path = os.path.join(output_dir, name + '.png')
    img.save(path)
    print(f'  Created {path}')
    return img

# ============ COLOR PALETTE ============
# Hair colors
HAIR_BROWN     = (80, 50, 30)
HAIR_DARK_BROWN = (50, 30, 15)
HAIR_BLACK     = (20, 18, 15)
HAIR_BLONDE    = (210, 180, 80)
HAIR_GOLDEN    = (220, 190, 70)
HAIR_GREY      = (140, 140, 140)
HAIR_SILVER    = (190, 195, 200)

# Eye colors
EYES_BROWN     = (100, 60, 30)
EYES_BLUE      = (50, 100, 200)
EYES_GREEN     = (50, 150, 70)

# Shirt colors
SHIRT_RED      = (180, 50, 50)
SHIRT_RED_SHADE = (130, 35, 35)
SHIRT_BLUE     = (50, 80, 180)
SHIRT_BLUE_SHADE = (35, 55, 130)
SHIRT_PINK     = (200, 100, 150)
SHIRT_PINK_SHADE = (160, 70, 120)
SHIRT_PURPLE   = (130, 60, 170)
SHIRT_PURPLE_SHADE = (90, 40, 130)
SHIRT_WHITE    = (240, 240, 240)
SHIRT_WHITE_SHADE = (200, 200, 200)
SHIRT_GOLD     = (200, 170, 50)
SHIRT_GOLD_SHADE = (160, 130, 30)
SHIRT_GREEN    = (60, 140, 60)
SHIRT_GREEN_SHADE = (40, 100, 40)

# Pants colors
PANTS_DARK_BLUE = (30, 40, 80)
PANTS_GREY     = (80, 80, 85)
PANTS_BROWN    = (90, 60, 35)
PANTS_JEANS    = (50, 60, 110)
PANTS_BLACK    = (30, 30, 35)

# Special: painter smock (multicolored stains on white)
# We'll add color spots after base generation

print('=== GENERATING STUDENT TEXTURES (4) ===')

# Student Boy 1: brown hair, blue eyes, red shirt, dark blue pants
make_variant('student_boy1',
    hair_color=HAIR_BROWN, eye_color=EYES_BLUE,
    shirt_color=SHIRT_RED, shirt_shade=SHIRT_RED_SHADE,
    pants_color=PANTS_DARK_BLUE, pants_shade=PANTS_DARK_BLUE)

# Student Boy 2: black hair, brown eyes, blue shirt, grey pants
make_variant('student_boy2',
    hair_color=HAIR_BLACK, eye_color=EYES_BROWN,
    shirt_color=SHIRT_BLUE, shirt_shade=SHIRT_BLUE_SHADE,
    pants_color=PANTS_GREY, pants_shade=PANTS_GREY)

# Student Girl 1: blonde long hair, green eyes, pink shirt, dark pants
make_variant('student_girl1',
    hair_color=HAIR_BLONDE, eye_color=EYES_GREEN,
    shirt_color=SHIRT_PINK, shirt_shade=SHIRT_PINK_SHADE,
    pants_color=PANTS_DARK_BLUE, pants_shade=PANTS_DARK_BLUE,
    long_hair=True)

# Student Girl 2: dark brown long hair, brown eyes, purple shirt, blue pants
make_variant('student_girl2',
    hair_color=HAIR_DARK_BROWN, eye_color=EYES_BROWN,
    shirt_color=SHIRT_PURPLE, shirt_shade=SHIRT_PURPLE_SHADE,
    pants_color=PANTS_JEANS, pants_shade=PANTS_JEANS,
    long_hair=True)

print('\n=== GENERATING BOSS TEXTURES (7) ===')
boss_dir = 'mods/boss/textures'

# Boss 1: Bram - golden hair, blue eyes, normal clothes (green-ish shirt)
make_variant('boss_bram',
    hair_color=HAIR_GOLDEN, eye_color=EYES_BLUE,
    shirt_color=SHIRT_GREEN, shirt_shade=SHIRT_GREEN_SHADE,
    pants_color=PANTS_JEANS, pants_shade=PANTS_JEANS,
    output_dir=boss_dir)

# Boss 2: Hugo - black hair, brown eyes, white karate tunic + black belt
make_variant('boss_hugo',
    hair_color=HAIR_BLACK, eye_color=EYES_BROWN,
    shirt_color=SHIRT_WHITE, shirt_shade=SHIRT_WHITE_SHADE,
    pants_color=SHIRT_WHITE, pants_shade=SHIRT_WHITE_SHADE,
    belt_rows=[25, 26],  # belt across midsection
    output_dir=boss_dir)

# Boss 3: Joachim - grey hair, brown eyes, golden gladiator armor
make_variant('boss_joachim',
    hair_color=HAIR_GREY, eye_color=EYES_BROWN,
    shirt_color=SHIRT_GOLD, shirt_shade=SHIRT_GOLD_SHADE,
    pants_color=PANTS_BROWN, pants_shade=PANTS_BROWN,
    output_dir=boss_dir)

# Boss 4: Julian - brown hair + brown eyes, normal clothes
make_variant('boss_julian',
    hair_color=HAIR_BROWN, eye_color=EYES_BROWN,
    shirt_color=SHIRT_BLUE, shirt_shade=SHIRT_BLUE_SHADE,
    pants_color=PANTS_GREY, pants_shade=PANTS_GREY,
    output_dir=boss_dir)

# Boss 5: Rosanne (girl) - brown hair + brown eyes, painter/artist clothes
# We'll make painter clothes as a white smock with color splatters
rosanne_img = make_variant('boss_rosanne',
    hair_color=HAIR_DARK_BROWN, eye_color=EYES_BROWN,
    shirt_color=SHIRT_WHITE, shirt_shade=SHIRT_WHITE_SHADE,
    pants_color=PANTS_JEANS, pants_shade=PANTS_JEANS,
    long_hair=True,
    output_dir=boss_dir)

# Add paint splatters to Rosanne's smock
import random
random.seed(42)
rpx = rosanne_img.load()
splatter_colors = [(200,50,50), (50,50,200), (50,180,50), (220,180,30), (180,50,180)]
# Body front paint spots
for _ in range(12):
    sx = random.randint(20, 27)
    sy = random.randint(21, 29)
    c = random.choice(splatter_colors)
    r,g,b,a = rpx[sx, sy]
    if a > 128:
        rpx[sx, sy] = (c[0], c[1], c[2], a)
# Arm paint spots
for _ in range(4):
    sx = random.randint(44, 47)
    sy = random.randint(20, 25)
    c = random.choice(splatter_colors)
    r,g,b,a = rpx[sx, sy]
    if a > 128:
        rpx[sx, sy] = (c[0], c[1], c[2], a)
# Body back paint spots
for _ in range(8):
    sx = random.randint(32, 39)
    sy = random.randint(21, 29)
    c = random.choice(splatter_colors)
    r,g,b,a = rpx[sx, sy]
    if a > 128:
        rpx[sx, sy] = (c[0], c[1], c[2], a)
rosanne_img.save(os.path.join(boss_dir, 'boss_rosanne.png'))
print('  Added paint splatters to boss_rosanne.png')

# Boss 6: Jan Willem - silver hair, brown eyes, blue t-shirt, jeans
make_variant('boss_janwillem',
    hair_color=HAIR_SILVER, eye_color=EYES_BROWN,
    shirt_color=SHIRT_BLUE, shirt_shade=SHIRT_BLUE_SHADE,
    pants_color=PANTS_JEANS, pants_shade=PANTS_JEANS,
    output_dir=boss_dir)

# Boss 7: Margriet (girl) - brown hair + brown eyes, red sweater, jeans
make_variant('boss_margriet',
    hair_color=HAIR_BROWN, eye_color=EYES_BROWN,
    shirt_color=SHIRT_RED, shirt_shade=SHIRT_RED_SHADE,
    pants_color=PANTS_JEANS, pants_shade=PANTS_JEANS,
    long_hair=True,
    output_dir=boss_dir)

# Clean up old generic textures
old = os.path.join(boss_dir, 'boss_teacher.png')
if os.path.exists(old):
    os.remove(old)
    print(f'  Removed old {old}')

# Also remove the old student_level*.png from enemy textures
for i in range(1, 7):
    old = os.path.join('mods/enemy/textures', f'student_level{i}.png')
    if os.path.exists(old):
        os.remove(old)
        print(f'  Removed old {old}')

print('\nDone! All textures generated.')
