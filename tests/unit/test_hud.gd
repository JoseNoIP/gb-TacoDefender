extends GutTest
## Tests para HUD — sin lógica de juego propia, solo refleja EventBus (ver HUD.gd).
## Accede a los labels "privados" vía reflección (Object.get(&"_campo")), mismo patrón
## de test ya usado para los autoloads (regla CLAUDE.md #57).

const HudGd := preload("res://src/features/ui/HUD.gd")

var _hud: CanvasLayer = null


func before_each() -> void:
	_hud = HudGd.new()
	add_child_autofree(_hud)


func test_gold_changed_updates_label_text() -> void:
	EventBus.gold_changed.emit(250)
	assert_eq((_hud.get(&"_gold_label") as Label).text, "$250")


func test_base_health_changed_updates_label_text() -> void:
	EventBus.base_health_changed.emit(2, 5)
	assert_eq((_hud.get(&"_hp_label") as Label).text, "2/5")


func test_wave_started_hides_start_wave_button() -> void:
	EventBus.wave_started.emit(3)
	assert_false((_hud.get(&"_start_wave_button") as Button).visible)


func test_wave_intermission_shows_start_wave_button() -> void:
	EventBus.wave_intermission_started.emit(4, 5.0)
	assert_true((_hud.get(&"_start_wave_button") as Button).visible)


func _sample_selection_info() -> Dictionary:
	return {
		"cell": Vector2i(1, 1),
		"tower_type": Constants.TOWER_TYPE_SALSA_VERDE,
		"level": 1,
		"max_level": Constants.TOWER_MAX_LEVEL,
		"damage": 15.0,
		"range": 150.0,
		"upgrade_cost": 35,
		"can_upgrade": true,
		"sell_value": 35,
	}


func test_tower_selected_shows_selection_panel() -> void:
	EventBus.tower_selected.emit(_sample_selection_info())
	assert_true((_hud.get(&"_selection_panel") as PanelContainer).visible)


func test_tower_deselected_hides_selection_panel() -> void:
	EventBus.tower_selected.emit(_sample_selection_info())
	EventBus.tower_deselected.emit()
	assert_false((_hud.get(&"_selection_panel") as PanelContainer).visible)


func test_tower_selected_at_max_level_disables_upgrade_button() -> void:
	var info: Dictionary = _sample_selection_info()
	info["can_upgrade"] = false
	info["level"] = Constants.TOWER_MAX_LEVEL
	EventBus.tower_selected.emit(info)
	assert_true((_hud.get(&"_selection_upgrade_button") as Button).disabled)


func test_action_feedback_shows_toast_with_message() -> void:
	EventBus.action_feedback.emit("Oro insuficiente")
	var toast: Label = _hud.get(&"_toast_label")
	assert_true(toast.visible)
	assert_eq(toast.text, "Oro insuficiente")
