extends Control
## Selección de nivel (a pedido explícito del jugador): lista de los 10 niveles
## (Constants.PATH_TEMPLATES/LEVEL_NAME_KEYS). Progresión estrictamente secuencial —
## "victorias" (MetaManager.get_victories()) sube solo al ganar el nivel FRONTERA (ver
## GameManager._win_game()), nunca al rejugar uno ya completado:
##   índice < victorias        -> completado, rejugable
##   índice == victorias       -> desbloqueado, todavía no completado (siguiente a jugar)
##   índice > victorias        -> bloqueado
## Elegir un nivel llama GameManager.request_level(i) ANTES de cambiar de escena — Board
## lo consume en su propio _ready() vía GameManager.resolve_level_index() (ver nota en
## GameManager.gd sobre por qué esto es seguro respecto al orden _build_scene()/
## start_game(), regla CLAUDE.md #48).

const ModalStyleGd := preload("res://src/shared/modal_style.gd")
const BackgroundStyleGd := preload("res://src/shared/background_style.gd")
const ButtonSoundGd := preload("res://src/shared/button_sound.gd")
const MAIN_MENU_SCENE: String = "res://src/scenes/MainMenu.tscn"
const GAME_SCENE: String = "res://src/scenes/Game.tscn"
const MENU_BG: String = "res://assets/sprites/backgrounds/menu_bg.png"

## level_index -> {"name_label": Label, "button": Button}
var _rows: Dictionary = {}


func _ready() -> void:
	_build_ui()
	EventBus.language_changed.connect(_on_language_changed)


func _exit_tree() -> void:
	if EventBus.language_changed.is_connected(_on_language_changed):
		EventBus.language_changed.disconnect(_on_language_changed)


func _build_ui() -> void:
	position = Vector2.ZERO
	set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))

	BackgroundStyleGd.add_background(self, MENU_BG)

	var title: Label = Label.new()
	title.text = "TITLE_LEVEL_SELECT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0.0, 50.0)
	title.set_size(Vector2(Constants.DESIGN_WIDTH, 40.0))
	title.add_theme_font_size_override(&"font_size", 26)
	title.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	add_child(title)

	## ScrollContainer -- 10 filas no entran garantizado en el hueco disponible en todas
	## las resoluciones/idiomas (mismo criterio que UpgradeScreen, que sí entra con solo
	## 5 filas; acá el doble de filas exige scroll para no arriesgarse).
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(20.0, 104.0)
	scroll.set_size(Vector2(Constants.DESIGN_WIDTH - 40.0, Constants.DESIGN_HEIGHT - 104.0 - 96.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	for index in range(Constants.PATH_TEMPLATES.size()):
		vbox.add_child(_build_row(index))

	var back_button: Button = Button.new()
	back_button.text = "BTN_BACK"
	back_button.position = Vector2(20.0, Constants.DESIGN_HEIGHT - 76.0)
	back_button.set_size(Vector2(Constants.DESIGN_WIDTH - 40.0, 48.0))
	back_button.pressed.connect(_on_back_pressed)
	ButtonSoundGd.attach(back_button)
	add_child(back_button)

	_refresh_all()


func _build_row(index: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 64.0)
	panel.add_theme_stylebox_override(&"panel", ModalStyleGd.opaque_panel())

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override(&"separation", 10)
	panel.add_child(hbox)

	var name_label: Label = Label.new()
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	name_label.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	hbox.add_child(name_label)

	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(120.0, 44.0)
	button.pressed.connect(_on_level_pressed.bind(index))
	ButtonSoundGd.attach(button)
	hbox.add_child(button)

	_rows[index] = {"name_label": name_label, "button": button}
	return panel


func _level_display_name(index: int) -> String:
	return "%d. %s" % [index + 1, tr(StringName(Constants.LEVEL_NAME_KEYS[index]))]


func _refresh_all() -> void:
	var victories: int = MetaManager.get_victories()
	for index: int in _rows.keys():
		_refresh_row(index, victories)


func _refresh_row(index: int, victories: int) -> void:
	var row: Dictionary = _rows.get(index, {}) as Dictionary
	if row.is_empty():
		return
	var name_label: Label = row["name_label"]
	var button: Button = row["button"]
	name_label.text = _level_display_name(index)
	if index > victories:
		button.text = tr(&"BTN_LEVEL_LOCKED")
		button.disabled = true
	elif index < victories:
		button.text = tr(&"BTN_LEVEL_REPLAY")
		button.disabled = false
	else:
		button.text = tr(&"BTN_PLAY")
		button.disabled = false


func _on_level_pressed(index: int) -> void:
	GameManager.request_level(index)
	get_tree().change_scene_to_file.call_deferred(GAME_SCENE)


func _on_language_changed(_locale: String) -> void:
	_refresh_all()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)
