#!/usr/bin/env python3
"""Genera las texturas tileables de piso del tablero de Taco Defender (camino de piedra
+ tierra/pasto construible) -- pixel art, Python stdlib puro, sin PIL, sin red.

A diferencia de los fondos de pantalla completa (Pollinations.ai, ver
tools/fetch_taco_backgrounds.py), ESTAS son texturas que se repiten sin costura cada
Constants.TILE_SIZE px, celda por celda, siguiendo la forma real del camino
(Constants.PATH_TURN_CELLS) -- pedirle esto a un generador de IA no da NINGUNA garantía
de tileo perfecto (ver /gen-ai-art, tabla "cuándo usar IA vs procedural"), así que se
generan proceduralmente con matemática de wraparound explícita: todo lo que se dibuja
cerca de un borde se dibuja TAMBIÉN en el borde opuesto, para que el patrón conecte sin
costura al repetirse en Board.gd::_draw(). Este es el fix real al pedido de "que el
camino en zigzag se vea como un camino real" -- antes de esto, un fondo de pantalla
completa (una escena fija sin relación con la forma del camino) quedaba semi-transparente
detrás de la grilla, lo cual no tenía sentido visual (la escena no zigzagueaba con el
camino real).

Uso: python3 tools/gen_board_tiles.py
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_assets import save_png, _grid, _flat, _circle, _rect  # noqa: E402


def _wrapped_circle(g, size, cx, cy, r, color):
    """Dibuja un círculo en las 9 posiciones de una grilla 3x3 de offsets (-size,0,+size)
    para garantizar que cualquier parte que sobresalga de un borde reaparezca en el
    opuesto -- sin esto, una mancha cerca del borde se cortaría de forma visible al
    repetir el tile en la celda vecina."""
    for ox in (-size, 0, size):
        for oy in (-size, 0, size):
            _circle(g, cx + ox, cy + oy, r, color)


def make_path_tile(size=120):
    """Camino de piedra: grilla de bloques rectangulares con mortero -- tileable por
    construcción (la grilla de bloques divide el tile en partes exactamente iguales, sin
    necesitar wraparound)."""
    mortar = (58, 46, 34, 255)
    stone_base = (120, 100, 78, 255)
    g = _grid(size, size, fill=mortar)
    cols, rows = 4, 4
    block_w = size / cols
    block_h = size / rows
    gap = 3
    random.seed(7)
    for row in range(rows):
        for col in range(cols):
            shade = random.randint(-14, 14)
            color = (
                max(0, min(255, stone_base[0] + shade)),
                max(0, min(255, stone_base[1] + shade)),
                max(0, min(255, stone_base[2] + shade)),
                255,
            )
            x1 = int(col * block_w) + gap
            y1 = int(row * block_h) + gap
            x2 = int((col + 1) * block_w) - gap
            y2 = int((row + 1) * block_h) - gap
            _rect(g, x1, y1, x2, y2, color)
    return _flat(g)


def make_ground_tile(size=120):
    """Tierra/pasto construible: base de tierra + pasto y piedritas dispersas, con
    wraparound para que las manchas no corten al repetir el tile."""
    dirt = (94, 74, 46, 255)
    tuft = (86, 122, 54, 255)
    pebble = (110, 96, 78, 255)
    g = _grid(size, size, fill=dirt)
    random.seed(11)
    for _ in range(26):
        cx = random.randint(0, size - 1)
        cy = random.randint(0, size - 1)
        r = random.randint(2, 4)
        _wrapped_circle(g, size, cx, cy, r, tuft)
    for _ in range(14):
        cx = random.randint(0, size - 1)
        cy = random.randint(0, size - 1)
        r = random.randint(1, 3)
        _wrapped_circle(g, size, cx, cy, r, pebble)
    return _flat(g)


BOARD_TILE_SPECS = [
    ("assets/sprites/board/path_tile.png", make_path_tile, 120),
    ("assets/sprites/board/ground_tile.png", make_ground_tile, 120),
]


def main() -> None:
    print("=== Generando texturas de piso del tablero ===")
    for path, fn, size in BOARD_TILE_SPECS:
        save_png(path, size, size, fn(size))
    print("Listo. Correr 'godot --headless --editor --quit' para reimportar en Godot.")


if __name__ == "__main__":
    main()
