#!/usr/bin/env python3
"""Genera assets/icon.png y assets/splash.png para Taco Defender: un taco estilizado
sobre fondo solido, generado con Python stdlib puro (sin PIL, sin red).

Reutiliza los helpers genericos de dibujo de tools/gen_assets.py (save_png, _grid,
_flat, _circle) en vez de reescribirlos — pero NUNCA llama a gen_assets.main() ni a
ninguna de sus funciones make_*/sfx_*: esas son 100% especificas de GuacBlaster
Survivor (el juego del que se derivo este template) y sobreescribirian assets que no
existen en este proyecto con el sprite equivocado (regla CLAUDE.md #36).

Uso: python3 tools/gen_taco_icon.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_assets import save_png, _grid, _flat, _circle  # noqa: E402

BG_ORANGE = (214, 106, 33, 255)
BG_BOARD = (22, 14, 9, 255)  # coincide con Constants.COLOR_BG_BOARD en el juego real.
SHELL = (224, 180, 96, 255)
SHELL_SHADOW = (176, 132, 60, 255)
LETTUCE = (94, 158, 58, 255)
TOMATO = (196, 62, 48, 255)
CHEESE = (238, 210, 110, 255)


def _draw_taco(g, cx, cy, r):
    """Taco estilizado: concha (circulo) + relleno (lechuga/queso/tomate) asomando arriba."""
    _circle(g, cx, cy + r // 10, r, SHELL_SHADOW)  # sombra para dar volumen.
    _circle(g, cx, cy, int(r * 0.94), SHELL)
    top_y = cy - int(r * 0.55)
    _circle(g, cx, top_y, int(r * 0.62), LETTUCE)
    _circle(g, cx - int(r * 0.18), top_y + int(r * 0.10), int(r * 0.16), TOMATO)
    _circle(g, cx + int(r * 0.22), top_y + int(r * 0.12), int(r * 0.14), TOMATO)
    _circle(g, cx, top_y - int(r * 0.05), int(r * 0.14), CHEESE)


def make_icon(size=512):
    g = _grid(size, size, fill=BG_ORANGE)
    _draw_taco(g, size // 2, int(size * 0.58), int(size * 0.34))
    return _flat(g)


def make_splash(size=512):
    g = _grid(size, size, fill=BG_BOARD)
    _draw_taco(g, size // 2, size // 2, int(size * 0.30))
    return _flat(g)


def main():
    print("=== Generando icono y splash de Taco Defender (procedural, sin IA) ===")
    save_png("assets/icon.png", 512, 512, make_icon(512))
    save_png("assets/splash.png", 512, 512, make_splash(512))
    print("Listo. Correr 'godot --headless --editor --quit' para reimportar en Godot.")


if __name__ == "__main__":
    main()
