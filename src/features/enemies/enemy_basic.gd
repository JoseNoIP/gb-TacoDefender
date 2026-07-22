extends "res://src/features/enemies/EnemyBase.gd"
## Enemigo Básico — mosca común (GDD sección 3, Matriz de Entidades).


func _ready() -> void:
	_max_health = Constants.ENEMY_BASIC_HP
	_base_speed = Constants.ENEMY_BASIC_SPEED
	_reward = Constants.ENEMY_BASIC_REWARD
	_build_visual(10.0, "res://assets/sprites/enemies/basic.png")
	super._ready()
