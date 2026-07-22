extends RefCounted
## Estilo compartido para paneles tipo "modal" (overlays construidos con PanelContainer:
## PauseScreen, GameOverScreen, VictoryScreen, SettingsScreen, panel de selección de
## torre, panel del tutorial).
##
## Un PanelContainer sin estilo propio usa el panel semi-transparente por defecto del
## tema de Godot — sobre el tablero de juego detrás, el texto del modal se mezclaría
## visualmente con lo que hay detrás y quedaría ilegible (regla CLAUDE.md #53). Aplicar
## SIEMPRE a cualquier PanelContainer usado como overlay/modal, sin excepción:
##
##   const ModalStyleGd := preload("res://src/shared/modal_style.gd")
##   _panel.add_theme_stylebox_override(&"panel", ModalStyleGd.opaque_panel())

const CORNER_RADIUS: int = 12
const BG_ALPHA: float = 0.97  ## casi 100% opaco — nunca dejar ver el fondo real detrás.


static func opaque_panel(bg_color: Color = Constants.COLOR_BG_BOARD) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(bg_color.r, bg_color.g, bg_color.b, BG_ALPHA)
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	return style
