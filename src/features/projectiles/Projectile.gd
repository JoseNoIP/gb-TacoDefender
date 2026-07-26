extends Node2D
## Proyectil simple sin física: viaja hacia una referencia de objetivo en vivo y aplica
## daño/efecto al llegar. Revalida is_instance_valid(target) TODOS los frames — el
## objetivo puede morir a mitad de vuelo por otra torre antes de que este impacte
## (regla CLAUDE.md #44/#59) y, si eso pasa, sigue hacia su última posición conocida.

const ImpactVfxGd := preload("res://src/features/vfx/impact_vfx.gd")

const SPEED: float = 520.0
const HIT_DISTANCE: float = 10.0
const AOE_BURST_AMOUNT: int = 20

var _target: Node2D = null
var _last_known_position: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _tower_type: String = ""
var _effect_params: Dictionary = {}


## effect_params (según _tower_type): {"slow_ratio", "slow_duration"} para Hielo Horchata,
## {"aoe_radius"} para Catapulta Guac, {"dot_damage_per_tick", "dot_tick_interval",
## "dot_duration"} para Queso Fundido. Vacío para Salsa Verde/Chile Habanero/Pico de Gallo
## (disparo único sin efecto adicional -- Pico de Gallo logra su multi-objetivo creando
## VARIOS proyectiles normales desde TowerBase, no con un effect_param acá).
func launch(target: Node2D, damage: float, tower_type: String, effect_params: Dictionary) -> void:
	_target = target
	_damage = damage
	_tower_type = tower_type
	_effect_params = effect_params
	if is_instance_valid(target):
		_last_known_position = (target as Node2D).global_position
	_build_visual()


func _process(delta: float) -> void:
	var aim_position: Vector2 = _last_known_position
	if is_instance_valid(_target):
		aim_position = _target.global_position
		_last_known_position = aim_position
	var to_target: Vector2 = aim_position - global_position
	var distance: float = to_target.length()
	var step: float = SPEED * delta
	if distance <= HIT_DISTANCE or distance <= step:
		_impact(aim_position)
		return
	global_position += to_target.normalized() * step


func _impact(at_position: Vector2) -> void:
	var burst_amount: int = 12
	match _tower_type:
		Constants.TOWER_TYPE_HIELO_HORCHATA:
			if is_instance_valid(_target):
				_target.call(&"take_damage", _damage)
				_target.call(
					&"apply_slow",
					float(_effect_params.get("slow_ratio", 0.5)),
					float(_effect_params.get("slow_duration", 2.0))
				)
		Constants.TOWER_TYPE_CATAPULTA_GUAC:
			_apply_aoe(at_position, float(_effect_params.get("aoe_radius", 50.0)))
			burst_amount = AOE_BURST_AMOUNT
		Constants.TOWER_TYPE_QUESO_FUNDIDO:
			if is_instance_valid(_target):
				_target.call(&"take_damage", _damage)
				_target.call(
					&"apply_dot",
					float(_effect_params.get("dot_damage_per_tick", 0.0)),
					float(_effect_params.get("dot_tick_interval", 0.5)),
					float(_effect_params.get("dot_duration", 0.0))
				)
		_:
			if is_instance_valid(_target):
				_target.call(&"take_damage", _damage)
	ImpactVfxGd.spawn(get_parent(), at_position, _impact_color(), burst_amount)
	queue_free()


func _impact_color() -> Color:
	match _tower_type:
		Constants.TOWER_TYPE_HIELO_HORCHATA:
			return Color(0.8, 0.9, 1.0, 1.0)
		Constants.TOWER_TYPE_CATAPULTA_GUAC:
			return Color(0.5, 0.35, 0.15, 1.0)
		Constants.TOWER_TYPE_CHILE_HABANERO:
			return Color(0.95, 0.25, 0.1, 1.0)
		Constants.TOWER_TYPE_QUESO_FUNDIDO:
			return Color(1.0, 0.82, 0.25, 1.0)
		Constants.TOWER_TYPE_PICO_GALLO:
			return Color(0.95, 0.45, 0.25, 1.0)
		_:
			return Color(0.4, 0.8, 0.3, 1.0)


func _apply_aoe(center: Vector2, radius: float) -> void:
	var radius_sq: float = radius * radius
	for node in get_tree().get_nodes_in_group(&"enemies"):
		if not is_instance_valid(node):
			continue
		var enemy: Node2D = node as Node2D
		if enemy == null:
			continue
		if enemy.global_position.distance_squared_to(center) <= radius_sq:
			enemy.call(&"take_damage", _damage)


## Sprites generados al doble del tamaño de render (ver tools/gen_taco_sprites.py) —
## se escala 0.5 para verse nítido en pantallas retina (regla CLAUDE.md #61).
func _build_visual() -> void:
	var texture_path: String = "res://assets/sprites/projectiles/salsa_verde.png"
	match _tower_type:
		Constants.TOWER_TYPE_HIELO_HORCHATA:
			texture_path = "res://assets/sprites/projectiles/hielo_horchata.png"
		Constants.TOWER_TYPE_CATAPULTA_GUAC:
			texture_path = "res://assets/sprites/projectiles/catapulta_guac.png"
		Constants.TOWER_TYPE_CHILE_HABANERO:
			texture_path = "res://assets/sprites/projectiles/chile_habanero.png"
		Constants.TOWER_TYPE_QUESO_FUNDIDO:
			texture_path = "res://assets/sprites/projectiles/queso_fundido.png"
		Constants.TOWER_TYPE_PICO_GALLO:
			texture_path = "res://assets/sprites/projectiles/pico_gallo.png"
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(texture_path)
	sprite.scale = Vector2(0.5, 0.5)
	add_child(sprite)
