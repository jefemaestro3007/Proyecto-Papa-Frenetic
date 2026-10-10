extends SceneTree
## Verifica las canciones (`MusicTrack`) y que el Conductor tome su tempo. Ejecutar:
##   godot --headless --path . --script res://tests/unit/test_music.gd

const MUSIC := "res://src/shared/resources/music/"
## BPM medido de cada canción y beats que dura desde su primer beat (el bucle se cuenta en beats
## enteros). La del nivel uno (remake, primer beat a 0,15 s) termina con un beat de cola: 57
## compases y uno.
const EXPECTED := {
	"nivel_uno": [177.0, 229],
	"industrial": [175.0, 84],
	"centro_comercial": [140.0, 88],
}

var _failures := 0


func _initialize() -> void:
	for track_name in EXPECTED:
		var track := load(MUSIC + track_name + ".tres") as MusicTrack
		if track == null or track.stream == null:
			_fail("%s no carga o no tiene audio" % track_name)
			continue
		if not is_equal_approx(track.bpm, EXPECTED[track_name][0]):
			_fail("%s: BPM %.1f" % [track_name, track.bpm])
		var beats: int = EXPECTED[track_name][1]
		if track.length_beats() != beats:
			_fail("%s: %d beats, se esperaban %d" % [track_name, track.length_beats(), beats])
	# La del menú no dura compases enteros (suena en bucle sin juicios de ritmo): solo su tempo.
	var menu := load(MUSIC + "menu.tres") as MusicTrack
	if menu == null or menu.stream == null or not is_equal_approx(menu.bpm, 190.5):
		_fail("la canción del menú no carga o no tiene su BPM medido (190,5)")

	# El autoload termina de armarse en el primer frame.
	await process_frame
	var conductor: ConductorClock = root.get_node("Conductor")
	var track := load(MUSIC + "nivel_uno.tres") as MusicTrack
	conductor.play_track(track)
	if not is_equal_approx(conductor.params.bpm, track.bpm) or conductor.current_track() != track:
		_fail("el Conductor no tomó el tempo de la canción")
	if conductor.beat_position() != 0.0:
		_fail("play_track no reinició el reloj")
	# Canción de peligro: sube de a poco con el peligro y la del nivel baja (juntas: −3 dB;
	# mezcla cruzada: se calla).
	var danger := load(MUSIC + "peligro.tres") as MusicTrack
	if danger == null or danger.stream == null or danger.volume_db >= 0.0:
		_fail("la canción de peligro no carga o no tiene el volumen bajado")
	conductor.set_danger_track(danger)
	conductor.set_danger(1.0)
	await create_timer(0.15).timeout
	if conductor.danger <= 0.0 or conductor.danger >= 1.0:
		_fail("el peligro no sube de a poco: %.2f" % conductor.danger)
	await create_timer(0.8).timeout
	if not is_equal_approx(conductor.danger, 1.0) or not is_equal_approx(conductor.main_gain(), ConductorClock.TOGETHER_MAIN_GAIN):
		_fail("al máximo, juntas: peligro %.2f, canción del nivel %.2f" % [conductor.danger, conductor.main_gain()])
	conductor.params.danger_crossfade = true
	if conductor.main_gain() != 0.0:
		_fail("con mezcla cruzada la canción del nivel no se calla")
	conductor.params.danger_crossfade = false
	conductor.set_danger_track(null)
	conductor.stop_music()
	if conductor.current_track() != null or conductor.is_music_playing():
		_fail("stop_music no apagó la música")
	if conductor.danger != 0.0:
		_fail("cambiar de canción no reinició el peligro")
	print("test_music: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _fail(message: String) -> void:
	_failures += 1
	printerr("  FALLO: ", message)
