#!/usr/bin/env python3
"""Genera los sprites procedurales de PROYECTILES de Taco Defender (pixel art, Python
stdlib puro, sin PIL, sin red).

Las torres y enemigos usaron este mismo enfoque en un primer pase, pero se reemplazaron
por arte generado con IA (ver tools/fetch_taco_object_sprites.py y /gen-ai-art) para
igualar el estilo "vector cartoon pulido" de la referencia de diseño
(bocetos/Taco-Defender-ejemplo.png) — por eso esas funciones se sacaron de este archivo:
si seguían acá, volver a correr `python3 tools/gen_taco_sprites.py` pisaría en silencio
los sprites de IA con los placeholders viejos (mismo riesgo que la regla CLAUDE.md #36).
Los proyectiles siguen siendo procedurales a propósito: a 12px de diámetro son
demasiado chicos para que sobreviva ningún detalle de una imagen de IA tras el downscale.

Reutiliza los helpers genericos de dibujo de tools/gen_assets.py (save_png, _grid,
_flat, _circle, _poly) en vez de reescribirlos -- pero NUNCA llama a gen_assets.main()
ni a ninguna de sus funciones make_*/sfx_*: esas son 100% especificas de GuacBlaster
Survivor, el juego del que se derivo este template (regla CLAUDE.md #36).

Uso: python3 tools/gen_taco_sprites.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_assets import save_png, _grid, _flat, _circle, _poly  # noqa: E402


# ---------------------------------------------------------------------------
# Proyectiles -- pequeños, sin outline (se ven en movimiento, un borde grueso
# los haria ver mas grandes de lo que su hitbox real es).
# ---------------------------------------------------------------------------

def make_projectile_salsa_verde(size=24):
    color = (102, 204, 77, 255)
    g = _grid(size, size)
    cx, cy = size // 2, size // 2
    r = size // 2 - 1
    _circle(g, cx, cy, r, color)
    _circle(g, cx - r // 3, cy - r // 3, max(1, r // 4), (200, 245, 190, 255))
    return _flat(g)


def make_projectile_hielo_horchata(size=24):
    color = (204, 230, 255, 255)
    g = _grid(size, size)
    cx, cy = size // 2, size // 2
    r = size // 2 - 1
    _poly(
        g,
        [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)],
        color,
    )
    _circle(g, cx, cy, max(1, r // 3), (255, 255, 255, 255))
    return _flat(g)


def make_projectile_catapulta_guac(size=24):
    color = (128, 89, 38, 255)
    g = _grid(size, size)
    cx, cy = size // 2, size // 2
    r = size // 2 - 1
    guac = (120, 176, 60, 255)
    _circle(g, cx, cy, r, guac)
    _circle(g, cx, cy, max(1, r // 3), color)
    return _flat(g)


PROJECTILE_SPECS = [
    ("assets/sprites/projectiles/salsa_verde.png", make_projectile_salsa_verde, 24),
    ("assets/sprites/projectiles/hielo_horchata.png", make_projectile_hielo_horchata, 24),
    ("assets/sprites/projectiles/catapulta_guac.png", make_projectile_catapulta_guac, 24),
]


def main() -> None:
    print("=== Generando sprites procedurales de proyectiles de Taco Defender ===")
    for path, fn, size in PROJECTILE_SPECS:
        save_png(path, size, size, fn(size))
    print("Listo. Correr 'godot --headless --editor --quit' para reimportar en Godot.")


if __name__ == "__main__":
    main()
