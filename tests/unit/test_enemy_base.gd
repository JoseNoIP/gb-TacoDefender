extends GutTest
## Tests para EnemyBase (movimiento por waypoints, daño, ralentización, progreso). Usa
## enemy_basic.gd como concreción mínima — EnemyBase no se instancia directo (sin stats
## propios, ver CLAUDE.md #13: subtipos heredan por ruta).
##
## HP/recompensa efectivos dependen de MetaManager.get_victories() (escalado por
## repetición, fuera del GDD — ver Constants.gd) — igual que test_game_manager.gd deriva
## _expected_base_hp_max() del MetaManager real en vez de asumir un guardado vacío (mismo
## espíritu que la regla CLAUDE.md #57), acá se deriva el HP/recompensa esperados con la
## MISMA fórmula que EnemyBase._ready(), nunca se asume Constants.ENEMY_BASIC_HP a secas.

const EnemyBasicGd := preload("res://src/features/enemies/enemy_basic.gd")

var _enemy: Node2D = null


func before_each() -> void:
	_enemy = EnemyBasicGd.new()
	add_child_autofree(_enemy)


func _expected_max_health() -> float:
	var victories: int = mini(MetaManager.get_victories(), Constants.ENEMY_VICTORY_SCALING_CAP)
	return (
		Constants.ENEMY_BASIC_HP * (1.0 + float(victories) * Constants.ENEMY_HP_BONUS_PER_VICTORY)
	)


func _expected_reward() -> int:
	var victories: int = mini(MetaManager.get_victories(), Constants.ENEMY_VICTORY_SCALING_CAP)
	var scaled: float = (
		float(Constants.ENEMY_BASIC_REWARD)
		* (1.0 + float(victories) * Constants.ENEMY_REWARD_BONUS_PER_VICTORY)
	)
	return int(round(scaled))


func test_setup_positions_enemy_at_first_waypoint() -> void:
	var waypoints: Array = [Vector2(10.0, 20.0), Vector2(100.0, 20.0)]
	_enemy.setup(waypoints, 90.0)
	assert_eq(_enemy.position, Vector2(10.0, 20.0))


func test_setup_resets_health_to_max() -> void:
	_enemy.setup([Vector2.ZERO, Vector2(100.0, 0.0)], 100.0)
	assert_almost_eq(_enemy.get_health(), _expected_max_health(), 0.001)


func test_take_damage_reduces_health() -> void:
	_enemy.setup([Vector2.ZERO, Vector2(100.0, 0.0)], 100.0)
	_enemy.take_damage(3.0)
	assert_almost_eq(_enemy.get_health(), _expected_max_health() - 3.0, 0.001)


func test_take_damage_ignores_non_positive_amount() -> void:
	_enemy.setup([Vector2.ZERO, Vector2(100.0, 0.0)], 100.0)
	_enemy.take_damage(0.0)
	_enemy.take_damage(-5.0)
	assert_almost_eq(_enemy.get_health(), _expected_max_health(), 0.001)


func test_lethal_damage_emits_enemy_destroyed_with_reward() -> void:
	_enemy.setup([Vector2.ZERO, Vector2(100.0, 0.0)], 100.0)
	watch_signals(EventBus)
	_enemy.take_damage(_expected_max_health() + 100.0)
	assert_signal_emitted(EventBus, "enemy_destroyed")


func test_movement_advances_toward_next_waypoint() -> void:
	_enemy.setup([Vector2.ZERO, Vector2(1000.0, 0.0)], 1000.0)
	_enemy._process(0.1)
	assert_gt(_enemy.position.x, 0.0)
	assert_almost_eq(_enemy.position.y, 0.0, 0.001)


func test_reaching_final_waypoint_emits_enemy_reached_base() -> void:
	_enemy.setup([Vector2.ZERO, Vector2(5.0, 0.0)], 5.0)  ## muy cerca — un solo frame alcanza.
	watch_signals(EventBus)
	_enemy._process(1.0)
	assert_signal_emitted(EventBus, "enemy_reached_base")


func test_apply_slow_reduces_distance_covered_in_same_delta() -> void:
	_enemy.setup([Vector2.ZERO, Vector2(1000.0, 0.0)], 1000.0)
	_enemy.apply_slow(0.5, 2.0)
	_enemy._process(0.1)
	var slowed_x: float = _enemy.position.x

	var baseline: Node2D = EnemyBasicGd.new()
	add_child_autofree(baseline)
	baseline.setup([Vector2.ZERO, Vector2(1000.0, 0.0)], 1000.0)
	baseline._process(0.1)

	var msg: String = "sin ralentización debería avanzar más en el mismo delta"
	assert_gt(baseline.position.x, slowed_x, msg)


func test_get_progress_increases_after_moving() -> void:
	_enemy.setup([Vector2.ZERO, Vector2(1000.0, 0.0)], 1000.0)
	assert_eq(_enemy.get_progress(), 0.0)
	_enemy._process(0.1)
	assert_gt(_enemy.get_progress(), 0.0)


func test_get_reward_matches_constants() -> void:
	assert_eq(_enemy.get_reward(), _expected_reward())
