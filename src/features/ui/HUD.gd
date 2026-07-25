extends CanvasLayer
## HUD de gameplay (GDD secciones 2 y 5): oro, vida de la taquería, oleada actual, barra
## de compra de torres, botón de iniciar oleada y panel de selección de torre. Sin lógica
## de juego propia — solo refleja EventBus/GameManager/MetaManager y traduce taps de UI a
## señales que Board/GameManager escuchan. Instanciada por Game.gd (construcción 100%
## programática). Los botones de compra usan los mismos sprites de torre que el tablero
## (ver /gen-ai-art) — icon path = "res://assets/sprites/towers/%s.png" % tower_type,
## porque Constants.TOWER_TYPE_* ya coincide 1:1 con el nombre de archivo.

const ModalStyleGd := preload("res://src/shared/modal_style.gd")
const IconStyleGd := preload("res://src/shared/icon_style.gd")
const ButtonSoundGd := preload("res://src/shared/button_sound.gd")
const HeartFullTexture: Texture2D = preload("res://assets/sprites/ui/heart.png")
const HeartEmptyTexture: Texture2D = preload("res://assets/sprites/ui/broken_heart.png")

const TOWER_BUTTON_WIDTH: float = 110.0
const TOWER_BUTTON_HEIGHT: float = 94.0
const TOWER_BUTTON_GAP: float = 10.0
const TOWER_BUTTON_ICON_SIZE: float = 40.0
const TOP_BAR_ICON_SIZE: float = 22.0
const SELECTION_ICON_SIZE: float = 48.0
## Fila de corazones de vida (reemplaza ícono único + texto "3/3" -- ver _rebuild_hp_hearts).
const HP_HEART_GAP: float = 3.0
const HP_HEART_MIN_ICON_SIZE: float = 12.0
const TOAST_DURATION: float = 1.6
const TOAST_FADE_IN: float = 0.15
const TOAST_FADE_OUT: float = 0.25
const TOAST_SLIDE_OFFSET: float = 10.0

## FTUE ligero (adaptado — ver idea-base.md): a diferencia del FTUE interactivo del
## template (pensado para un juego de movimiento/disparo tipo GuacBlaster Survivor, con
## Player/GemSpawner/PowerUpDropper), Taco Defender no tiene avatar ni drag-to-move ni
## recolección de gemas — sus 3 mecánicas nuevas son "construir", "iniciar oleada" y
## "mejorar/vender", así que se documentan como 3 mensajes estáticos en vez de una escena
## de tutorial separada con estados que esperan señales de sistemas que este juego no tiene.
## Keys de traducción (ver /mobile-i18n), no texto de display -- tr() se aplica donde se
## consumen (_build_ftue_overlay/_on_ftue_button_pressed).
const FTUE_MESSAGE_KEYS: Array = ["FTUE_1", "FTUE_2", "FTUE_3"]

var _gold_label: Label = Label.new()
var _wave_label: Label = Label.new()
var _hp_hearts_box: Control = Control.new()
var _hp_hearts: Array = []  ## TextureRect por vida máxima -- ver _rebuild_hp_hearts().
var _hp_hearts_max: int = -1  ## -1 = todavía no se construyó ninguna fila.
var _pause_button: Button = Button.new()
var _start_wave_button: Button = Button.new()
var _toast_label: Label = Label.new()
var _toast_timer: float = 0.0
var _toast_rest_position: Vector2 = Vector2.ZERO
var _toast_tween: Tween = null

var _selection_panel: PanelContainer = PanelContainer.new()
var _selection_icon: TextureRect = TextureRect.new()
var _selection_title: Label = Label.new()
var _selection_stats: Label = Label.new()
var _selection_upgrade_button: Button = Button.new()
var _selection_sell_button: Button = Button.new()
var _selected_cell: Vector2i = Vector2i(-1, -1)

var _ftue_panel: PanelContainer = PanelContainer.new()
var _ftue_label: Label = Label.new()
var _ftue_button: Button = Button.new()
var _ftue_step: int = 0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_top_bar()
	_build_bottom_bar()
	_build_toast()
	_build_selection_panel()
	_build_ftue_overlay()

	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.base_health_changed.connect(_on_base_health_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_intermission_started.connect(_on_wave_intermission_started)
	EventBus.tower_selected.connect(_on_tower_selected)
	EventBus.tower_deselected.connect(_on_tower_deselected)
	EventBus.action_feedback.connect(_on_action_feedback)

	_on_gold_changed(GameManager.get_gold())


## Godot desconecta automáticamente las señales de un objeto liberado, pero queue_free()
## difiere la liberación real al final del frame — durante esa ventana, una escena NUEVA
## (tras restart/menú) ya pudo conectar SU propio HUD al mismo EventBus, y este HUD viejo
## seguiría reaccionando también si algo emite antes de que termine de liberarse. Cortar
## la conexión acá, explícito, evita esa doble escucha transitoria.
func _exit_tree() -> void:
	if EventBus.gold_changed.is_connected(_on_gold_changed):
		EventBus.gold_changed.disconnect(_on_gold_changed)
	if EventBus.base_health_changed.is_connected(_on_base_health_changed):
		EventBus.base_health_changed.disconnect(_on_base_health_changed)
	if EventBus.wave_started.is_connected(_on_wave_started):
		EventBus.wave_started.disconnect(_on_wave_started)
	if EventBus.wave_intermission_started.is_connected(_on_wave_intermission_started):
		EventBus.wave_intermission_started.disconnect(_on_wave_intermission_started)
	if EventBus.tower_selected.is_connected(_on_tower_selected):
		EventBus.tower_selected.disconnect(_on_tower_selected)
	if EventBus.tower_deselected.is_connected(_on_tower_deselected):
		EventBus.tower_deselected.disconnect(_on_tower_deselected)
	if EventBus.action_feedback.is_connected(_on_action_feedback):
		EventBus.action_feedback.disconnect(_on_action_feedback)
	## Un Tween en vuelo (toast a mitad de animación) no se limpia solo si este nodo se
	## libera antes de que termine -- matarlo acá evita un ObjectDB huérfano, tanto en
	## tests (add_child_autofree) como en una transición real de escena a mitad de un toast.
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_play_toast_tween(1.0, 0.0, TOAST_FADE_OUT, _toast_rest_position, _toast_rest_position)
			_toast_tween.tween_callback(_toast_label.hide)


func _build_top_bar() -> void:
	var bar: ColorRect = ColorRect.new()
	bar.position = Vector2.ZERO
	bar.set_size(Vector2(Constants.DESIGN_WIDTH, Constants.HUD_TOP_HEIGHT))
	bar.color = Constants.COLOR_BG_BOARD
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	var coin_icon: TextureRect = IconStyleGd.make_icon("res://assets/sprites/ui/coin.png")
	coin_icon.position = Vector2(16.0, 25.0)
	coin_icon.set_size(Vector2(TOP_BAR_ICON_SIZE, TOP_BAR_ICON_SIZE))
	add_child(coin_icon)

	_gold_label.position = Vector2(16.0 + TOP_BAR_ICON_SIZE + 6.0, 26.0)
	_gold_label.set_size(Vector2(120.0, 26.0))
	_style_label(_gold_label, Constants.COLOR_GOLD)
	add_child(_gold_label)

	_wave_label.position = Vector2(16.0, 54.0)
	_wave_label.set_size(Vector2(310.0, 26.0))
	_style_label(_wave_label, Constants.COLOR_HUD_TEXT)
	_wave_label.text = tr(&"LABEL_WAVE") % [0, Constants.TOTAL_WAVES]
	add_child(_wave_label)

	## Caja de corazones alineada al mismo borde derecho que tenía antes el ícono+"3/3"
	## (DESIGN_WIDTH - 16) -- ver _rebuild_hp_hearts() para cómo se llena.
	var hp_box_width: float = 154.0
	var hp_box_x: float = Constants.DESIGN_WIDTH - 16.0 - hp_box_width
	_hp_hearts_box.position = Vector2(hp_box_x, 25.0)
	_hp_hearts_box.set_size(Vector2(hp_box_width, TOP_BAR_ICON_SIZE))
	_hp_hearts_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_hearts_box)

	_pause_button.text = "II"
	_pause_button.position = Vector2(Constants.DESIGN_WIDTH - 56.0, 52.0)
	_pause_button.set_size(Vector2(40.0, 40.0))
	_pause_button.pressed.connect(_on_pause_pressed)
	ButtonSoundGd.attach(_pause_button)
	add_child(_pause_button)


func _build_bottom_bar() -> void:
	var bar_top: float = Constants.DESIGN_HEIGHT - Constants.BOTTOM_BAR_HEIGHT
	var bar: ColorRect = ColorRect.new()
	bar.position = Vector2(0.0, bar_top)
	bar.set_size(Vector2(Constants.DESIGN_WIDTH, Constants.BOTTOM_BAR_HEIGHT))
	bar.color = Constants.COLOR_BG_BOARD
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	_start_wave_button.text = "BTN_START_WAVE"
	_start_wave_button.position = Vector2(20.0, bar_top + 6.0)
	_start_wave_button.set_size(Vector2(Constants.DESIGN_WIDTH - 40.0, 34.0))
	_start_wave_button.pressed.connect(_on_start_wave_pressed)
	ButtonSoundGd.attach(_start_wave_button)
	add_child(_start_wave_button)

	var buttons_y: float = bar_top + 48.0
	var total_width: float = 3.0 * TOWER_BUTTON_WIDTH + 2.0 * TOWER_BUTTON_GAP
	var start_x: float = (Constants.DESIGN_WIDTH - total_width) * 0.5
	var index: int = 0
	for tower_type: String in Constants.TOWER_TYPES:
		var data: Dictionary = Constants.TOWER_CATALOG.get(tower_type, {}) as Dictionary
		var button: Button = Button.new()
		button.text = ""
		button.position = Vector2(
			start_x + float(index) * (TOWER_BUTTON_WIDTH + TOWER_BUTTON_GAP), buttons_y
		)
		button.set_size(Vector2(TOWER_BUTTON_WIDTH, TOWER_BUTTON_HEIGHT))
		button.pressed.connect(_on_tower_button_pressed.bind(tower_type))
		ButtonSoundGd.attach(button)
		add_child(button)

		var icon: TextureRect = IconStyleGd.make_icon(
			"res://assets/sprites/towers/%s.png" % tower_type
		)
		icon.position = Vector2((TOWER_BUTTON_WIDTH - TOWER_BUTTON_ICON_SIZE) * 0.5, 6.0)
		icon.set_size(Vector2(TOWER_BUTTON_ICON_SIZE, TOWER_BUTTON_ICON_SIZE))
		button.add_child(icon)

		var label: Label = Label.new()
		label.text = "%s\n$%d" % [tr(String(data.get("name", ""))), int(data.get("cost", 0))]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(&"font_size", 13)
		label.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
		label.position = Vector2(0.0, TOWER_BUTTON_ICON_SIZE + 10.0)
		label.set_size(
			Vector2(TOWER_BUTTON_WIDTH, TOWER_BUTTON_HEIGHT - TOWER_BUTTON_ICON_SIZE - 10.0)
		)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
		index += 1


func _build_toast() -> void:
	_toast_rest_position = Vector2(20.0, Constants.HUD_TOP_HEIGHT + 8.0)
	_toast_label.position = _toast_rest_position
	_toast_label.set_size(Vector2(Constants.DESIGN_WIDTH - 40.0, 32.0))
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_stylebox_override(&"normal", ModalStyleGd.opaque_panel())
	_style_label(_toast_label, Constants.COLOR_HUD_TEXT)
	_toast_label.modulate.a = 0.0
	_toast_label.visible = false
	add_child(_toast_label)


func _build_selection_panel() -> void:
	var panel_w: float = 280.0
	var panel_h: float = 190.0
	_selection_panel.position = Vector2(
		(Constants.DESIGN_WIDTH - panel_w) * 0.5,
		Constants.DESIGN_HEIGHT - Constants.BOTTOM_BAR_HEIGHT - panel_h - 12.0
	)
	_selection_panel.set_size(Vector2(panel_w, panel_h))
	_selection_panel.add_theme_stylebox_override(&"panel", ModalStyleGd.opaque_panel())
	add_child(_selection_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 8)
	_selection_panel.add_child(vbox)

	var info_row: HBoxContainer = HBoxContainer.new()
	info_row.add_theme_constant_override(&"separation", 12)
	vbox.add_child(info_row)

	_selection_icon.custom_minimum_size = Vector2(SELECTION_ICON_SIZE, SELECTION_ICON_SIZE)
	_selection_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_selection_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	info_row.add_child(_selection_icon)

	var text_vbox: VBoxContainer = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(text_vbox)

	_selection_title.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	_selection_title.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	text_vbox.add_child(_selection_title)

	_selection_stats.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	_selection_stats.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	text_vbox.add_child(_selection_stats)

	var buttons_row: HBoxContainer = HBoxContainer.new()
	buttons_row.add_theme_constant_override(&"separation", 8)
	vbox.add_child(buttons_row)

	_selection_upgrade_button.custom_minimum_size = Vector2(120.0, 40.0)
	_selection_upgrade_button.pressed.connect(_on_upgrade_pressed)
	ButtonSoundGd.attach(_selection_upgrade_button)
	buttons_row.add_child(_selection_upgrade_button)

	_selection_sell_button.custom_minimum_size = Vector2(120.0, 40.0)
	_selection_sell_button.pressed.connect(_on_sell_pressed)
	ButtonSoundGd.attach(_selection_sell_button)
	buttons_row.add_child(_selection_sell_button)

	var close_button: Button = Button.new()
	close_button.text = "BTN_CLOSE"
	close_button.custom_minimum_size = Vector2(0.0, 32.0)
	close_button.pressed.connect(_on_close_selection_pressed)
	ButtonSoundGd.attach(close_button)
	vbox.add_child(close_button)

	_selection_panel.hide()


func _build_ftue_overlay() -> void:
	var panel_w: float = 320.0
	var panel_h: float = 200.0
	_ftue_panel.position = Vector2(
		(Constants.DESIGN_WIDTH - panel_w) * 0.5, (Constants.DESIGN_HEIGHT - panel_h) * 0.5
	)
	_ftue_panel.set_size(Vector2(panel_w, panel_h))
	_ftue_panel.add_theme_stylebox_override(&"panel", ModalStyleGd.opaque_panel())
	## Defensivo: si algún mensaje futuro fuera más ancho que el panel, esto recorta en vez
	## de desbordar la pantalla (ver bug real de abajo — la causa raíz ya se arregla con
	## autowrap_mode, esto es una segunda red de seguridad).
	_ftue_panel.clip_contents = true
	add_child(_ftue_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 12)
	_ftue_panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "FTUE_TITLE"
	title.add_theme_font_size_override(&"font_size", 22)
	title.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	vbox.add_child(title)

	## Bug real encontrado con el probe visual (regla CLAUDE.md #49): sin autowrap_mode, un
	## Label mide su tamaño natural/mínimo como el ancho de la línea SIN cortar — con una
	## oración larga, eso empuja al VBoxContainer/PanelContainer padre bien más ancho que
	## panel_w (custom_minimum_size solo pone un PISO, nunca un techo), desbordando la
	## pantalla (texto y botón "Siguiente" cortados en el borde derecho). AUTOWRAP_WORD
	## fuerza el cálculo de tamaño mínimo a asumir que el texto SÍ puede cortarse en
	## palabras, resolviendo la causa raíz (no solo el síntoma).
	_ftue_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_ftue_label.text = tr(StringName(FTUE_MESSAGE_KEYS[0]))
	_ftue_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	_ftue_label.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	_ftue_label.custom_minimum_size = Vector2(panel_w - 32.0, 110.0)
	vbox.add_child(_ftue_label)

	_ftue_button.text = "BTN_NEXT"
	_ftue_button.custom_minimum_size = Vector2(0.0, 40.0)
	_ftue_button.pressed.connect(_on_ftue_button_pressed)
	ButtonSoundGd.attach(_ftue_button)
	vbox.add_child(_ftue_button)

	## set_tutorial_shown(true) SOLO se llama al completar el último paso (_on_ftue_button_
	## pressed), nunca acá — si no, un save existente con el flag ya en true simplemente no
	## muestra nada, que es el comportamiento correcto para partidas siguientes.
	_ftue_panel.visible = not SaveManager.get_tutorial_shown()


func _style_label(label: Label, color: Color) -> void:
	label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	label.add_theme_color_override(&"font_color", color)


func _on_gold_changed(new_amount: int) -> void:
	_gold_label.text = "$%d" % new_amount


## Un corazón por vida máxima (en vez de un ícono único + texto "3/3") -- el jugador
## reportó que el contador numérico no era claro ("tuve que jugar varias partidas para
## entender cómo funcionaba"). El máximo es fijo durante toda la partida (ver
## GameManager._base_hp_max, solo se fija una vez al iniciar según la mejora "Barra
## Blindada"), así que la fila de corazones se reconstruye solo cuando cambia -- nunca en
## cada impacto recibido.
func _on_base_health_changed(current: int, maximum: int) -> void:
	if maximum != _hp_hearts_max:
		_rebuild_hp_hearts(maximum)
	for i in range(_hp_hearts.size()):
		var heart: TextureRect = _hp_hearts[i]
		heart.texture = HeartFullTexture if i < current else HeartEmptyTexture


## Corazones en una sola fila que SIEMPRE cabe en hp_box_width (154px) sin importar cuántas
## vidas máximas tenga la partida (3 base, hasta 8 con "Barra Blindada" nivel 5) -- el
## tamaño de ícono se auto-ajusta hacia abajo (nunca crece más allá de TOP_BAR_ICON_SIZE)
## en vez de asumir que un tamaño fijo alcanza para cualquier cantidad (mismo criterio de
## auto-escalado que la regla CLAUDE.md #54, acá en un solo eje).
func _rebuild_hp_hearts(maximum: int) -> void:
	for heart: TextureRect in _hp_hearts:
		heart.queue_free()
	_hp_hearts.clear()
	_hp_hearts_max = maximum
	if maximum <= 0:
		return
	var icon_size: float = clampf(
		(_hp_hearts_box.size.x - float(maximum - 1) * HP_HEART_GAP) / float(maximum),
		HP_HEART_MIN_ICON_SIZE,
		TOP_BAR_ICON_SIZE
	)
	for i in range(maximum):
		var heart: TextureRect = IconStyleGd.make_icon("res://assets/sprites/ui/heart.png")
		heart.position = Vector2(float(i) * (icon_size + HP_HEART_GAP), 0.0)
		heart.set_size(Vector2(icon_size, icon_size))
		_hp_hearts_box.add_child(heart)
		_hp_hearts.append(heart)


## Nombre del nivel activo (GameManager.get_current_level_index(), fijado en start_game()
## ANTES de que se emitan wave_started/wave_intermission_started -- ver nota en
## GameManager.start_game()) prefijado a la etiqueta de oleada. El jugador pidió
## explícitamente poder ver en qué nivel está durante la partida, no solo en el menú.
func _current_level_name() -> String:
	var index: int = GameManager.get_current_level_index()
	if index < 0 or index >= Constants.LEVEL_NAME_KEYS.size():
		return ""
	return tr(StringName(Constants.LEVEL_NAME_KEYS[index]))


func _level_and_wave_text(wave_number: int) -> String:
	var wave_text: String = tr(&"LABEL_WAVE") % [wave_number, Constants.TOTAL_WAVES]
	return "%s · %s" % [_current_level_name(), wave_text]


## Ambos estados (jugando / preparando la siguiente) usan el MISMO formato corto
## (LABEL_WAVE, sin el sufijo "— get ready" de LABEL_WAVE_PREPARE) -- con el nombre del
## nivel también en la línea, el texto combinado completo se salía del viewport (390px)
## en inglés/portugués antes de este fix (bug real, encontrado con el probe visual, ver
## regla CLAUDE.md #49). El botón START WAVE (visible solo en el estado de preparación)
## ya comunica "preparate" sin necesidad de repetirlo en texto.
func _on_wave_started(wave_number: int) -> void:
	_wave_label.text = _level_and_wave_text(wave_number)
	_start_wave_button.visible = false


func _on_wave_intermission_started(next_wave_number: int, _auto_start_delay: float) -> void:
	_wave_label.text = _level_and_wave_text(next_wave_number)
	_start_wave_button.visible = true


func _on_tower_button_pressed(tower_type: String) -> void:
	EventBus.build_mode_requested.emit(tower_type)


func _on_start_wave_pressed() -> void:
	EventBus.start_wave_button_pressed.emit()


func _on_pause_pressed() -> void:
	GameManager.pause_game()


func _on_tower_selected(info: Dictionary) -> void:
	_selected_cell = info.get("cell", Vector2i(-1, -1))
	var tower_type: String = String(info.get("tower_type", ""))
	var level: int = int(info.get("level", 1))
	var max_level: int = int(info.get("max_level", Constants.TOWER_MAX_LEVEL))
	var catalog_entry: Dictionary = Constants.TOWER_CATALOG.get(tower_type, {}) as Dictionary
	_selection_icon.texture = load("res://assets/sprites/towers/%s.png" % tower_type)
	var tower_name: String = tr(String(catalog_entry.get("name", tower_type)))
	var level_text: String = tr(&"LABEL_LEVEL") % [level, max_level]
	_selection_title.text = "%s — %s" % [tower_name, level_text]
	_selection_stats.text = (
		tr(&"LABEL_TOWER_STATS") % [float(info.get("damage", 0.0)), float(info.get("range", 0.0))]
	)

	var can_upgrade: bool = bool(info.get("can_upgrade", false))
	_selection_upgrade_button.disabled = not can_upgrade
	if can_upgrade:
		_selection_upgrade_button.text = tr(&"BTN_UPGRADE_COST") % int(info.get("upgrade_cost", 0))
	else:
		_selection_upgrade_button.text = tr(&"LABEL_MAX_LEVEL")
	_selection_sell_button.text = tr(&"BTN_SELL_COST") % int(info.get("sell_value", 0))
	_selection_panel.show()


func _on_tower_deselected() -> void:
	_selected_cell = Vector2i(-1, -1)
	_selection_panel.hide()


func _on_upgrade_pressed() -> void:
	EventBus.tower_upgrade_requested.emit(_selected_cell)


func _on_sell_pressed() -> void:
	EventBus.tower_sell_requested.emit(_selected_cell)


func _on_close_selection_pressed() -> void:
	EventBus.tower_deselected.emit()


func _on_action_feedback(message: String) -> void:
	_toast_label.text = message
	_toast_timer = TOAST_DURATION
	var start_position: Vector2 = _toast_rest_position - Vector2(0.0, TOAST_SLIDE_OFFSET)
	_play_toast_tween(0.0, 1.0, TOAST_FADE_IN, start_position, _toast_rest_position)
	_toast_label.show()


## Un solo helper para entrada/salida -- mata cualquier tween en vuelo antes de arrancar
## uno nuevo, para que dos toasts seguidos (ej. "Oro insuficiente" tapeado rápido) no
## dejen animaciones superpuestas peleando por la misma propiedad.
func _play_toast_tween(
	alpha_from: float, alpha_to: float, duration: float, pos_from: Vector2, pos_to: Vector2
) -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.modulate.a = alpha_from
	_toast_label.position = pos_from
	_toast_tween = create_tween()
	_toast_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_toast_tween.tween_property(_toast_label, ^"modulate:a", alpha_to, duration)
	_toast_tween.parallel().tween_property(_toast_label, ^"position", pos_to, duration)


func _on_ftue_button_pressed() -> void:
	_ftue_step += 1
	if _ftue_step >= FTUE_MESSAGE_KEYS.size():
		_ftue_panel.hide()
		SaveManager.set_tutorial_shown(true)
		return
	_ftue_label.text = tr(StringName(FTUE_MESSAGE_KEYS[_ftue_step]))
	if _ftue_step == FTUE_MESSAGE_KEYS.size() - 1:
		_ftue_button.text = "BTN_GOT_IT"
