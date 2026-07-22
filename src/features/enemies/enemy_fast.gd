extends "res://src/features/enemies/EnemyBase.gd"
## Enemigo Rápido — cucaracha veloz (GDD sección 3, Matriz de Entidades).


func _ready() -> void:
	_max_health = Constants.ENEMY_FAST_HP
	_base_speed = Constants.ENEMY_FAST_SPEED
	_reward = Constants.ENEMY_FAST_REWARD
	_build_visual(8.0, "res://assets/sprites/enemies/fast.png")
	super._ready()
