extends CanvasLayer
## Pantalla de configuración: único ajuste soportado es sonido on/off. GDD no pide
## sensibilidad de swipe ni vibración para un tower defense de tap/drag-cámara, y el
## juego no implementa multi-idioma en esta versión (ver idea-base.md, sección FASE 0).
## Se abre llamando open() directo (MainMenu es el dueño de esta instancia) — no hay
## escena propia, "Cerrar" solo oculta el panel.

const ModalStyleGd := preload("res://src/shared/modal_style.gd")

var _panel: PanelContainer = PanelContainer.new()
var _sound_button: Button = Button.new()


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.hide()


func open() -> void:
	_refresh_sound_button()
	_panel.show()


func _build_ui() -> void:
	var panel_w: float = 260.0
	var panel_h: float = 190.0
	_panel.position = Vector2(
		(Constants.DESIGN_WIDTH - panel_w) * 0.5, (Constants.DESIGN_HEIGHT - panel_h) * 0.5
	)
	_panel.set_size(Vector2(panel_w, panel_h))
	_panel.add_theme_stylebox_override(&"panel", ModalStyleGd.opaque_panel())
	add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 12)
	_panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Configuracion"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 20)
	title.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	vbox.add_child(title)

	_sound_button.custom_minimum_size = Vector2(0.0, 44.0)
	_sound_button.pressed.connect(_on_sound_pressed)
	vbox.add_child(_sound_button)

	var close_button: Button = Button.new()
	close_button.text = "Cerrar"
	close_button.custom_minimum_size = Vector2(0.0, 44.0)
	close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(close_button)


func _refresh_sound_button() -> void:
	_sound_button.text = "Sonido: ON" if SaveManager.get_sound_enabled() else "Sonido: OFF"


func _on_sound_pressed() -> void:
	var new_value: bool = not SaveManager.get_sound_enabled()
	SaveManager.set_sound_enabled(new_value)
	EventBus.sound_setting_changed.emit(new_value)
	_refresh_sound_button()


func _on_close_pressed() -> void:
	_panel.hide()
