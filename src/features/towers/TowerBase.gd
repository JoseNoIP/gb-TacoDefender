extends Node2D
## Clase base de las 3 torres (GDD sección 3). Sin class_name — subtipos heredan por ruta
## (regla CLAUDE.md #13) y solo declaran su tipo + visual; el resto de los stats sale de
## Constants.TOWER_CATALOG (única fuente de verdad — ver Constants.gd) vía
## _configure_from_catalog(). Encuentra objetivos por grupo (`&"enemies"`) + distancia,
## nunca por Area2D (ver nota en Constants.gd sobre por qué este juego no usa física).
## Targeting "First" (GDD sección 3): el enemigo con MAYOR get_progress() dentro de rango
## (el más cerca del final del camino).

const ProjectileGd := preload("res://src/features/projectiles/Projectile.gd")
const UpgradeShopGd := preload("res://src/features/meta/upgrade_shop.gd")
const GridMathGd := preload("res://src/features/board/grid_math.gd")

var _grid_cell: Vector2i = Vector2i.ZERO
var _tower_type: String = ""
var _level: int = 1
var _total_invested: int = 0

var _base_cost: int = 0
var _base_damage: float = 0.0
var _base_range: float = 0.0
var _base_cooldown: float = 1.0
var _upgrade_cost: int = 0
var _upgrade_damage_bonus: float = 0.0
var _upgrade_range_bonus: float = 0.0
## Solo Hielo Horchata usa estos dos (GDD: su upgrade extiende SOLO duración de
## ralentización, nunca daño/rango — a diferencia de las otras dos torres).
var _base_slow_duration: float = 0.0
var _upgrade_slow_duration_ratio: float = 0.0

var _cooldown_timer: float = 0.0
var _selected: bool = false


func _ready() -> void:
	add_to_group(&"towers")


## Llamado por el subtipo en su propio _ready() (ANTES de super._ready()) — carga todos
## los stats desde Constants.TOWER_CATALOG[tower_type], dejando a cada subtipo con una
## sola línea propia en vez de repetir cada const individual.
func _configure_from_catalog(tower_type: String) -> void:
	_tower_type = tower_type
	var data: Dictionary = Constants.TOWER_CATALOG.get(tower_type, {}) as Dictionary
	_base_cost = int(data.get("cost", 0))
	_base_damage = float(data.get("damage", 0.0))
	_base_range = float(data.get("range", 0.0))
	_base_cooldown = float(data.get("cooldown", 1.0))
	_upgrade_cost = int(data.get("upgrade_cost", 0))
	_upgrade_damage_bonus = float(data.get("upgrade_damage", 0.0))
	_upgrade_range_bonus = float(data.get("upgrade_range", 0.0))
	_base_slow_duration = float(data.get("slow_duration", 0.0))
	_upgrade_slow_duration_ratio = float(data.get("upgrade_slow_duration_ratio", 0.0))


## Llamado por Board justo después de add_child() (mismo orden que EnemyBase.setup()).
func setup(grid_cell: Vector2i) -> void:
	_grid_cell = grid_cell
	_total_invested = _base_cost
	_cooldown_timer = 0.0
	position = GridMathGd.cell_to_local_center(grid_cell)


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		return
	var target: Node2D = _find_target()
	if target != null:
		_fire_at(target)
		_cooldown_timer = get_effective_cooldown()


func get_effective_damage() -> float:
	var level_bonus: float = float(_level - 1) * _upgrade_damage_bonus
	var meta_level: int = MetaManager.get_upgrade_level(Constants.META_UPGRADE_ID_DAMAGE)
	return (_base_damage + level_bonus) * UpgradeShopGd.damage_multiplier(meta_level)


func get_effective_range() -> float:
	var level_bonus: float = float(_level - 1) * _upgrade_range_bonus
	var meta_level: int = MetaManager.get_upgrade_level(Constants.META_UPGRADE_ID_RANGE)
	return (_base_range + level_bonus) * UpgradeShopGd.range_multiplier(meta_level)


func get_effective_cooldown() -> float:
	var meta_level: int = MetaManager.get_upgrade_level(Constants.META_UPGRADE_ID_COOLDOWN)
	return _base_cooldown * UpgradeShopGd.cooldown_multiplier(meta_level)


func get_effective_slow_duration() -> float:
	return _base_slow_duration * (1.0 + float(_level - 1) * _upgrade_slow_duration_ratio)


## false si ya está al nivel máximo o si no alcanza el oro — nunca cobra sin subir de
## nivel ni sube de nivel sin cobrar.
func upgrade() -> bool:
	if _level >= Constants.TOWER_MAX_LEVEL:
		return false
	if not GameManager.spend_gold(_upgrade_cost):
		return false
	_total_invested += _upgrade_cost
	_level += 1
	queue_redraw()
	return true


func get_sell_value() -> int:
	return int(round(float(_total_invested) * Constants.TOWER_SELL_RATIO))


func get_level() -> int:
	return _level


func get_tower_type() -> String:
	return _tower_type


func get_grid_cell() -> Vector2i:
	return _grid_cell


func get_upgrade_cost() -> int:
	return _upgrade_cost


func set_selected(value: bool) -> void:
	_selected = value
	queue_redraw()


func _find_target() -> Node2D:
	var best: Node2D = null
	var best_progress: float = -1.0
	var range_sq: float = get_effective_range() * get_effective_range()
	for node in get_tree().get_nodes_in_group(&"enemies"):
		if not is_instance_valid(node):
			continue
		var enemy: Node2D = node as Node2D
		if enemy == null:
			continue
		if global_position.distance_squared_to(enemy.global_position) > range_sq:
			continue
		var progress: float = float(enemy.call(&"get_progress"))
		if progress > best_progress:
			best_progress = progress
			best = enemy
	return best


func _fire_at(target: Node2D) -> void:
	var projectile: Node2D = ProjectileGd.new()
	get_parent().add_child(projectile)
	projectile.global_position = global_position
	var effect_params: Dictionary = {}
	if _tower_type == Constants.TOWER_TYPE_HIELO_HORCHATA:
		effect_params["slow_ratio"] = Constants.TOWER_HIELO_HORCHATA_SLOW_RATIO
		effect_params["slow_duration"] = get_effective_slow_duration()
	elif _tower_type == Constants.TOWER_TYPE_CATAPULTA_GUAC:
		effect_params["aoe_radius"] = Constants.TOWER_CATAPULTA_GUAC_AOE_RADIUS
	projectile.call(&"launch", target, get_effective_damage(), _tower_type, effect_params)


func _build_visual(size: Vector2, color: Color) -> void:
	var body: Polygon2D = Polygon2D.new()
	body.polygon = PackedVector2Array(
		[
			Vector2(-size.x * 0.5, -size.y * 0.5),
			Vector2(size.x * 0.5, -size.y * 0.5),
			Vector2(size.x * 0.5, size.y * 0.5),
			Vector2(-size.x * 0.5, size.y * 0.5),
		]
	)
	body.color = color
	add_child(body)


## Anillo de rango — visible solo mientras la torre está seleccionada (tap del jugador).
func _draw() -> void:
	if _selected:
		draw_arc(
			Vector2.ZERO, get_effective_range(), 0.0, TAU, 48, Constants.COLOR_RANGE_INDICATOR, 2.0
		)
