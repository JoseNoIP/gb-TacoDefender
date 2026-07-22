extends Node
## Constantes tipadas de Taco Defender. Autoload PRIMERO — todo lo demás depende de esto.
## Fuente de verdad: taco-defender-gdd.md (v1.1).
##
## Sin capas de física ([layer_names] no existe en project.godot a propósito): las torres
## encuentran objetivos y los proyectiles impactan por consulta de grupo (`&"enemies"`) +
## distancia, y los enemigos avanzan por waypoints manuales — no hay ningún Area2D/
## CharacterBody2D con collision_layer/collision_mask en todo el juego. Evita por completo
## la clase de bug de la regla CLAUDE.md #42 (layer nombrada sin emisor real) porque
## simplemente no hay ninguna layer que definir.

# --- Geometría / layout (390x844 portrait, debe calzar con project.godot [display]) ---
const DESIGN_WIDTH: float = 390.0
const DESIGN_HEIGHT: float = 844.0

# --- Grid del tablero (GDD sección 3 y 4 — el camino fijo hacia la taquería) ---
const TILE_SIZE: float = 60.0
const GRID_COLS: int = 6
const GRID_ROWS: int = 14
const BOARD_WIDTH: float = GRID_COLS * TILE_SIZE
const BOARD_HEIGHT: float = GRID_ROWS * TILE_SIZE

## Camino como lista de puntos de giro (columna, fila), 0-indexado. Todo tramo entre dos
## puntos consecutivos es horizontal o vertical (nunca diagonal) — grid_math.gd expande
## esto a la lista completa de celdas de camino. Spawn = primer punto; taquería/base =
## último punto. Serpentea las 14 filas para darle propósito real al control de "drag para
## desplazar cámara" del GDD sección 2 (el tablero completo, 840px de alto, no entra en
## el área de juego visible entre el HUD superior y la barra inferior — hace falta pan).
const PATH_TURN_CELLS: Array = [
	Vector2i(0, 0),
	Vector2i(5, 0),
	Vector2i(5, 2),
	Vector2i(0, 2),
	Vector2i(0, 4),
	Vector2i(5, 4),
	Vector2i(5, 6),
	Vector2i(0, 6),
	Vector2i(0, 8),
	Vector2i(5, 8),
	Vector2i(5, 10),
	Vector2i(0, 10),
	Vector2i(0, 12),
	Vector2i(5, 12),
	Vector2i(5, 13),
]

# --- HUD / layout de UI (deja espacio fijo arriba y abajo del tablero) ---
const HUD_TOP_HEIGHT: float = 90.0
const BOTTOM_BAR_HEIGHT: float = 150.0
## Legibilidad móvil (FASE 8 del skill /new-game) — nunca texto de gameplay más chico.
const UI_MIN_FONT_SIZE: int = 18

# --- Cámara (drag vertical, GDD sección 2 "Controles") ---
const CAMERA_DRAG_THRESHOLD_PX: float = 12.0  ## por debajo de esto, un touch es TAP no drag.

# --- Economía in-game (GDD sección 2) ---
const STARTING_GOLD: int = 100
const TOWER_SELL_RATIO: float = 0.7
const WAVE_AUTO_START_DELAY: float = 5.0

# --- Base / vida de la taquería (GDD sección 2) ---
## Vida inicial real = META_BASE_HP_PER_LEVEL[0] (3, "Vida Inicial Base" del GDD) — única
## fuente de verdad, ver upgrade_shop.gd::base_hp_for_level(). Sin constante separada acá
## para no tener el mismo "3" en dos lugares que puedan desincronizarse.
## GDD no especifica daño por enemigo que llega a la base; asumido 1 vida c/u (ver idea-base.md).
const BASE_DAMAGE_PER_LEAK: int = 1
const TOTAL_WAVES: int = 10

# --- Enemigos: Básico / mosca común (GDD sección 3) ---
const ENEMY_BASIC_HP: float = 10.0
const ENEMY_BASIC_SPEED: float = 80.0
const ENEMY_BASIC_REWARD: int = 5

# --- Enemigos: Rápido / cucaracha veloz (GDD sección 3) ---
const ENEMY_FAST_HP: float = 5.0
const ENEMY_FAST_SPEED: float = 200.0
const ENEMY_FAST_REWARD: int = 8

# --- Enemigos: Tank / ratón de carga pesado (GDD sección 3) ---
const ENEMY_TANK_HP: float = 100.0
const ENEMY_TANK_SPEED: float = 30.0
const ENEMY_TANK_REWARD: int = 25

# --- Torres: nivel máximo in-game (GDD sección 3: "hasta Nivel 3") ---
const TOWER_MAX_LEVEL: int = 3

# --- Torres: Salsa Verde (GDD sección 3) ---
const TOWER_SALSA_VERDE_COST: int = 50
const TOWER_SALSA_VERDE_DAMAGE: float = 15.0
const TOWER_SALSA_VERDE_RANGE: float = 150.0
const TOWER_SALSA_VERDE_COOLDOWN: float = 1.2
const TOWER_SALSA_VERDE_UPGRADE_COST: int = 35
const TOWER_SALSA_VERDE_UPGRADE_DAMAGE: float = 5.0
const TOWER_SALSA_VERDE_UPGRADE_RANGE: float = 15.0

# --- Torres: Hielo Horchata (GDD sección 3 — el upgrade SOLO extiende duración de
# ralentización; el GDD no le da bono de daño/rango, a diferencia de las otras dos). ---
const TOWER_HIELO_HORCHATA_COST: int = 75
const TOWER_HIELO_HORCHATA_DAMAGE: float = 8.0
const TOWER_HIELO_HORCHATA_RANGE: float = 120.0
const TOWER_HIELO_HORCHATA_COOLDOWN: float = 1.5
const TOWER_HIELO_HORCHATA_SLOW_RATIO: float = 0.5
const TOWER_HIELO_HORCHATA_SLOW_DURATION: float = 2.0
const TOWER_HIELO_HORCHATA_UPGRADE_COST: int = 50
const TOWER_HIELO_HORCHATA_UPGRADE_SLOW_DURATION_RATIO: float = 0.25

# --- Torres: Catapulta Guac (GDD sección 3 — el "Daño" de la tabla ES el daño de área). ---
const TOWER_CATAPULTA_GUAC_COST: int = 120
const TOWER_CATAPULTA_GUAC_DAMAGE: float = 25.0
const TOWER_CATAPULTA_GUAC_RANGE: float = 200.0
const TOWER_CATAPULTA_GUAC_COOLDOWN: float = 2.5
const TOWER_CATAPULTA_GUAC_AOE_RADIUS: float = 50.0
const TOWER_CATAPULTA_GUAC_UPGRADE_COST: int = 80
const TOWER_CATAPULTA_GUAC_UPGRADE_DAMAGE: float = 10.0

## IDs de torre/enemigo — String plano (nunca StringName) como valor, mismo motivo que
## MetaManager de otros proyectos GuacamoleBit: no depender de que String/StringName
## comparen igual como key/valor en absolutamente todos los casos de uso (Dictionary,
## match, etc.).
const TOWER_TYPE_SALSA_VERDE: String = "salsa_verde"
const TOWER_TYPE_HIELO_HORCHATA: String = "hielo_horchata"
const TOWER_TYPE_CATAPULTA_GUAC: String = "catapulta_guac"

const ENEMY_TYPE_BASIC: String = "basic"
const ENEMY_TYPE_FAST: String = "fast"
const ENEMY_TYPE_TANK: String = "tank"

const TOWER_TYPES: Array = [
	TOWER_TYPE_SALSA_VERDE, TOWER_TYPE_HIELO_HORCHATA, TOWER_TYPE_CATAPULTA_GUAC
]

## Catálogo único por tipo de torre — única fuente de verdad para HUD (botones de
## compra/nombre), Board (chequeo de oro ANTES de instanciar la torre) y TowerBase.setup()
## (subtipos se configuran leyendo esto, en vez de repetir cada const individual). Campos
## que un tipo no usa (ej. "aoe_radius" en Salsa Verde) quedan en 0.0 — nunca null, para
## no forzar checks de null en el código que los lee.
const TOWER_CATALOG: Dictionary = {
	TOWER_TYPE_SALSA_VERDE:
	{
		"name": "Salsa Verde",
		"cost": TOWER_SALSA_VERDE_COST,
		"damage": TOWER_SALSA_VERDE_DAMAGE,
		"range": TOWER_SALSA_VERDE_RANGE,
		"cooldown": TOWER_SALSA_VERDE_COOLDOWN,
		"upgrade_cost": TOWER_SALSA_VERDE_UPGRADE_COST,
		"upgrade_damage": TOWER_SALSA_VERDE_UPGRADE_DAMAGE,
		"upgrade_range": TOWER_SALSA_VERDE_UPGRADE_RANGE,
		"slow_duration": 0.0,
		"upgrade_slow_duration_ratio": 0.0,
		"aoe_radius": 0.0,
	},
	TOWER_TYPE_HIELO_HORCHATA:
	{
		"name": "Hielo Horchata",
		"cost": TOWER_HIELO_HORCHATA_COST,
		"damage": TOWER_HIELO_HORCHATA_DAMAGE,
		"range": TOWER_HIELO_HORCHATA_RANGE,
		"cooldown": TOWER_HIELO_HORCHATA_COOLDOWN,
		"upgrade_cost": TOWER_HIELO_HORCHATA_UPGRADE_COST,
		"upgrade_damage": 0.0,
		"upgrade_range": 0.0,
		"slow_duration": TOWER_HIELO_HORCHATA_SLOW_DURATION,
		"upgrade_slow_duration_ratio": TOWER_HIELO_HORCHATA_UPGRADE_SLOW_DURATION_RATIO,
		"aoe_radius": 0.0,
	},
	TOWER_TYPE_CATAPULTA_GUAC:
	{
		"name": "Catapulta Guac",
		"cost": TOWER_CATAPULTA_GUAC_COST,
		"damage": TOWER_CATAPULTA_GUAC_DAMAGE,
		"range": TOWER_CATAPULTA_GUAC_RANGE,
		"cooldown": TOWER_CATAPULTA_GUAC_COOLDOWN,
		"upgrade_cost": TOWER_CATAPULTA_GUAC_UPGRADE_COST,
		"upgrade_damage": TOWER_CATAPULTA_GUAC_UPGRADE_DAMAGE,
		"upgrade_range": 0.0,
		"slow_duration": 0.0,
		"upgrade_slow_duration_ratio": 0.0,
		"aoe_radius": TOWER_CATAPULTA_GUAC_AOE_RADIUS,
	},
}

## Diseño de las 10 oleadas (GDD sección 4), 1 entrada por oleada (índice 0 = Oleada 1).
## Cada oleada es una lista de grupos {type, count, interval}; wave_queue.gd los expande a
## una cola de spawn. Orden de grupos = orden de aparición en el GDD (secuencial, no
## intercalado — decisión de diseño documentada en idea-base.md, el GDD no especifica
## intercalado y una cola secuencial es determinística y fácil de testear).
const WAVE_DEFINITIONS: Array = [
	[{"type": "basic", "count": 5, "interval": 1.5}],
	[{"type": "basic", "count": 8, "interval": 1.2}],
	[{"type": "basic", "count": 5, "interval": 1.0}, {"type": "fast", "count": 3, "interval": 1.0}],
	[{"type": "fast", "count": 10, "interval": 0.6}],
	[{"type": "basic", "count": 6, "interval": 1.0}, {"type": "tank", "count": 1, "interval": 1.0}],
	[{"type": "fast", "count": 12, "interval": 0.8}, {"type": "tank", "count": 2, "interval": 0.8}],
	[
		{"type": "basic", "count": 15, "interval": 0.5},
		{"type": "fast", "count": 8, "interval": 0.5}
	],
	[{"type": "tank", "count": 4, "interval": 1.0}, {"type": "fast", "count": 10, "interval": 1.0}],
	[
		{"type": "basic", "count": 20, "interval": 0.4},
		{"type": "fast", "count": 15, "interval": 0.4}
	],
	[
		{"type": "tank", "count": 6, "interval": 0.5},
		{"type": "fast", "count": 15, "interval": 0.5},
		{"type": "basic", "count": 10, "interval": 0.5},
	],
]

# --- Metagame: Propinas (GDD sección 5) ---
const TIP_REWARD_PER_WAVE: int = 10
const TIP_REWARD_VICTORY_BONUS: int = 50

# --- Metagame: Upgrades permanentes (GDD sección 5 — 5 niveles, mismo costo por nivel
# para las 5 mejoras). IDs usados como key en MetaManager/upgrade_shop.gd. ---
const META_UPGRADE_MAX_LEVEL: int = 5
## índice = nivel_actual (costo del SIGUIENTE nivel).
const META_UPGRADE_COSTS: Array = [100, 250, 500, 1000, 2000]

const META_UPGRADE_ID_DAMAGE: String = "damage"  ## Salsa Más Picante: +5% daño global/nivel.
const META_UPGRADE_ID_RANGE: String = "range"  ## Vista de Águila: +5% rango global/nivel.
const META_UPGRADE_ID_COOLDOWN: String = "cooldown"  ## Despacho Rápido: -3% cooldown/nivel.
## Clientes Generosos: +10% propinas ganadas/nivel.
const META_UPGRADE_ID_TIPS: String = "tips"
## Barra Blindada: vida inicial 3→4→5→6→7 (nivel 5 extrapolado, ver META_BASE_HP_PER_LEVEL).
const META_UPGRADE_ID_BASE_HP: String = "base_hp"

const META_DAMAGE_BONUS_PER_LEVEL: float = 0.05
const META_RANGE_BONUS_PER_LEVEL: float = 0.05
const META_COOLDOWN_REDUCTION_PER_LEVEL: float = 0.03
## GDD: "+10% multiplicador de propinas ganadas" sin aclarar "por nivel" explícito como las
## otras 4 mejoras — asumido también por nivel (mismo patrón que el resto, ya que la
## sección dice "cada mejora tiene 5 niveles" de forma general). Documentado en idea-base.md.
const META_TIP_BONUS_PER_LEVEL: float = 0.10
## GDD lista literalmente 5 valores (3,4,5,6,7 = base + 4 pasos de +1). Como el sistema de
## tienda es uniforme (las 5 mejoras usan 5 niveles con el mismo costo por nivel), se
## extrapola el nivel 5 continuando el mismo patrón (+1/nivel) → 8. Documentado en
## idea-base.md como asunción explícita (el GDD no muestra ese 5to escalón).
const META_BASE_HP_PER_LEVEL: Array = [3, 4, 5, 6, 7, 8]  ## índice = nivel (0 = sin comprar).

# --- Colores UI (Constants es la única fuente — nunca hardcodear un Color en un feature) ---
const COLOR_BG_BOARD: Color = Color(0.086, 0.055, 0.035, 1.0)  ## marrón taquería, noche.
const COLOR_HUD_TEXT: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_GOLD: Color = Color(1.0, 0.85, 0.2, 1.0)
const COLOR_TIPS: Color = Color(0.55, 0.9, 0.6, 1.0)
const COLOR_HP_FULL: Color = Color(0.9, 0.25, 0.25, 1.0)
const COLOR_HP_EMPTY: Color = Color(0.35, 0.1, 0.1, 1.0)

## Paleta del Theme global (tools/build_game_theme.gd -> assets/theme/game_theme.tres,
## referenciado en project.godot [gui] theme/custom) — reestiliza TODOS los Button/Label/
## PanelContainer del juego de una sola vez, en vez del tema plano default de Godot.
const COLOR_BUTTON_NORMAL: Color = Color(0.75, 0.32, 0.12, 1.0)  ## naranja chile tostado.
const COLOR_BUTTON_HOVER: Color = Color(0.85, 0.4, 0.16, 1.0)
const COLOR_BUTTON_PRESSED: Color = Color(0.58, 0.24, 0.09, 1.0)
const COLOR_BUTTON_DISABLED: Color = Color(0.35, 0.3, 0.28, 0.55)
const COLOR_BUTTON_TEXT: Color = Color(1.0, 0.97, 0.9, 1.0)
const COLOR_BUTTON_TEXT_DISABLED: Color = Color(0.8, 0.78, 0.75, 0.7)
const UI_BUTTON_CORNER_RADIUS: int = 12
const UI_PANEL_CORNER_RADIUS: int = 12  ## igual a ModalStyleGd.CORNER_RADIUS, a propósito.

const COLOR_TILE_BUILDABLE: Color = Color(0.62, 0.5, 0.32, 1.0)
const COLOR_TILE_PATH: Color = Color(0.42, 0.32, 0.18, 1.0)
const COLOR_TILE_BORDER: Color = Color(0.2, 0.15, 0.08, 0.6)
const COLOR_TILE_BASE: Color = Color(0.85, 0.45, 0.15, 1.0)
const COLOR_TILE_SPAWN: Color = Color(0.3, 0.45, 0.25, 1.0)

const COLOR_RANGE_INDICATOR: Color = Color(1.0, 1.0, 1.0, 0.35)

const COLOR_HEALTHBAR_BG: Color = Color(0.0, 0.0, 0.0, 0.6)
const COLOR_HEALTHBAR_FILL: Color = Color(0.8, 0.15, 0.15, 1.0)
