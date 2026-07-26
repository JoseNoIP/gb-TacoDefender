extends "res://src/features/towers/TowerBase.gd"
## Torre Queso Fundido — daño en el tiempo (DoT, ver EnemyBase.apply_dot), rango el más
## corto del juego a cambio de daño sostenido alto (ver nota extensa en Constants.gd).
## Upgrade: SOLO extiende duración del DoT, sin bono de daño/rango (mismo patrón que
## Hielo Horchata con el enlentecimiento).


func _ready() -> void:
	_configure_from_catalog(Constants.TOWER_TYPE_QUESO_FUNDIDO)
	_build_visual("res://assets/sprites/towers/queso_fundido.png")
	super._ready()
