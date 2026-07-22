extends Node2D
## Proyectil simple sin física: viaja hacia una referencia de objetivo en vivo y aplica
## daño/efecto al llegar. Revalida is_instance_valid(target) TODOS los frames — el
## objetivo puede morir a mitad de vuelo por otra torre antes de que este impacte
## (regla CLAUDE.md #44/#59) y, si eso pasa, sigue hacia su última posición conocida.

const SPEED: float = 520.0
const HIT_DISTANCE: float = 10.0

var _target: Node2D = null
var _last_known_position: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _tower_type: String = ""
var _effect_params: Dictionary = {}


## effect_params (según _tower_type): {"slow_ratio", "slow_duration"} para Hielo Horchata,
## {"aoe_radius"} para Catapulta Guac. Vacío para Salsa Verde (disparo único sin efecto).
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
		_:
			if is_instance_valid(_target):
				_target.call(&"take_damage", _damage)
	queue_free()


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


func _build_visual() -> void:
	var color: Color = Constants.COLOR_PROJECTILE_SALSA_VERDE
	match _tower_type:
		Constants.TOWER_TYPE_HIELO_HORCHATA:
			color = Constants.COLOR_PROJECTILE_HIELO_HORCHATA
		Constants.TOWER_TYPE_CATAPULTA_GUAC:
			color = Constants.COLOR_PROJECTILE_CATAPULTA_GUAC
	var body: Polygon2D = Polygon2D.new()
	body.polygon = _make_circle_points(6.0, 8)
	body.color = color
	add_child(body)


func _make_circle_points(radius: float, sides: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(sides):
		var angle: float = TAU * float(i) / float(sides)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
