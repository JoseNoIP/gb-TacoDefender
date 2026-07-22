extends GutTest
## Tests para grid_math.gd — conversiones grilla/mundo y expansión del camino fijo (GDD
## sección 4, Constants.PATH_TURN_CELLS).

const GridMathGd := preload("res://src/features/board/grid_math.gd")


func test_world_to_cell_origin() -> void:
	assert_eq(GridMathGd.world_to_cell(Vector2(0.0, 0.0)), Vector2i(0, 0))


func test_world_to_cell_middle_of_first_cell() -> void:
	var half_tile: float = Constants.TILE_SIZE * 0.5
	assert_eq(GridMathGd.world_to_cell(Vector2(half_tile, half_tile)), Vector2i(0, 0))


func test_world_to_cell_second_column() -> void:
	var x: float = Constants.TILE_SIZE + 5.0
	assert_eq(GridMathGd.world_to_cell(Vector2(x, 5.0)), Vector2i(1, 0))


func test_cell_to_local_center_is_middle_of_tile() -> void:
	var center: Vector2 = GridMathGd.cell_to_local_center(Vector2i(2, 3))
	var expected: Vector2 = Vector2(2.5 * Constants.TILE_SIZE, 3.5 * Constants.TILE_SIZE)
	assert_almost_eq(center.x, expected.x, 0.01)
	assert_almost_eq(center.y, expected.y, 0.01)


func test_cell_to_local_center_round_trips_with_world_to_cell() -> void:
	for col in range(Constants.GRID_COLS):
		for row in range(Constants.GRID_ROWS):
			var cell: Vector2i = Vector2i(col, row)
			var center: Vector2 = GridMathGd.cell_to_local_center(cell)
			var msg: String = "el centro de una celda debe mapear de vuelta a esa celda"
			assert_eq(GridMathGd.world_to_cell(center), cell, msg)


func test_is_in_bounds_accepts_corners() -> void:
	assert_true(GridMathGd.is_in_bounds(Vector2i(0, 0)))
	assert_true(GridMathGd.is_in_bounds(Vector2i(Constants.GRID_COLS - 1, Constants.GRID_ROWS - 1)))


func test_is_in_bounds_rejects_out_of_range() -> void:
	assert_false(GridMathGd.is_in_bounds(Vector2i(-1, 0)), "columna negativa es inválida")
	var col_cell: Vector2i = Vector2i(Constants.GRID_COLS, 0)
	assert_false(GridMathGd.is_in_bounds(col_cell), "col == GRID_COLS ya es inválida")
	var row_cell: Vector2i = Vector2i(0, Constants.GRID_ROWS)
	assert_false(GridMathGd.is_in_bounds(row_cell), "row == GRID_ROWS ya es inválida")


func test_compute_path_cells_includes_every_turn_point() -> void:
	var path_cells: Dictionary = GridMathGd.compute_path_cells(Constants.PATH_TURN_CELLS)
	for cell: Vector2i in Constants.PATH_TURN_CELLS:
		assert_true(
			path_cells.has(cell), "cada punto de giro debe estar en el set de celdas de camino"
		)


## Si el algoritmo de expansión "saltara" una celda (ej. un bug de signo en el paso),
## esa celda quedaría aislada — sin ningún vecino ortogonal también en el camino.
func test_compute_path_cells_has_no_isolated_cells() -> void:
	var path_cells: Dictionary = GridMathGd.compute_path_cells(Constants.PATH_TURN_CELLS)
	for cell: Vector2i in path_cells.keys():
		var neighbors: Array = [
			Vector2i(cell.x + 1, cell.y),
			Vector2i(cell.x - 1, cell.y),
			Vector2i(cell.x, cell.y + 1),
			Vector2i(cell.x, cell.y - 1),
		]
		var has_neighbor: bool = false
		for neighbor: Vector2i in neighbors:
			if path_cells.has(neighbor):
				has_neighbor = true
				break
		assert_true(has_neighbor, "celda de camino aislada: %s" % str(cell))


func test_compute_path_world_points_matches_turn_cell_count() -> void:
	var points: Array = GridMathGd.compute_path_world_points(Constants.PATH_TURN_CELLS)
	assert_eq(points.size(), Constants.PATH_TURN_CELLS.size())


func test_compute_path_length_is_positive() -> void:
	var points: Array = GridMathGd.compute_path_world_points(Constants.PATH_TURN_CELLS)
	assert_gt(GridMathGd.compute_path_length(points), 0.0)


func test_compute_camera_bounds_collapses_when_board_fits_on_screen() -> void:
	var bounds: Vector2 = GridMathGd.compute_camera_bounds(100.0, 844.0, 90.0, 150.0)
	var msg: String = "si el tablero entero cabe, min y max deben coincidir"
	assert_almost_eq(bounds.x, bounds.y, 0.01, msg)


func test_compute_camera_bounds_gives_real_pan_range_for_this_board() -> void:
	var bounds: Vector2 = GridMathGd.compute_camera_bounds(
		Constants.BOARD_HEIGHT,
		Constants.DESIGN_HEIGHT,
		Constants.HUD_TOP_HEIGHT,
		Constants.BOTTOM_BAR_HEIGHT
	)
	var msg: String = "el tablero real (14 filas) no entra en pantalla — debe poder panearse"
	assert_gt(bounds.y, bounds.x, msg)
