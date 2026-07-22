extends GutTest
## Tests para EnemySpawner (orquestación de las 10 oleadas — GDD sección 4). Usa un
## camino recto de prueba (no el real del Board) — la forma del camino no importa para
## verificar timing de spawn / conteo de vivos / disparo de wave_cleared.

const EnemySpawnerGd := preload("res://src/features/enemies/EnemySpawner.gd")

var _spawner: Node = null


func before_each() -> void:
	_spawner = EnemySpawnerGd.new()
	add_child_autofree(_spawner)
	_spawner.configure_path([Vector2.ZERO, Vector2(1000.0, 0.0)], 1000.0)


func after_each() -> void:
	## Cualquier enemigo real spawneado en un test queda en el grupo global "enemies" —
	## limpiarlo evita que un test contamine el conteo de get_nodes_in_group() del
	## siguiente test de esta misma suite.
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		(enemy as Node2D).queue_free()


func test_wave_started_spawns_first_enemy_after_its_interval() -> void:
	EventBus.wave_started.emit(1)  ## Oleada 1: 5 básicos, intervalo 1.5s (GDD sección 4).
	var msg: String = "no debería spawnear antes de que pase el intervalo"
	assert_eq(get_tree().get_nodes_in_group(&"enemies").size(), 0, msg)
	_spawner._process(1.5)
	assert_eq(get_tree().get_nodes_in_group(&"enemies").size(), 1)


func test_wave_1_spawns_all_five_basics_eventually() -> void:
	EventBus.wave_started.emit(1)
	for i in range(5):
		_spawner._process(1.5)
	assert_eq(get_tree().get_nodes_in_group(&"enemies").size(), 5)


func test_wave_cleared_does_not_emit_while_enemies_remain() -> void:
	EventBus.wave_started.emit(1)
	for i in range(5):
		_spawner._process(1.5)
	var enemies: Array = get_tree().get_nodes_in_group(&"enemies").duplicate()
	assert_eq(enemies.size(), 5)

	watch_signals(EventBus)
	for i in range(3):  ## mata solo 3 de los 5 — todavía quedan 2 vivos.
		(enemies[i] as Node2D).call(&"take_damage", 9999.0)
	assert_signal_not_emitted(EventBus, "wave_cleared")


func test_wave_cleared_emits_once_all_spawned_enemies_die() -> void:
	EventBus.wave_started.emit(1)
	for i in range(5):
		_spawner._process(1.5)
	var enemies: Array = get_tree().get_nodes_in_group(&"enemies").duplicate()

	watch_signals(EventBus)
	for enemy in enemies:
		(enemy as Node2D).call(&"take_damage", 9999.0)
	assert_signal_emitted(EventBus, "wave_cleared")


## Regresión dirigida a la regla CLAUDE.md #59: si varias muertes ocurren "en el mismo
## instante" (acá simulado matando a los 5 en el mismo tick, como haría un AoE) el guard
## _wave_cleared_emitted debe evitar que wave_cleared se emita más de una vez.
func test_wave_cleared_emits_exactly_once_even_with_simultaneous_deaths() -> void:
	EventBus.wave_started.emit(1)
	for i in range(5):
		_spawner._process(1.5)
	var enemies: Array = get_tree().get_nodes_in_group(&"enemies").duplicate()

	watch_signals(EventBus)
	for enemy in enemies:
		(enemy as Node2D).call(&"take_damage", 9999.0)
	assert_signal_emit_count(EventBus, "wave_cleared", 1)
