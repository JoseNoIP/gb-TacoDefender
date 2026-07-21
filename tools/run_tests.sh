#!/bin/bash
# Corre la suite GUT SIN contaminar el guardado real del usuario.
#
# Bug real (ver regla CLAUDE.md correspondiente): cualquier autoload que persista en
# user://algo.json (progreso, oro, desbloqueos) es el MISMO archivo real que usa una
# partida jugada a mano. GUT no aísla ese estado entre corridas, así que un test que suba
# un valor "solo si es mayor" u otorgue algo sin revertirlo queda escrito ahí PARA
# SIEMPRE — con decenas de corridas a lo largo de una sesión de desarrollo, el guardado
# real termina con progreso que el jugador nunca ganó, y el síntoma solo se nota jugando
# de verdad mucho después.
#
# Este script es la red de seguridad: respalda los user://*.json relevantes antes de
# correr la suite y los restaura después, pase lo que pase — así CUALQUIER test,
# presente o futuro, nunca puede afectar permanentemente una partida real.
#
# Uso: ./tools/run_tests.sh (mismos argumentos de siempre para godot/GUT, opcional)
set -uo pipefail

PROJECT_NAME=$(grep -m1 '^config/name=' project.godot | sed -E 's/config\/name="(.*)"/\1/')
USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/$PROJECT_NAME"

# Agregar acá cada archivo user://*.json que el juego persista (ver autoloads con save()).
JSON_FILES=("save.json" "meta.json")

BACKUP_DIR=$(mktemp -d)

_backup() {
    local name="$1"
    local src="$USER_DATA_DIR/$name"
    if [ -f "$src" ]; then
        cp "$src" "$BACKUP_DIR/$name"
    else
        touch "$BACKUP_DIR/$name.absent"
    fi
}

_restore() {
    local name="$1"
    local dst="$USER_DATA_DIR/$name"
    if [ -f "$BACKUP_DIR/$name.absent" ]; then
        rm -f "$dst"
    elif [ -f "$BACKUP_DIR/$name" ]; then
        cp "$BACKUP_DIR/$name" "$dst"
    fi
}

for f in "${JSON_FILES[@]}"; do
    _backup "$f"
done

godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit -glog=2 "$@"
EXIT_CODE=$?

for f in "${JSON_FILES[@]}"; do
    _restore "$f"
done
rm -rf "$BACKUP_DIR"

exit $EXIT_CODE
