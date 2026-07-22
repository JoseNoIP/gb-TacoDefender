extends GutTest
## Tests para MetaManager (autoload real, persiste en user://meta.json — GDD sección 5:
## propinas y mejoras permanentes). Roundtrip + restauración explícita al final de cada
## test escribiendo directo al Dictionary interno `_data` vía reflección (regla CLAUDE.md
## #57) — es el MISMO archivo que usa una partida jugada a mano; tools/run_tests.sh
## además respalda/restaura meta.json como red de seguridad adicional.

const UpgradeShopGd := preload("res://src/features/meta/upgrade_shop.gd")


func test_add_tips_increases_total() -> void:
	var original: int = MetaManager.get_tips()
	MetaManager.add_tips(15)
	assert_eq(MetaManager.get_tips(), original + 15)
	_restore_tips(original)


func test_add_tips_ignores_non_positive_amounts() -> void:
	var original: int = MetaManager.get_tips()
	MetaManager.add_tips(0)
	MetaManager.add_tips(-5)
	assert_eq(MetaManager.get_tips(), original)


func test_spend_tips_fails_when_not_affordable() -> void:
	var original: int = MetaManager.get_tips()
	assert_false(MetaManager.spend_tips(original + 1000))
	assert_eq(MetaManager.get_tips(), original)


func test_spend_tips_succeeds_and_deducts() -> void:
	var original: int = MetaManager.get_tips()
	MetaManager.add_tips(500)  ## asegura saldo suficiente para el gasto de abajo.
	assert_true(MetaManager.spend_tips(200))
	assert_eq(MetaManager.get_tips(), original + 500 - 200)
	_restore_tips(original)


func test_purchase_upgrade_roundtrip_for_every_upgrade_id() -> void:
	for upgrade_id: String in UpgradeShopGd.UPGRADE_IDS:
		var original_level: int = MetaManager.get_upgrade_level(upgrade_id)
		var original_tips: int = MetaManager.get_tips()
		MetaManager.add_tips(3000)  ## cubre el costo del nivel más caro (2000).

		var success: bool = MetaManager.purchase_upgrade(upgrade_id)
		assert_true(
			success, "la compra de %s debería tener éxito con propinas de sobra" % upgrade_id
		)
		assert_eq(MetaManager.get_upgrade_level(upgrade_id), original_level + 1)

		_set_upgrade_level(upgrade_id, original_level)
		_restore_tips(original_tips)


func test_purchase_upgrade_fails_when_already_max_level() -> void:
	var upgrade_id: String = Constants.META_UPGRADE_ID_DAMAGE
	var original_level: int = MetaManager.get_upgrade_level(upgrade_id)
	var original_tips: int = MetaManager.get_tips()

	_set_upgrade_level(upgrade_id, Constants.META_UPGRADE_MAX_LEVEL)
	MetaManager.add_tips(5000)
	assert_false(MetaManager.purchase_upgrade(upgrade_id))

	_set_upgrade_level(upgrade_id, original_level)
	_restore_tips(original_tips)


func test_set_best_wave_if_higher_only_increases() -> void:
	var original: int = MetaManager.get_best_wave()
	MetaManager.set_best_wave_if_higher(original + 1)
	assert_eq(MetaManager.get_best_wave(), original + 1)
	MetaManager.set_best_wave_if_higher(0)  ## nunca debe bajar el valor.
	assert_eq(MetaManager.get_best_wave(), original + 1)
	_restore_best_wave(original)


func test_add_victory_increments_count() -> void:
	var original: int = MetaManager.get_victories()
	MetaManager.add_victory()
	assert_eq(MetaManager.get_victories(), original + 1)
	_restore_victories(original)


func test_increment_games_played_increments_count() -> void:
	var original: int = MetaManager.get_total_games_played()
	MetaManager.increment_games_played()
	assert_eq(MetaManager.get_total_games_played(), original + 1)
	_restore_games_played(original)


func _restore_tips(value: int) -> void:
	var data: Dictionary = MetaManager.get(&"_data")
	data["tips"] = value
	MetaManager.save()


func _restore_best_wave(value: int) -> void:
	var data: Dictionary = MetaManager.get(&"_data")
	data["best_wave"] = value
	MetaManager.save()


func _restore_victories(value: int) -> void:
	var data: Dictionary = MetaManager.get(&"_data")
	data["victories"] = value
	MetaManager.save()


func _restore_games_played(value: int) -> void:
	var data: Dictionary = MetaManager.get(&"_data")
	data["total_games_played"] = value
	MetaManager.save()


func _set_upgrade_level(upgrade_id: String, level: int) -> void:
	var data: Dictionary = MetaManager.get(&"_data")
	var levels: Dictionary = data.get("upgrade_levels", {}) as Dictionary
	levels[upgrade_id] = level
	data["upgrade_levels"] = levels
	MetaManager.save()
