extends CanvasLayer
## Overlay de pausa: CONTINUAR / REINICIAR / MENU PRINCIPAL. Se muestra al recibir
## EventBus.game_paused y se oculta con game_resumed. "Continuar" llama
## GameManager.resume_game() directo (autoload global); reiniciar/menu emiten señales
## locales — Game.gd (dueño directo de esta instancia) decide a qué escena ir y fuerza
## get_tree().paused = false antes de cambiar de escena (regla CLAUDE.md #40).

signal restart_requested
signal main_menu_requested

const ModalStyleGd := preload("res://src/shared/modal_style.gd")
const IconStyleGd := preload("res://src/shared/icon_style.gd")
const ICON_SIZE: float = 56.0

var _panel: PanelContainer = PanelContainer.new()


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.hide()
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)


func _exit_tree() -> void:
	if EventBus.game_paused.is_connected(_on_game_paused):
		EventBus.game_paused.disconnect(_on_game_paused)
	if EventBus.game_resumed.is_connected(_on_game_resumed):
		EventBus.game_resumed.disconnect(_on_game_resumed)


func _build_ui() -> void:
	var panel_w: float = 280.0
	var panel_h: float = 300.0
	_panel.position = Vector2(
		(Constants.DESIGN_WIDTH - panel_w) * 0.5, (Constants.DESIGN_HEIGHT - panel_h) * 0.5
	)
	_panel.set_size(Vector2(panel_w, panel_h))
	_panel.add_theme_stylebox_override(&"panel", ModalStyleGd.opaque_panel())
	add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 12)
	_panel.add_child(vbox)

	var icon: TextureRect = IconStyleGd.make_icon("res://assets/sprites/ui/pause_icon.png")
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)

	var title: Label = Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 22)
	title.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	vbox.add_child(title)

	vbox.add_child(_make_button("Continuar", _on_resume_pressed))
	vbox.add_child(_make_button("Reiniciar", _on_restart_pressed))
	vbox.add_child(_make_button("Menu Principal", _on_menu_pressed))


func _make_button(text: String, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.pressed.connect(handler)
	return button


func _on_game_paused() -> void:
	_panel.show()


func _on_game_resumed() -> void:
	_panel.hide()


func _on_resume_pressed() -> void:
	GameManager.resume_game()


func _on_restart_pressed() -> void:
	GameManager.resume_game()
	restart_requested.emit()


func _on_menu_pressed() -> void:
	GameManager.resume_game()
	main_menu_requested.emit()
