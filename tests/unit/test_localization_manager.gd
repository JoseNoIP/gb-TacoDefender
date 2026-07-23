extends GutTest
## Tests para LocalizationManager (autoload real, CSV real en
## assets/translations/translations.txt). Roundtrip: guarda idioma/locale original,
## restaura al final (mismo patrón que test_save_manager.gd, regla CLAUDE.md #57) --
## set_language() escribe de verdad en el user://save.json real del desarrollador.


func test_set_language_valid_locale_updates_translation_server() -> void:
	var original_locale: String = LocalizationManager.get_current_language()
	var original_saved: String = SaveManager.get_language()

	assert_true(LocalizationManager.set_language("en"))
	assert_eq(LocalizationManager.get_current_language(), "en")
	assert_eq(SaveManager.get_language(), "en")

	LocalizationManager.set_language(original_locale)
	SaveManager.set_language(original_saved)


func test_set_language_invalid_locale_returns_false_and_changes_nothing() -> void:
	var original_locale: String = LocalizationManager.get_current_language()
	var original_saved: String = SaveManager.get_language()

	assert_false(LocalizationManager.set_language("xx_invalid"))
	assert_eq(LocalizationManager.get_current_language(), original_locale)
	assert_eq(SaveManager.get_language(), original_saved)


func test_set_language_emits_language_changed() -> void:
	var original_locale: String = LocalizationManager.get_current_language()
	var original_saved: String = SaveManager.get_language()

	watch_signals(EventBus)
	LocalizationManager.set_language("pt_BR")
	assert_signal_emitted(EventBus, "language_changed")

	LocalizationManager.set_language(original_locale)
	SaveManager.set_language(original_saved)


func test_is_language_selected_reflects_save_manager() -> void:
	var original_saved: String = SaveManager.get_language()

	SaveManager.set_language("")
	assert_false(LocalizationManager.is_language_selected())
	SaveManager.set_language("es")
	assert_true(LocalizationManager.is_language_selected())

	SaveManager.set_language(original_saved)


## _ready() del autoload ya corrió una sola vez al bootear el proceso (regla de autoloads
## en Godot) y cargó el CSV real -- alcanza con inspeccionar los Translation ya
## registrados en TranslationServer, sin llamar set_locale() (evita tocar el idioma
## activo global desde un test que no lo necesita).
func test_csv_loaded_translations_for_all_supported_locales() -> void:
	for locale: String in Constants.SUPPORTED_LOCALES:
		var translation: Translation = TranslationServer.get_translation_object(locale)
		assert_not_null(translation, "falta Translation para locale %s" % locale)
		if translation == null:
			continue
		var message: String = String(translation.get_message(&"BTN_PLAY"))
		assert_false(message.is_empty(), "BTN_PLAY vacío para locale %s" % locale)
