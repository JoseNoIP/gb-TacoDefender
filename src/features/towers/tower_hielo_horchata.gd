extends "res://src/features/towers/TowerBase.gd"
## Torre Hielo Horchata — ralentiza 50% por 2s (GDD sección 3). Upgrade: +25% duración de
## ralentizado/nivel (sin bono de daño/rango, a diferencia de las otras dos torres).


func _ready() -> void:
	_configure_from_catalog(Constants.TOWER_TYPE_HIELO_HORCHATA)
	_build_visual(Vector2(36.0, 36.0), Constants.COLOR_TOWER_HIELO_HORCHATA)
	super._ready()
