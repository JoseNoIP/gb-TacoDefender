#!/usr/bin/env python3
"""Genera el ícono real de la app (el que se ve al instalarla en el teléfono) con IA,
en el mismo estilo "vector cartoon pulido" ya usado para torres/enemigos
(tools/fetch_taco_object_sprites.py) -- reemplazó al taco de círculos planos generado
proceduralmente en el ahora eliminado tools/gen_taco_icon.py, que no compartía estilo
con el resto del arte final del juego.

Concepto: un taco-mascota con un mini cañón de chile (la torre "Salsa Verde", la más
icónica/barata del juego) montado encima, en pose de defensa -- une visualmente
"Taco" + "Defender" en una sola imagen, en vez de un taco genérico sin relación con el
gameplay.

Genera 4 archivos (Android adaptive icons, ver /android-deploy y la búsqueda de Godot
docs sobre launcher_icons/adaptive_*):
  assets/icon.png                     512x512 fondo sólido -- ícono plano (fallback/
                                       favicon/tiendas), reemplaza a config/icon.
  assets/icon_adaptive_foreground.png 432x432 fondo TRANSPARENTE, sujeto centrado
                                       dentro de la "safe zone" (circulo de 66% del
                                       canvas) para no recortarse en máscaras
                                       circulares/squircle de distintos launchers.
  assets/icon_adaptive_background.png 432x432 color sólido plano (mismo naranja marca).
  assets/icon_adaptive_monochrome.png 432x432 silueta blanca sobre transparente --
                                       "themed icons" de Android 13+ (Material You).
  assets/icon_192.png                 192x192 -- launcher_icons/main_192x192
                                       (launchers pre-adaptive-icon, Android <8).

Uso: /tmp/gb_venv/bin/python3 tools/fetch_taco_app_icon.py
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
BG_ORANGE = (214, 106, 33, 255)  # Constants.COLOR_BUTTON_NORMAL-adyacente, marca ya usada.
SEED = 9001

PROMPT = (
    "cute taco shell mascot character with a tiny red chili pepper cannon turret "
    "mounted on top like a tower defense turret, heroic defending pose"
    ", cute cartoon vector game asset, thick black outline, simple flat cel shading, "
    "vibrant saturated colors, mobile game icon style, white background, centered, "
    "isolated single object, no text, no watermark"
)


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


## Mismo flood-fill que fetch_taco_object_sprites.py (ver comentario ahí sobre por qué
## no un umbral de distancia global).
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


def _paste_centered_fitted(
    subject: Image.Image, canvas_size: int, fill_ratio: float, bg: tuple
) -> Image.Image:
    """Escala `subject` (ya recortado a su contenido) para que quepa dentro de un
    cuadrado de `fill_ratio` * canvas_size, centrado. bg=None -> canvas transparente."""
    canvas = Image.new("RGBA", (canvas_size, canvas_size), bg)
    target = int(canvas_size * fill_ratio)
    scale = min(target / subject.width, target / subject.height)
    new_size = (max(1, int(subject.width * scale)), max(1, int(subject.height * scale)))
    resized = subject.resize(new_size, Image.LANCZOS)
    offset = ((canvas_size - new_size[0]) // 2, (canvas_size - new_size[1]) // 2)
    canvas.alpha_composite(resized, offset)
    return canvas


def main() -> None:
    raw_dir = "assets/sprites/_raw_ai"
    os.makedirs(raw_dir, exist_ok=True)
    raw_path = os.path.join(raw_dir, "app_icon.png")

    if os.path.exists(raw_path):
        print(f"Usando raw en cache: {raw_path}")
        img = Image.open(raw_path).convert("RGBA")
    else:
        print(f"Descargando ícono (seed={SEED}) ...")
        img = fetch_image(PROMPT, FETCH_SIZE, SEED)
        if img is None:
            print("FALLO: no se pudo descargar la imagen.")
            sys.exit(1)
        img.save(raw_path, "PNG")

    subject = crop_to_content(remove_background(img))

    # Ícono plano 512x512 (fallback/tiendas) -- sujeto llena ~86% del canvas.
    flat = _paste_centered_fitted(subject, 512, 0.86, BG_ORANGE)
    flat.convert("RGB").save("assets/icon.png", "PNG")
    print("  OK -> assets/icon.png (512x512)")

    # Adaptive foreground -- sujeto dentro de la "safe zone" (circulo 66% del canvas,
    # ver búsqueda de Godot docs) para no recortarse en máscaras circulares/squircle.
    # 0.58 en vez de 0.66 porque la restricción real es sobre la DIAGONAL del bounding
    # box (brazos extendidos a los costados), no el lado -- un cuadrado de lado 0.66
    # ya se sale del círculo de radio 0.33 por las esquinas.
    adaptive_fg = _paste_centered_fitted(subject, 432, 0.58, (0, 0, 0, 0))
    adaptive_fg.save("assets/icon_adaptive_foreground.png", "PNG")
    print("  OK -> assets/icon_adaptive_foreground.png (432x432, transparente)")

    # Adaptive background -- color sólido plano, sin sujeto (el foreground ya lo trae).
    adaptive_bg = Image.new("RGBA", (432, 432), BG_ORANGE)
    adaptive_bg.convert("RGB").save("assets/icon_adaptive_background.png", "PNG")
    print("  OK -> assets/icon_adaptive_background.png (432x432)")

    # Adaptive monochrome (Android 13+, "themed icons" con Material You) -- MISMA silueta
    # que el foreground (misma safe zone, ya verificada con máscara circular), pero
    # rellena de blanco sólido: Android recolorea esta capa según el tema del sistema, así
    # que el color de origen no importa, solo el canal alpha define la forma.
    adaptive_mono = Image.new("RGBA", adaptive_fg.size, (0, 0, 0, 0))
    fg_px = adaptive_fg.load()
    mono_px = adaptive_mono.load()
    for y in range(adaptive_fg.height):
        for x in range(adaptive_fg.width):
            alpha = fg_px[x, y][3]
            mono_px[x, y] = (255, 255, 255, alpha)
    adaptive_mono.save("assets/icon_adaptive_monochrome.png", "PNG")
    print("  OK -> assets/icon_adaptive_monochrome.png (432x432, silueta blanca)")

    # main_192x192 -- launchers pre-adaptive-icon (Android <8).
    icon_192 = flat.resize((192, 192), Image.LANCZOS)
    icon_192.convert("RGB").save("assets/icon_192.png", "PNG")
    print("  OK -> assets/icon_192.png (192x192)")

    opaque = sum(1 for p in subject.getdata() if p[3] > 100)
    pct = opaque * 100 // (subject.width * subject.height)
    print(f"Sujeto extraído: {subject.size}, {pct}% opaco dentro de su propio bbox.")


if __name__ == "__main__":
    main()
