extends SceneTree
## Verifica las canciones (`MusicTrack`) y que el Conductor tome su tempo. Ejecutar:
##   godot --headless --path . --script res://tests/unit/test_music.gd

const MUSIC := "res://src/shared/resources/music/"
## BPM medido de cada canción y compases que dura (todas empiezan en el beat).
const EXPECTED := {
	"nivel_uno": [177.0, 65],
	"industrial": [175.0, 21],
	"centro_comercial": [140.0, 22],
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
		var bars: int = EXPECTED[track_name][1]
		if track.length_beats() != bars * ConductorClock.BEATS_PER_BAR:
			_fail("%s: %d beats, se esperaban %d compases" % [track_name, track.length_beats(), bars])

	# El autoload termina de armarse en el primer frame.
	await process_frame
	var conductor: ConductorClock = root.get_node("Conductor")
	var track := load(MUSIC + "nivel_uno.tres") as MusicTrack
	conductor.play_track(track)
	if not is_equal_approx(conductor.params.bpm, track.bpm) or conductor.current_track() != track:
		_fail("el Conductor no tomó el tempo de la canción")
	if conductor.beat_position() != 0.0:
		_fail("play_track no reinició el reloj")
	conductor.stop_music()
	if conductor.current_track() != null or conductor.is_music_playing():
		_fail("stop_music no apagó la música")
	print("test_music: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _fail(message: String) -> void:
	_failures += 1
	printerr("  FALLO: ", message)
