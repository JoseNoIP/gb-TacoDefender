#!/usr/bin/env python3
"""Genera íconos pequeños de HUD para Taco Defender (moneda de oro, corazón de vida,
pausa, estrella de victoria, corazón roto de derrota) -- pixel art, Python stdlib puro,
sin PIL, sin red.

Mismo criterio que tools/gen_taco_sprites.py: a estos tamaños (~22-48px de render en
juego) el generador procedural da más control y nitidez que pedirle esto a IA (ver
/gen-ai-art, tabla "Cuándo usar IA vs procedural"). Reutiliza los helpers de
tools/gen_assets.py (save_png, _grid, _flat, _circle, _poly, _outline_circle, _rect)
pero escribe sus propias funciones make_* en vez de llamar a las de GuacBlaster Survivor
(regla CLAUDE.md #36) -- la técnica del corazón (dos círculos + un triángulo) está
inspirada en gen_assets.make_heart() pero reimplementada acá, parametrizada por tamaño.

Tamaño: el doble del render en juego para verse nítido en pantallas retina, igual que
tools/gen_taco_sprites.py y tools/fetch_taco_object_sprites.py (regla CLAUDE.md #62) --
el TextureRect que lo muestra usa expand_mode=EXPAND_IGNORE_SIZE + set_size(display, display)
para escalarlo hacia abajo.

Uso: python3 tools/gen_ui_icons.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_assets import save_png, _grid, _flat, _circle, _poly, _outline_circle, _rect  # noqa: E402

T = (0, 0, 0, 0)
OUTLINE = (60, 40, 10, 255)


def _thick_line(g, x1, y1, x2, y2, width, color):
    """Segmento con ancho, dibujado como quad (mismo helper que tools/gen_taco_sprites.py,
    duplicado acá a propósito -- cada gen_*.py de este proyecto es autocontenido)."""
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


def _draw_heart_shape(g, size, color):
    """Silueta de corazon (dos lobulos + punta triangular) -- compartida por
    make_heart() y make_broken_heart()."""
    cx, cy = size // 2, int(size * 0.44)
    lobe_r = int(size * 0.27)
    ox = int(size * 0.22)
    _circle(g, cx - ox, cy, lobe_r, color)
    _circle(g, cx + ox, cy, lobe_r, color)
    tip_y = cy + int(size * 0.42)
    _poly(
        g,
        [
            (cx - int(size * 0.46), cy + int(lobe_r * 0.3)),
            (cx + int(size * 0.46), cy + int(lobe_r * 0.3)),
            (cx, tip_y),
        ],
        color,
    )
    return cx, cy, lobe_r, ox, tip_y


def make_heart(size=44):
    """Corazon de vida: dos lobulos + punta triangular + brillo (misma tecnica que
    gen_assets.make_heart(), reimplementada param por `size`)."""
    red = (224, 48, 48, 255)
    shine = (255, 140, 140, 255)
    g = _grid(size, size)
    cx, cy, lobe_r, ox, _tip_y = _draw_heart_shape(g, size, red)
    _circle(g, cx - ox - lobe_r // 3, cy - lobe_r // 3, max(1, size // 12), shine)
    return _flat(g)


def make_broken_heart(size=96):
    """Corazon roto (derrota, GameOverScreen): mismo contorno que make_heart() en un
    rojo apagado + una grieta en zigzag dibujada ENCIMA en transparente -- el hueco deja
    ver el panel de fondo, leyendose como una grieta real partiendo el corazon en dos."""
    dull_red = (150, 55, 55, 255)
    g = _grid(size, size)
    cx, cy, lobe_r, _ox, tip_y = _draw_heart_shape(g, size, dull_red)
    crack = [
        (cx, cy - lobe_r // 2),
        (cx - size // 14, cy + size // 8),
        (cx + size // 16, cy + size // 4),
        (cx - size // 12, tip_y - size // 10),
    ]
    for i in range(len(crack) - 1):
        _thick_line(
            g, crack[i][0], crack[i][1], crack[i + 1][0], crack[i + 1][1], max(2, size // 16), T
        )
    return _flat(g)


def make_star(size=96):
    """Estrella de 5 puntas (victoria, VictoryScreen) -- doble trazo (oscuro atras,
    dorado adelante) para dar contorno, misma tecnica que _outline_circle en coin/torres."""
    gold = (255, 215, 70, 255)
    gold_dark = (200, 150, 20, 255)
    g = _grid(size, size)
    cx, cy = size // 2, size // 2

    def _star_points(scale):
        pts = []
        r_out = size * 0.46 * scale
        r_in = r_out * 0.42
        for i in range(10):
            r = r_out if i % 2 == 0 else r_in
            angle = -math.pi / 2 + i * math.pi / 5
            pts.append((int(cx + r * math.cos(angle)), int(cy + r * math.sin(angle))))
        return pts

    _poly(g, _star_points(1.14), gold_dark)
    _poly(g, _star_points(1.0), gold)
    return _flat(g)


def make_pause_icon(size=96):
    """Dos barras (simbolo de pausa, PauseScreen)."""
    cream = (255, 247, 235, 255)
    g = _grid(size, size)
    bar_w = int(size * 0.16)
    gap = int(size * 0.16)
    top = int(size * 0.2)
    bot = int(size * 0.8)
    cx = size // 2
    _rect(g, cx - gap // 2 - bar_w, top, cx - gap // 2, bot, cream)
    _rect(g, cx + gap // 2, top, cx + gap // 2 + bar_w, bot, cream)
    return _flat(g)


UI_SPECS = [
    ("assets/sprites/ui/coin.png", make_coin, 44),
    ("assets/sprites/ui/heart.png", make_heart, 44),
    ("assets/sprites/ui/broken_heart.png", make_broken_heart, 96),
    ("assets/sprites/ui/star.png", make_star, 96),
    ("assets/sprites/ui/pause_icon.png", make_pause_icon, 96),
]


def main() -> None:
    print("=== Generando iconos de HUD de Taco Defender ===")
    for path, fn, size in UI_SPECS:
        save_png(path, size, size, fn(size))
    print("Listo. Correr 'godot --headless --editor --quit' para reimportar en Godot.")


if __name__ == "__main__":
    main()
