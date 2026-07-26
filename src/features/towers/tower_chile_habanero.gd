extends "res://src/features/towers/TowerBase.gd"
## Torre Chile Habanero — francotirador: el rango/daño por impacto más altos del juego,
## a cambio del cooldown más lento (ver nota extensa en Constants.gd). Disparo único sin
## efecto adicional, mismo mecanismo simple que Salsa Verde. Upgrade: +daño, +rango/nivel.


func _ready() -> void:
	_configure_from_catalog(Constants.TOWER_TYPE_CHILE_HABANERO)
	_build_visual("res://assets/sprites/towers/chile_habanero.png")
	super._ready()
