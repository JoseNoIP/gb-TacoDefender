extends GutTest
## Tests para SaveManager (autoload real, persiste en user://save.json). Los casos son
## deliberadamente roundtrip (guardan un valor, lo leen, restauran el original al final)
## — el archivo real persiste entre corridas de test en la misma máquina de desarrollo
## (regla CLAUDE.md #57); tools/run_tests.sh además respalda/restaura save.json como red
## de seguridad adicional.


func test_tutorial_shown_roundtrip() -> void:
	var original: bool = SaveManager.get_tutorial_shown()
	SaveManager.set_tutorial_shown(true)
	assert_true(SaveManager.get_tutorial_shown())
	SaveManager.set_tutorial_shown(false)
	assert_false(SaveManager.get_tutorial_shown())
	SaveManager.set_tutorial_shown(original)


func test_sound_enabled_roundtrip() -> void:
	var original: bool = SaveManager.get_sound_enabled()
	SaveManager.set_sound_enabled(false)
	assert_false(SaveManager.get_sound_enabled())
	SaveManager.set_sound_enabled(true)
	assert_true(SaveManager.get_sound_enabled())
	SaveManager.set_sound_enabled(original)


func test_language_roundtrip() -> void:
	var original: String = SaveManager.get_language()
	SaveManager.set_language("en")
	assert_eq(SaveManager.get_language(), "en")
	SaveManager.set_language("fr")
	assert_eq(SaveManager.get_language(), "fr")
	SaveManager.set_language(original)
