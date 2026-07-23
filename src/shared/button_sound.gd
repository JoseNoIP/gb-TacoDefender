extends RefCounted
## Conecta el SFX de tap genérico (assets/audio/button_tap.wav) a un Button -- centraliza
## la conexión para no repetir `AudioManager.play_sfx(&"button_tap")` en cada uno de los
## ~30 botones del juego. AudioManager ya decide solo si el sonido está habilitado
## (SaveManager.get_sound_enabled()) y si el archivo existe -- este helper no necesita
## ninguna de esas dos comprobaciones, solo conectar la señal.
##
##   const ButtonSoundGd := preload("res://src/shared/button_sound.gd")
##   ButtonSoundGd.attach(my_button)


static func attach(button: Button) -> void:
	button.pressed.connect(func(): AudioManager.play_sfx("button_tap"))
