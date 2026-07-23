extends Control
## Tienda de mejoras permanentes (GDD sección 5): 5 mejoras, 5 niveles cada una, costo
## 100/250/500/1000/2000 propinas por nivel (Constants.META_UPGRADE_COSTS). Construcción
## 100% programática — fondo con arte IA vía BackgroundStyleGd (ver /gen-ai-art).

const UpgradeShopGd := preload("res://src/features/meta/upgrade_shop.gd")
const ModalStyleGd := preload("res://src/shared/modal_style.gd")
const BackgroundStyleGd := preload("res://src/shared/background_style.gd")
const ButtonSoundGd := preload("res://src/shared/button_sound.gd")
const MAIN_MENU_SCENE: String = "res://src/scenes/MainMenu.tscn"
const UPGRADE_BG: String = "res://assets/sprites/backgrounds/upgrade_bg.png"

var _tips_label: Label = Label.new()
## upgrade_id -> {"name_label": Label, "level_label": Label, "button": Button}
var _rows: Dictionary = {}


func _ready() -> void:
	_build_ui()
	EventBus.meta_upgrade_purchased.connect(_on_meta_upgrade_purchased)
	EventBus.tips_changed.connect(_on_tips_changed)
	EventBus.language_changed.connect(_on_language_changed)


func _exit_tree() -> void:
	if EventBus.meta_upgrade_purchased.is_connected(_on_meta_upgrade_purchased):
		EventBus.meta_upgrade_purchased.disconnect(_on_meta_upgrade_purchased)
	if EventBus.tips_changed.is_connected(_on_tips_changed):
		EventBus.tips_changed.disconnect(_on_tips_changed)
	if EventBus.language_changed.is_connected(_on_language_changed):
		EventBus.language_changed.disconnect(_on_language_changed)


func _build_ui() -> void:
	position = Vector2.ZERO
	set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))

	BackgroundStyleGd.add_background(self, UPGRADE_BG)

	var title: Label = Label.new()
	title.text = "TITLE_UPGRADES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0.0, 50.0)
	title.set_size(Vector2(Constants.DESIGN_WIDTH, 40.0))
	title.add_theme_font_size_override(&"font_size", 26)
	title.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	add_child(title)

	_tips_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tips_label.position = Vector2(0.0, 96.0)
	_tips_label.set_size(Vector2(Constants.DESIGN_WIDTH, 30.0))
	_tips_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	_tips_label.add_theme_color_override(&"font_color", Constants.COLOR_TIPS)
	add_child(_tips_label)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 14)
	vbox.position = Vector2(20.0, 150.0)
	vbox.set_size(Vector2(Constants.DESIGN_WIDTH - 40.0, 560.0))
	add_child(vbox)

	for upgrade_id: String in UpgradeShopGd.UPGRADE_IDS:
		vbox.add_child(_build_row(upgrade_id))

	var back_button: Button = Button.new()
	back_button.text = "BTN_BACK"
	back_button.position = Vector2(20.0, Constants.DESIGN_HEIGHT - 76.0)
	back_button.set_size(Vector2(Constants.DESIGN_WIDTH - 40.0, 48.0))
	back_button.pressed.connect(_on_back_pressed)
	ButtonSoundGd.attach(back_button)
	add_child(back_button)

	_refresh_all()


func _build_row(upgrade_id: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 96.0)
	panel.add_theme_stylebox_override(&"panel", ModalStyleGd.opaque_panel())

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override(&"separation", 10)
	panel.add_child(hbox)

	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	## Sin autowrap, un nombre de mejora largo (traducido o no -- las versiones en
	## español ya eran igual de largas) reporta su ancho natural COMPLETO como tamaño
	## mínimo, empujando hbox/panel más ancho que la fila y desbordando la pantalla por
	## la derecha (mismo bug/mismo fix que el panel de FTUE en HUD.gd -- AUTOWRAP_WORD
	## resuelve la causa raíz, no solo el síntoma).
	var name_label: Label = Label.new()
	name_label.text = _display_name(upgrade_id)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	name_label.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	info_vbox.add_child(name_label)

	var level_label: Label = Label.new()
	level_label.add_theme_font_size_override(&"font_size", 14)
	level_label.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	info_vbox.add_child(level_label)

	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(130.0, 44.0)
	button.pressed.connect(_on_upgrade_pressed.bind(upgrade_id))
	ButtonSoundGd.attach(button)
	hbox.add_child(button)

	_rows[upgrade_id] = {"name_label": name_label, "level_label": level_label, "button": button}
	return panel


func _display_name(upgrade_id: String) -> String:
	match upgrade_id:
		Constants.META_UPGRADE_ID_DAMAGE:
			return tr(&"UPGRADE_NAME_DAMAGE")
		Constants.META_UPGRADE_ID_RANGE:
			return tr(&"UPGRADE_NAME_RANGE")
		Constants.META_UPGRADE_ID_COOLDOWN:
			return tr(&"UPGRADE_NAME_COOLDOWN")
		Constants.META_UPGRADE_ID_TIPS:
			return tr(&"UPGRADE_NAME_TIPS")
		Constants.META_UPGRADE_ID_BASE_HP:
			return tr(&"UPGRADE_NAME_BASE_HP")
		_:
			return upgrade_id


func _refresh_all() -> void:
	_tips_label.text = tr(&"LABEL_TIPS") % MetaManager.get_tips()
	for upgrade_id: String in _rows.keys():
		_refresh_row(upgrade_id)


func _refresh_row(upgrade_id: String) -> void:
	var row: Dictionary = _rows.get(upgrade_id, {}) as Dictionary
	if row.is_empty():
		return
	var name_label: Label = row["name_label"]
	var level_label: Label = row["level_label"]
	var button: Button = row["button"]
	name_label.text = _display_name(upgrade_id)
	var level: int = MetaManager.get_upgrade_level(upgrade_id)
	level_label.text = tr(&"LABEL_LEVEL") % [level, Constants.META_UPGRADE_MAX_LEVEL]
	if UpgradeShopGd.is_max_level(level):
		button.text = tr(&"LABEL_MAX_LEVEL")
		button.disabled = true
	else:
		var cost: int = UpgradeShopGd.cost_for_next_level(level)
		button.text = tr(&"BTN_BUY_COST") % cost
		button.disabled = cost > MetaManager.get_tips()


func _on_upgrade_pressed(upgrade_id: String) -> void:
	if not MetaManager.purchase_upgrade(upgrade_id):
		EventBus.action_feedback.emit(tr(&"TOAST_INSUFFICIENT_TIPS"))


func _on_meta_upgrade_purchased(_upgrade_id: String, _new_level: int) -> void:
	_refresh_all()


func _on_tips_changed(_new_amount: int) -> void:
	_refresh_all()


func _on_language_changed(_locale: String) -> void:
	_refresh_all()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)
