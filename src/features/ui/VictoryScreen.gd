extends CanvasLayer
## Overlay de victoria: se muestra al recibir EventBus.game_won (oleada 10 superada, GDD
## sección 2). Muestra propinas totales acumuladas y botones para jugar de nuevo o volver
## al menú. Game.gd decide a qué escena ir.

signal restart_requested
signal main_menu_requested

const ModalStyleGd := preload("res://src/shared/modal_style.gd")
const IconStyleGd := preload("res://src/shared/icon_style.gd")
const ButtonSoundGd := preload("res://src/shared/button_sound.gd")
const ICON_SIZE: float = 64.0

var _panel: PanelContainer = PanelContainer.new()
var _stats_label: Label = Label.new()


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.hide()
	EventBus.game_won.connect(_on_game_won)


func _exit_tree() -> void:
	if EventBus.game_won.is_connected(_on_game_won):
		EventBus.game_won.disconnect(_on_game_won)


func _build_ui() -> void:
	var panel_w: float = 280.0
	var panel_h: float = 320.0
	_panel.position = Vector2(
		(Constants.DESIGN_WIDTH - panel_w) * 0.5, (Constants.DESIGN_HEIGHT - panel_h) * 0.5
	)
	_panel.set_size(Vector2(panel_w, panel_h))
	_panel.add_theme_stylebox_override(&"panel", ModalStyleGd.opaque_panel())
	add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 12)
	_panel.add_child(vbox)

	var icon: TextureRect = IconStyleGd.make_icon("res://assets/sprites/ui/star.png")
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)

	var title: Label = Label.new()
	title.text = "TITLE_VICTORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 20)
	title.add_theme_color_override(&"font_color", Constants.COLOR_TIPS)
	vbox.add_child(title)

	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	_stats_label.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	vbox.add_child(_stats_label)

	vbox.add_child(_make_button("BTN_PLAY_AGAIN", _on_restart_pressed))
	vbox.add_child(_make_button("BTN_MAIN_MENU", _on_menu_pressed))


func _make_button(text: String, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.pressed.connect(handler)
	ButtonSoundGd.attach(button)
	return button


func _on_game_won() -> void:
	_stats_label.text = (
		tr(&"LABEL_VICTORY_STATS") % [Constants.TOTAL_WAVES, MetaManager.get_tips()]
	)
	_panel.show()


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_menu_pressed() -> void:
	main_menu_requested.emit()
