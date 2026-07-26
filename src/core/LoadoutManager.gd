extends Node
## Torres desbloqueables (compradas con propinas, ver Constants.TOWER_UNLOCK_COST) + el
## equipo de 3 activo para la PRÓXIMA partida (persiste hasta que se cambie desde
## LoadoutScreen -- "editable desde el menú en cualquier momento", no forzado en cada
## partida). Autoload separado de MetaManager para no acercarse al límite de 20 métodos
## públicos por clase que exige gdlint (regla CLAUDE.md #52) -- misma responsabilidad
## única que ya siguen MetaManager/SaveManager, en su propio user://loadout.json.

const SAVE_PATH: String = "user://loadout.json"

var _data: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_data = parsed


func save() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_data))


## Las 3 torres originales (Constants.TOWER_TYPES) están desbloqueadas desde siempre, sin
## costo -- "por defecto tiene las 3 que ya tenemos implementadas", pedido explícito.
func get_unlocked_towers() -> Array:
	var unlocked: Array = _data.get("unlocked_towers", []) as Array
	var result: Array = Constants.TOWER_TYPES.duplicate()
	for tower_type: String in unlocked:
		if tower_type not in result:
			result.append(tower_type)
	return result


func is_tower_unlocked(tower_type: String) -> bool:
	return tower_type in get_unlocked_towers()


## false si ya estaba desbloqueada, si el tipo no es desbloqueable, o si no alcanzan las
## propinas -- nunca cobra sin desbloquear ni desbloquea sin cobrar.
func unlock_tower(tower_type: String) -> bool:
	if is_tower_unlocked(tower_type) or tower_type not in Constants.TOWER_UNLOCKABLE_TYPES:
		return false
	var cost: int = int(Constants.TOWER_UNLOCK_COST.get(tower_type, 0))
	if cost <= 0 or not MetaManager.spend_tips(cost):
		return false
	var unlocked: Array = _data.get("unlocked_towers", []) as Array
	unlocked.append(tower_type)
	_data["unlocked_towers"] = unlocked
	save()
	EventBus.tower_unlocked.emit(tower_type)
	return true


## Default (nunca configurado, o guardado incompleto) = las 3 torres originales.
func get_current_loadout() -> Array:
	var loadout: Array = _data.get("current_loadout", []) as Array
	if loadout.size() != 3:
		return Constants.TOWER_TYPES.duplicate()
	return loadout


## false si no son exactamente 3 tipos distintos, o si alguno no está desbloqueado --
## nunca deja guardado un equipo inválido.
func set_current_loadout(tower_types: Array) -> bool:
	if tower_types.size() != 3:
		return false
	var unique: Dictionary = {}
	for tower_type: String in tower_types:
		if not is_tower_unlocked(tower_type):
			return false
		unique[tower_type] = true
	if unique.size() != 3:
		return false
	_data["current_loadout"] = tower_types
	save()
	EventBus.loadout_changed.emit(tower_types)
	return true
