#!/usr/bin/env python3
"""Genera íconos pequeños de HUD para Taco Defender (moneda de oro, corazón de vida) --
pixel art, Python stdlib puro, sin PIL, sin red.

Mismo criterio que tools/gen_taco_sprites.py: a estos tamaños (~22px de render en
juego) el generador procedural da más control y nitidez que pedirle esto a IA (ver
/gen-ai-art, tabla "Cuándo usar IA vs procedural"). Reutiliza los helpers de
tools/gen_assets.py (save_png, _grid, _flat, _circle, _poly, _outline_circle) pero
escribe sus propias funciones make_* en vez de llamar a las de GuacBlaster Survivor
(regla CLAUDE.md #36) -- la técnica del corazón (dos círculos + un triángulo) está
inspirada en gen_assets.make_heart() pero reimplementada acá, parametrizada por tamaño.

Tamaño: el doble del render en juego (22px -> 44px) para verse nítido en pantallas
retina, igual que tools/gen_taco_sprites.py y tools/fetch_taco_object_sprites.py
(regla CLAUDE.md #62) -- el TextureRect que lo muestra usa expand_mode=EXPAND_IGNORE_SIZE
+ set_size(22, 22) para escalarlo hacia abajo.

Uso: python3 tools/gen_ui_icons.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_assets import save_png, _grid, _flat, _circle, _poly, _outline_circle  # noqa: E402

OUTLINE = (60, 40, 10, 255)


def make_coin(size=44):
    """Moneda de oro: círculo amarillo con borde y brillo, sin texto (se lee bien a
    cualquier tamaño sin depender de tipografía)."""
    gold = (255, 210, 60, 255)
    gold_dark = (214, 165, 30, 255)
    shine = (255, 240, 170, 255)
    g = _grid(size, size)
    cx, cy = size // 2, size // 2
    r = size // 2 - 2
    _circle(g, cx, cy, r, gold_dark)
    _circle(g, cx, cy, int(r * 0.82), gold)
    _circle(g, cx - r // 4, cy - r // 4, max(1, r // 5), shine)
    _outline_circle(g, cx, cy, r, OUTLINE)
    return _flat(g)


def make_heart(size=44):
    """Corazon de vida: dos lobulos + punta triangular + brillo (misma tecnica que
    gen_assets.make_heart(), reimplementada param por `size`)."""
    red = (224, 48, 48, 255)
    shine = (255, 140, 140, 255)
    g = _grid(size, size)
    cx, cy = size // 2, int(size * 0.44)
    lobe_r = int(size * 0.27)
    ox = int(size * 0.22)
    _circle(g, cx - ox, cy, lobe_r, red)
    _circle(g, cx + ox, cy, lobe_r, red)
    tip_y = cy + int(size * 0.42)
    _poly(
        g,
        [
            (cx - int(size * 0.46), cy + int(lobe_r * 0.3)),
            (cx + int(size * 0.46), cy + int(lobe_r * 0.3)),
            (cx, tip_y),
        ],
        red,
    )
    _circle(g, cx - ox - lobe_r // 3, cy - lobe_r // 3, max(1, size // 12), shine)
    return _flat(g)


UI_SPECS = [
    ("assets/sprites/ui/coin.png", make_coin, 44),
    ("assets/sprites/ui/heart.png", make_heart, 44),
]


def main() -> None:
    print("=== Generando iconos de HUD de Taco Defender ===")
    for path, fn, size in UI_SPECS:
        save_png(path, size, size, fn(size))
    print("Listo. Correr 'godot --headless --editor --quit' para reimportar en Godot.")


if __name__ == "__main__":
    main()
