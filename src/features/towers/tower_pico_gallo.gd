extends "res://src/features/towers/TowerBase.gd"
## Torre Pico de Gallo — dispara a hasta 3 objetivos DISTINTOS en el mismo ciclo de
## cooldown (ver TowerBase._max_simultaneous_targets/_find_targets), en vez de
## concentrar daño en uno solo (ver nota extensa en Constants.gd). Upgrade: +daño por
## objetivo/nivel, sin bono de rango.


func _ready() -> void:
	_configure_from_catalog(Constants.TOWER_TYPE_PICO_GALLO)
	_build_visual("res://assets/sprites/towers/pico_gallo.png")
	super._ready()
