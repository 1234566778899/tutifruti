"""Genera la imagen para redes (Open Graph 1200x630) e íconos PWA de la web."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os
W, H = 1200, 630
OUT = 'webapp/static'
F = '/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf'

def grad(w, h, top, bottom):
    img = Image.new('RGB', (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / (h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return img

bg = grad(W, H, (18, 92, 107), (10, 23, 51)).convert('RGBA')
pat = Image.open('webapp/static/img/ui/game_pattern.png').convert('RGBA')
pat = pat.resize((320, 320 * pat.height // pat.width))
layer = Image.new('RGBA', (W, H))
for x in range(0, W, pat.width):
    for y in range(0, H, pat.height):
        layer.alpha_composite(pat, (x, y))
a = layer.getchannel('A').point(lambda v: int(v * 0.06))
layer.putalpha(a)
bg.alpha_composite(layer)
glow = Image.new('RGBA', (W, H)); ImageDraw.Draw(glow).ellipse((700, 40, 1180, 620), fill=(255, 148, 31, 70))
bg.alpha_composite(glow.filter(ImageFilter.GaussianBlur(90)))

logo = Image.open('webapp/static/img/ui/logo_wordmark.png').convert('RGBA')
lw = 600; logo = logo.resize((lw, lw * logo.height // logo.width), Image.LANCZOS)
bg.alpha_composite(logo, (70, 120))
badge = Image.open('webapp/static/img/ui/logo_badge.png').convert('RGBA')
badge = badge.resize((150, 150 * badge.height // badge.width), Image.LANCZOS).rotate(8, expand=True, resample=Image.BICUBIC)
bg.alpha_composite(badge, (70 + lw - 130, 120 + logo.height - 40))

tuti = Image.open('art/source/poses_v2/tuti_hello.png').convert('RGBA').resize((520, 520), Image.LANCZOS)
bg.alpha_composite(tuti, (W - 560, H - 540))

d = ImageDraw.Draw(bg)
f1 = ImageFont.truetype(F, 44); f2 = ImageFont.truetype(F, 30)
d.text((74, 340), 'El Stop de siempre,', font=f1, fill=(255, 255, 255))
d.text((74, 394), 'con un árbitro de IA', font=f1, fill=(255, 210, 63))
pill = 'Juega gratis en tutifruti.site'
tw = d.textlength(pill, font=f2)
d.rounded_rectangle((70, 480, 70 + tw + 56, 540), radius=30, fill=(255, 148, 31), outline=(46, 28, 20), width=3)
d.text((98, 492), pill, font=f2, fill=(46, 28, 20))
bg.convert('RGB').save(f'{OUT}/og.png', optimize=True)

icon = Image.open('art/icon.png').convert('RGBA')
for s in (192, 512):
    icon.resize((s, s), Image.LANCZOS).save(f'{OUT}/icon-{s}.png', optimize=True)
# Ícono "maskable": con margen seguro sobre el color de fondo.
m = Image.new('RGBA', (512, 512), (13, 69, 84, 255)); m.alpha_composite(icon.resize((410, 410), Image.LANCZOS), (51, 51))
m.save(f'{OUT}/icon-maskable.png', optimize=True)
print('ok', os.path.getsize(f'{OUT}/og.png'))
