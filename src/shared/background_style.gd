extends RefCounted
## Fondo de pantalla completa con arte generado por IA (ver /gen-ai-art) + velo oscuro
## semi-transparente encima, para que texto/botones sin panel propio (título, tips,
## botón "Volver") sigan siendo legibles sobre una imagen con detalle -- mismo motivo que
## ModalStyleGd.opaque_panel() (regla CLAUDE.md #53), aplicado a fondos en vez de paneles.
##
##   const BackgroundStyleGd := preload("res://src/shared/background_style.gd")
##   BackgroundStyleGd.add_background(self, "res://assets/sprites/backgrounds/menu_bg.png")

const DIM_ALPHA_DEFAULT: float = 0.35


static func add_background(
	parent: Node, texture_path: String, dim_alpha: float = DIM_ALPHA_DEFAULT
) -> void:
	var bg: TextureRect = TextureRect.new()
	bg.texture = load(texture_path)
	bg.position = Vector2.ZERO
	bg.set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)

	if dim_alpha > 0.0:
		var scrim: ColorRect = ColorRect.new()
		scrim.position = Vector2.ZERO
		scrim.set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))
		scrim.color = Color(0.0, 0.0, 0.0, dim_alpha)
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(scrim)
