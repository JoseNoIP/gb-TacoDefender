#!/usr/bin/env python3
"""Descarga los 3 fondos de pantalla completa de Taco Defender desde Pollinations.ai
(Flux, gratuito). Ver /gen-ai-art: descargas SECUENCIALES (tier gratis = 1 en cola),
JPEG convertido a PNG, seeds documentados para reproducibilidad.

Uso: /tmp/gb_venv/bin/python3 tools/fetch_taco_backgrounds.py
"""
import io
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

from PIL import Image

WIDTH = 390
HEIGHT = 844

BACKGROUNDS = [
    {
        "path": "assets/sprites/backgrounds/menu_bg.png",
        "prompt": (
            "cozy taco truck at night game background portrait, warm string lights, "
            "papel picado banners, glowing neon taco sign, wooden counter, festive "
            "atmosphere, warm orange and brown tones, mobile game art, no text, no letters"
        ),
        "seed": 4001,
    },
    {
        "path": "assets/sprites/backgrounds/game_bg.png",
        "prompt": (
            "empty dark wooden table texture background, plain wood plank surface, "
            "subtle wood grain pattern, dim night ambiance, very dark brown tones, "
            "minimal low detail, no objects, no props, mobile game background portrait, "
            "no text, no letters"
        ),
        "seed": 4102,
    },
    {
        "path": "assets/sprites/backgrounds/upgrade_bg.png",
        "prompt": (
            "taqueria pantry storage room at night game background portrait, wooden "
            "shelves with salsa jars and dried chili peppers hanging, warm dim lighting, "
            "brown and orange tones, mobile game art, no text, no letters"
        ),
        "seed": 4003,
    },
]


def fetch_image(prompt: str, width: int, height: int, seed: int, retries: int = 3):
    enc = urllib.parse.quote(prompt)
    url = (
        f"https://image.pollinations.ai/prompt/{enc}"
        f"?width={width}&height={height}&nologo=true&model=flux&seed={seed}"
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


def main() -> None:
    for spec in BACKGROUNDS:
        print(f"Descargando {spec['path']} (seed={spec['seed']}) ...")
        img = fetch_image(spec["prompt"], WIDTH, HEIGHT, spec["seed"])
        if img is None:
            print(f"  FALLO: {spec['path']}")
            continue
        img.save(spec["path"], "PNG")
        print(f"  OK -> {spec['path']} ({img.width}x{img.height})")
        time.sleep(3)


if __name__ == "__main__":
    main()
