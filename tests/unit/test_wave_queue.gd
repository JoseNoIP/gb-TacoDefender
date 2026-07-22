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


func test_wave_10_final_matches_gdd() -> void:
	var queue: Array = WaveQueueGd.build_spawn_queue(10)
	assert_eq(queue.size(), 3)
	assert_eq(String(queue[0]["type"]), "tank")
	assert_eq(int(queue[0]["remaining"]), 6)
	assert_eq(String(queue[1]["type"]), "fast")
	assert_eq(int(queue[1]["remaining"]), 15)
	assert_eq(String(queue[2]["type"]), "basic")
	assert_eq(int(queue[2]["remaining"]), 10)


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
