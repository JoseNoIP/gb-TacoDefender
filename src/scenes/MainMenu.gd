extends Control
## Menú principal (GDD): JUGAR, MEJORAS, CONFIGURACIÓN. "JUGAR" siempre enruta a
## Game.tscn — el FTUE de Taco Defender es un overlay ligero DENTRO de Game.tscn (ver
## HUD.gd), no una escena de tutorial separada: la arquitectura de tutorial del template
## está pensada para un juego de movimiento/disparo (Player/GemSpawner/PowerUpDropper) que
## no existe en este tower defense — ver idea-base.md, sección FASE 0/FTUE.
##
## i18n (ver /mobile-i18n): título/subtítulo/botones son texto estático asignado una sola
## vez -- usan la KEY cruda (sin tr()) y Control.auto_translate_mode los retraduce solo
## si el idioma cambia mientras esta pantalla sigue viva (child SettingsScreen abierto
## encima). stats_label/tips_label tienen valores incrustados con %, así que SÍ necesitan
## tr() explícito + reconstruirse en EventBus.language_changed (auto_translate no alcanza
## para texto formateado).

const GAME_SCENE: String = "res://src/scenes/Game.tscn"
const UPGRADE_SCREEN_SCENE: String = "res://src/scenes/UpgradeScreen.tscn"
const LANGUAGE_SELECT_SCENE: String = "res://src/scenes/LanguageSelectScreen.tscn"
const SettingsScreenGd := preload("res://src/features/ui/SettingsScreen.gd")
const BackgroundStyleGd := preload("res://src/shared/background_style.gd")
const ButtonSoundGd := preload("res://src/shared/button_sound.gd")
const MENU_BG: String = "res://assets/sprites/backgrounds/menu_bg.png"

var _tips_label: Label = Label.new()
var _stats_label: Label = Label.new()
var _settings: CanvasLayer = null


func _ready() -> void:
	if not LocalizationManager.is_language_selected():
		get_tree().change_scene_to_file.call_deferred(LANGUAGE_SELECT_SCENE)
		return
	_build_ui()
	EventBus.tips_changed.connect(_on_tips_changed)
	EventBus.language_changed.connect(_on_language_changed)


func _exit_tree() -> void:
	if EventBus.tips_changed.is_connected(_on_tips_changed):
		EventBus.tips_changed.disconnect(_on_tips_changed)
	if EventBus.language_changed.is_connected(_on_language_changed):
		EventBus.language_changed.disconnect(_on_language_changed)


func _build_ui() -> void:
	position = Vector2.ZERO
	set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))

	BackgroundStyleGd.add_background(self, MENU_BG)

	var title: Label = Label.new()
	title.text = "Taco Defender"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0.0, 140.0)
	title.set_size(Vector2(Constants.DESIGN_WIDTH, 60.0))
	title.add_theme_font_size_override(&"font_size", 34)
	title.add_theme_color_override(&"font_color", Constants.COLOR_GOLD)
	add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "MENU_SUBTITLE"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0.0, 200.0)
	subtitle.set_size(Vector2(Constants.DESIGN_WIDTH, 30.0))
	subtitle.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	subtitle.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	add_child(subtitle)

	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.position = Vector2(0.0, 250.0)
	_stats_label.set_size(Vector2(Constants.DESIGN_WIDTH, 26.0))
	_stats_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	_stats_label.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	add_child(_stats_label)
	_refresh_stats_label()

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
	play_button.text = "BTN_PLAY"
	play_button.custom_minimum_size = Vector2(0.0, 52.0)
	play_button.pressed.connect(_on_play_pressed)
	ButtonSoundGd.attach(play_button)
	vbox.add_child(play_button)

	var upgrades_button: Button = Button.new()
	upgrades_button.text = "BTN_UPGRADES"
	upgrades_button.custom_minimum_size = Vector2(0.0, 52.0)
	upgrades_button.pressed.connect(_on_upgrades_pressed)
	ButtonSoundGd.attach(upgrades_button)
	vbox.add_child(upgrades_button)

	var settings_button: Button = Button.new()
	settings_button.text = "BTN_SETTINGS"
	settings_button.custom_minimum_size = Vector2(0.0, 52.0)
	settings_button.pressed.connect(_on_settings_pressed)
	ButtonSoundGd.attach(settings_button)
	vbox.add_child(settings_button)

	_settings = SettingsScreenGd.new()
	add_child(_settings)


func _refresh_stats_label() -> void:
	_stats_label.text = (
		tr(&"MENU_STATS")
		% [MetaManager.get_best_wave(), Constants.TOTAL_WAVES, MetaManager.get_victories()]
	)


func _on_tips_changed(new_amount: int) -> void:
	_tips_label.text = tr(&"LABEL_TIPS") % new_amount


func _on_language_changed(_locale: String) -> void:
	_refresh_stats_label()
	_on_tips_changed(MetaManager.get_tips())


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred(GAME_SCENE)


func _on_upgrades_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred(UPGRADE_SCREEN_SCENE)


func _on_settings_pressed() -> void:
	_settings.open()
