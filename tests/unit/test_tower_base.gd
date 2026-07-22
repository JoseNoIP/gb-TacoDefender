extends GutTest
## Tests para TowerBase (posicionamiento, upgrade, venta, targeting). Usa
## tower_salsa_verde.gd como concreción mínima. Los multiplicadores de metagame (daño/
## rango/cooldown) dependen de MetaManager.get_upgrade_level(...) — persiste en el
## user://meta.json REAL del desarrollador — así que los tests derivan el valor esperado
## dinámicamente en vez de asumir multiplicador 1.0 (mismo espíritu que
## test_game_manager.gd, regla CLAUDE.md #57). El oro de GameManager es estado de sesión
## (no persiste a disco), así que no necesita restaurarse entre tests.

const TowerSalsaVerdeGd := preload("res://src/features/towers/tower_salsa_verde.gd")
const TowerHieloHorchataGd := preload("res://src/features/towers/tower_hielo_horchata.gd")
const UpgradeShopGd := preload("res://src/features/meta/upgrade_shop.gd")

var _tower: Node2D = null


func before_each() -> void:
	_tower = TowerSalsaVerdeGd.new()
	add_child_autofree(_tower)
	_tower.setup(Vector2i(2, 2))


func test_setup_positions_tower_at_cell_center() -> void:
	var expected: Vector2 = Vector2(2.5 * Constants.TILE_SIZE, 2.5 * Constants.TILE_SIZE)
	assert_almost_eq(_tower.position.x, expected.x, 0.01)
	assert_almost_eq(_tower.position.y, expected.y, 0.01)


func test_setup_records_grid_cell() -> void:
	assert_eq(_tower.get_grid_cell(), Vector2i(2, 2))


func test_starts_at_level_one() -> void:
	assert_eq(_tower.get_level(), 1)


func test_effective_damage_matches_base_times_meta_multiplier() -> void:
	var meta_level: int = MetaManager.get_upgrade_level(Constants.META_UPGRADE_ID_DAMAGE)
	var multiplier: float = UpgradeShopGd.damage_multiplier(meta_level)
	var expected: float = Constants.TOWER_SALSA_VERDE_DAMAGE * multiplier
	assert_almost_eq(_tower.get_effective_damage(), expected, 0.01)


func test_effective_range_matches_base_times_meta_multiplier() -> void:
	var meta_level: int = MetaManager.get_upgrade_level(Constants.META_UPGRADE_ID_RANGE)
	var multiplier: float = UpgradeShopGd.range_multiplier(meta_level)
	var expected: float = Constants.TOWER_SALSA_VERDE_RANGE * multiplier
	assert_almost_eq(_tower.get_effective_range(), expected, 0.01)


func test_upgrade_increases_level_and_effective_damage() -> void:
	GameManager.start_game()  ## asegura oro suficiente (100) para pagar el upgrade (35).
	var damage_before: float = _tower.get_effective_damage()
	var success: bool = _tower.upgrade()
	assert_true(success)
	assert_eq(_tower.get_level(), 2)
	assert_gt(_tower.get_effective_damage(), damage_before)


func test_upgrade_fails_without_enough_gold() -> void:
	GameManager.start_game()
	GameManager.spend_gold(GameManager.get_gold())  ## vacía el oro de la partida a 0.
	assert_false(_tower.upgrade())
	assert_eq(_tower.get_level(), 1)


func test_upgrade_fails_past_max_level() -> void:
	GameManager.start_game()
	GameManager.add_gold(10000)
	_tower.upgrade()
	_tower.upgrade()
	assert_eq(_tower.get_level(), Constants.TOWER_MAX_LEVEL)
	assert_false(_tower.upgrade())


func test_sell_value_is_seventy_percent_of_invested() -> void:
	var invested: float = float(Constants.TOWER_SALSA_VERDE_COST)
	var expected: int = int(round(invested * Constants.TOWER_SELL_RATIO))
	assert_eq(_tower.get_sell_value(), expected)


func test_sell_value_increases_after_upgrade() -> void:
	GameManager.start_game()
	GameManager.add_gold(10000)
	var sell_before: int = _tower.get_sell_value()
	_tower.upgrade()
	assert_gt(_tower.get_sell_value(), sell_before)


## GDD sección 3: el upgrade de Hielo Horchata SOLO extiende la duración del
## enlentecimiento — a diferencia de Salsa Verde/Catapulta Guac, no sube daño ni rango.
func test_ice_tower_upgrade_only_extends_slow_duration_not_damage() -> void:
	var ice_tower: Node2D = TowerHieloHorchataGd.new()
	add_child_autofree(ice_tower)
	ice_tower.setup(Vector2i(0, 0))
	GameManager.start_game()
	GameManager.add_gold(10000)

	var damage_before: float = ice_tower.get_effective_damage()
	var duration_before: float = ice_tower.get_effective_slow_duration()
	ice_tower.upgrade()
	var msg: String = "Hielo Horchata no mejora daño, solo duración (GDD sección 3)"
	assert_almost_eq(ice_tower.get_effective_damage(), damage_before, 0.01, msg)
	assert_gt(ice_tower.get_effective_slow_duration(), duration_before)
