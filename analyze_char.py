from PIL import Image
import colorsys

img = Image.open('mods/player/textures/character.png').convert('RGBA')
px = img.load()
print(f'Size: {img.size}')

from collections import Counter
cats = Counter()
for y in range(32):
    for x in range(64):
        r,g,b,a = px[x,y]
        if a < 128: continue
        h,s,v = colorsys.rgb_to_hsv(r/255, g/255, b/255)
        if s < 0.15 and v > 0.7: cats['skin'] += 1
        elif 0.2 < h < 0.45 and s > 0.2: cats['green_shirt'] += 1
        elif 0.05 < h < 0.12 and s > 0.3 and v > 0.2: cats['brown_hair'] += 1
        elif s < 0.1 and v > 0.9: cats['white_eye'] += 1
        elif v < 0.15: cats['black'] += 1
        elif 0.55 < h < 0.72 and s > 0.3: cats['blue_pants'] += 1
        else: cats[f'h{h:.2f}s{s:.2f}v{v:.2f}'] += 1
print(f'Categories: {dict(cats)}')

def label(r,g,b,a):
    if a<128: return '....'
    h,s,v = colorsys.rgb_to_hsv(r/255,g/255,b/255)
    if s<0.15 and v>0.7: return 'SKIN'
    if 0.2<h<0.45 and s>0.2: return 'SHRT'
    if 0.05<h<0.12 and s>0.3 and v>0.2: return 'HAIR'
    if s<0.1 and v>0.9: return 'WHTE'
    if v<0.15: return 'BLK '
    if 0.55<h<0.72 and s>0.3: return 'PANT'
    return 'unk '

print('\nHEAD FRONT (x=8-15, y=8-15):')
for y in range(8,16):
    row = ''.join(label(*px[x,y]) + ' ' for x in range(8,16))
    print(f'  y{y:2d}: {row}')

print('\nBODY FRONT (x=20-27, y=20-31):')
for y in range(20,32):
    row = ''.join(label(*px[x,y]) + ' ' for x in range(20,28))
    print(f'  y{y:2d}: {row}')

print('\nARM FRONT (x=44-47, y=20-31):')
for y in range(20,32):
    row = ''.join(label(*px[x,y]) + ' ' for x in range(44,48))
    print(f'  y{y:2d}: {row}')

print('\nLEG FRONT (x=4-7, y=20-31):')
for y in range(20,32):
    row = ''.join(label(*px[x,y]) + ' ' for x in range(4,8))
    print(f'  y{y:2d}: {row}')
