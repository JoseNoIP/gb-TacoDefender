extends "res://src/features/towers/TowerBase.gd"
## Torre Catapulta Guac — daño en área, R=50px (GDD sección 3). Upgrade: +10 Daño AoE/nivel.


func _ready() -> void:
	_configure_from_catalog(Constants.TOWER_TYPE_CATAPULTA_GUAC)
	_build_visual(Vector2(40.0, 40.0), Constants.COLOR_TOWER_CATAPULTA_GUAC)
	super._ready()
