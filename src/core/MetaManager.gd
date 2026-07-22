extends Node
## Persistencia de la metaprogresión permanente (GDD sección 5): propinas y niveles de las
## 5 mejoras de la tienda del menú principal, más estadísticas cross-run (mejor oleada,
## victorias, partidas jugadas). Mismo patrón que SaveManager.gd (JSON plano en user://)
## pero en su propio archivo — SaveManager ya cubre settings/tutorial y separarlo evita
## acercarse al máximo de 20 métodos públicos por clase que exige gdlint (regla CLAUDE.md
## #52); además es, de por sí, una responsabilidad propia. Sin class_name — es autoload.

const SAVE_PATH: String = "user://meta.json"
const UpgradeShopGd := preload("res://src/features/meta/upgrade_shop.gd")

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


# --- Propinas ---
func get_tips() -> int:
	return _data.get("tips", 0) as int


func add_tips(amount: int) -> void:
	if amount <= 0:
		return
	_data["tips"] = get_tips() + amount
	save()
	EventBus.tips_changed.emit(get_tips())


## false si no alcanza — nunca deja el total en negativo.
func spend_tips(amount: int) -> bool:
	if amount <= 0 or amount > get_tips():
		return false
	_data["tips"] = get_tips() - amount
	save()
	EventBus.tips_changed.emit(get_tips())
	return true


# --- Mejoras permanentes (upgrade_id: uno de upgrade_shop.gd::UPGRADE_IDS) ---
func get_upgrade_level(upgrade_id: String) -> int:
	var levels: Dictionary = _data.get("upgrade_levels", {}) as Dictionary
	return int(levels.get(upgrade_id, 0))


## Compra el siguiente nivel de `upgrade_id` si hay propinas suficientes y no está al
## máximo. Devuelve false sin cambiar nada si falla cualquiera de las dos condiciones.
func purchase_upgrade(upgrade_id: String) -> bool:
	var level: int = get_upgrade_level(upgrade_id)
	if UpgradeShopGd.is_max_level(level):
		return false
	var cost: int = UpgradeShopGd.cost_for_next_level(level)
	if not spend_tips(cost):
		return false
	_set_upgrade_level(upgrade_id, level + 1)
	EventBus.meta_upgrade_purchased.emit(upgrade_id, level + 1)
	return true


# --- Estadísticas cross-run ---
func get_best_wave() -> int:
	return _data.get("best_wave", 0) as int


func set_best_wave_if_higher(wave: int) -> void:
	if wave > get_best_wave():
		_data["best_wave"] = wave
		save()


func get_victories() -> int:
	return _data.get("victories", 0) as int


func add_victory() -> void:
	_data["victories"] = get_victories() + 1
	save()


func get_total_games_played() -> int:
	return _data.get("total_games_played", 0) as int


func increment_games_played() -> void:
	_data["total_games_played"] = get_total_games_played() + 1
	save()


func _set_upgrade_level(upgrade_id: String, level: int) -> void:
	var levels: Dictionary = _data.get("upgrade_levels", {}) as Dictionary
	levels[upgrade_id] = level
	_data["upgrade_levels"] = levels
	save()
