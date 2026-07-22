extends RefCounted
## Lógica pura de la tienda de mejoras permanentes (GDD sección 5): costos y bonos por
## nivel. Sin estado, sin nodo — testeable sin escena. MetaManager es el dueño del estado
## persistido (nivel comprado de cada mejora, propinas); este módulo solo sabe traducir
## "nivel N" a "costo"/"bono".

const UPGRADE_IDS: Array = [
	Constants.META_UPGRADE_ID_DAMAGE,
	Constants.META_UPGRADE_ID_RANGE,
	Constants.META_UPGRADE_ID_COOLDOWN,
	Constants.META_UPGRADE_ID_TIPS,
	Constants.META_UPGRADE_ID_BASE_HP,
]


static func is_max_level(current_level: int) -> bool:
	return current_level >= Constants.META_UPGRADE_MAX_LEVEL


## current_level = 0 significa "sin comprar todavía". Devuelve -1 si ya está al máximo
## (nunca debería llamarse en ese caso — MetaManager valida con is_max_level() antes).
static func cost_for_next_level(current_level: int) -> int:
	if is_max_level(current_level):
		return -1
	return int(Constants.META_UPGRADE_COSTS[current_level])


static func damage_multiplier(level: int) -> float:
	return 1.0 + float(level) * Constants.META_DAMAGE_BONUS_PER_LEVEL


static func range_multiplier(level: int) -> float:
	return 1.0 + float(level) * Constants.META_RANGE_BONUS_PER_LEVEL


static func cooldown_multiplier(level: int) -> float:
	return 1.0 - float(level) * Constants.META_COOLDOWN_REDUCTION_PER_LEVEL


static func tip_multiplier(level: int) -> float:
	return 1.0 + float(level) * Constants.META_TIP_BONUS_PER_LEVEL


static func base_hp_for_level(level: int) -> int:
	var clamped: int = clampi(level, 0, Constants.META_BASE_HP_PER_LEVEL.size() - 1)
	return int(Constants.META_BASE_HP_PER_LEVEL[clamped])
