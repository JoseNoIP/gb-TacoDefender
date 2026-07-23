extends Node
## Bus de señales global. TODA comunicación entre features NO relacionadas pasa por acá
## — nunca get_parent()/get_node() con rutas hardcodeadas entre features distintas.
##
## Excepciones deliberadas (no violan la regla, son otra categoría de acceso):
## - Llamar autoloads directo (GameManager.spend_gold(), SaveManager.get_tutorial_shown(),
##   MetaManager.get_tips()) es normal: son el service layer global, no un feature sibling.
## - Board (grid + torres) es UNA sola feature (colocar una torre depende inherentemente
##   de la celda del grid) — sus scripts internos (Board.gd, grid_math.gd, TowerBase y
##   subtipos) se llaman directo entre sí sin pasar por acá.
## - Consultas espaciales en vivo (torres buscando enemigos en rango) usan grupos
##   (`get_tree().get_nodes_in_group(&"enemies")`), no señales — EventBus es para EVENTOS
##   discretos, no para polling continuo por frame.
## - Game.gd (composition root de Game.tscn) puede wirear referencias directas entre los
##   nodos que ÉL MISMO instancia una sola vez al construir la escena (ej. pasarle el
##   camino del Board a EnemySpawner) — es configuración de arranque, no comunicación
##   continua entre features.

# --- Game state ---
signal game_started
signal game_over
signal game_won
signal game_paused
signal game_resumed

# --- Economía (oro de la partida) ---
signal gold_changed(new_amount: int)

# --- Base / vida de la taquería ---
signal base_health_changed(current: int, maximum: int)

# --- Oleadas ---
signal wave_started(wave_number: int)
signal wave_intermission_started(next_wave_number: int, auto_start_delay: float)
signal wave_cleared(wave_number: int)
signal start_wave_button_pressed

# --- Enemigos ---
signal enemy_spawned(enemy_type: String)
signal enemy_destroyed(position: Vector2, reward: int)
signal enemy_reached_base(damage: int)

# --- Tablero / torres (ver Board.gd — grid y torres son una sola feature) ---
signal build_mode_requested(tower_type: String)
signal build_mode_cancelled
signal tower_placed(tower_type: String, cell: Vector2i)
signal tower_selected(info: Dictionary)
signal tower_deselected
signal tower_upgrade_requested(cell: Vector2i)
signal tower_upgraded(cell: Vector2i, new_level: int)
signal tower_sell_requested(cell: Vector2i)
signal tower_sold(cell: Vector2i, refund: int)

# --- Metagame (propinas, mejoras permanentes) ---
signal tips_changed(new_amount: int)
signal meta_upgrade_purchased(upgrade_id: String, new_level: int)

# --- UI genérica ---
## Mensaje corto tipo "toast" (ej. "Oro insuficiente", "Casilla no disponible") — evita
## crear una señal específica por cada mensaje de feedback posible.
signal action_feedback(message: String)
signal sound_setting_changed(enabled: bool)
## Emitida por LocalizationManager.set_language() -- pantallas vivas con texto formateado
## con tr() (no el auto_translate_mode nativo de Control, que ya retraduce solo el texto
## estático) escuchan esto para re-renderizar sus labels dinámicos (ver /mobile-i18n).
signal language_changed(locale: String)
