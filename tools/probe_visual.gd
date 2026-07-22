extends Node2D
## Probe visual NO headless (regla CLAUDE.md #49): get_viewport().get_texture().get_image()
## devuelve null bajo --headless (RenderingServer "dummy") — este script se corre con
## `godot --path . tools/probe_visual.tscn` (ventana real, sin --headless) para capturar
## PNGs reales del juego y detectar bugs visuales que ningún test headless puede atrapar
## (ej. reglas #43 CanvasLayer tapando el juego, #50 Container ignorando position, #54
## auto-escalado que solo chequea un eje). Dev-only — no se referencia desde ningún
## autoload/escena real del juego.
##
## Instancia las escenas como HIJAS de este mismo nodo en vez de usar
## get_tree().change_scene_to_file(): como Godot carga este .tscn directo por línea de
## comandos, ESTE nodo es el current_scene — change_scene_to_file() lo liberaría a mitad
## de su propia corutina _ready() (que sigue con awaits pendientes), dejando el proceso
## colgado para siempre sin ningún error. Instanciar como hijo evita el problema por
## completo.

## user:// (no una ruta de sesión hardcodeada) para que esto sea reusable en cualquier
## corrida futura, no solo en la máquina/sesión donde se escribió — se resuelve a la
## misma carpeta de datos de usuario que save.json/meta.json (ver OS.get_user_data_dir()).
const OUTPUT_SUBDIR: String = "probe_screenshots"
const MainMenuGd := preload("res://src/scenes/MainMenu.gd")
const GameGd := preload("res://src/scenes/Game.gd")
const BoardGd := preload("res://src/features/board/Board.gd")

var _current: Node = null


func _ready() -> void:
	var output_dir: String = OS.get_user_data_dir() + "/" + OUTPUT_SUBDIR
	DirAccess.make_dir_recursive_absolute(output_dir)
	print("PROBE_OUTPUT_DIR: " + output_dir)

	await _capture_main_menu(output_dir)
	await _capture_game_initial(output_dir)
	await _capture_game_with_towers_and_wave(output_dir)
	print("PROBE_DONE")
	get_tree().quit()


func _swap_to(instance: Node) -> void:
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
	_current = instance
	add_child(instance)


func _capture_main_menu(output_dir: String) -> void:
	_swap_to(MainMenuGd.new())
	await get_tree().create_timer(0.3, true).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture(output_dir, "probe_main_menu.png")


func _capture_game_initial(output_dir: String) -> void:
	_swap_to(GameGd.new())
	await get_tree().create_timer(0.3, true).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture(output_dir, "probe_game_initial.png")


func _capture_game_with_towers_and_wave(output_dir: String) -> void:
	var board: Node2D = _find_board()
	if board != null:
		board.try_place_tower(Constants.TOWER_TYPE_SALSA_VERDE, Vector2i(1, 1))
		board.try_place_tower(Constants.TOWER_TYPE_HIELO_HORCHATA, Vector2i(4, 1))
		board.try_place_tower(Constants.TOWER_TYPE_CATAPULTA_GUAC, Vector2i(2, 3))
	else:
		print("PROBE_WARN: no se encontró Board.")
	EventBus.start_wave_button_pressed.emit()
	await get_tree().create_timer(1.5, true).timeout
	await _capture(output_dir, "probe_game_with_towers.png")


func _find_board() -> Node2D:
	if _current == null:
		return null
	for child in _current.get_children():
		if child is Node2D and child.get_script() == BoardGd:
			return child
	return null


func _capture(output_dir: String, filename: String) -> void:
	await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		print("PROBE_ERROR: imagen nula para %s (¿corriste con --headless por error?)" % filename)
		return
	image.save_png(output_dir + "/" + filename)
	print("PROBE_SAVED: " + filename)
