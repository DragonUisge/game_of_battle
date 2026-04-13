from PIL import Image

template = Image.open('mods/registered/textures/items/registered_sword_bronze.png').convert('RGBA')
pixels = template.load()

shape = []
for y in range(16):
    for x in range(16):
        r, g, b, a = pixels[x, y]
        if a > 0:
            shape.append((x, y, (r, g, b, a)))

def classify(r, g, b):
    if (r, g, b) in [(255,159,114), (255,135,61)]:
        return 'light'
    elif (r, g, b) in [(173,95,27), (225,119,48)]:
        return 'mid'
    elif (r, g, b) in [(127,54,3), (150,78,15)]:
        return 'dark'
    elif (r, g, b) in [(57,39,18), (108,73,19), (79,53,13)]:
        return 'handle'
    else:
        return 'dark'

def make_sword(color_map, outpath):
    img = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    px = img.load()
    for x, y, (r, g, b, a) in shape:
        role = classify(r, g, b)
        variants = color_map.get(role, [(r, g, b)])
        brightness = r + g + b
        idx = 0 if brightness > 400 else (1 if len(variants) > 1 else 0)
        color = variants[min(idx, len(variants)-1)]
        px[x, y] = (color[0], color[1], color[2], 255)
    img.save(outpath)
    print('Created:', outpath)

out = 'mods/registered/textures/items/'

# Fire Sword - red/orange/gold
make_sword({
    'light':  [(255, 220, 50), (255, 180, 30)],
    'mid':    [(255, 100, 20), (220, 60, 10)],
    'dark':   [(180, 30, 0), (140, 20, 0)],
    'handle': [(80, 40, 20), (100, 55, 25)],
}, out + 'registered_sword_fire.png')

# Diamond Sword - cyan/blue
make_sword({
    'light':  [(180, 235, 255), (150, 220, 255)],
    'mid':    [(80, 180, 230), (50, 150, 210)],
    'dark':   [(30, 100, 170), (20, 70, 140)],
    'handle': [(60, 50, 80), (80, 65, 100)],
}, out + 'registered_sword_diamond.png')

# Ancient Sword - dark green
make_sword({
    'light':  [(140, 200, 100), (120, 180, 80)],
    'mid':    [(80, 130, 50), (100, 120, 60)],
    'dark':   [(40, 70, 25), (50, 80, 30)],
    'handle': [(50, 35, 20), (70, 50, 25)],
}, out + 'registered_sword_ancient.png')

# Dragon Power Sword - purple
make_sword({
    'light':  [(220, 140, 255), (200, 110, 250)],
    'mid':    [(160, 60, 220), (140, 40, 200)],
    'dark':   [(100, 20, 160), (80, 10, 130)],
    'handle': [(50, 30, 70), (65, 40, 85)],
}, out + 'registered_sword_dragonpower.png')

# Sword of Four Elements - multicolor by Y
img = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
px = img.load()
def elem_color(y, role):
    if y <= 3:
        c = {'light': (255,200,50), 'mid': (255,80,20), 'dark': (200,30,0), 'handle': (80,40,20)}
    elif y <= 6:
        c = {'light': (100,200,255), 'mid': (40,120,220), 'dark': (20,70,170), 'handle': (40,50,80)}
    elif y <= 9:
        c = {'light': (255,255,200), 'mid': (220,220,100), 'dark': (180,180,50), 'handle': (80,80,40)}
    else:
        c = {'light': (120,200,80), 'mid': (70,140,40), 'dark': (40,80,20), 'handle': (50,40,20)}
    return c.get(role, (128,128,128))
for x, y, (r, g, b, a) in shape:
    role = classify(r, g, b)
    color = elem_color(y, role)
    px[x, y] = (color[0], color[1], color[2], 255)
img.save(out + 'registered_sword_elements.png')
print('Created:', out + 'registered_sword_elements.png')
print('Done - all 5 swords!')
