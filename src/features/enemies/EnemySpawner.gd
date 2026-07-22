extends Node
## Orquesta el spawn de las 10 oleadas (GDD sección 4). Game.gd (composition root de
## Game.tscn) llama configure_path() una sola vez, después de instanciar tanto Board como
## EnemySpawner, para pasarle los waypoints reales del camino.

const WaveQueueGd := preload("res://src/features/enemies/wave_queue.gd")

const ENEMY_SCRIPTS: Dictionary = {
	"basic": preload("res://src/features/enemies/enemy_basic.gd"),
	"fast": preload("res://src/features/enemies/enemy_fast.gd"),
	"tank": preload("res://src/features/enemies/enemy_tank.gd"),
}

var _path_points: Array = []
var _path_length: float = 0.0
var _current_wave: int = 0
var _spawn_queue: Array = []
var _alive_count: int = 0
var _wave_active: bool = false
var _wave_cleared_emitted: bool = false


func _ready() -> void:
	EventBus.enemy_destroyed.connect(_on_enemy_destroyed)
	EventBus.enemy_reached_base.connect(_on_enemy_reached_base)
	EventBus.wave_started.connect(_on_wave_started)


func _exit_tree() -> void:
	if EventBus.enemy_destroyed.is_connected(_on_enemy_destroyed):
		EventBus.enemy_destroyed.disconnect(_on_enemy_destroyed)
	if EventBus.enemy_reached_base.is_connected(_on_enemy_reached_base):
		EventBus.enemy_reached_base.disconnect(_on_enemy_reached_base)
	if EventBus.wave_started.is_connected(_on_wave_started):
		EventBus.wave_started.disconnect(_on_wave_started)


func configure_path(path_points: Array, path_length: float) -> void:
	_path_points = path_points
	_path_length = path_length


func _process(delta: float) -> void:
	if not _wave_active:
		return
	for entry: Dictionary in _spawn_queue:
		if int(entry["remaining"]) <= 0:
			continue
		entry["timer"] = float(entry["timer"]) - delta
		if float(entry["timer"]) <= 0.0:
			_spawn_enemy(String(entry["type"]))
			entry["remaining"] = int(entry["remaining"]) - 1
			entry["timer"] = float(entry["interval"])
	## Pasada separada, DESPUÉS de procesar todos los spawns de este frame — así detecta
	## "ya no queda nada por spawnear" en el MISMO frame en que se spawnea el último
	## enemigo, en vez de necesitar un frame extra para notarlo (con _process a 60fps en
	## juego real esa demora de 1 frame es imperceptible, pero hacía que un test que
	## avanza _process() un número exacto de veces viera _wave_active todavía en true justo
	## después de agotar la cola — más robusto chequear altiro en vez de parchear el test).
	var all_spawned: bool = true
	for entry: Dictionary in _spawn_queue:
		if int(entry["remaining"]) > 0:
			all_spawned = false
			break
	if all_spawned:
		_wave_active = false
		_check_wave_cleared()


func _on_wave_started(wave_number: int) -> void:
	_current_wave = wave_number
	_spawn_queue = WaveQueueGd.build_spawn_queue(wave_number)
	_alive_count = 0
	_wave_active = true
	_wave_cleared_emitted = false


func _spawn_enemy(enemy_type: String) -> void:
	if _path_points.size() < 2:
		return
	var enemy_script: GDScript = ENEMY_SCRIPTS.get(enemy_type) as GDScript
	if enemy_script == null:
		return
	var enemy: Node2D = enemy_script.new()
	add_child(enemy)
	enemy.call(&"setup", _path_points, _path_length)
	_alive_count += 1
	EventBus.enemy_spawned.emit(enemy_type)


func _on_enemy_destroyed(_position: Vector2, _reward: int) -> void:
	_decrement_alive()


func _on_enemy_reached_base(_damage: int) -> void:
	_decrement_alive()


func _decrement_alive() -> void:
	_alive_count = maxi(_alive_count - 1, 0)
	if not _wave_active:
		_check_wave_cleared()


## Guard `_wave_cleared_emitted`: si varios enemigos mueren en el mismo frame (ej. la
## Catapulta Guac hace daño en área y mata a los últimos 2-3 enemigos de la oleada a la
## vez), cada muerte llama _decrement_alive() -> _check_wave_cleared() por separado; sin
## este guard, la SEGUNDA y tercera llamada volverían a ver _alive_count<=0 y remitirían
## wave_cleared otra vez, haciendo que GameManager otorgue las propinas de esa oleada
## más de una vez (mismo espíritu que la regla CLAUDE.md #59: una acción en área puede
## disparar el mismo cierre de estado varias veces si no se guarda explícitamente).
func _check_wave_cleared() -> void:
	if _wave_active or _wave_cleared_emitted:
		return
	if _alive_count <= 0:
		_wave_cleared_emitted = true
		EventBus.wave_cleared.emit(_current_wave)
