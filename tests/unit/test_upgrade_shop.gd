extends GutTest
## Tests para upgrade_shop.gd — costos y bonos por nivel de las 5 mejoras permanentes
## (GDD sección 5). Módulo puro (extends RefCounted) — sin autoload, sin escena.

const UpgradeShopGd := preload("res://src/features/meta/upgrade_shop.gd")


func test_cost_for_next_level_matches_gdd_schedule() -> void:
	var expected: Array = [100, 250, 500, 1000, 2000]
	for level in range(5):
		assert_eq(UpgradeShopGd.cost_for_next_level(level), expected[level])


func test_is_max_level_true_at_five() -> void:
	assert_true(UpgradeShopGd.is_max_level(5))
	assert_false(UpgradeShopGd.is_max_level(4))


func test_cost_for_next_level_returns_negative_one_past_max() -> void:
	assert_eq(UpgradeShopGd.cost_for_next_level(5), -1)


func test_damage_multiplier_five_percent_per_level() -> void:
	assert_almost_eq(UpgradeShopGd.damage_multiplier(0), 1.0, 0.001)
	assert_almost_eq(UpgradeShopGd.damage_multiplier(1), 1.05, 0.001)
	assert_almost_eq(UpgradeShopGd.damage_multiplier(5), 1.25, 0.001)


func test_range_multiplier_five_percent_per_level() -> void:
	assert_almost_eq(UpgradeShopGd.range_multiplier(3), 1.15, 0.001)


func test_cooldown_multiplier_reduces_by_three_percent_per_level() -> void:
	assert_almost_eq(UpgradeShopGd.cooldown_multiplier(0), 1.0, 0.001)
	assert_almost_eq(UpgradeShopGd.cooldown_multiplier(5), 0.85, 0.001)


func test_tip_multiplier_ten_percent_per_level() -> void:
	assert_almost_eq(UpgradeShopGd.tip_multiplier(0), 1.0, 0.001)
	assert_almost_eq(UpgradeShopGd.tip_multiplier(5), 1.5, 0.001)


## GDD lista literalmente "3 → 4 → 5 → 6 → 7" (documentado como niveles 0-4); nivel 5 se
## extrapola a 8 siguiendo el mismo patrón +1/nivel — ver Constants.gd y idea-base.md.
func test_base_hp_for_level_matches_gdd_progression() -> void:
	assert_eq(UpgradeShopGd.base_hp_for_level(0), 3)
	assert_eq(UpgradeShopGd.base_hp_for_level(1), 4)
	assert_eq(UpgradeShopGd.base_hp_for_level(2), 5)
	assert_eq(UpgradeShopGd.base_hp_for_level(3), 6)
	assert_eq(UpgradeShopGd.base_hp_for_level(4), 7)
	assert_eq(UpgradeShopGd.base_hp_for_level(5), 8)


func test_base_hp_for_level_clamps_out_of_range() -> void:
	assert_eq(UpgradeShopGd.base_hp_for_level(-1), 3)
	assert_eq(UpgradeShopGd.base_hp_for_level(99), 8)
