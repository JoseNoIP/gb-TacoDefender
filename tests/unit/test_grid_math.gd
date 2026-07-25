extends GutTest
## Tests para grid_math.gd — conversiones grilla/mundo y expansión de los 10 templates de
## camino (GDD sección 4, Constants.PATH_TEMPLATES, uno por nivel — ver idea-base.md).

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
	for template: Array in Constants.PATH_TEMPLATES:
		var path_cells: Dictionary = GridMathGd.compute_path_cells(template)
		for cell: Vector2i in template:
			assert_true(
				path_cells.has(cell), "cada punto de giro debe estar en el set de celdas de camino"
			)


## Si el algoritmo de expansión "saltara" una celda (ej. un bug de signo en el paso),
## esa celda quedaría aislada — sin ningún vecino ortogonal también en el camino. Se valida
## en LOS 10 templates -- cada uno se diseñó a mano (tools/gen_board_tiles.py no valida
## esto), así que un error de tipeo en un Vector2i de cualquiera de los 10 debe fallar acá.
func test_compute_path_cells_has_no_isolated_cells() -> void:
	for template: Array in Constants.PATH_TEMPLATES:
		var path_cells: Dictionary = GridMathGd.compute_path_cells(template)
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


## Todo tramo de cada template debe ser puramente horizontal o vertical (nunca diagonal,
## nunca de largo cero) Y la fila nunca debe retroceder -- un enemigo que caminara "hacia
## arriba" en pantalla confundiría al jugador (ver nota en Constants.PATH_TEMPLATES).
func test_all_templates_are_axis_aligned_and_move_forward() -> void:
	for template: Array in Constants.PATH_TEMPLATES:
		for i in range(template.size() - 1):
			var from_cell: Vector2i = template[i]
			var to_cell: Vector2i = template[i + 1]
			var same_col: bool = from_cell.x == to_cell.x
			var same_row: bool = from_cell.y == to_cell.y
			assert_true(
				same_col != same_row,
				"tramo diagonal o de largo cero: %s -> %s" % [from_cell, to_cell]
			)
			assert_true(
				to_cell.y >= from_cell.y, "la fila retrocede: %s -> %s" % [from_cell, to_cell]
			)


func test_all_templates_start_at_row_zero_and_end_at_last_row() -> void:
	for template: Array in Constants.PATH_TEMPLATES:
		assert_eq((template[0] as Vector2i).y, 0, "todo template debe empezar en la fila 0")
		assert_eq(
			(template[-1] as Vector2i).y,
			Constants.GRID_ROWS - 1,
			"todo template debe terminar en la última fila (la base)"
		)


func test_at_least_ten_path_templates_exist() -> void:
	assert_gte(Constants.PATH_TEMPLATES.size(), 10)
	assert_eq(
		Constants.BOARD_PATH_TEXTURES.size(),
		Constants.PATH_TEMPLATES.size(),
		"debe haber una textura de camino por template"
	)
	assert_eq(
		Constants.BOARD_GROUND_TEXTURES.size(),
		Constants.PATH_TEMPLATES.size(),
		"debe haber una textura de suelo por template"
	)


func test_compute_path_world_points_matches_turn_cell_count() -> void:
	var points: Array = GridMathGd.compute_path_world_points(Constants.PATH_TEMPLATES[0])
	assert_eq(points.size(), Constants.PATH_TEMPLATES[0].size())


func test_compute_path_length_is_positive() -> void:
	for template: Array in Constants.PATH_TEMPLATES:
		var points: Array = GridMathGd.compute_path_world_points(template)
		assert_gt(GridMathGd.compute_path_length(points), 0.0)


func test_select_path_template_index_wraps_around_with_modulo() -> void:
	assert_eq(GridMathGd.select_path_template_index(0, 10), 0)
	assert_eq(GridMathGd.select_path_template_index(3, 10), 3)
	assert_eq(GridMathGd.select_path_template_index(10, 10), 0, "victoria 10 vuelve al template 0")
	assert_eq(GridMathGd.select_path_template_index(23, 10), 3, "cicla indefinidamente")


func test_select_path_template_index_defends_against_empty_template_list() -> void:
	assert_eq(GridMathGd.select_path_template_index(5, 0), 0)


func test_compute_camera_bounds_collapses_when_board_fits_on_screen() -> void:
	var bounds: Vector2 = GridMathGd.compute_camera_bounds(100.0, 844.0, 90.0, 150.0)
	var msg: String = "si el tablero entero cabe, min y max deben coincidir"
	assert_almost_eq(bounds.x, bounds.y, 0.01, msg)


func test_compute_camera_bounds_collapses_for_this_board() -> void:
	var bounds: Vector2 = GridMathGd.compute_camera_bounds(
		Constants.BOARD_HEIGHT,
		Constants.DESIGN_HEIGHT,
		Constants.HUD_TOP_HEIGHT,
		Constants.BOTTOM_BAR_HEIGHT
	)
	var msg: String = "el tablero real (10 filas) ya entra en pantalla — no debe hacer falta pan"
	assert_almost_eq(bounds.x, bounds.y, 0.01, msg)
