extends Node
## SFX y música — stub funcional (ver /gen-ai-art para el pipeline de generación real).
## Nunca crashea si falta un archivo de audio: ResourceLoader.exists() antes de load()
## (regla CLAUDE.md sección AudioManager). Se suscribe DIRECTO a EventBus para decidir qué
## sonido tocar en cada evento de gameplay, en vez de que cada feature (torres, enemigos)
## llame play_sfx() a mano — así ninguna torre/enemigo necesita saber nada de audio.
## .wav, no .ogg: tools/gen_assets.py sintetiza WAV puro (stdlib `wave`), sin encoder
## externo (regla CLAUDE.md #46). Sin class_name — es autoload.

const SFX_DIR: String = "res://assets/audio/"
const MUSIC_PATH: String = "res://assets/audio/music_loop.wav"

const SFX_FILES: Dictionary = {
	"tower_place": "tower_place.wav",
	"tower_upgrade": "tower_upgrade.wav",
	"enemy_die": "enemy_die.wav",
	"enemy_leak": "enemy_leak.wav",
	"wave_start": "wave_start.wav",
	"victory": "victory.wav",
	"defeat": "defeat.wav",
	"button_tap": "button_tap.wav",
}

var _music_player: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready() -> void:
	_music_player.name = &"MusicPlayer"
	_music_player.bus = &"Master"
	_music_player.volume_db = -8.0  ## fondo discreto — no debe competir con los SFX.
	## Loop manual en vez de depender de loop_mode en el .import de music_loop.wav: los
	## .import están en .gitignore (regla CLAUDE.md sección Android CI/CD, se regeneran
	## con --editor --quit) y por default un WAV importa con loop deshabilitado — sin
	## esto la música sonaría una sola vez y quedaría en silencio el resto de la partida.
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)
	EventBus.sound_setting_changed.connect(_on_sound_setting_changed)
	EventBus.tower_placed.connect(_on_tower_placed)
	EventBus.tower_upgraded.connect(_on_tower_upgraded)
	EventBus.enemy_destroyed.connect(_on_enemy_destroyed)
	EventBus.enemy_reached_base.connect(_on_enemy_reached_base)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.game_won.connect(_on_game_won)
	EventBus.game_over.connect(_on_game_over)
	play_music()


func play_sfx(sfx_name: String) -> void:
	if not SaveManager.get_sound_enabled():
		return
	var filename: Variant = SFX_FILES.get(sfx_name)
	if filename == null:
		return
	var path: String = SFX_DIR + String(filename)
	if not ResourceLoader.exists(path):
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = load(path)
	player.bus = &"Master"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_music() -> void:
	if not SaveManager.get_sound_enabled():
		return
	if not ResourceLoader.exists(MUSIC_PATH):
		return
	_music_player.stream = load(MUSIC_PATH)
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


## AudioStreamPlayer.stop() NUNCA emite `finished` (solo dispara al llegar al final
## natural del clip) -- parar música a propósito (victoria/derrota/config) no reinicia
## el loop por accidente.
func _on_music_finished() -> void:
	if SaveManager.get_sound_enabled():
		_music_player.play()


func _on_sound_setting_changed(enabled: bool) -> void:
	if enabled:
		play_music()
	else:
		stop_music()


func _on_tower_placed(_tower_type: String, _cell: Vector2i) -> void:
	play_sfx("tower_place")


func _on_tower_upgraded(_cell: Vector2i, _new_level: int) -> void:
	play_sfx("tower_upgrade")


func _on_enemy_destroyed(_position: Vector2, _reward: int) -> void:
	play_sfx("enemy_die")


func _on_enemy_reached_base(_damage: int) -> void:
	play_sfx("enemy_leak")


func _on_wave_started(_wave_number: int) -> void:
	play_sfx("wave_start")


func _on_game_won() -> void:
	stop_music()
	play_sfx("victory")


func _on_game_over() -> void:
	stop_music()
	play_sfx("defeat")
