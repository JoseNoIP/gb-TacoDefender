extends Node
## Carga traducciones de CSV en runtime (ver /mobile-i18n). Sin class_name — es autoload
## (regla CLAUDE.md #10), y DEBE cargar DESPUÉS de SaveManager en project.godot (regla
## CLAUDE.md #29) porque _ready() lee SaveManager.get_language().
##
## .txt, no .csv: Godot excluye archivos .csv del PCK exportado aunque el include_filter
## los liste explícitamente (bug conocido #38957, regla CLAUDE.md #30) — el contenido
## sigue siendo CSV válido, solo cambia la extensión.

const CSV_PATH: String = "res://assets/translations/translations.txt"


func _ready() -> void:
	_load_csv()
	var lang: String = SaveManager.get_language()
	if lang.is_empty() or not lang in Constants.SUPPORTED_LOCALES:
		lang = Constants.DEFAULT_LOCALE
	TranslationServer.set_locale(lang)


## false si lang no está soportado -- no cambia nada ni persiste, para que el llamador
## (SettingsScreen/LanguageSelectScreen) sepa que el tap no tuvo efecto.
func set_language(lang: String) -> bool:
	if not lang in Constants.SUPPORTED_LOCALES:
		return false
	SaveManager.set_language(lang)
	TranslationServer.set_locale(lang)
	EventBus.language_changed.emit(lang)
	return true


func get_current_language() -> String:
	return TranslationServer.get_locale()


func is_language_selected() -> bool:
	return not SaveManager.get_language().is_empty()


## Saltos de línea en CSV rompen el parser de línea de FileAccess.get_csv_line() -- el
## archivo usa "[BR]" como placeholder, reemplazado acá por el "\n" real (regla CLAUDE.md #28).
func _load_csv() -> void:
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return
	var header: PackedStringArray = file.get_csv_line()
	var locale_cols: Array = []
	var translations: Array = []
	for i in range(1, header.size()):
		var locale: String = header[i].strip_edges()
		locale_cols.append(locale)
		var t: Translation = Translation.new()
		t.locale = locale
		translations.append(t)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 2 or row[0].is_empty():
			continue
		var key: String = row[0].strip_edges()
		for i in locale_cols.size():
			if i + 1 >= row.size():
				continue
			var value: String = row[i + 1].replace("[BR]", "\n")
			(translations[i] as Translation).add_message(key, value)
	for t: Translation in translations:
		TranslationServer.add_translation(t)
	file.close()
