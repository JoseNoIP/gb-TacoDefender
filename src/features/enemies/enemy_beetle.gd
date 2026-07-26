extends "res://src/features/enemies/EnemyBase.gd"
## Enemigo Escarabajo Acorazado -- armadura (reduce daño plano por golpe, ver
## EnemyBase.take_damage()/Constants.ENEMY_BEETLE_ARMOR). Aparece SOLO en las oleadas 8
## y 10 (Constants.WAVE_DEFINITIONS) para sentirse como progresión dentro de la partida,
## no como un enemigo más desde el principio.


func _ready() -> void:
	_max_health = Constants.ENEMY_BEETLE_HP
	_base_speed = Constants.ENEMY_BEETLE_SPEED
	_reward = Constants.ENEMY_BEETLE_REWARD
	_armor = Constants.ENEMY_BEETLE_ARMOR
	_build_visual(14.0, "res://assets/sprites/enemies/beetle.png")
	super._ready()
