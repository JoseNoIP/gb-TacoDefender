extends Control
## Pantalla de selección de idioma en el primer arranque (ver /mobile-i18n). MainMenu.gd
## enruta acá si SaveManager.get_language() está vacío; nunca se vuelve a mostrar
## automáticamente después (el jugador cambia de idioma desde SettingsScreen).
##
## Los botones muestran el nombre de cada idioma en SU PROPIO idioma (nunca traducidos) a
## propósito: un jugador que no lee el idioma actualmente activo igual debe poder
## reconocer el suyo en la lista.

const MAIN_MENU_SCENE: String = "res://src/scenes/MainMenu.tscn"
const BackgroundStyleGd := preload("res://src/shared/background_style.gd")
const ButtonSoundGd := preload("res://src/shared/button_sound.gd")
const MENU_BG: String = "res://assets/sprites/backgrounds/menu_bg.png"

## locale -> nombre nativo (nunca tr() -- ver nota de arriba).
const LANGUAGE_NAMES: Dictionary = {
	"es": "Español",
	"en": "English",
	"pt_BR": "Português",
	"fr": "Français",
}


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	position = Vector2.ZERO
	set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))

	BackgroundStyleGd.add_background(self, MENU_BG)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 16)
	vbox.position = Vector2((Constants.DESIGN_WIDTH - 240.0) * 0.5, 340.0)
	vbox.set_size(Vector2(240.0, 260.0))
	add_child(vbox)

	for locale: String in Constants.SUPPORTED_LOCALES:
		var button: Button = Button.new()
		button.text = String(LANGUAGE_NAMES.get(locale, locale))
		button.custom_minimum_size = Vector2(0.0, 52.0)
		button.pressed.connect(_on_language_pressed.bind(locale))
		ButtonSoundGd.attach(button)
		vbox.add_child(button)


func _on_language_pressed(locale: String) -> void:
	LocalizationManager.set_language(locale)
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)
