#!/usr/bin/env python3
"""Descarga sprites de las 3 torres desbloqueables de Taco Defender (Chile Habanero,
Queso Fundido, Pico de Gallo) en el mismo estilo "vector cartoon pulido" que las 3
torres originales -- ver tools/fetch_taco_object_sprites.py, mismo pipeline (flood-fill
+ crop), script separado para mantener este lote de arte autocontenido.

Uso: /tmp/gb_venv/bin/python3 tools/fetch_taco_weapon_sprites.py
"""
import io
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

from PIL import Image, ImageDraw

FETCH_SIZE = 512

STYLE_SUFFIX = (
    ", cute cartoon vector game asset, thick black outline, simple flat cel shading, "
    "vibrant saturated colors, mobile game icon style, white background, centered, "
    "isolated single object, no text, no watermark"
)

# path -> (prompt, seed, output_size) -- output_size = 2x el tamaño de render en juego
# (Sprite2D.scale=0.5, regla CLAUDE.md #62), mismo patrón que fetch_taco_object_sprites.py.
SPECS = [
    (
        "assets/sprites/towers/chile_habanero.png",
        "menacing red habanero chili pepper shaped sniper cannon turret, long barrel, "
        "glowing hot orange embers at the tip" + STYLE_SUFFIX,
        6001,
        (76, 76),
    ),
    (
        "assets/sprites/towers/queso_fundido.png",
        "cute cartoon fondue pot turret bubbling with melted orange cheese, cheese "
        "dripping over the sides, steaming" + STYLE_SUFFIX,
        6002,
        (76, 76),
    ),
    (
        "assets/sprites/towers/pico_gallo.png",
        "small tri-barrel salsa launcher turret made of a wooden molcajete bowl, diced "
        "tomato onion and cilantro pieces loaded in three barrels" + STYLE_SUFFIX,
        6003,
        (80, 80),
    ),
]


def fetch_image(prompt: str, size: int, seed: int, retries: int = 3):
    enc = urllib.parse.quote(prompt)
    url = (
        f"https://image.pollinations.ai/prompt/{enc}"
        f"?width={size}&height={size}&nologo=true&model=flux&seed={seed}"
    )
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "TacoDefender/1.0"})
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = resp.read()
            if data[:2] in (b"\xff\xd8", b"\x89P"):
                return Image.open(io.BytesIO(data)).convert("RGBA")
            print(f"  [intento {attempt + 1}] respuesta invalida: {data[:80]!r}")
        except (urllib.error.URLError, OSError) as exc:
            print(f"  [intento {attempt + 1}] error: {exc}")
        time.sleep(5)
    return None


## Flood-fill (no umbral de distancia global) -- ver comentario extenso en
## fetch_taco_object_sprites.py sobre por qué (sombreado suave bajo el objeto vs zonas
## claras aisladas dentro de la silueta, ej. el vapor blanco de Queso Fundido).
def remove_background(img: Image.Image, thresh: int = 70) -> Image.Image:
    img = img.convert("RGBA")
    work = img.convert("RGB")
    w, h = work.size
    sentinel = (1, 2, 3)
    step = max(1, w // 60)
    for x in range(0, w, step):
        ImageDraw.floodfill(work, (x, 0), sentinel, thresh=thresh)
        ImageDraw.floodfill(work, (x, h - 1), sentinel, thresh=thresh)
    for y in range(0, h, step):
        ImageDraw.floodfill(work, (0, y), sentinel, thresh=thresh)
        ImageDraw.floodfill(work, (w - 1, y), sentinel, thresh=thresh)
    wpx = work.load()
    ipx = img.load()
    for y in range(h):
        for x in range(w):
            if wpx[x, y] == sentinel:
                r, g, b, a = ipx[x, y]
                ipx[x, y] = (r, g, b, 0)
    return img


def crop_to_content(img: Image.Image, padding: int = 6) -> Image.Image:
    bbox = img.getbbox()
    if bbox is None:
        return img
    x0, y0, x1, y1 = bbox
    x0 = max(0, x0 - padding)
    y0 = max(0, y0 - padding)
    x1 = min(img.width, x1 + padding)
    y1 = min(img.height, y1 + padding)
    return img.crop((x0, y0, x1, y1))


def main() -> None:
    raw_dir = "assets/sprites/_raw_ai"
    os.makedirs(raw_dir, exist_ok=True)
    for path, prompt, seed, output_size in SPECS:
        raw_path = os.path.join(raw_dir, os.path.basename(path))
        if os.path.exists(raw_path):
            print(f"Usando raw en cache: {raw_path}")
            img = Image.open(raw_path).convert("RGBA")
        else:
            print(f"Descargando {path} (seed={seed}) ...")
            img = fetch_image(prompt, FETCH_SIZE, seed)
            if img is None:
                print(f"  FALLO: {path}")
                continue
            img.save(raw_path, "PNG")
            time.sleep(3)
        keyed = remove_background(img)
        keyed = crop_to_content(keyed)
        keyed = keyed.resize(output_size, Image.LANCZOS)
        keyed.save(path, "PNG")
        opaque = sum(1 for p in keyed.getdata() if p[3] > 100)
        pct = opaque * 100 // (output_size[0] * output_size[1])
        print(f"  OK -> {path} ({output_size[0]}x{output_size[1]}, {pct}% opaco)")


if __name__ == "__main__":
    main()
