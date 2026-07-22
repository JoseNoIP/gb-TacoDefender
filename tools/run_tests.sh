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

OUTPUT_LOG="$BACKUP_DIR/gut_output.log"
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit -glog=2 "$@" 2>&1 | tee "$OUTPUT_LOG"
EXIT_CODE=${PIPESTATUS[0]}

# Bug real descubierto en desarrollo (Taco Defender): un test_*.gd con un error de sintaxis
# (ej. llamar a una función que no existe) NO hace que GUT falle la corrida — lo reporta
# como "Failed to load script" + SCRIPT ERROR en la salida, pero simplemente lo excluye del
# conteo (0 tests de ese archivo) y el exit code sigue siendo 0. Sin este chequeo, un
# archivo de test roto pasaría el gate en silencio, dando falsa confianza ("todo en verde")
# mientras esa suite entera queda sin ejecutarse. Cualquier mención de estos strings en la
# salida fuerza el exit code a 1, sin importar lo que haya reportado GUT.
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" "$OUTPUT_LOG"; then
    echo ""
    echo "FALLO: al menos un archivo de test no pudo cargarse (ver SCRIPT ERROR/Parse Error arriba)." >&2
    echo "GUT excluye esos archivos del conteo en vez de fallar la corrida — por eso este chequeo." >&2
    EXIT_CODE=1
fi

for f in "${JSON_FILES[@]}"; do
    _restore "$f"
done
rm -rf "$BACKUP_DIR"

exit $EXIT_CODE
