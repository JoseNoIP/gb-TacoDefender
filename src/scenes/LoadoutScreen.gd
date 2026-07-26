extends Control
## Selección del equipo de 3 torres para la PRÓXIMA partida (a pedido explícito: "el
## jugador pueda irlas intercambiando... elegir cuáles usar en cada nivel de las que ya
## ha comprado"). Persistente hasta que se cambie (LoadoutManager.get_current_loadout()),
## editable en cualquier momento desde MainMenu -- NO se fuerza un paso extra en cada
## partida, por decisión explícita del usuario (ver conversación).

const ModalStyleGd := preload("res://src/shared/modal_style.gd")
const BackgroundStyleGd := preload("res://src/shared/background_style.gd")
const ButtonSoundGd := preload("res://src/shared/button_sound.gd")
const IconStyleGd := preload("res://src/shared/icon_style.gd")
const MAIN_MENU_SCENE: String = "res://src/scenes/MainMenu.tscn"
const UPGRADE_BG: String = "res://assets/sprites/backgrounds/upgrade_bg.png"
const REQUIRED_COUNT: int = 3
const ROW_ICON_SIZE: float = 48.0

var _save_button: Button = Button.new()
var _count_label: Label = Label.new()
## tower_type -> Button (toggle_mode = true)
var _rows: Dictionary = {}


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	position = Vector2.ZERO
	set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))

	BackgroundStyleGd.add_background(self, UPGRADE_BG)

	var title: Label = Label.new()
	title.text = "TITLE_LOADOUT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0.0, 50.0)
	title.set_size(Vector2(Constants.DESIGN_WIDTH, 40.0))
	title.add_theme_font_size_override(&"font_size", 26)
	title.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	add_child(title)

	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.position = Vector2(0.0, 96.0)
	_count_label.set_size(Vector2(Constants.DESIGN_WIDTH, 30.0))
	_count_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	_count_label.add_theme_color_override(&"font_color", Constants.COLOR_TIPS)
	add_child(_count_label)

	## ScrollContainer: hasta 6 torres hoy (3 originales + 3 desbloqueables), más en el
	## futuro -- mismo criterio que LevelSelectScreen, nunca asumir que entran sin scroll.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(20.0, 140.0)
	scroll.set_size(Vector2(Constants.DESIGN_WIDTH - 40.0, Constants.DESIGN_HEIGHT - 140.0 - 140.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var current_loadout: Array = LoadoutManager.get_current_loadout()
	for tower_type: String in LoadoutManager.get_unlocked_towers():
		vbox.add_child(_build_row(tower_type, tower_type in current_loadout))

	_save_button.text = "BTN_SAVE_LOADOUT"
	_save_button.position = Vector2(20.0, Constants.DESIGN_HEIGHT - 132.0)
	_save_button.set_size(Vector2(Constants.DESIGN_WIDTH - 40.0, 48.0))
	_save_button.pressed.connect(_on_save_pressed)
	ButtonSoundGd.attach(_save_button)
	add_child(_save_button)

	var back_button: Button = Button.new()
	back_button.text = "BTN_BACK"
	back_button.position = Vector2(20.0, Constants.DESIGN_HEIGHT - 76.0)
	back_button.set_size(Vector2(Constants.DESIGN_WIDTH - 40.0, 48.0))
	back_button.pressed.connect(_on_back_pressed)
	ButtonSoundGd.attach(back_button)
	add_child(back_button)

	_refresh_count_label()


func _build_row(tower_type: String, is_selected: bool) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 72.0)
	panel.add_theme_stylebox_override(&"panel", ModalStyleGd.opaque_panel())

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override(&"separation", 10)
	panel.add_child(hbox)

	var icon: TextureRect = IconStyleGd.make_icon("res://assets/sprites/towers/%s.png" % tower_type)
	icon.custom_minimum_size = Vector2(ROW_ICON_SIZE, ROW_ICON_SIZE)
	hbox.add_child(icon)

	var data: Dictionary = Constants.TOWER_CATALOG.get(tower_type, {}) as Dictionary
	var name_label: Label = Label.new()
	name_label.text = tr(String(data.get("name", "")))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	name_label.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	hbox.add_child(name_label)

	var toggle: Button = Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = is_selected
	toggle.custom_minimum_size = Vector2(120.0, 44.0)
	toggle.text = tr(&"BTN_SELECTED") if is_selected else tr(&"BTN_SELECT")
	toggle.toggled.connect(_on_toggle_changed.bind(tower_type))
	ButtonSoundGd.attach(toggle)
	hbox.add_child(toggle)

	_rows[tower_type] = toggle
	return panel


func _selected_types() -> Array:
	var selected: Array = []
	for tower_type: String in _rows.keys():
		var button: Button = _rows[tower_type]
		if button.button_pressed:
			selected.append(tower_type)
	return selected


## set_pressed_no_signal() (no la propiedad .button_pressed directa) para revertir un
## intento de elegir una 4ta torre -- asignar .button_pressed SÍ vuelve a emitir
## `toggled` (verificado en runtime), lo que reentraría a este mismo handler.
func _on_toggle_changed(is_now_pressed: bool, tower_type: String) -> void:
	var button: Button = _rows[tower_type]
	if is_now_pressed and _selected_types().size() > REQUIRED_COUNT:
		button.set_pressed_no_signal(false)
		EventBus.action_feedback.emit(tr(&"TOAST_LOADOUT_FULL"))
		return
	button.text = tr(&"BTN_SELECTED") if button.button_pressed else tr(&"BTN_SELECT")
	_refresh_count_label()


func _refresh_count_label() -> void:
	var count: int = _selected_types().size()
	_count_label.text = tr(&"LABEL_LOADOUT_COUNT") % [count, REQUIRED_COUNT]
	_save_button.disabled = count != REQUIRED_COUNT


func _on_save_pressed() -> void:
	if LoadoutManager.set_current_loadout(_selected_types()):
		EventBus.action_feedback.emit(tr(&"TOAST_LOADOUT_SAVED"))


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)
