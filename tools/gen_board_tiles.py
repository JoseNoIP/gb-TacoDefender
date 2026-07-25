#!/usr/bin/env python3
"""Genera las texturas tileables de piso del tablero de Taco Defender (camino de piedra
+ tierra/pasto construible) -- pixel art, Python stdlib puro, sin PIL, sin red.

A diferencia de los fondos de pantalla completa (Pollinations.ai, ver
tools/fetch_taco_backgrounds.py), ESTAS son texturas que se repiten sin costura cada
Constants.TILE_SIZE px, celda por celda, siguiendo la forma real del camino de cada
NIVEL (Constants.PATH_TEMPLATES[n]) -- pedirle esto a un generador de IA no da NINGUNA
garantía de tileo perfecto (ver /gen-ai-art, tabla "cuándo usar IA vs procedural"), así
que se generan proceduralmente con matemática de wraparound explícita: todo lo que se
dibuja cerca de un borde se dibuja TAMBIÉN en el borde opuesto, para que el patrón
conecte sin costura al repetirse en Board.gd::_draw().

10 temas (uno por nivel/PATH_TEMPLATES, ver Constants.BOARD_PATH_TEXTURES/
BOARD_GROUND_TEXTURES) -- misma geometría de generación (grilla de bloques para el
camino, círculos con wraparound para el suelo), solo cambia la paleta de color por
tema. El tema 0 usa la MISMA paleta que el tablero original de un solo camino (para no
cambiar la apariencia de la primera partida de nadie).

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


def make_path_tile(size, mortar, stone_base, seed):
    """Camino: grilla de bloques rectangulares con mortero -- tileable por construcción
    (la grilla de bloques divide el tile en partes exactamente iguales, sin necesitar
    wraparound)."""
    g = _grid(size, size, fill=mortar)
    cols, rows = 4, 4
    block_w = size / cols
    block_h = size / rows
    gap = 3
    random.seed(seed)
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


def make_ground_tile(size, base, tuft, pebble, seed):
    """Suelo construible: base + 2 capas de manchas dispersas (pasto/piedritas u otro
    par temático), con wraparound para que las manchas no corten al repetir el tile."""
    g = _grid(size, size, fill=base)
    random.seed(seed)
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


## Un tema por nivel (índice = MetaManager.get_victories() % 10, ver GridMathGd.
## select_path_template_index() y Constants.PATH_TEMPLATES). Tema 0 = paleta original
## (piedra/tierra), sin cambios respecto al tablero de un solo camino.
THEMES = [
    {  # 0: Piedra clásica (nivel 1, victories=0 -- paleta original sin cambios)
        "name": "piedra",
        "mortar": (58, 46, 34, 255),
        "stone_base": (120, 100, 78, 255),
        "ground_base": (94, 74, 46, 255),
        "tuft": (86, 122, 54, 255),
        "pebble": (110, 96, 78, 255),
    },
    {  # 1: Arena del desierto
        "name": "desierto",
        "mortar": (120, 92, 54, 255),
        "stone_base": (206, 174, 116, 255),
        "ground_base": (176, 138, 82, 255),
        "tuft": (150, 118, 62, 255),
        "pebble": (128, 96, 58, 255),
    },
    {  # 2: Nieve / hielo
        "name": "nieve",
        "mortar": (140, 158, 176, 255),
        "stone_base": (214, 228, 238, 255),
        "ground_base": (232, 240, 246, 255),
        "tuft": (196, 214, 228, 255),
        "pebble": (160, 182, 200, 255),
    },
    {  # 3: Selva
        "name": "selva",
        "mortar": (32, 44, 24, 255),
        "stone_base": (90, 108, 66, 255),
        "ground_base": (54, 70, 34, 255),
        "tuft": (46, 104, 48, 255),
        "pebble": (74, 90, 52, 255),
    },
    {  # 4: Volcánico
        "name": "volcanico",
        "mortar": (30, 20, 18, 255),
        "stone_base": (66, 46, 42, 255),
        "ground_base": (44, 28, 26, 255),
        "tuft": (196, 90, 30, 255),  # brasas, no pasto
        "pebble": (90, 60, 50, 255),
    },
    {  # 5: Playa costera
        "name": "playa",
        "mortar": (150, 140, 116, 255),
        "stone_base": (196, 186, 158, 255),
        "ground_base": (220, 206, 172, 255),
        "tuft": (200, 190, 158, 255),
        "pebble": (150, 170, 176, 255),  # conchas/piedras claras
    },
    {  # 6: Pantano
        "name": "pantano",
        "mortar": (40, 46, 30, 255),
        "stone_base": (76, 84, 58, 255),
        "ground_base": (52, 58, 38, 255),
        "tuft": (66, 92, 50, 255),
        "pebble": (36, 50, 40, 255),  # agua estancada oscura
    },
    {  # 7: Nocturno / piedra lunar
        "name": "nocturno",
        "mortar": (30, 32, 48, 255),
        "stone_base": (86, 92, 118, 255),
        "ground_base": (44, 46, 66, 255),
        "tuft": (60, 64, 92, 255),
        "pebble": (110, 114, 140, 255),
    },
    {  # 8: Otoño
        "name": "otono",
        "mortar": (66, 40, 24, 255),
        "stone_base": (140, 96, 60, 255),
        "ground_base": (98, 66, 34, 255),
        "tuft": (196, 120, 40, 255),  # hojas naranjas
        "pebble": (168, 60, 40, 255),  # hojas rojas
    },
    {  # 9: Dorado / prestigio (nivel 10 y cíclico en adelante)
        "name": "dorado",
        "mortar": (90, 66, 20, 255),
        "stone_base": (212, 172, 74, 255),
        "ground_base": (74, 40, 96, 255),  # base púrpura real
        "tuft": (162, 122, 210, 255),
        "pebble": (232, 196, 96, 255),
    },
]


def main() -> None:
    print("=== Generando texturas de piso del tablero (10 temas) ===")
    size = 120
    for index, theme in enumerate(THEMES):
        save_png(
            f"assets/sprites/board/path_tile_{index}.png",
            size,
            size,
            make_path_tile(size, theme["mortar"], theme["stone_base"], seed=7 + index),
        )
        save_png(
            f"assets/sprites/board/ground_tile_{index}.png",
            size,
            size,
            make_ground_tile(
                size, theme["ground_base"], theme["tuft"], theme["pebble"], seed=11 + index
            ),
        )
    print("Listo. Correr 'godot --headless --editor --quit' para reimportar en Godot.")


if __name__ == "__main__":
    main()
