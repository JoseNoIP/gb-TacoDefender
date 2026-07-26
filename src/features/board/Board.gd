extends Node2D
## Feature "tablero": grilla + camino + colocación/mejora/venta de torres + TODO el input
## de mundo (tap para construir/seleccionar, drag para paneo de cámara, GDD sección 2).
## Grid y torres son la MISMA feature — colocar una torre depende inherentemente de la
## celda de grilla (ver nota de arquitectura en EventBus.gd). Se autoposiciona centrado
## horizontalmente en el viewport (nunca asumir que Game.gd debe conocer ese offset).

const GridMathGd := preload("res://src/features/board/grid_math.gd")
const TOWER_SCRIPTS: Dictionary = {
	"salsa_verde": preload("res://src/features/towers/tower_salsa_verde.gd"),
	"hielo_horchata": preload("res://src/features/towers/tower_hielo_horchata.gd"),
	"catapulta_guac": preload("res://src/features/towers/tower_catapulta_guac.gd"),
	"chile_habanero": preload("res://src/features/towers/tower_chile_habanero.gd"),
	"queso_fundido": preload("res://src/features/towers/tower_queso_fundido.gd"),
	"pico_gallo": preload("res://src/features/towers/tower_pico_gallo.gd"),
}
const NONE_CELL: Vector2i = Vector2i(-1, -1)

var _camera: Camera2D = Camera2D.new()
var _path_cells: Dictionary = {}
var _path_turn_cells: Array = []
var _path_world_points: Array = []
var _path_length: float = 0.0
var _template_index: int = 0
var _towers: Dictionary = {}  ## Vector2i -> Node2D (tower instance)
var _pending_tower_type: String = ""
var _selected_cell: Vector2i = NONE_CELL
var _camera_min_y: float = 0.0
var _camera_max_y: float = 0.0
var _touch_active: bool = false
var _is_dragging: bool = false
var _accumulated_drag: float = 0.0


## El template de camino/tema visual se elige UNA sola vez acá -- GameManager.
## resolve_level_index() decide si es un nivel pedido explícitamente (LevelSelectScreen/
## "Siguiente nivel") o el default de progresión según victorias (ver nota extensa en
## Constants.PATH_TEMPLATES). Es seguro llamarla ACÁ, antes de que GameManager.
## start_game() corra (ver Game.gd::_build_scene(), regla CLAUDE.md #48): resolve_level_
## index() es pura, no depende de nada que start_game() vaya a cambiar recién después.
## Queda fijo el resto de la partida (nunca se recalcula en medio de las 10 oleadas).
func _ready() -> void:
	position = Vector2((Constants.DESIGN_WIDTH - Constants.BOARD_WIDTH) * 0.5, 0.0)

	_template_index = GameManager.resolve_level_index()
	_path_turn_cells = Constants.PATH_TEMPLATES[_template_index]
	_path_cells = GridMathGd.compute_path_cells(_path_turn_cells)
	_path_world_points = GridMathGd.compute_path_world_points(_path_turn_cells)
	_path_length = GridMathGd.compute_path_length(_path_world_points)

	var bounds: Vector2 = GridMathGd.compute_camera_bounds(
		Constants.BOARD_HEIGHT,
		Constants.DESIGN_HEIGHT,
		Constants.HUD_TOP_HEIGHT,
		Constants.BOTTOM_BAR_HEIGHT
	)
	_camera_min_y = bounds.x
	_camera_max_y = bounds.y
	_camera.position = Vector2(Constants.BOARD_WIDTH * 0.5, _camera_min_y)
	_camera.enabled = true
	add_child(_camera)

	EventBus.build_mode_requested.connect(_on_build_mode_requested)
	EventBus.tower_upgrade_requested.connect(_on_tower_upgrade_requested)
	EventBus.tower_sell_requested.connect(_on_tower_sell_requested)
	queue_redraw()


func _exit_tree() -> void:
	if EventBus.build_mode_requested.is_connected(_on_build_mode_requested):
		EventBus.build_mode_requested.disconnect(_on_build_mode_requested)
	if EventBus.tower_upgrade_requested.is_connected(_on_tower_upgrade_requested):
		EventBus.tower_upgrade_requested.disconnect(_on_tower_upgrade_requested)
	if EventBus.tower_sell_requested.is_connected(_on_tower_sell_requested):
		EventBus.tower_sell_requested.disconnect(_on_tower_sell_requested)


func get_path_world_points() -> Array:
	return _path_world_points


func get_path_length() -> float:
	return _path_length


## Expuesto para tests -- el template activo depende de MetaManager.get_victories(), así
## que ningún test debe asumir un template fijo (regla CLAUDE.md #57, mismo espíritu:
## nunca depender de estado real de progreso del jugador). Los tests que necesiten "una
## celda de camino" o "una celda construible" deben derivarla de acá, no hardcodearla.
func get_path_cells() -> Dictionary:
	return _path_cells


func is_buildable(cell: Vector2i) -> bool:
	return GridMathGd.is_in_bounds(cell) and not _path_cells.has(cell) and not _towers.has(cell)


func get_tower_at(cell: Vector2i) -> Node2D:
	return _towers.get(cell)


func try_place_tower(tower_type: String, cell: Vector2i) -> bool:
	if not is_buildable(cell):
		EventBus.action_feedback.emit(tr(&"TOAST_CELL_UNAVAILABLE"))
		return false
	var catalog_entry: Dictionary = Constants.TOWER_CATALOG.get(tower_type, {}) as Dictionary
	if catalog_entry.is_empty():
		return false
	var cost: int = int(catalog_entry.get("cost", 0))
	if not GameManager.spend_gold(cost):
		EventBus.action_feedback.emit(tr(&"TOAST_INSUFFICIENT_GOLD"))
		return false
	var tower_script: GDScript = TOWER_SCRIPTS.get(tower_type) as GDScript
	if tower_script == null:
		GameManager.add_gold(cost)  ## revertir el gasto — tipo desconocido, defensivo.
		return false
	var tower: Node2D = tower_script.new()
	add_child(tower)
	tower.call(&"setup", cell)
	_towers[cell] = tower
	EventBus.tower_placed.emit(tower_type, cell)
	return true


func sell_tower_at(cell: Vector2i) -> bool:
	var tower: Node2D = _towers.get(cell)
	if tower == null or not is_instance_valid(tower):
		return false
	var refund: int = int(tower.call(&"get_sell_value"))
	GameManager.add_gold(refund)
	_towers.erase(cell)
	tower.queue_free()
	EventBus.tower_sold.emit(cell, refund)
	return true


func upgrade_tower_at(cell: Vector2i) -> bool:
	var tower: Node2D = _towers.get(cell)
	if tower == null or not is_instance_valid(tower):
		return false
	return bool(tower.call(&"upgrade"))


func _on_build_mode_requested(tower_type: String) -> void:
	_clear_selection()
	EventBus.tower_deselected.emit()
	_pending_tower_type = tower_type
	queue_redraw()  ## activa el resaltado verde de celdas construibles.


func _on_tower_upgrade_requested(cell: Vector2i) -> void:
	if upgrade_tower_at(cell):
		_emit_tower_selected(cell)  ## refresca el panel con el nuevo nivel/costos.
	else:
		EventBus.action_feedback.emit(tr(&"TOAST_UPGRADE_FAILED"))


func _on_tower_sell_requested(cell: Vector2i) -> void:
	if sell_tower_at(cell):
		if _selected_cell == cell:
			_selected_cell = NONE_CELL
		EventBus.tower_deselected.emit()
	else:
		EventBus.action_feedback.emit(tr(&"TOAST_SELL_FAILED"))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			_on_press()
		else:
			_on_release()
	elif event is InputEventScreenDrag:
		_on_drag((event as InputEventScreenDrag).relative)
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_on_press()
			else:
				_on_release()
	elif event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		if mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_on_drag(mouse_motion.relative)


func _on_press() -> void:
	_touch_active = true
	_is_dragging = false
	_accumulated_drag = 0.0


## Distingue tap de drag por distancia acumulada (regla CLAUDE.md #41 aplicada a tap-vs-
## drag): por debajo de CAMERA_DRAG_THRESHOLD_PX sigue siendo candidato a tap; una vez
## que se cruza el umbral, el gesto completo queda clasificado como drag (nunca vuelve a
## ser tap aunque el dedo se quede quieto después).
func _on_drag(relative: Vector2) -> void:
	if not _touch_active:
		return
	_accumulated_drag += relative.length()
	if _accumulated_drag >= Constants.CAMERA_DRAG_THRESHOLD_PX:
		_is_dragging = true
	_camera.position.y = clampf(_camera.position.y - relative.y, _camera_min_y, _camera_max_y)


func _on_release() -> void:
	if _touch_active and not _is_dragging:
		_handle_tap()
	_touch_active = false
	_is_dragging = false


func _handle_tap() -> void:
	var world_position: Vector2 = get_global_mouse_position()
	var local_position: Vector2 = to_local(world_position)
	var cell: Vector2i = GridMathGd.world_to_cell(local_position)
	if not GridMathGd.is_in_bounds(cell):
		return
	if _towers.has(cell):
		_emit_tower_selected(cell)
		return
	if _pending_tower_type != "":
		if try_place_tower(_pending_tower_type, cell):
			_pending_tower_type = ""
			EventBus.build_mode_cancelled.emit()
			queue_redraw()  ## apaga el resaltado verde -- ya no hay torre pendiente.
		return
	if _selected_cell != NONE_CELL:
		_clear_selection()
		EventBus.tower_deselected.emit()


func _emit_tower_selected(cell: Vector2i) -> void:
	var tower: Node2D = _towers.get(cell)
	if tower == null or not is_instance_valid(tower):
		return
	_clear_selection()
	var level: int = int(tower.call(&"get_level"))
	var info: Dictionary = {
		"cell": cell,
		"tower_type": String(tower.call(&"get_tower_type")),
		"level": level,
		"max_level": Constants.TOWER_MAX_LEVEL,
		"damage": float(tower.call(&"get_effective_damage")),
		"range": float(tower.call(&"get_effective_range")),
		"upgrade_cost": int(tower.call(&"get_upgrade_cost")),
		"can_upgrade": level < Constants.TOWER_MAX_LEVEL,
		"sell_value": int(tower.call(&"get_sell_value")),
	}
	_selected_cell = cell
	tower.call(&"set_selected", true)
	EventBus.tower_selected.emit(info)


func _clear_selection() -> void:
	if _selected_cell != NONE_CELL:
		var previous: Node2D = _towers.get(_selected_cell)
		if previous != null and is_instance_valid(previous):
			previous.call(&"set_selected", false)
	_selected_cell = NONE_CELL


## Cada celda dibuja la textura de piso del TEMA del template activo (_template_index,
## ver Constants.BOARD_PATH_TEXTURES/BOARD_GROUND_TEXTURES) según _path_cells -- el zigzag
## real del camino elegido es lo que determina dónde se ve la textura de "calle" vs la de
## "tierra", así que la forma visual coincide exactamente con por dónde caminan los
## enemigos (no un fondo escénico fijo sin relación con la forma real). Base/spawn son un
## tinte de color semi-transparente ENCIMA de la textura de piso (siguen siendo un solo
## tile cada uno, funcionan como "cartel" de inicio/fin). Con una torre pendiente de
## colocar (_pending_tower_type != ""), las celdas construibles reciben además un
## resaltado verde translúcido encima de todo lo anterior.
func _draw() -> void:
	var path_texture: Texture2D = Constants.BOARD_PATH_TEXTURES[_template_index]
	var ground_texture: Texture2D = Constants.BOARD_GROUND_TEXTURES[_template_index]
	for row in range(Constants.GRID_ROWS):
		for col in range(Constants.GRID_COLS):
			var cell: Vector2i = Vector2i(col, row)
			var rect: Rect2 = Rect2(
				Vector2(float(col), float(row)) * Constants.TILE_SIZE,
				Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE)
			)
			var is_path: bool = _path_cells.has(cell)
			draw_texture_rect(path_texture if is_path else ground_texture, rect, false)
			if cell == _path_turn_cells[-1]:
				draw_rect(rect, Constants.COLOR_TILE_BASE_TINT, true)
			elif cell == _path_turn_cells[0]:
				draw_rect(rect, Constants.COLOR_TILE_SPAWN_TINT, true)
			draw_rect(rect, Constants.COLOR_TILE_BORDER, false, 1.0)
			if _pending_tower_type != "" and is_buildable(cell):
				draw_rect(rect, Constants.COLOR_BUILD_HIGHLIGHT, true)
