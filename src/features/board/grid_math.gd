extends RefCounted
## Lógica pura de grilla/camino/cámara — sin estado, sin nodo, testeable sin escena
## (mismo estilo que grid_math.gd/wave_scaling.gd de otros proyectos GuacamoleBit).
## Board.gd es el dueño del estado (Dictionary de torres, Camera2D real); este módulo
## solo sabe convertir coordenadas y expandir el camino del GDD (sección 4) a datos útiles.


static func world_to_cell(local_position: Vector2) -> Vector2i:
	var col: int = int(floor(local_position.x / Constants.TILE_SIZE))
	var row: int = int(floor(local_position.y / Constants.TILE_SIZE))
	return Vector2i(col, row)


static func cell_to_local_center(cell: Vector2i) -> Vector2:
	var x: float = (float(cell.x) + 0.5) * Constants.TILE_SIZE
	var y: float = (float(cell.y) + 0.5) * Constants.TILE_SIZE
	return Vector2(x, y)


static func is_in_bounds(cell: Vector2i) -> bool:
	var col_ok: bool = cell.x >= 0 and cell.x < Constants.GRID_COLS
	var row_ok: bool = cell.y >= 0 and cell.y < Constants.GRID_ROWS
	return col_ok and row_ok


## Expande los puntos de giro (Constants.PATH_TURN_CELLS) a TODAS las celdas que el
## camino ocupa — cada tramo entre dos puntos consecutivos es horizontal o vertical
## (nunca diagonal), así que basta caminar de a un paso de grilla por vez. Devuelve un
## Dictionary usado como set (celda -> true) para lookup O(1).
static func compute_path_cells(turn_points: Array) -> Dictionary:
	var cells: Dictionary = {}
	if turn_points.is_empty():
		return cells
	cells[turn_points[0]] = true
	for i in range(turn_points.size() - 1):
		var from_cell: Vector2i = turn_points[i]
		var to_cell: Vector2i = turn_points[i + 1]
		var step_x: int = signi(to_cell.x - from_cell.x)
		var step_y: int = signi(to_cell.y - from_cell.y)
		var current: Vector2i = from_cell
		while current != to_cell:
			current = Vector2i(current.x + step_x, current.y + step_y)
			cells[current] = true
	return cells


## Convierte los puntos de giro a posiciones locales (centro de celda) — son los
## waypoints que siguen los enemigos. Un tramo recto entre dos puntos de giro cubre
## automáticamente todas las celdas intermedias sin necesitar un waypoint por celda.
static func compute_path_world_points(turn_points: Array) -> Array:
	var points: Array = []
	for cell: Vector2i in turn_points:
		points.append(cell_to_local_center(cell))
	return points


static func compute_path_length(world_points: Array) -> float:
	var total: float = 0.0
	for i in range(world_points.size() - 1):
		total += (world_points[i + 1] as Vector2).distance_to(world_points[i] as Vector2)
	return total


## Rango vertical [min_y, max_y] que puede ocupar la Camera2D (hija del Board, mismo
## espacio local) para que el drag nunca muestre más allá del tablero. Si el tablero
## entero ya cabe en el área visible, ambos límites colapsan al mismo punto (centrado) —
## nunca se retorna un rango invertido (min > max).
static func compute_camera_bounds(
	board_height: float, viewport_height: float, hud_top: float, bottom_bar: float
) -> Vector2:
	var half_viewport: float = viewport_height * 0.5
	var min_y: float = half_viewport - hud_top
	var max_y: float = half_viewport + board_height - viewport_height + bottom_bar
	if max_y < min_y:
		var mid: float = (min_y + max_y) * 0.5
		return Vector2(mid, mid)
	return Vector2(min_y, max_y)
