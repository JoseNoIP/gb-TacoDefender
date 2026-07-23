extends RefCounted
## Crea un TextureRect que respeta set_size()/custom_minimum_size en vez de forzar el
## tamaño nativo del sprite -- sin expand_mode=EXPAND_IGNORE_SIZE, Godot ignora cualquier
## tamaño pedido y usa el tamaño nativo de la textura (2x el render en juego, regla
## CLAUDE.md #62), pisando el texto/ícono vecino. Ya causó ese bug real una vez
## (HUD._build_bottom_bar, íconos de torre desbordando sobre el nombre/precio) --
## centralizado acá para no repetirlo en cada pantalla nueva que agregue un ícono.
##
##   const IconStyleGd := preload("res://src/shared/icon_style.gd")
##   var icon: TextureRect = IconStyleGd.make_icon("res://assets/sprites/ui/star.png")


static func make_icon(texture_path: String) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.texture = load(texture_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
