extends GutTest
## Tests para LoadoutManager (torres desbloqueables + equipo de 3 activo). Autoload real
## con persistencia en user://loadout.json (y unlock_tower gasta MetaManager.spend_tips
## real) -- todo test que mute tips/torres desbloqueadas/equipo debe restaurar el estado
## original al final, mismo patrón que test_game_manager.gd (regla CLAUDE.md #57): nunca
## asumir cuántas propinas tiene el save real, ni dejar unlocks/equipo que el jugador
## nunca ganó.

const UNLOCKABLE: String = Constants.TOWER_TYPE_CHILE_HABANERO


func _backup_loadout_data() -> Dictionary:
	return (LoadoutManager.get(&"_data") as Dictionary).duplicate(true)


func _restore_loadout_data(original: Dictionary) -> void:
	var data: Dictionary = LoadoutManager.get(&"_data")
	data.clear()
	for key: String in original.keys():
		data[key] = original[key]
	LoadoutManager.save()


func _backup_tips() -> int:
	return MetaManager.get_tips()


func _restore_tips(original: int) -> void:
	var data: Dictionary = MetaManager.get(&"_data")
	data["tips"] = original
	MetaManager.save()


func test_the_three_original_towers_are_unlocked_by_default() -> void:
	for tower_type: String in Constants.TOWER_TYPES:
		var msg: String = "%s debería estar desbloqueada desde el principio" % tower_type
		assert_true(LoadoutManager.is_tower_unlocked(tower_type), msg)


func test_new_towers_are_not_unlocked_unless_purchased() -> void:
	var original: Dictionary = _backup_loadout_data()
	var data: Dictionary = LoadoutManager.get(&"_data")
	data["unlocked_towers"] = []
	assert_false(LoadoutManager.is_tower_unlocked(UNLOCKABLE))
	_restore_loadout_data(original)


func test_unlock_tower_fails_without_enough_tips() -> void:
	var original_loadout: Dictionary = _backup_loadout_data()
	var original_tips: int = _backup_tips()
	var data: Dictionary = LoadoutManager.get(&"_data")
	data["unlocked_towers"] = []
	var tips_data: Dictionary = MetaManager.get(&"_data")
	tips_data["tips"] = 0

	assert_false(LoadoutManager.unlock_tower(UNLOCKABLE))
	assert_false(LoadoutManager.is_tower_unlocked(UNLOCKABLE))

	_restore_loadout_data(original_loadout)
	_restore_tips(original_tips)


func test_unlock_tower_succeeds_and_spends_tips_when_affordable() -> void:
	var original_loadout: Dictionary = _backup_loadout_data()
	var original_tips: int = _backup_tips()
	var data: Dictionary = LoadoutManager.get(&"_data")
	data["unlocked_towers"] = []
	var cost: int = int(Constants.TOWER_UNLOCK_COST[UNLOCKABLE])
	var tips_data: Dictionary = MetaManager.get(&"_data")
	tips_data["tips"] = cost + 100

	assert_true(LoadoutManager.unlock_tower(UNLOCKABLE))
	assert_true(LoadoutManager.is_tower_unlocked(UNLOCKABLE))
	assert_eq(MetaManager.get_tips(), 100, "debe descontar exactamente el costo de desbloqueo")

	_restore_loadout_data(original_loadout)
	_restore_tips(original_tips)


func test_unlock_tower_fails_if_already_unlocked() -> void:
	var original_loadout: Dictionary = _backup_loadout_data()
	var original_tips: int = _backup_tips()
	var tips_data: Dictionary = MetaManager.get(&"_data")
	tips_data["tips"] = 100000

	assert_true(LoadoutManager.unlock_tower(UNLOCKABLE))
	var tips_after_first: int = MetaManager.get_tips()
	assert_false(LoadoutManager.unlock_tower(UNLOCKABLE))
	assert_eq(
		MetaManager.get_tips(), tips_after_first, "el segundo intento no debe cobrar de nuevo"
	)

	_restore_loadout_data(original_loadout)
	_restore_tips(original_tips)


func test_unlock_tower_rejects_a_non_unlockable_type() -> void:
	var original_tips: int = _backup_tips()
	var tips_data: Dictionary = MetaManager.get(&"_data")
	tips_data["tips"] = 100000
	assert_false(LoadoutManager.unlock_tower(Constants.TOWER_TYPE_SALSA_VERDE))
	_restore_tips(original_tips)


func test_current_loadout_defaults_to_the_three_original_towers() -> void:
	var original: Dictionary = _backup_loadout_data()
	var data: Dictionary = LoadoutManager.get(&"_data")
	data.erase("current_loadout")
	assert_eq(LoadoutManager.get_current_loadout(), Constants.TOWER_TYPES)
	_restore_loadout_data(original)


func test_set_current_loadout_rejects_wrong_size() -> void:
	var original: Dictionary = _backup_loadout_data()
	assert_false(LoadoutManager.set_current_loadout([Constants.TOWER_TYPE_SALSA_VERDE]))
	_restore_loadout_data(original)


func test_set_current_loadout_rejects_duplicates() -> void:
	var original: Dictionary = _backup_loadout_data()
	var duplicated: Array = [
		Constants.TOWER_TYPE_SALSA_VERDE,
		Constants.TOWER_TYPE_SALSA_VERDE,
		Constants.TOWER_TYPE_HIELO_HORCHATA,
	]
	assert_false(LoadoutManager.set_current_loadout(duplicated))
	_restore_loadout_data(original)


func test_set_current_loadout_rejects_a_tower_that_is_not_unlocked() -> void:
	var original: Dictionary = _backup_loadout_data()
	var data: Dictionary = LoadoutManager.get(&"_data")
	data["unlocked_towers"] = []
	var attempted: Array = [
		Constants.TOWER_TYPE_SALSA_VERDE, Constants.TOWER_TYPE_HIELO_HORCHATA, UNLOCKABLE
	]
	assert_false(LoadoutManager.set_current_loadout(attempted))
	_restore_loadout_data(original)


func test_set_current_loadout_succeeds_with_three_valid_unlocked_towers() -> void:
	var original: Dictionary = _backup_loadout_data()
	var valid: Array = [
		Constants.TOWER_TYPE_HIELO_HORCHATA,
		Constants.TOWER_TYPE_CATAPULTA_GUAC,
		Constants.TOWER_TYPE_SALSA_VERDE,
	]
	assert_true(LoadoutManager.set_current_loadout(valid))
	assert_eq(LoadoutManager.get_current_loadout(), valid)
	_restore_loadout_data(original)
