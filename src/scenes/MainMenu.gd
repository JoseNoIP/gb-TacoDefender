extends Control
## Menú principal (GDD): JUGAR, MEJORAS, CONFIGURACIÓN. "JUGAR" siempre enruta a
## Game.tscn — el FTUE de Taco Defender es un overlay ligero DENTRO de Game.tscn (ver
## HUD.gd), no una escena de tutorial separada: la arquitectura de tutorial del template
## está pensada para un juego de movimiento/disparo (Player/GemSpawner/PowerUpDropper) que
## no existe en este tower defense — ver idea-base.md, sección FASE 0/FTUE.

const GAME_SCENE: String = "res://src/scenes/Game.tscn"
const UPGRADE_SCREEN_SCENE: String = "res://src/scenes/UpgradeScreen.tscn"
const SettingsScreenGd := preload("res://src/features/ui/SettingsScreen.gd")

var _tips_label: Label = Label.new()
var _settings: CanvasLayer = null


func _ready() -> void:
	_build_ui()
	EventBus.tips_changed.connect(_on_tips_changed)


func _exit_tree() -> void:
	if EventBus.tips_changed.is_connected(_on_tips_changed):
		EventBus.tips_changed.disconnect(_on_tips_changed)


func _build_ui() -> void:
	position = Vector2.ZERO
	set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))

	var bg: ColorRect = ColorRect.new()
	bg.position = Vector2.ZERO
	bg.set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))
	bg.color = Constants.COLOR_BG_BOARD
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title: Label = Label.new()
	title.text = "Taco Defender"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0.0, 140.0)
	title.set_size(Vector2(Constants.DESIGN_WIDTH, 60.0))
	title.add_theme_font_size_override(&"font_size", 34)
	title.add_theme_color_override(&"font_color", Constants.COLOR_GOLD)
	add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "Defiende la barra de la taqueria"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0.0, 200.0)
	subtitle.set_size(Vector2(Constants.DESIGN_WIDTH, 30.0))
	subtitle.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	subtitle.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	add_child(subtitle)

	var stats_label: Label = Label.new()
	stats_label.text = (
		"Mejor oleada: %d/%d   Victorias: %d"
		% [MetaManager.get_best_wave(), Constants.TOTAL_WAVES, MetaManager.get_victories()]
	)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.position = Vector2(0.0, 250.0)
	stats_label.set_size(Vector2(Constants.DESIGN_WIDTH, 26.0))
	stats_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	stats_label.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	add_child(stats_label)

	_tips_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tips_label.position = Vector2(0.0, 282.0)
	_tips_label.set_size(Vector2(Constants.DESIGN_WIDTH, 26.0))
	_tips_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	_tips_label.add_theme_color_override(&"font_color", Constants.COLOR_TIPS)
	add_child(_tips_label)
	_on_tips_changed(MetaManager.get_tips())

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 16)
	vbox.position = Vector2((Constants.DESIGN_WIDTH - 220.0) * 0.5, 420.0)
	vbox.set_size(Vector2(220.0, 220.0))
	add_child(vbox)

	var play_button: Button = Button.new()
	play_button.text = "JUGAR"
	play_button.custom_minimum_size = Vector2(0.0, 52.0)
	play_button.pressed.connect(_on_play_pressed)
	vbox.add_child(play_button)

	var upgrades_button: Button = Button.new()
	upgrades_button.text = "MEJORAS"
	upgrades_button.custom_minimum_size = Vector2(0.0, 52.0)
	upgrades_button.pressed.connect(_on_upgrades_pressed)
	vbox.add_child(upgrades_button)

	var settings_button: Button = Button.new()
	settings_button.text = "CONFIGURACION"
	settings_button.custom_minimum_size = Vector2(0.0, 52.0)
	settings_button.pressed.connect(_on_settings_pressed)
	vbox.add_child(settings_button)

	_settings = SettingsScreenGd.new()
	add_child(_settings)


func _on_tips_changed(new_amount: int) -> void:
	_tips_label.text = "Propinas: %d" % new_amount


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred(GAME_SCENE)


func _on_upgrades_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred(UPGRADE_SCREEN_SCENE)


func _on_settings_pressed() -> void:
	_settings.open()
