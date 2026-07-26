extends Control
## Tienda de torres desbloqueables (no GDD v1.1 — agregada a pedido explícito, ver nota
## extensa en Constants.gd sobre Chile Habanero/Queso Fundido/Pico de Gallo). Se compran
## con propinas, una sola vez cada una (para siempre, no por partida). Distinta de
## UpgradeScreen: esa sube estadísticas globales de las torres YA desbloqueadas; esta
## desbloquea OPCIONES DE JUEGO nuevas — mismo patrón visual (fila + botón), pantalla
## separada por decisión explícita del usuario. Elegir cuáles 3 llevar a la partida es
## responsabilidad de LoadoutScreen, no de acá.

const ModalStyleGd := preload("res://src/shared/modal_style.gd")
const BackgroundStyleGd := preload("res://src/shared/background_style.gd")
const ButtonSoundGd := preload("res://src/shared/button_sound.gd")
const IconStyleGd := preload("res://src/shared/icon_style.gd")
const MAIN_MENU_SCENE: String = "res://src/scenes/MainMenu.tscn"
const UPGRADE_BG: String = "res://assets/sprites/backgrounds/upgrade_bg.png"
const ROW_ICON_SIZE: float = 48.0

var _tips_label: Label = Label.new()
## tower_type -> {"name_label": Label, "stats_label": Label, "button": Button}
var _rows: Dictionary = {}


func _ready() -> void:
	_build_ui()
	EventBus.tower_unlocked.connect(_on_tower_unlocked)
	EventBus.tips_changed.connect(_on_tips_changed)
	EventBus.language_changed.connect(_on_language_changed)


func _exit_tree() -> void:
	if EventBus.tower_unlocked.is_connected(_on_tower_unlocked):
		EventBus.tower_unlocked.disconnect(_on_tower_unlocked)
	if EventBus.tips_changed.is_connected(_on_tips_changed):
		EventBus.tips_changed.disconnect(_on_tips_changed)
	if EventBus.language_changed.is_connected(_on_language_changed):
		EventBus.language_changed.disconnect(_on_language_changed)


func _build_ui() -> void:
	position = Vector2.ZERO
	set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))

	BackgroundStyleGd.add_background(self, UPGRADE_BG)

	var title: Label = Label.new()
	title.text = "TITLE_WEAPON_SHOP"
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

	## Centrado vertical DINÁMICO en el hueco disponible (entre las propinas y el botón
	## Volver) según la cantidad real de filas -- fijar un alto reservado a mano (intento
	## anterior: 400px, después 336px) no alcanza, porque el VBoxContainer solo ocupa su
	## alto NATURAL de contenido (filas * alto + separaciones) sin importar qué tamaño se
	## le asigne con set_size() -- el espacio vacío quedaba entre el contenido real y el
	## botón Volver, no adentro del container. Con 3 torres hoy el hueco es chico; si se
	## agregan más torres desbloqueables en el futuro, este cálculo se ajusta solo.
	var row_count: int = Constants.TOWER_UNLOCKABLE_TYPES.size()
	var row_height: float = 96.0
	var row_separation: float = 14.0
	var content_height: float = (
		float(row_count) * row_height + float(maxi(row_count - 1, 0)) * row_separation
	)
	var zone_top: float = 140.0
	var zone_bottom: float = Constants.DESIGN_HEIGHT - 76.0 - 20.0  ## margen sobre "Volver".
	var vbox_y: float = zone_top + maxf(0.0, (zone_bottom - zone_top - content_height) * 0.5)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", row_separation)
	vbox.position = Vector2(20.0, vbox_y)
	vbox.set_size(Vector2(Constants.DESIGN_WIDTH - 40.0, content_height))
	add_child(vbox)

	for tower_type: String in Constants.TOWER_UNLOCKABLE_TYPES:
		vbox.add_child(_build_row(tower_type))

	var back_button: Button = Button.new()
	back_button.text = "BTN_BACK"
	back_button.position = Vector2(20.0, Constants.DESIGN_HEIGHT - 76.0)
	back_button.set_size(Vector2(Constants.DESIGN_WIDTH - 40.0, 48.0))
	back_button.pressed.connect(_on_back_pressed)
	ButtonSoundGd.attach(back_button)
	add_child(back_button)

	_refresh_all()


func _build_row(tower_type: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 96.0)
	panel.add_theme_stylebox_override(&"panel", ModalStyleGd.opaque_panel())

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override(&"separation", 10)
	panel.add_child(hbox)

	var icon: TextureRect = IconStyleGd.make_icon("res://assets/sprites/towers/%s.png" % tower_type)
	icon.custom_minimum_size = Vector2(ROW_ICON_SIZE, ROW_ICON_SIZE)
	hbox.add_child(icon)

	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	## Autowrap: mismo motivo que UpgradeScreen/GameOverScreen -- un nombre largo o su
	## traducción no debe empujar el botón fuera de la pantalla.
	var name_label: Label = Label.new()
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	name_label.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	info_vbox.add_child(name_label)

	var stats_label: Label = Label.new()
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	stats_label.add_theme_font_size_override(&"font_size", 13)
	stats_label.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	info_vbox.add_child(stats_label)

	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(130.0, 44.0)
	button.pressed.connect(_on_unlock_pressed.bind(tower_type))
	ButtonSoundGd.attach(button)
	hbox.add_child(button)

	_rows[tower_type] = {"name_label": name_label, "stats_label": stats_label, "button": button}
	return panel


func _refresh_all() -> void:
	_tips_label.text = tr(&"LABEL_TIPS") % MetaManager.get_tips()
	for tower_type: String in _rows.keys():
		_refresh_row(tower_type)


func _refresh_row(tower_type: String) -> void:
	var row: Dictionary = _rows.get(tower_type, {}) as Dictionary
	if row.is_empty():
		return
	var data: Dictionary = Constants.TOWER_CATALOG.get(tower_type, {}) as Dictionary
	var name_label: Label = row["name_label"]
	var stats_label: Label = row["stats_label"]
	var button: Button = row["button"]
	name_label.text = tr(String(data.get("name", "")))
	stats_label.text = (
		tr(&"LABEL_TOWER_STATS") % [float(data.get("damage", 0.0)), float(data.get("range", 0.0))]
	)
	if LoadoutManager.is_tower_unlocked(tower_type):
		button.text = tr(&"LABEL_UNLOCKED")
		button.disabled = true
	else:
		var cost: int = int(Constants.TOWER_UNLOCK_COST.get(tower_type, 0))
		button.text = tr(&"BTN_UNLOCK_COST") % cost
		button.disabled = cost > MetaManager.get_tips()


func _on_unlock_pressed(tower_type: String) -> void:
	if not LoadoutManager.unlock_tower(tower_type):
		EventBus.action_feedback.emit(tr(&"TOAST_INSUFFICIENT_TIPS"))


func _on_tower_unlocked(_tower_type: String) -> void:
	_refresh_all()


func _on_tips_changed(_new_amount: int) -> void:
	_refresh_all()


func _on_language_changed(_locale: String) -> void:
	_refresh_all()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)
