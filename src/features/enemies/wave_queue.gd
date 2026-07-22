extends RefCounted
## Lógica pura de construcción de la cola de spawn de una oleada (GDD sección 4). Sin
## estado, sin nodo — testeable sin escena. EnemySpawner.gd consume el Array que devuelve
## build_spawn_queue() y lo va vaciando en su _process().


## wave_number es 1-indexado (Oleada 1..10, ver GDD). Devuelve [] si está fuera de rango
## (nunca crashea con un índice inválido).
static func build_spawn_queue(wave_number: int) -> Array:
	var index: int = wave_number - 1
	if index < 0 or index >= Constants.WAVE_DEFINITIONS.size():
		return []
	var groups: Array = Constants.WAVE_DEFINITIONS[index]
	var queue: Array = []
	for group: Dictionary in groups:
		(
			queue
			. append(
				{
					"type": String(group.get("type", Constants.ENEMY_TYPE_BASIC)),
					"remaining": int(group.get("count", 0)),
					"interval": float(group.get("interval", 1.0)),
					"timer": 0.0,
				}
			)
		)
	return queue


## Total de enemigos que trae una oleada (suma de todos sus grupos) — útil para UI de
## progreso y para tests que verifican la cola completa contra el GDD.
static func total_enemy_count(wave_number: int) -> int:
	var total: int = 0
	for entry: Dictionary in build_spawn_queue(wave_number):
		total += int(entry.get("remaining", 0))
	return total
