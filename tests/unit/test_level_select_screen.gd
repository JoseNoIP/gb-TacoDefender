extends GutTest
## Tests para LevelSelectScreen -- la partición bloqueado/desbloqueado/completado es
## lógica real (no solo reflejar algo ya testeado en otro lado, a diferencia de
## UpgradeScreen), así que vale la pena un test dedicado. Muta MetaManager.victories
## temporalmente (mismo patrón de restauración que test_game_manager.gd, regla CLAUDE.md
## #57) para poder ejercitar los 3 estados de forma determinística.

const LevelSelectScreenGd := preload("res://src/scenes/LevelSelectScreen.gd")

var _screen: Control = null
var _original_victories: int = 0


func before_each() -> void:
	_original_victories = MetaManager.get_victories()
	_set_victories(3)
	_screen = LevelSelectScreenGd.new()
	add_child_autofree(_screen)


func after_each() -> void:
	_set_victories(_original_victories)


func _set_victories(value: int) -> void:
	var data: Dictionary = MetaManager.get(&"_data")
	data["victories"] = value
	MetaManager.save()


func _row(index: int) -> Dictionary:
	var rows: Dictionary = _screen.get(&"_rows")
	return rows.get(index, {}) as Dictionary


func test_completed_levels_show_replay_and_are_enabled() -> void:
	for index in range(3):  ## 0, 1, 2 < victories=3 -- completados.
		var button: Button = _row(index)["button"]
		assert_false(button.disabled, "nivel %d debería ser rejugable" % index)
		assert_eq(button.text, tr(&"BTN_LEVEL_REPLAY"))


func test_frontier_level_shows_play_and_is_enabled() -> void:
	var button: Button = _row(3)["button"]  ## índice == victories=3.
	assert_false(button.disabled, "el nivel frontera debe ser jugable")
	assert_eq(button.text, tr(&"BTN_PLAY"))


func test_locked_levels_are_disabled() -> void:
	for index in range(4, Constants.PATH_TEMPLATES.size()):  ## > victories=3.
		var button: Button = _row(index)["button"]
		assert_true(button.disabled, "nivel %d debería estar bloqueado" % index)
		assert_eq(button.text, tr(&"BTN_LEVEL_LOCKED"))
