extends Node2D
## Escena raíz de gameplay (GDD completo). Construcción 100% programática — sin sprites de
## fondo todavía (ver /gen-ai-art); fondo es un ColorRect con Constants.COLOR_BG_BOARD.
## Instancia todos los sistemas y pantallas de overlay, wirea el camino del Board hacia
## EnemySpawner (configuración de arranque, no un evento continuo — ver nota de
## arquitectura en EventBus.gd) y conecta la navegación de escena que las pantallas piden
## por señal local.

const BoardGd := preload("res://src/features/board/Board.gd")
const EnemySpawnerGd := preload("res://src/features/enemies/EnemySpawner.gd")
const HudGd := preload("res://src/features/ui/HUD.gd")
const PauseScreenGd := preload("res://src/features/ui/PauseScreen.gd")
const GameOverScreenGd := preload("res://src/features/ui/GameOverScreen.gd")
const VictoryScreenGd := preload("res://src/features/ui/VictoryScreen.gd")

const MAIN_MENU_SCENE: String = "res://src/scenes/MainMenu.tscn"
const GAME_SCENE: String = "res://src/scenes/Game.tscn"


func _ready() -> void:
	_build_scene()
	GameManager.start_game()
	EventBus.game_over.connect(_on_game_session_ended)
	EventBus.game_won.connect(_on_game_session_ended)


func _exit_tree() -> void:
	if EventBus.game_over.is_connected(_on_game_session_ended):
		EventBus.game_over.disconnect(_on_game_session_ended)
	if EventBus.game_won.is_connected(_on_game_session_ended):
		EventBus.game_won.disconnect(_on_game_session_ended)


func _build_scene() -> void:
	## Sin CanvasLayer: cualquier nodo dentro de un CanvasLayer se dibuja SIEMPRE por
	## encima de los Node2D normales (Board, enemigos, torres, proyectiles), sin importar
	## su valor de `layer` — un ColorRect de fondo ahí adentro taparía todo el juego
	## (regla CLAUDE.md #43). Se agrega primero para quedar detrás por orden de árbol.
	var bg: ColorRect = ColorRect.new()
	bg.color = Constants.COLOR_BG_BOARD
	bg.position = Vector2.ZERO
	bg.set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var board: Node2D = BoardGd.new()
	add_child(board)

	var enemy_spawner: Node = EnemySpawnerGd.new()
	add_child(enemy_spawner)
	## Wireo de arranque (composition root): Board ya calculó sus waypoints en su propio
	## _ready() (ya corrió, por el add_child de arriba), así que el dato es válido de
	## inmediato. Esto NO es comunicación continua entre features (eso va por EventBus) —
	## es configuración de una sola vez al construir la escena.
	enemy_spawner.call(
		&"configure_path", board.call(&"get_path_world_points"), board.call(&"get_path_length")
	)

	add_child(HudGd.new())

	var pause_screen: CanvasLayer = PauseScreenGd.new()
	add_child(pause_screen)
	pause_screen.connect(&"restart_requested", _on_restart_requested)
	pause_screen.connect(&"main_menu_requested", _on_main_menu_requested)

	var game_over_screen: CanvasLayer = GameOverScreenGd.new()
	add_child(game_over_screen)
	game_over_screen.connect(&"restart_requested", _on_restart_requested)
	game_over_screen.connect(&"main_menu_requested", _on_main_menu_requested)

	var victory_screen: CanvasLayer = VictoryScreenGd.new()
	add_child(victory_screen)
	victory_screen.connect(&"restart_requested", _on_restart_requested)
	victory_screen.connect(&"main_menu_requested", _on_main_menu_requested)


## Cualquier desenlace (derrota o victoria) cuenta como "una partida jugada".
func _on_game_session_ended() -> void:
	MetaManager.increment_games_played()


func _on_restart_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(GAME_SCENE)


func _on_main_menu_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		GameManager.pause_game()
