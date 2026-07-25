extends GutTest
## Tests para Board (celdas construibles, colocación/venta/mejora de torres — GDD
## secciones 2 y 3). El oro de GameManager es estado de sesión (no persiste a disco), así
## que no necesita restaurarse entre tests — basta con start_game() en before_each().
##
## Board elige uno de Constants.PATH_TEMPLATES según MetaManager.get_victories() (progreso
## REAL del jugador, ver Board._ready()) -- ningún test de acá puede asumir que está activo
## el template 0 en particular (regla CLAUDE.md #57, mismo espíritu de nunca depender de
## estado real de progreso). Por eso "una celda de camino"/"una celda construible" se
## derivan de _board.get_path_cells() en tiempo de ejecución, sea cual sea el template
## activo, en vez de hardcodear coordenadas que solo son válidas para el template 0.

const BoardGd := preload("res://src/features/board/Board.gd")

var _board: Node2D = null


func before_each() -> void:
	GameManager.start_game()
	_board = BoardGd.new()
	add_child_autofree(_board)


## Primera celda fuera del camino real del template ACTIVO -- nunca (1,1) hardcodeado,
## que solo era construible para el template 0 (ver comentario de arriba).
func _first_buildable_cell() -> Vector2i:
	for row in range(Constants.GRID_ROWS):
		for col in range(Constants.GRID_COLS):
			var cell: Vector2i = Vector2i(col, row)
			if _board.is_buildable(cell):
				return cell
	return Vector2i(-1, -1)


func test_path_cells_are_not_buildable() -> void:
	for cell: Vector2i in _board.get_path_cells().keys():
		var msg: String = "una celda de camino nunca debe ser construible: %s" % str(cell)
		assert_false(_board.is_buildable(cell), msg)


func test_off_path_cell_is_buildable() -> void:
	var cell: Vector2i = _first_buildable_cell()
	assert_true(_board.is_buildable(cell))


func test_out_of_bounds_cell_is_not_buildable() -> void:
	assert_false(_board.is_buildable(Vector2i(-1, 0)))
	assert_false(_board.is_buildable(Vector2i(Constants.GRID_COLS, 0)))


func test_place_tower_on_buildable_cell_succeeds_and_spends_gold() -> void:
	var cell: Vector2i = _first_buildable_cell()
	var gold_before: int = GameManager.get_gold()
	var success: bool = _board.try_place_tower(Constants.TOWER_TYPE_SALSA_VERDE, cell)
	assert_true(success)
	assert_eq(GameManager.get_gold(), gold_before - Constants.TOWER_SALSA_VERDE_COST)
	assert_not_null(_board.get_tower_at(cell))


func test_place_tower_on_path_cell_fails() -> void:
	var path_cell: Vector2i = _board.get_path_cells().keys()[0]
	var gold_before: int = GameManager.get_gold()
	assert_false(_board.try_place_tower(Constants.TOWER_TYPE_SALSA_VERDE, path_cell))
	assert_eq(GameManager.get_gold(), gold_before, "un intento fallido no debe descontar oro")


func test_place_tower_without_enough_gold_fails() -> void:
	var cell: Vector2i = _first_buildable_cell()
	GameManager.spend_gold(GameManager.get_gold())  ## vacía el oro de la partida.
	assert_false(_board.try_place_tower(Constants.TOWER_TYPE_SALSA_VERDE, cell))
	assert_null(_board.get_tower_at(cell))


func test_cell_is_not_buildable_after_placing_a_tower() -> void:
	var cell: Vector2i = _first_buildable_cell()
	_board.try_place_tower(Constants.TOWER_TYPE_SALSA_VERDE, cell)
	assert_false(_board.is_buildable(cell))


func test_sell_tower_refunds_seventy_percent_and_frees_cell() -> void:
	var cell: Vector2i = _first_buildable_cell()
	_board.try_place_tower(Constants.TOWER_TYPE_SALSA_VERDE, cell)
	var gold_before: int = GameManager.get_gold()
	var invested: float = float(Constants.TOWER_SALSA_VERDE_COST)
	var expected_refund: int = int(round(invested * Constants.TOWER_SELL_RATIO))
	assert_true(_board.sell_tower_at(cell))
	assert_eq(GameManager.get_gold(), gold_before + expected_refund)
	assert_true(_board.is_buildable(cell))


func test_sell_tower_on_empty_cell_fails() -> void:
	assert_false(_board.sell_tower_at(Vector2i(3, 3)))


func test_upgrade_tower_at_increases_level() -> void:
	var cell: Vector2i = _first_buildable_cell()
	GameManager.add_gold(10000)
	_board.try_place_tower(Constants.TOWER_TYPE_SALSA_VERDE, cell)
	assert_true(_board.upgrade_tower_at(cell))
	var tower: Node2D = _board.get_tower_at(cell)
	assert_eq(int(tower.call(&"get_level")), 2)


func test_upgrade_tower_at_empty_cell_fails() -> void:
	assert_false(_board.upgrade_tower_at(Vector2i(3, 3)))


func test_build_mode_requested_then_tap_equivalent_places_tower() -> void:
	## Simula el flujo real: HUD pide modo construcción por EventBus, Board coloca en la
	## siguiente celda válida — acá se ejercita try_place_tower directo (la traducción de
	## tap->celda ya está cubierta por los tests de grid_math).
	var cell: Vector2i = _first_buildable_cell()
	EventBus.build_mode_requested.emit(Constants.TOWER_TYPE_HIELO_HORCHATA)
	assert_true(_board.try_place_tower(Constants.TOWER_TYPE_HIELO_HORCHATA, cell))
