#!/usr/bin/env python3
"""Descarga sprites de torres/enemigos de Taco Defender en estilo "vector cartoon
pulido" (referencia: bocetos/Taco-Defender-ejemplo.png) desde Pollinations.ai, en vez
del pixel-art procedural de tools/gen_taco_sprites.py.

Reemplaza ESE approach a propósito -- el usuario pidió específicamente el look "chile
cannon / licuadora / catapulta" ilustrado, que el generador procedural (formas simples,
sin sombreado) no puede lograr. Fuera de la recomendación por defecto del skill
/gen-ai-art ("<=64x64 -> procedural") por decisión explícita del usuario: se genera a
512x512 (más detalle sobrevive el downscale) y se reduce con LANCZOS al tamaño 2x de
render (mismo patrón de tools/gen_taco_sprites.py: Sprite2D.scale=0.5 en el juego).

Todos los prompts comparten el mismo STYLE_SUFFIX para maximizar consistencia visual
entre piezas generadas de forma independiente (Pollinations no tiene memoria de estilo
entre pedidos) -- aun así, esperar variación entre piezas y curar/reintentar seeds si
alguna no encaja.

Uso: /tmp/gb_venv/bin/python3 tools/fetch_taco_object_sprites.py
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

# path -> (prompt, seed, output_size)  -- output_size = 2x el tamaño de render en juego
# (ver Constants.gd / TowerBase.gd / EnemyBase.gd), mismo patrón que gen_taco_sprites.py.
SPECS = [
    (
        "assets/sprites/towers/salsa_verde.png",
        "red chili pepper shaped cannon turret, green salsa sauce dripping from the tip"
        + STYLE_SUFFIX,
        5001,
        (72, 72),
    ),
    (
        "assets/sprites/towers/hielo_horchata.png",
        "cute cartoon blender machine, white body, ice cubes on top, creamy horchata "
        "drink inside" + STYLE_SUFFIX,
        5002,
        (72, 72),
    ),
    (
        "assets/sprites/towers/catapulta_guac.png",
        "small wooden toy catapult loaded with a green avocado guacamole ball"
        + STYLE_SUFFIX,
        5003,
        (80, 80),
    ),
    (
        "assets/sprites/enemies/basic.png",
        "cute cartoon housefly insect, black body, small wings, big cartoon eyes"
        + STYLE_SUFFIX,
        5004,
        (40, 40),
    ),
    (
        "assets/sprites/enemies/fast.png",
        "cute cartoon cockroach insect, brown body, small legs, big cartoon eyes"
        + STYLE_SUFFIX,
        5005,
        (32, 32),
    ),
    (
        "assets/sprites/enemies/tank.png",
        "cute cartoon gray mouse rodent, big round ears, pink nose, chubby body"
        + STYLE_SUFFIX,
        5006,
        (64, 64),
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


## Flood-fill en vez de un umbral de distancia global: un umbral global confunde el
## sombreado suave que Pollinations agrega bajo el objeto (gris claro, no blanco puro)
## con detalles reales del sprite si el umbral es bajo, o come partes claras del propio
## objeto (hielo, cuerpo blanco de la licuadora) si es alto. Flood-fill desde el borde
## solo limpia lo que está CONECTADO al fondo, así que un umbral más generoso (70) no
## toca zonas claras aisladas dentro de la silueta.
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


def crop_to_content(img: Image.Image, padding: int = 10) -> Image.Image:
    """Recorta al bounding box de píxeles no transparentes -- maximiza el detalle que
    sobrevive el downscale final (12x+ de un canvas de 512px a un sprite de ~40px)."""
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
