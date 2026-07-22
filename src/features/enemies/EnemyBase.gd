extends Node2D
## Clase base de todos los enemigos (GDD sección 3). Sin class_name — los subtipos
## heredan por ruta (`extends "res://.../EnemyBase.gd"`, regla CLAUDE.md #13) para evitar
## problemas de orden de carga en headless. Movimiento manual por waypoints — sin física
## (ni CharacterBody2D ni Area2D): ver nota en Constants.gd sobre por qué este juego no
## define ninguna capa de física. `position`/`global_position` son las propiedades nativas
## de Node2D — nunca redeclaradas (regla CLAUDE.md #38).

var _max_health: float = 10.0
var _health: float = 10.0
var _base_speed: float = 80.0
var _reward: int = 5
var _visual_radius: float = 10.0

var _waypoints: Array = []
var _segment_index: int = 0
var _distance_traveled: float = 0.0
var _total_path_length: float = 1.0

var _slow_multiplier: float = 1.0
var _slow_timer: float = 0.0


func _ready() -> void:
	add_to_group(&"enemies")


## Llamado por EnemySpawner justo después de add_child() (ver orden en
## EnemySpawner.gd::_spawn_enemy) — en ese punto el _ready() del subtipo ya corrió y
## _max_health/_base_speed/_reward ya tienen su valor final, así que _health = _max_health
## usa el dato correcto.
func setup(waypoints: Array, total_path_length: float) -> void:
	_waypoints = waypoints
	_total_path_length = maxf(total_path_length, 1.0)
	_segment_index = 0
	_distance_traveled = 0.0
	_health = _max_health
	if not _waypoints.is_empty():
		position = _waypoints[0]


func _process(delta: float) -> void:
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_multiplier = 1.0
	_move(delta)


func take_damage(amount: float) -> void:
	if amount <= 0.0 or _health <= 0.0:
		return
	_health -= amount
	queue_redraw()
	if _health <= 0.0:
		_die()


## ratio/duration del efecto de Hielo Horchata (GDD sección 3) — se queda con el
## enlentecimiento MÁS FUERTE activo y el timer MÁS LARGO si ya había uno corriendo (nunca
## "refresca" a un valor más débil que el que ya tenía).
func apply_slow(ratio: float, duration: float) -> void:
	_slow_multiplier = minf(_slow_multiplier, 1.0 - ratio)
	_slow_timer = maxf(_slow_timer, duration)


func get_progress() -> float:
	return _distance_traveled


func get_reward() -> int:
	return _reward


func get_health() -> float:
	return _health


func get_max_health() -> float:
	return _max_health


## texture_path apunta a un sprite generado al doble del tamaño de render (ver
## tools/gen_taco_sprites.py) — se escala 0.5 para verse nítido en pantallas retina tras
## el stretch/mode=canvas_items del proyecto (regla CLAUDE.md #61). radius se sigue
## guardando para la barra de vida (_draw()), que no depende del sprite.
func _build_visual(radius: float, texture_path: String) -> void:
	_visual_radius = radius
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(texture_path)
	sprite.scale = Vector2(0.5, 0.5)
	add_child(sprite)


func _move(delta: float) -> void:
	if _segment_index + 1 >= _waypoints.size():
		return
	var target: Vector2 = _waypoints[_segment_index + 1]
	var effective_speed: float = _base_speed * _slow_multiplier
	var to_target: Vector2 = target - position
	var distance: float = to_target.length()
	var step: float = effective_speed * delta
	if distance <= step:
		_distance_traveled += distance
		position = target
		_segment_index += 1
		if _segment_index + 1 >= _waypoints.size():
			_on_reached_base()
	else:
		position += to_target.normalized() * step
		_distance_traveled += step


func _on_reached_base() -> void:
	EventBus.enemy_reached_base.emit(Constants.BASE_DAMAGE_PER_LEAK)
	queue_free()


func _die() -> void:
	EventBus.enemy_destroyed.emit(global_position, _reward)
	queue_free()


## Barra de vida simple sobre el enemigo — solo se dibuja si ya recibió daño (a full HP
## no muestra nada, sin artefactos: Godot limpia el buffer de dibujo en cada _draw()).
func _draw() -> void:
	if _health >= _max_health:
		return
	var bar_width: float = _visual_radius * 2.0
	var bar_height: float = 4.0
	var bar_pos: Vector2 = Vector2(-_visual_radius, -_visual_radius - 10.0)
	draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Constants.COLOR_HEALTHBAR_BG, true)
	var ratio: float = clampf(_health / _max_health, 0.0, 1.0)
	var fill_size: Vector2 = Vector2(bar_width * ratio, bar_height)
	draw_rect(Rect2(bar_pos, fill_size), Constants.COLOR_HEALTHBAR_FILL, true)
