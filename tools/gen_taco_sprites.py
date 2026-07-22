#!/usr/bin/env python3
"""Genera los sprites procedurales de torres/enemigos/proyectiles de Taco Defender
(pixel art, Python stdlib puro, sin PIL, sin red).

Reutiliza los helpers genericos de dibujo de tools/gen_assets.py (save_png, _grid,
_flat, _circle, _outline_circle, _rect, _poly, _rounded_rect) en vez de reescribirlos
-- pero NUNCA llama a gen_assets.main() ni a ninguna de sus funciones make_*/sfx_*: esas
son 100% especificas de GuacBlaster Survivor, el juego del que se derivo este template
(regla CLAUDE.md #36).

Tamanos: el doble del tamano de render en juego (Constants.gd) para que se vean nitidos
en pantallas retina despues del escalado de Godot (stretch/mode=canvas_items) -- ver
TowerBase._build_visual/EnemyBase._build_visual, que aplican Sprite2D.scale=0.5.

Uso: python3 tools/gen_taco_sprites.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_assets import (  # noqa: E402
    save_png,
    _grid,
    _flat,
    _circle,
    _outline_circle,
    _rect,
    _poly,
    _rounded_rect,
)

T = (0, 0, 0, 0)
OUTLINE = (18, 12, 6, 255)


def _shade(c, delta):
    return (
        max(0, min(255, c[0] + delta)),
        max(0, min(255, c[1] + delta)),
        max(0, min(255, c[2] + delta)),
        255,
    )


def _thick_line(g, x1, y1, x2, y2, width, color):
    """Segmento con ancho, dibujado como quad -- usado para brazos/patas/antenas
    que deben sobresalir de un cuerpo circular ya dibujado."""
    dx, dy = x2 - x1, y2 - y1
    length = math.hypot(dx, dy)
    if length == 0:
        return
    nx, ny = -dy / length * width / 2, dx / length * width / 2
    _poly(
        g,
        [
            (int(x1 + nx), int(y1 + ny)),
            (int(x2 + nx), int(y2 + ny)),
            (int(x2 - nx), int(y2 - ny)),
            (int(x1 - nx), int(y1 - ny)),
        ],
        color,
    )


# ---------------------------------------------------------------------------
# Torres -- base cuadrada redondeada (mismo lenguaje visual que _icon_base) +
# silueta simbolica de la mecanica encima.
# ---------------------------------------------------------------------------

def _tower_base(g, size, color):
    dark = _shade(color, -70)
    light = _shade(color, 35)
    r = size // 7
    _rounded_rect(g, 0, 0, size - 1, size - 1, r, dark)
    _rounded_rect(g, 2, 2, size - 3, size - 3, r - 1, color)
    _rounded_rect(g, 2, 2, size - 3, size // 2, r - 1, light)


def make_tower_salsa_verde(size=72):
    """Cañon de salsa: botella con boquilla disparando un chorro."""
    color = (64, 166, 51, 255)
    g = _grid(size, size)
    _tower_base(g, size, color)
    cx = size // 2
    bottle_w = size // 5
    bottle_top = size // 3
    bottle_bot = size - size // 5
    dark = _shade(color, -60)
    _rounded_rect(g, cx - bottle_w, bottle_top, cx + bottle_w, bottle_bot, bottle_w // 2, dark)
    neck_w = bottle_w // 2
    neck_top = bottle_top - size // 10
    _rect(g, cx - neck_w, neck_top, cx + neck_w, bottle_top, dark)
    spray = (150, 235, 130, 255)
    for ox in (-1, 0, 1):
        length = size // 8 if ox == 0 else size // 11
        _poly(
            g,
            [
                (cx + ox * neck_w, neck_top),
                (cx + ox * neck_w - 2, neck_top - length),
                (cx + ox * neck_w + 2, neck_top - length),
            ],
            spray,
        )
    _outline_circle(g, cx, bottle_top + (bottle_bot - bottle_top) // 2, bottle_w, OUTLINE)
    return _flat(g)


def make_tower_hielo_horchata(size=72):
    """Cañon de hielo/horchata: vaso con lineas de canela y un cristal de hielo."""
    color = (217, 204, 166, 255)
    g = _grid(size, size)
    _tower_base(g, size, color)
    cx = size // 2
    cup_top = size // 3
    cup_bot = size - size // 5
    cup_hw = size // 5
    cream = (238, 228, 200, 255)
    _poly(
        g,
        [
            (cx - cup_hw, cup_top),
            (cx + cup_hw, cup_top),
            (cx + cup_hw - 3, cup_bot),
            (cx - cup_hw + 3, cup_bot),
        ],
        cream,
    )
    cinnamon = (168, 122, 66, 255)
    step = (cup_bot - cup_top) // 4
    for i in range(1, 4):
        y = cup_top + step * i
        _rect(g, cx - cup_hw + 2, y, cx + cup_hw - 2, y + 1, cinnamon)
    ice = (196, 226, 255, 255)
    iy = size // 6
    ir = size // 9
    _poly(
        g,
        [
            (cx, iy - ir),
            (cx + ir, iy),
            (cx, iy + ir),
            (cx - ir, iy),
        ],
        ice,
    )
    _poly(
        g,
        [(cx - 1, iy - ir), (cx + 1, iy - ir), (cx + 1, iy + ir), (cx - 1, iy + ir)],
        (255, 255, 255, 255),
    )
    return _flat(g)


def make_tower_catapulta_guac(size=80):
    """Catapulta: base de madera + brazo diagonal con guacamole en la cuchara."""
    color = (89, 140, 64, 255)
    g = _grid(size, size)
    _tower_base(g, size, color)
    wood = (110, 74, 40, 255)
    wood_dark = _shade(wood, -40)
    base_y = size - size // 4
    _rect(g, size // 6, base_y, size - size // 6, base_y + size // 14, wood_dark)
    pivot_x, pivot_y = size // 2 + size // 8, base_y
    tip_x, tip_y = size // 5, size // 4
    _thick_line(g, pivot_x, pivot_y, tip_x, tip_y, size // 9, wood)
    _circle(g, pivot_x, pivot_y, size // 12, wood_dark)
    cup = _shade(wood, -20)
    _circle(g, tip_x, tip_y, size // 10, cup)
    guac = (120, 176, 60, 255)
    pit = (94, 60, 30, 255)
    gr = size // 7
    _circle(g, tip_x, tip_y - size // 14, gr, guac)
    _circle(g, tip_x, tip_y - size // 14, gr // 3, pit)
    _outline_circle(g, tip_x, tip_y - size // 14, gr, OUTLINE)
    return _flat(g)


# ---------------------------------------------------------------------------
# Enemigos -- silueta reconocible sobre circulo base del color de Constants.gd.
# ---------------------------------------------------------------------------

def make_enemy_basic(size=40):
    """Mosca comun: cuerpo ovalado oscuro + dos alas translucidas."""
    color = (38, 38, 46, 255)
    g = _grid(size, size)
    cx, cy = size // 2, size // 2
    r = size // 2 - 1
    wing = (210, 215, 225, 130)
    _circle(g, cx - r // 2, cy - r // 3, int(r * 0.62), wing)
    _circle(g, cx + r // 2, cy - r // 3, int(r * 0.62), wing)
    _circle(g, cx, cy, r, color)
    eye = (196, 40, 40, 255)
    _circle(g, cx - r // 3, cy - r // 4, max(1, r // 6), eye)
    _circle(g, cx + r // 3, cy - r // 4, max(1, r // 6), eye)
    _outline_circle(g, cx, cy, r, OUTLINE)
    return _flat(g)


def make_enemy_fast(size=32):
    """Cucaracha veloz: cuerpo ovalado marron (mas ancho que alto) + patas y
    antenas dibujadas DESPUES del cuerpo para que sobresalgan visibles."""
    color = (115, 71, 38, 255)
    g = _grid(size, size)
    cx, cy = size // 2, size // 2
    body_hw = size // 2 - 1
    body_hh = int(body_hw * 0.68)
    # Ovalo horizontal: capsula = rect central + circulos en cada extremo.
    _circle(g, cx - (body_hw - body_hh), cy, body_hh, color)
    _circle(g, cx + (body_hw - body_hh), cy, body_hh, color)
    _rect(g, cx - (body_hw - body_hh), cy - body_hh, cx + (body_hw - body_hh), cy + body_hh, color)
    stripe = _shade(color, -35)
    _rect(g, cx - 1, cy - body_hh + 1, cx + 1, cy + body_hh - 1, stripe)
    leg_len = body_hh + size // 6
    for ox in (-1, 0, 1):
        lx = cx + ox * (body_hw // 2)
        direction = -1 if ox <= 0 else 1
        _thick_line(g, lx, cy - body_hh // 3, lx + direction * 3, cy - leg_len, 2, OUTLINE)
        _thick_line(g, lx, cy + body_hh // 3, lx + direction * 3, cy + leg_len, 2, OUTLINE)
    front_x = cx + (body_hw - body_hh) * 2
    _thick_line(g, front_x, cy - body_hh // 2, front_x + size // 5, cy - leg_len, 1, OUTLINE)
    _thick_line(g, front_x, cy + body_hh // 4, front_x + size // 5, cy + body_hh // 6, 1, OUTLINE)
    return _flat(g)


def make_enemy_tank(size=64):
    """Raton de carga pesado: cuerpo redondo gris + orejas (dibujadas DESPUES del
    cuerpo, centradas fuera de su radio, para que no queden tapadas) + cola."""
    color = (140, 140, 148, 255)
    g = _grid(size, size)
    cx, cy = size // 2, size // 2
    r = size // 2 - 2
    tail = _shade(color, -45)
    _thick_line(g, cx + r // 2, cy + r - 4, cx + r + size // 10, cy + r + size // 12, 4, tail)
    _circle(g, cx, cy, r, color)
    ear_inner = (196, 158, 160, 255)
    ear_r = int(r * 0.35)
    for ox in (-1, 1):
        ecx = cx + ox * int(r * 0.78)
        ecy = cy - int(r * 0.62)
        _circle(g, ecx, ecy, ear_r, color)
        _circle(g, ecx, ecy, int(ear_r * 0.55), ear_inner)
        _outline_circle(g, ecx, ecy, ear_r, OUTLINE)
    nose = (214, 130, 140, 255)
    _circle(g, cx, cy + int(r * 0.5), max(1, r // 6), nose)
    _outline_circle(g, cx, cy, r, OUTLINE)
    return _flat(g)


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


TOWER_SPECS = [
    ("assets/sprites/towers/salsa_verde.png", make_tower_salsa_verde, 72),
    ("assets/sprites/towers/hielo_horchata.png", make_tower_hielo_horchata, 72),
    ("assets/sprites/towers/catapulta_guac.png", make_tower_catapulta_guac, 80),
]

ENEMY_SPECS = [
    ("assets/sprites/enemies/basic.png", make_enemy_basic, 40),
    ("assets/sprites/enemies/fast.png", make_enemy_fast, 32),
    ("assets/sprites/enemies/tank.png", make_enemy_tank, 64),
]

PROJECTILE_SPECS = [
    ("assets/sprites/projectiles/salsa_verde.png", make_projectile_salsa_verde, 24),
    ("assets/sprites/projectiles/hielo_horchata.png", make_projectile_hielo_horchata, 24),
    ("assets/sprites/projectiles/catapulta_guac.png", make_projectile_catapulta_guac, 24),
]


def main() -> None:
    print("=== Generando sprites procedurales de Taco Defender ===")
    for path, fn, size in TOWER_SPECS + ENEMY_SPECS + PROJECTILE_SPECS:
        save_png(path, size, size, fn(size))
    print("Listo. Correr 'godot --headless --editor --quit' para reimportar en Godot.")


if __name__ == "__main__":
    main()
