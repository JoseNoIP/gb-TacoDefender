extends "res://src/features/towers/TowerBase.gd"
## Torre Hielo Horchata — ralentiza 50% por 2s (GDD sección 3). Upgrade: +25% duración de
## ralentizado/nivel (sin bono de daño/rango, a diferencia de las otras dos torres).


func _ready() -> void:
	_configure_from_catalog(Constants.TOWER_TYPE_HIELO_HORCHATA)
	_build_visual("res://assets/sprites/towers/hielo_horchata.png")
	super._ready()
