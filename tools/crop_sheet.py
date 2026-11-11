"""Recorta una hoja de stickers/avatares (fondo blanco) en piezas individuales con fondo transparente.

Uso: python3 tools/crop_sheet.py <hoja.png> <cols> <rows> <nombre1,nombre2,...> <carpeta_salida> [--size 512] [--circle]

Detecta el contenido de cada celda (todo lo que no es casi blanco), lo recorta con un margen, quita el fondo
blanco conectado a los bordes (flood fill) y lo centra en un lienzo cuadrado transparente.
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


def remove_white_bg(im: Image.Image, thresh=250) -> Image.Image:
    """Vuelve transparente el blanco conectado a los bordes (no el blanco interior, p. ej. ojos)."""
    rgb = np.asarray(im.convert("RGB")).astype(np.int16)
    white = (rgb.min(axis=2) >= thresh)
    h, w = white.shape
    bg = np.zeros_like(white)
    stack = [(y, x) for x in range(w) for y in (0, h - 1)] + [(y, x) for y in range(h) for x in (0, w - 1)]
    while stack:
        y, x = stack.pop()
        if 0 <= y < h and 0 <= x < w and white[y, x] and not bg[y, x]:
            bg[y, x] = True
            stack.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    a = Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(0.8))
    out = im.convert("RGBA")
    out.putalpha(a)
    return out


def grid_boxes(ink, cols, rows, count):
    """Caja del contenido dentro de cada celda de una cuadrícula uniforme."""
    H, W = ink.shape
    cw, ch = W / cols, H / rows
    boxes = []
    for i in range(count):
        r, c = divmod(i, cols)
        x0, y0 = int(c * cw), int(r * ch)
        cell = ink[y0:int(y0 + ch), x0:int(x0 + cw)].copy()
        # descarta trozos de las celdas vecinas (tocan el borde de la celda)
        from scipy import ndimage
        lab, n = ndimage.label(cell)
        for k, (sy, sx) in enumerate(ndimage.find_objects(lab), start=1):
            h, w = cell.shape
            touches = sy.start == 0 or sx.start == 0 or sy.stop == h or sx.stop == w
            if touches and (lab[sy, sx] == k).sum() < 0.01 * h * w:
                cell[lab == k] = False
        ink[y0:int(y0 + ch), x0:int(x0 + cw)] = cell
        ys, xs = np.where(cell)
        boxes.append((slice(y0 + ys.min(), y0 + ys.max() + 1), slice(x0 + xs.min(), x0 + xs.max() + 1)))
    return boxes


def component_boxes(ink, count, dilate):
    """Las `count` piezas conectadas más grandes, ordenadas por filas y columnas."""
    from scipy import ndimage
    lab, n = ndimage.label(ndimage.binary_dilation(ink, iterations=dilate) if dilate else ink)
    found = ndimage.find_objects(lab)
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    comps = [found[k] for k in np.argsort(sizes)[::-1][:count]]
    comps.sort(key=lambda b: (b[0].start + b[0].stop) / 2)
    avg_h = np.mean([b[0].stop - b[0].start for b in comps])
    rows, cur = [], []
    for b in comps:
        if cur and (b[0].start + b[0].stop) / 2 - (cur[0][0].start + cur[0][0].stop) / 2 > avg_h * 0.5:
            rows.append(cur)
            cur = []
        cur.append(b)
    rows.append(cur)
    return [b for r in rows for b in sorted(r, key=lambda b: b[1].start)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet")
    ap.add_argument("cols", type=int)
    ap.add_argument("rows", type=int)
    ap.add_argument("names")
    ap.add_argument("out")
    ap.add_argument("--size", type=int, default=512)
    ap.add_argument("--circle", action="store_true", help="recorte circular exacto (avatares)")
    ap.add_argument("--pad", type=float, default=0.04)
    ap.add_argument("--dilate", type=int, default=6)
    ap.add_argument("--grid", action="store_true", help="recorta por celdas iguales en vez de por componentes")
    ap.add_argument("--key", default=None, help="color de fondo plano a eliminar (hex, p. ej. FF00FF); si no, fondo blanco")
    ap.add_argument("--tol", type=int, default=70, help="tolerancia del color clave")
    a = ap.parse_args()

    names = a.names.split(",")
    im = Image.open(a.sheet).convert("RGB")
    W, H = im.size
    arr = np.asarray(im).astype(np.int16)
    if a.key:
        key = np.array([int(a.key[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.int16)
        dist = np.abs(arr - key).sum(axis=2)
        ink = dist > a.tol
        # quita el color clave: alfa por distancia (bordes suaves) y "despill" del tinte magenta en los bordes
        alpha = np.clip((dist - a.tol * 0.6) / (a.tol * 0.8) * 255, 0, 255).astype(np.uint8)
        rgb = arr.copy()
        spill = (alpha < 250)
        if a.key.upper() == "FF00FF":
            g = rgb[..., 1]
            rgb[..., 0] = np.where(spill, np.minimum(rgb[..., 0], g + 40), rgb[..., 0])
            rgb[..., 2] = np.where(spill, np.minimum(rgb[..., 2], g + 40), rgb[..., 2])
        im = Image.fromarray(np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), alpha]), "RGBA")
    else:
        ink = arr.min(axis=2) < 235
    os.makedirs(a.out, exist_ok=True)
    comps = grid_boxes(ink, a.cols, a.rows, len(names)) if a.grid else component_boxes(ink, len(names), a.dilate)
    for name, (sy, sx) in zip(names, comps):
        piece = im.crop((sx.start, sy.start, sx.stop, sy.stop))
        if a.key and not a.circle:
            side = int(max(piece.size) * (1 + 2 * a.pad))
            canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            canvas.paste(piece, ((side - piece.width) // 2, (side - piece.height) // 2), piece)
            canvas.resize((a.size, a.size), Image.LANCZOS).save(os.path.join(a.out, f"{name}.png"))
            print("ok", name, piece.size)
            continue
        if not a.circle:
            # margen blanco para que el relleno del fondo rodee la figura sin colarse en zonas blancas cerradas
            m = 6
            framed = Image.new("RGB", (piece.width + 2 * m, piece.height + 2 * m), "white")
            framed.paste(piece, (m, m))
            piece = framed
        if a.circle:
            side = max(piece.size)
            sq = Image.new("RGB", (side, side), "white")
            sq.paste(piece, ((side - piece.width) // 2, (side - piece.height) // 2))
            S = a.size * 4
            big = sq.resize((S, S), Image.LANCZOS).convert("RGBA")
            mask = Image.new("L", (S, S), 0)
            inset = int(S * 0.012)
            ImageDraw.Draw(mask).ellipse((inset, inset, S - inset, S - inset), fill=255)
            big.putalpha(mask)
            out = big.resize((a.size, a.size), Image.LANCZOS)
        else:
            piece = remove_white_bg(piece)
            side = int(max(piece.size) * (1 + 2 * a.pad))
            canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            canvas.paste(piece, ((side - piece.width) // 2, (side - piece.height) // 2), piece)
            out = canvas.resize((a.size, a.size), Image.LANCZOS)
        out.save(os.path.join(a.out, f"{name}.png"))
        print("ok", name, piece.size)


if __name__ == "__main__":
    main()
