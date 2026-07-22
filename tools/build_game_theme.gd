extends SceneTree
## Genera assets/theme/game_theme.tres UNA SOLA VEZ -- correr con
## `godot --headless -s tools/build_game_theme.gd` cada vez que se toquen los colores de
## Constants.gd (COLOR_BUTTON_*, UI_BUTTON_CORNER_RADIUS, UI_PANEL_CORNER_RADIUS). El
## .tres resultante se referencia en project.godot [gui] theme/custom -- reestiliza TODOS
## los Button/Label/PanelContainer del juego de una sola vez, sin tocar cada pantalla
## individualmente (antes de esto, todo el juego usaba el tema plano default de Godot).
##
## Los PanelContainer "modal" (Pause/GameOver/Victory/Settings/paneles de HUD) YA tienen
## su propio override explícito vía ModalStyleGd.opaque_panel() -- este Theme solo les da
## un default sensato por si se agrega un panel nuevo que se olvide de llamarlo.

const ModalStyleGd := preload("res://src/shared/modal_style.gd")
const OUTPUT_PATH: String = "res://assets/theme/game_theme.tres"


func _init() -> void:
	var theme: Theme = Theme.new()
	_style_buttons(theme)
	_style_labels(theme)
	_style_panels(theme)

	var dir: DirAccess = DirAccess.open("res://assets")
	if dir != null and not dir.dir_exists("theme"):
		dir.make_dir("theme")

	var err: int = ResourceSaver.save(theme, OUTPUT_PATH)
	if err == OK:
		print("OK -> ", OUTPUT_PATH)
	else:
		print("ERROR guardando theme: ", err)
	quit()


func _button_style(bg: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = Constants.UI_BUTTON_CORNER_RADIUS
	style.corner_radius_top_right = Constants.UI_BUTTON_CORNER_RADIUS
	style.corner_radius_bottom_left = Constants.UI_BUTTON_CORNER_RADIUS
	style.corner_radius_bottom_right = Constants.UI_BUTTON_CORNER_RADIUS
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _style_buttons(theme: Theme) -> void:
	theme.set_stylebox(&"normal", &"Button", _button_style(Constants.COLOR_BUTTON_NORMAL))
	theme.set_stylebox(&"hover", &"Button", _button_style(Constants.COLOR_BUTTON_HOVER))
	theme.set_stylebox(&"pressed", &"Button", _button_style(Constants.COLOR_BUTTON_PRESSED))
	theme.set_stylebox(&"disabled", &"Button", _button_style(Constants.COLOR_BUTTON_DISABLED))
	## Botón táctil, sin teclado/gamepad -- un focus ring dibujado encima solo generaría
	## un halo doble si algo dispara focus_mode; lo dejamos sin dibujar nada.
	theme.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())

	theme.set_color(&"font_color", &"Button", Constants.COLOR_BUTTON_TEXT)
	theme.set_color(&"font_hover_color", &"Button", Constants.COLOR_BUTTON_TEXT)
	theme.set_color(&"font_pressed_color", &"Button", Constants.COLOR_BUTTON_TEXT)
	theme.set_color(&"font_disabled_color", &"Button", Constants.COLOR_BUTTON_TEXT_DISABLED)
	theme.set_color(&"font_focus_color", &"Button", Constants.COLOR_BUTTON_TEXT)


func _style_labels(theme: Theme) -> void:
	theme.set_color(&"font_color", &"Label", Constants.COLOR_HUD_TEXT)


func _style_panels(theme: Theme) -> void:
	theme.set_stylebox(&"panel", &"PanelContainer", ModalStyleGd.opaque_panel())
