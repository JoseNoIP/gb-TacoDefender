extends CanvasLayer
## Pantalla de configuración: sonido on/off + idioma (ver /mobile-i18n). GDD no pide
## sensibilidad de swipe ni vibración para un tower defense de tap/drag-cámara.
## Se abre llamando open() directo (MainMenu es el dueño de esta instancia) — no hay
## escena propia, "Cerrar" solo oculta el panel.
##
## Única pantalla donde el idioma puede cambiar MIENTRAS ella misma sigue viva (el
## selector de idioma está adentro) -- por eso _sound_button/_lang_button se refrescan
## explícitamente en _on_language_pressed() además del título/botón "Cerrar", que usan la
## KEY cruda y se retraducen solos vía Control.auto_translate_mode.

const ModalStyleGd := preload("res://src/shared/modal_style.gd")
const ButtonSoundGd := preload("res://src/shared/button_sound.gd")

## locale -> nombre nativo (nunca tr() -- un jugador que no lee el idioma activo debe
## poder reconocer el suyo igual, mismo criterio que LanguageSelectScreen).
const LANGUAGE_NAMES: Dictionary = {
	"es": "Español",
	"en": "English",
	"pt_BR": "Português",
	"fr": "Français",
}

var _panel: PanelContainer = PanelContainer.new()
var _sound_button: Button = Button.new()
var _lang_button: Button = Button.new()


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.hide()


func open() -> void:
	_refresh_sound_button()
	_refresh_lang_button()
	_panel.show()


func _build_ui() -> void:
	var panel_w: float = 260.0
	var panel_h: float = 250.0
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
	title.text = "TITLE_SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 20)
	title.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	vbox.add_child(title)

	_sound_button.custom_minimum_size = Vector2(0.0, 44.0)
	_sound_button.pressed.connect(_on_sound_pressed)
	ButtonSoundGd.attach(_sound_button)
	vbox.add_child(_sound_button)

	_lang_button.custom_minimum_size = Vector2(0.0, 44.0)
	_lang_button.pressed.connect(_on_lang_pressed)
	ButtonSoundGd.attach(_lang_button)
	vbox.add_child(_lang_button)

	var close_button: Button = Button.new()
	close_button.text = "BTN_CLOSE"
	close_button.custom_minimum_size = Vector2(0.0, 44.0)
	close_button.pressed.connect(_on_close_pressed)
	ButtonSoundGd.attach(close_button)
	vbox.add_child(close_button)


func _refresh_sound_button() -> void:
	_sound_button.text = (
		tr(&"SETTINGS_SOUND_ON") if SaveManager.get_sound_enabled() else tr(&"SETTINGS_SOUND_OFF")
	)


func _refresh_lang_button() -> void:
	var current: String = LocalizationManager.get_current_language()
	var name: String = String(LANGUAGE_NAMES.get(current, current))
	_lang_button.text = "%s: %s" % [tr(&"SETTINGS_LANGUAGE"), name]


func _on_sound_pressed() -> void:
	var new_value: bool = not SaveManager.get_sound_enabled()
	SaveManager.set_sound_enabled(new_value)
	EventBus.sound_setting_changed.emit(new_value)
	_refresh_sound_button()


func _on_lang_pressed() -> void:
	var locales: Array = Constants.SUPPORTED_LOCALES
	var current_index: int = locales.find(LocalizationManager.get_current_language())
	var next_index: int = (current_index + 1) % locales.size()
	LocalizationManager.set_language(String(locales[next_index]))
	_refresh_sound_button()
	_refresh_lang_button()


func _on_close_pressed() -> void:
	_panel.hide()
