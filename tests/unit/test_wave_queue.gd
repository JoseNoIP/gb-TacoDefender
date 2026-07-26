extends GutTest
## Tests para wave_queue.gd — construcción de la cola de spawn contra la tabla de las 10
## oleadas del GDD (sección 4). Módulo puro (extends RefCounted) — sin autoload, sin escena.

const WaveQueueGd := preload("res://src/features/enemies/wave_queue.gd")


func test_wave_1_is_five_basic_at_1_5s() -> void:
	var queue: Array = WaveQueueGd.build_spawn_queue(1)
	assert_eq(queue.size(), 1)
	assert_eq(String(queue[0]["type"]), "basic")
	assert_eq(int(queue[0]["remaining"]), 5)
	assert_almost_eq(float(queue[0]["interval"]), 1.5, 0.001)


func test_wave_3_mixes_basic_and_fast() -> void:
	var queue: Array = WaveQueueGd.build_spawn_queue(3)
	assert_eq(queue.size(), 2)
	assert_eq(String(queue[0]["type"]), "basic")
	assert_eq(int(queue[0]["remaining"]), 5)
	assert_eq(String(queue[1]["type"]), "fast")
	assert_eq(int(queue[1]["remaining"]), 3)


## GDD + el escarabajo acorazado agregado después (oleadas 8/10 solamente, ver nota
## extensa en Constants.ENEMY_BEETLE_HP) -- ya no es "solo GDD", de ahí el nombre.
func test_wave_10_final_matches_gdd_plus_beetle() -> void:
	var queue: Array = WaveQueueGd.build_spawn_queue(10)
	assert_eq(queue.size(), 4)
	assert_eq(String(queue[0]["type"]), "tank")
	assert_eq(int(queue[0]["remaining"]), 6)
	assert_eq(String(queue[1]["type"]), "fast")
	assert_eq(int(queue[1]["remaining"]), 15)
	assert_eq(String(queue[2]["type"]), "basic")
	assert_eq(int(queue[2]["remaining"]), 10)
	assert_eq(String(queue[3]["type"]), "beetle")
	assert_eq(int(queue[3]["remaining"]), 8)


## El escarabajo aparece SOLO en oleadas avanzadas (8 y 10) -- nunca en las primeras,
## para que se sienta como progresión dentro de la partida (pedido explícito).
func test_beetle_only_appears_in_advanced_waves() -> void:
	for wave_number in range(1, 8):
		var queue: Array = WaveQueueGd.build_spawn_queue(wave_number)
		for entry: Dictionary in queue:
			var msg: String = "oleada %d no debería tener escarabajos todavía" % wave_number
			assert_ne(String(entry["type"]), "beetle", msg)

	var wave_8_types: Array = []
	for entry: Dictionary in WaveQueueGd.build_spawn_queue(8):
		wave_8_types.append(String(entry["type"]))
	assert_true("beetle" in wave_8_types, "la oleada 8 debería incluir escarabajos")

	var wave_10_types: Array = []
	for entry: Dictionary in WaveQueueGd.build_spawn_queue(10):
		wave_10_types.append(String(entry["type"]))
	assert_true("beetle" in wave_10_types, "la oleada 10 debería incluir escarabajos")


func test_out_of_range_wave_returns_empty() -> void:
	assert_eq(WaveQueueGd.build_spawn_queue(0), [])
	assert_eq(WaveQueueGd.build_spawn_queue(11), [])
	assert_eq(WaveQueueGd.build_spawn_queue(-1), [])


func test_total_enemy_count_matches_gdd_wave_9_swarm() -> void:
	assert_eq(WaveQueueGd.total_enemy_count(9), 35)  ## 20 básicos + 15 rápidos (GDD "Enjambre").


func test_all_ten_waves_are_non_empty() -> void:
	for wave_number in range(1, 11):
		var msg: String = "oleada %d no debería estar vacía" % wave_number
		assert_gt(WaveQueueGd.total_enemy_count(wave_number), 0, msg)
