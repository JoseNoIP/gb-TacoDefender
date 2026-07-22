extends "res://src/features/towers/TowerBase.gd"
## Torre Salsa Verde — disparo único (GDD sección 3). Upgrade: +5 Daño, +15 Rango/nivel.


func _ready() -> void:
	_configure_from_catalog(Constants.TOWER_TYPE_SALSA_VERDE)
	_build_visual("res://assets/sprites/towers/salsa_verde.png")
	super._ready()
