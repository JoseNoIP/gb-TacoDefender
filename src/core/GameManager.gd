extends Node
## Máquina de estados de la partida (GDD secciones 2 y 4): oro, vida de la taquería,
## oleada actual y la transición manual/auto-start entre oleadas. Sin class_name — autoload.

enum State { MENU, PLAYING, WAVE_INTERMISSION, PAUSED, GAME_OVER, GAME_WON }

const UpgradeShopGd := preload("res://src/features/meta/upgrade_shop.gd")

var _state: State = State.MENU
var _previous_state: State = State.MENU
var _gold: int = 0
var _base_hp: int = 0
var _base_hp_max: int = 0
var _current_wave: int = 0
var _session_time: float = 0.0
var _intermission_timer: float = 0.0


func _ready() -> void:
	EventBus.enemy_destroyed.connect(_on_enemy_destroyed)
	EventBus.enemy_reached_base.connect(_on_enemy_reached_base)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.start_wave_button_pressed.connect(_on_start_wave_button_pressed)


func _process(delta: float) -> void:
	match _state:
		State.PLAYING:
			_session_time += delta
		State.WAVE_INTERMISSION:
			_intermission_timer -= delta
			if _intermission_timer <= 0.0:
				_start_next_wave()


## Resetea toda la partida (oro, vida de la taquería según metagame, oleada) y arranca el
## primer intermission — llamado por Game.gd al construir la escena (composition root).
func start_game() -> void:
	_gold = Constants.STARTING_GOLD
	_base_hp_max = UpgradeShopGd.base_hp_for_level(
		MetaManager.get_upgrade_level(Constants.META_UPGRADE_ID_BASE_HP)
	)
	_base_hp = _base_hp_max
	_current_wave = 0
	_session_time = 0.0
	get_tree().paused = false
	EventBus.game_started.emit()
	EventBus.gold_changed.emit(_gold)
	EventBus.base_health_changed.emit(_base_hp, _base_hp_max)
	_begin_intermission()


func pause_game() -> void:
	if _state != State.PLAYING and _state != State.WAVE_INTERMISSION:
		return
	_previous_state = _state
	_state = State.PAUSED
	get_tree().paused = true
	EventBus.game_paused.emit()


func resume_game() -> void:
	if _state != State.PAUSED:
		return
	_state = _previous_state
	get_tree().paused = false
	EventBus.game_resumed.emit()


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	_gold += amount
	EventBus.gold_changed.emit(_gold)


## false si no alcanza el oro — nunca deja el total en negativo.
func spend_gold(amount: int) -> bool:
	if amount <= 0 or amount > _gold:
		return false
	_gold -= amount
	EventBus.gold_changed.emit(_gold)
	return true


func get_gold() -> int:
	return _gold


func damage_base(amount: int) -> void:
	if _state == State.GAME_OVER or _state == State.GAME_WON or amount <= 0:
		return
	_base_hp = maxi(_base_hp - amount, 0)
	EventBus.base_health_changed.emit(_base_hp, _base_hp_max)
	if _base_hp <= 0:
		_trigger_game_over()


func get_base_hp() -> int:
	return _base_hp


func get_base_hp_max() -> int:
	return _base_hp_max


func get_current_wave() -> int:
	return _current_wave


func get_state() -> State:
	return _state


func is_playing() -> bool:
	return _state == State.PLAYING


func get_session_time() -> float:
	return _session_time


func _begin_intermission() -> void:
	_state = State.WAVE_INTERMISSION
	_intermission_timer = Constants.WAVE_AUTO_START_DELAY
	EventBus.wave_intermission_started.emit(_current_wave + 1, _intermission_timer)


func _start_next_wave() -> void:
	_current_wave += 1
	_state = State.PLAYING
	EventBus.wave_started.emit(_current_wave)


func _on_start_wave_button_pressed() -> void:
	if _state == State.WAVE_INTERMISSION:
		_start_next_wave()


func _on_enemy_destroyed(_position: Vector2, reward: int) -> void:
	add_gold(reward)


func _on_enemy_reached_base(damage: int) -> void:
	damage_base(damage)


func _on_wave_cleared(wave_number: int) -> void:
	if _state == State.GAME_OVER or _state == State.GAME_WON:
		return
	MetaManager.add_tips(_with_tip_multiplier(Constants.TIP_REWARD_PER_WAVE))
	if wave_number >= Constants.TOTAL_WAVES:
		_win_game()
	else:
		_begin_intermission()


func _win_game() -> void:
	_state = State.GAME_WON
	MetaManager.add_tips(_with_tip_multiplier(Constants.TIP_REWARD_VICTORY_BONUS))
	MetaManager.add_victory()
	MetaManager.set_best_wave_if_higher(Constants.TOTAL_WAVES)
	EventBus.game_won.emit()


func _trigger_game_over() -> void:
	_state = State.GAME_OVER
	MetaManager.set_best_wave_if_higher(_current_wave)
	EventBus.game_over.emit()


func _with_tip_multiplier(base_amount: int) -> int:
	var level: int = MetaManager.get_upgrade_level(Constants.META_UPGRADE_ID_TIPS)
	return int(round(float(base_amount) * UpgradeShopGd.tip_multiplier(level)))
