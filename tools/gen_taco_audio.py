#!/usr/bin/env python3
"""Genera los SFX y la música de fondo de Taco Defender -- WAV puro vía Python stdlib
(wave/struct/array), sin PIL, sin red, sin encoder externo (regla CLAUDE.md #46).

Reutiliza los helpers de síntesis de tools/gen_assets.py (_env, _sine, _sweep, _noise,
_mix, _concat, save_wav, RATE) pero escribe sus propias funciones sfx_*/music_* en vez
de llamar a las de GuacBlaster Survivor (regla CLAUDE.md #36) -- los nombres de archivo
en AudioManager.SFX_FILES/MUSIC_PATH son específicos de Taco Defender.

Uso: python3 tools/gen_taco_audio.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_assets import _env, _sine, _sweep, _noise, _mix, _concat, save_wav, RATE  # noqa: E402


def _click(dur=0.012, amp=0.5):
    """Transiente de ruido muy corto -- sin esto, un SFX de impacto solo con tonos
    puros se percibe blando/sintético (regla CLAUDE.md #58)."""
    return _env(_noise(dur, amp), 0.0005, dur * 0.8)


def sfx_tower_place():
    """Torre construida: click de contacto + golpe grave corto (objeto asentándose)."""
    click = _click(0.012, 0.5)
    thud = _env(_sweep(220, 90, 0.09, 0.4), 0.002, 0.08)
    return _mix(click, thud)


def sfx_tower_upgrade():
    """Mejora de torre: arpegio ascendente corto de 3 notas + brillo."""
    return _concat(
        _env(_sine(523, 0.06, 0.35), 0.002, 0.03),  # C5
        _env(_sine(659, 0.06, 0.35), 0.002, 0.03),  # E5
        _env(_sine(784, 0.10, 0.4), 0.002, 0.06),  # G5
    )


def sfx_enemy_die():
    """Plaga eliminada: sweep descendente + noise burst corto (splat)."""
    pop = _mix(_sweep(500, 150, 0.12, 0.35), _noise(0.06, 0.2))
    return _env(pop, 0.002, 0.08)


def sfx_enemy_leak():
    """Plaga llega a la base (daño): alarma grave, doble beep corto."""
    beep1 = _env(_sine(180, 0.08, 0.4), 0.002, 0.03)
    silence = [0.0] * int(0.02 * RATE)
    beep2 = _env(_sine(150, 0.1, 0.45), 0.002, 0.05)
    return _concat(beep1, silence, beep2)


def sfx_wave_start():
    """Oleada arranca: dos notas ascendentes cortas ("acá vienen")."""
    n1 = _env(_sine(440, 0.08, 0.35), 0.002, 0.03)
    n2 = _env(_sine(660, 0.12, 0.4), 0.002, 0.05)
    return _concat(n1, n2)


def sfx_victory():
    """Victoria: arpegio ascendente de 4 notas (fanfarria simple)."""
    freqs = [523, 659, 784, 1047]  # C5 E5 G5 C6
    return _concat(*[_env(_sine(f, 0.16, 0.4), 0.004, 0.08) for f in freqs])


def sfx_defeat():
    """Derrota: sweep descendente largo, sombrío."""
    return _env(_sweep(300, 80, 0.6, 0.4), 0.01, 0.3)


def sfx_button_tap():
    """Tap de UI: click muy corto, sin cuerpo tonal -- no debe competir con los SFX de
    gameplay, que suenan mucho más seguido que un tap de menú."""
    return _click(0.015, 0.35)


def music_loop():
    """Música de fondo: dos acordes suaves alternados (A -> G, un paso entero abajo) con
    un tremolo lento de amplitud, en vez de un acorde ESTATICO de 3 tonos fijos sin
    ninguna variación en 4s -- el jugador reportó que sonaba como "un zumbido molesto"
    (correcto: sin movimiento de tono NI de amplitud, un pad sostenido se percibe como
    drone/zumbido, no como música, sin importar cuán consonante sea el acorde en sí).

    Duración EXACTA de 4.0s, dividida en 2 mitades de 2.0s cada una (un acorde por
    mitad) -- todas las frecuencias completan un número entero de ciclos DENTRO de su
    propia mitad (ver lista de abajo), así que no hay click ni en el empalme entre
    acordes (t=2.0s) ni en el loop completo (t=4.0s vuelve a t=0.0s), mismo criterio que
    la versión anterior pero aplicado dos veces.
    Acorde A (0.0-2.0s): 220/330/440 Hz -> 440/660/880 ciclos en 2s (todos enteros).
    Acorde B (2.0-4.0s): 196/294/392 Hz -> 392/588/784 ciclos en 2s (todos enteros).
    Tremolo: 0.5 Hz (2 ciclos completos en los 4.0s) modulando la amplitud entre ~82% y
    100% -- le da al pad una sensación de "respiración" en vez de un tono plano sostenido.
    """
    half = 2.0
    chord_a = _mix(_sine(220, half, 0.5), _sine(330, half, 0.4), _sine(440, half, 0.3))
    chord_b = _mix(_sine(196, half, 0.5), _sine(294, half, 0.4), _sine(392, half, 0.3))
    pad = _concat(chord_a, chord_b)
    tremolo_hz = 0.5
    return [
        s * (0.825 + 0.175 * math.sin(2 * math.pi * tremolo_hz * i / RATE)) * 0.22
        for i, s in enumerate(pad)
    ]


AUDIO_SPECS = [
    ("assets/audio/tower_place.wav", sfx_tower_place),
    ("assets/audio/tower_upgrade.wav", sfx_tower_upgrade),
    ("assets/audio/enemy_die.wav", sfx_enemy_die),
    ("assets/audio/enemy_leak.wav", sfx_enemy_leak),
    ("assets/audio/wave_start.wav", sfx_wave_start),
    ("assets/audio/victory.wav", sfx_victory),
    ("assets/audio/defeat.wav", sfx_defeat),
    ("assets/audio/button_tap.wav", sfx_button_tap),
    ("assets/audio/music_loop.wav", music_loop),
]


def main() -> None:
    print("=== Generando audio de Taco Defender ===")
    for path, fn in AUDIO_SPECS:
        save_wav(path, fn())
    print("Listo. Correr 'godot --headless --editor --quit' para reimportar en Godot.")


if __name__ == "__main__":
    main()
