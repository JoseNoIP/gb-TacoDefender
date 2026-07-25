extends GutTest
## Tests para GameManager (autoload real). La vida máxima de la base depende de
## MetaManager.get_upgrade_level("base_hp") — persiste en el user://meta.json REAL del
## desarrollador — así que los tests no asumen "vida inicial = 3": la derivan igual que
## GameManager (UpgradeShopGd.base_hp_for_level), mismo espíritu que la regla CLAUDE.md
## #57 (tests idempotentes/relativos en vez de asumir un guardado vacío).
##
## Dos tests (wave_cleared) SÍ otorgan propinas/victorias/mejor-oleada reales vía
## MetaManager al ejercitar el flujo completo — se restauran al final escribiendo directo
## al Dictionary interno `_data` vía reflección (mismo patrón documentado en la regla
## CLAUDE.md #57), para no dejar progreso permanente que el jugador nunca ganó.

const UpgradeShopGd := preload("res://src/features/meta/upgrade_shop.gd")
const GridMathGd := preload("res://src/features/board/grid_math.gd")


func _expected_base_hp_max() -> int:
	var level: int = MetaManager.get_upgrade_level(Constants.META_UPGRADE_ID_BASE_HP)
	return UpgradeShopGd.base_hp_for_level(level)


func test_start_game_resets_gold_to_starting_amount() -> void:
	GameManager.start_game()
	assert_eq(GameManager.get_gold(), Constants.STARTING_GOLD)


func test_start_game_sets_base_hp_to_max() -> void:
	GameManager.start_game()
	assert_eq(GameManager.get_base_hp(), _expected_base_hp_max())
	assert_eq(GameManager.get_base_hp_max(), _expected_base_hp_max())


func test_start_game_resets_wave_to_zero() -> void:
	GameManager.start_game()
	assert_eq(GameManager.get_current_wave(), 0)


func test_add_gold_increases_total() -> void:
	GameManager.start_game()
	GameManager.add_gold(20)
	assert_eq(GameManager.get_gold(), Constants.STARTING_GOLD + 20)


func test_spend_gold_succeeds_when_affordable() -> void:
	GameManager.start_game()
	assert_true(GameManager.spend_gold(50))
	assert_eq(GameManager.get_gold(), Constants.STARTING_GOLD - 50)


func test_spend_gold_fails_when_not_affordable() -> void:
	GameManager.start_game()
	assert_false(GameManager.spend_gold(Constants.STARTING_GOLD + 1))
	var msg: String = "un gasto rechazado no debe descontar nada"
	assert_eq(GameManager.get_gold(), Constants.STARTING_GOLD, msg)


func test_spend_gold_rejects_zero_and_negative() -> void:
	GameManager.start_game()
	assert_false(GameManager.spend_gold(0))
	assert_false(GameManager.spend_gold(-10))


func test_damage_base_reduces_hp_and_emits_signal() -> void:
	GameManager.start_game()
	watch_signals(EventBus)
	GameManager.damage_base(1)
	assert_eq(GameManager.get_base_hp(), _expected_base_hp_max() - 1)
	assert_signal_emitted(EventBus, "base_health_changed")


func test_damage_base_never_goes_negative() -> void:
	GameManager.start_game()
	GameManager.damage_base(9999)
	assert_eq(GameManager.get_base_hp(), 0)


## _current_wave sigue en 0 acá (start_game() recién reseteó, nunca se avanzó una
## oleada) — set_best_wave_if_higher(0) es un no-op garantizado (get_best_wave() real
## nunca es negativo), así que este test no necesita restaurar nada de MetaManager.
func test_damage_base_to_zero_triggers_game_over() -> void:
	GameManager.start_game()
	watch_signals(EventBus)
	GameManager.damage_base(_expected_base_hp_max())
	assert_signal_emitted(EventBus, "game_over")
	assert_eq(GameManager.get_state(), GameManager.State.GAME_OVER)


func test_pause_and_resume_round_trip() -> void:
	GameManager.start_game()
	GameManager.pause_game()
	assert_eq(GameManager.get_state(), GameManager.State.PAUSED)
	assert_true(GameManager.get_tree().paused)
	GameManager.resume_game()
	assert_eq(GameManager.get_state(), GameManager.State.WAVE_INTERMISSION)
	assert_false(GameManager.get_tree().paused)


func test_pause_is_noop_when_not_playing() -> void:
	GameManager.start_game()
	GameManager.damage_base(_expected_base_hp_max())
	assert_eq(GameManager.get_state(), GameManager.State.GAME_OVER)
	GameManager.pause_game()
	var msg: String = "no se puede pausar un juego ya terminado"
	assert_eq(GameManager.get_state(), GameManager.State.GAME_OVER, msg)
	GameManager.get_tree().paused = false  ## limpieza defensiva — no afecta al resto de la suite.


func test_start_wave_button_advances_wave_and_state() -> void:
	GameManager.start_game()
	EventBus.start_wave_button_pressed.emit()
	assert_eq(GameManager.get_current_wave(), 1)
	assert_eq(GameManager.get_state(), GameManager.State.PLAYING)


func test_wave_cleared_mid_game_starts_intermission_not_victory() -> void:
	GameManager.start_game()
	EventBus.start_wave_button_pressed.emit()
	var original_tips: int = MetaManager.get_tips()

	watch_signals(EventBus)
	EventBus.wave_cleared.emit(1)
	assert_eq(GameManager.get_state(), GameManager.State.WAVE_INTERMISSION)
	assert_signal_not_emitted(EventBus, "game_won")

	_restore_meta_tips(original_tips)


func test_wave_cleared_at_final_wave_triggers_victory() -> void:
	GameManager.start_game()
	var original_tips: int = MetaManager.get_tips()
	var original_victories: int = MetaManager.get_victories()
	var original_best_wave: int = MetaManager.get_best_wave()

	watch_signals(EventBus)
	EventBus.wave_cleared.emit(Constants.TOTAL_WAVES)
	assert_signal_emitted(EventBus, "game_won")
	assert_eq(GameManager.get_state(), GameManager.State.GAME_WON)

	_restore_meta_full(original_tips, original_victories, original_best_wave)


func test_resolve_level_index_defaults_to_victories_based_template() -> void:
	var victories: int = MetaManager.get_victories()
	var expected: int = GridMathGd.select_path_template_index(
		victories, Constants.PATH_TEMPLATES.size()
	)
	assert_eq(GameManager.resolve_level_index(), expected)


func test_request_level_overrides_resolve_level_index_until_consumed() -> void:
	GameManager.request_level(3)
	assert_eq(GameManager.resolve_level_index(), 3, "el pedido explícito debe ganar")
	GameManager.start_game()
	assert_eq(GameManager.get_current_level_index(), 3, "start_game debe fijar el nivel pedido")

	var victories: int = MetaManager.get_victories()
	var expected: int = GridMathGd.select_path_template_index(
		victories, Constants.PATH_TEMPLATES.size()
	)
	var msg: String = "el pedido se consume una sola vez -- la siguiente resolución cae al default"
	assert_eq(GameManager.resolve_level_index(), expected, msg)


func test_win_game_grants_efficiency_bonus_from_unspent_gold() -> void:
	GameManager.start_game()
	var original_tips: int = MetaManager.get_tips()
	var original_victories: int = MetaManager.get_victories()
	var original_best_wave: int = MetaManager.get_best_wave()

	## Sin gastar nada -- el oro inicial completo sigue "sin gastar" al momento de ganar.
	EventBus.wave_cleared.emit(Constants.TOTAL_WAVES)

	var tip_level: int = MetaManager.get_upgrade_level(Constants.META_UPGRADE_ID_TIPS)
	var multiplier: float = UpgradeShopGd.tip_multiplier(tip_level)
	## _on_wave_cleared() SIEMPRE otorga el bono por oleada ANTES de decidir si además es
	## victoria (ver GameManager._on_wave_cleared) -- las 3 recompensas se suman.
	var wave_bonus: int = int(round(float(Constants.TIP_REWARD_PER_WAVE) * multiplier))
	var victory_bonus: int = int(round(float(Constants.TIP_REWARD_VICTORY_BONUS) * multiplier))
	var raw_efficiency: int = int(
		floor(float(Constants.STARTING_GOLD) * Constants.EFFICIENCY_TIP_RATIO)
	)
	var efficiency_bonus: int = int(round(float(raw_efficiency) * multiplier))
	var expected_total: int = original_tips + wave_bonus + victory_bonus + efficiency_bonus
	assert_eq(MetaManager.get_tips(), expected_total)

	_restore_meta_full(original_tips, original_victories, original_best_wave)


func test_win_game_on_frontier_level_grants_a_victory() -> void:
	var original_victories: int = MetaManager.get_victories()
	var original_tips: int = MetaManager.get_tips()
	var original_best_wave: int = MetaManager.get_best_wave()

	GameManager.start_game()  ## sin request_level -- usa el default (la frontera real).
	EventBus.wave_cleared.emit(Constants.TOTAL_WAVES)
	var msg: String = "ganar el nivel frontera SÍ debe sumar una victoria"
	assert_eq(MetaManager.get_victories(), original_victories + 1, msg)

	_restore_meta_full(original_tips, original_victories, original_best_wave)


## Rejugar un nivel YA completado (LevelSelectScreen) no debe re-sumar progresión --
## solo el nivel frontera hace avanzar victories (ver GameManager._win_game()).
func test_win_game_on_replayed_completed_level_does_not_grant_extra_victory() -> void:
	var original_victories: int = MetaManager.get_victories()
	var original_tips: int = MetaManager.get_tips()
	var original_best_wave: int = MetaManager.get_best_wave()

	## Necesita al menos 1 victoria real para poder "rejugar" el nivel 0 -- si el save
	## real todavía no tiene ninguna, se le otorga una sintéticamente para poder ejercitar
	## el escenario (se restaura al final, mismo patrón que el resto de este archivo).
	if original_victories <= 0:
		var data: Dictionary = MetaManager.get(&"_data")
		data["victories"] = 1
		MetaManager.save()

	var victories_before_win: int = MetaManager.get_victories()
	GameManager.request_level(0)
	GameManager.start_game()
	EventBus.wave_cleared.emit(Constants.TOTAL_WAVES)
	var msg: String = "rejugar un nivel ya completado no debe sumar una victoria nueva"
	assert_eq(MetaManager.get_victories(), victories_before_win, msg)

	_restore_meta_full(original_tips, original_victories, original_best_wave)


func _restore_meta_tips(original_tips: int) -> void:
	var data: Dictionary = MetaManager.get(&"_data")
	data["tips"] = original_tips
	MetaManager.save()


func _restore_meta_full(
	original_tips: int, original_victories: int, original_best_wave: int
) -> void:
	var data: Dictionary = MetaManager.get(&"_data")
	data["tips"] = original_tips
	data["victories"] = original_victories
	data["best_wave"] = original_best_wave
	MetaManager.save()
