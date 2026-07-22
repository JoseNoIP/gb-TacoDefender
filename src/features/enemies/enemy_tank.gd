extends "res://src/features/enemies/EnemyBase.gd"
## Enemigo Tank — ratón de carga pesado (GDD sección 3, Matriz de Entidades).


func _ready() -> void:
	_max_health = Constants.ENEMY_TANK_HP
	_base_speed = Constants.ENEMY_TANK_SPEED
	_reward = Constants.ENEMY_TANK_REWARD
	_build_visual(16.0, Constants.COLOR_ENEMY_TANK)
	super._ready()
