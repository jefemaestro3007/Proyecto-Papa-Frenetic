class_name ConductorClock
extends Node
## Reloj musical global (autoload `Conductor`). Única fuente de verdad del tempo:
## todo lo que late o juzga ritmo pregunta aquí, nunca a TIME por su cuenta.
## Su configuración vive en `params` (RhythmParams) y se puede cambiar en caliente.
## Con una canción (`play_track`) el reloj sigue la posición de reproducción del audio, así los
## beats caen sobre la música; sin canción (o en headless) avanza solo con el tiempo de juego.

signal beat(index: int)
## Semicorchea (SUBDIVISIONS por beat): para patrones rápidos (p. ej. la tiradora).
signal subbeat(index: int)
signal track_changed(track: MusicTrack)

enum Judgment { PERFECT, GOOD, MISS }

const SUBDIVISIONS := 4
const BEATS_PER_BAR := 4
## Más desfase que esto entre el reloj y la música (inicio, salto, tirón) se corrige de golpe;
## menos, se corrige suave para que los beats no tiemblen.
const MUSIC_SNAP := 0.08
const MUSIC_CORRECTION := 8.0

var params := RhythmParams.new()

var _time := 0.0
var _bpm := 0.0
var _last_beat := -1
var _last_subbeat := -1
## Parte de Engine.time_scale que viene de un hitstop: el reloj la compensa para que congelar
## la acción no desplace los beats (la escala de tiempo de debug sí ralentiza la música).
## Solo lectura: se pide con `set_hitstop()`.
var hitstop_scale := 1.0
var _pending_hitstop := 1.0
var _click: AudioStreamPlayer
var _music: AudioStreamPlayer
var _track: MusicTrack
## Vueltas completas de la canción en bucle y última posición leída (para detectar la vuelta).
var _loops := 0
var _last_song_position := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bpm = params.bpm
	_click = AudioStreamPlayer.new()
	_click.stream = _make_click()
	add_child(_click)
	_music = AudioStreamPlayer.new()
	add_child(_music)


func _exit_tree() -> void:
	_click.stop()
	_click.stream = null
	_music.stop()
	_music.stream = null


## Reproduce `track` en bucle desde el principio y reinicia el reloj en el beat 0.
## `null` (o la música desactivada) la apaga y el reloj sigue solo.
func play_track(track: MusicTrack) -> void:
	_track = track
	_music.stop()
	_music.stream = null
	if track != null and track.stream != null and params.music_enabled:
		# El tempo es el de la canción aunque no se pueda oír (headless): mismo juego en los tests.
		params.bpm = track.bpm
		_bpm = track.bpm
		if _can_play_audio():
			_music.stream = _looping(track.stream)
			_update_music_mix()
			_music.play()
	restart()
	track_changed.emit(track)


func stop_music() -> void:
	play_track(null)


func current_track() -> MusicTrack:
	return _track


func is_music_playing() -> bool:
	return _music.playing and _track != null


## Vuelve al beat 0 (y la canción al principio).
func restart() -> void:
	_time = 0.0
	_loops = 0
	_last_song_position = 0.0
	_last_beat = -1
	_last_subbeat = -1
	if is_music_playing():
		_music.seek(0.0)


func _process(delta: float) -> void:
	if not is_equal_approx(_bpm, params.bpm):
		# Conserva la posición en el compás al cambiar de tempo.
		var position := beat_position()
		_bpm = clampf(params.bpm, 60.0, 240.0)
		_time = position * beat_length()
	if _track != null and _track.stream != null and _can_play_audio() \
			and params.music_enabled != (_music.stream != null):
		# Se activó o desactivó la música desde el menú.
		play_track(_track)
	if is_music_playing():
		_follow_music(delta / maxf(hitstop_scale, 0.001))
	else:
		_time += delta / maxf(hitstop_scale, 0.001)
	_apply_hitstop()
	var sub := floori(beat_position() * SUBDIVISIONS)
	if sub != _last_subbeat:
		_last_subbeat = sub
		subbeat.emit(sub)
	var index := floori(beat_position())
	if index != _last_beat:
		_last_beat = index
		beat.emit(index)
		if params.metronome_enabled and (params.metronome_over_music or not is_music_playing()):
			_click.volume_db = params.metronome_volume_db
			_click.pitch_scale = 1.6 if index % BEATS_PER_BAR == 0 else 1.0
			_click.play()


## Avanza con el tiempo de juego y corrige hacia la posición real de la música: la posición de
## reproducción solo se actualiza por bloques de mezcla, así que no se usa sola.
func _follow_music(step: float) -> void:
	_update_music_mix()
	var raw := _music.get_playback_position()
	if raw < _last_song_position - 1.0:
		_loops += 1
	_last_song_position = raw
	var song := raw + (AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()) \
			* _music.pitch_scale
	var length := _music.stream.get_length()
	var beats := (_loops * length + song - _track.first_beat) * _track.bpm / 60.0
	var target := beats * beat_length()
	_time += step
	var error := target - _time
	if absf(error) > MUSIC_SNAP:
		_time = target
	else:
		# Nunca hacia atrás: los beats ya emitidos no se repiten.
		_time += maxf(error * minf(step * MUSIC_CORRECTION, 1.0), -step * 0.5)


## Volumen y velocidad de la canción: el BPM de debug la acelera y la escala de tiempo de debug la
## frena (el hitstop no, igual que no mueve los beats).
func _update_music_mix() -> void:
	if _track == null:
		return
	_music.volume_db = params.music_volume_db + _track.volume_db
	var debug_scale := Engine.time_scale / maxf(hitstop_scale, 0.001)
	_music.pitch_scale = clampf(params.bpm / _track.bpm * debug_scale, 0.05, 4.0)


## Copia de la canción en bucle completo (el import no se versiona, así que se fija aquí).
static func _looping(stream: AudioStream) -> AudioStream:
	var copy := stream.duplicate() as AudioStream
	if copy is AudioStreamWAV:
		var wav := copy as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	elif copy is AudioStreamOggVorbis or copy is AudioStreamMP3:
		copy.set(&"loop", true)
	return copy


## Sin dispositivo de audio real (headless, tests) la música no avanzaría: el reloj va solo.
static func _can_play_audio() -> bool:
	return DisplayServer.get_name() != "headless"


## Congela la acción (`scale` < 1) o la libera (1) sin mover los beats. El cambio se aplica en el
## próximo `_process` del reloj, después de consumir el delta del frame: Godot calcula ese delta
## con la escala vigente al empezar el frame, así que cambiarla antes desfasaría el beat.
func set_hitstop(scale: float) -> void:
	_pending_hitstop = clampf(scale, 0.001, 1.0)


func _apply_hitstop() -> void:
	if is_equal_approx(_pending_hitstop, hitstop_scale):
		return
	var base := Engine.time_scale / maxf(hitstop_scale, 0.001)
	hitstop_scale = _pending_hitstop
	Engine.time_scale = base * hitstop_scale


func beat_length() -> float:
	return 60.0 / _bpm


func beat_position() -> float:
	return _time / beat_length()


func beat_index() -> int:
	return floori(beat_position())


## 0 justo en el beat, sube hasta 1 justo antes del siguiente.
func phase() -> float:
	return fposmod(beat_position(), 1.0)


## 1 en el beat y decae exponencialmente; útil para que algo "lata".
func pulse(sharpness: float = 7.0) -> float:
	return exp(-phase() * sharpness)


## Distancia con signo al beat más cercano, en segundos.
func offset_to_beat() -> float:
	var position := (_time - params.input_offset) / beat_length()
	return (position - roundf(position)) * beat_length()


func judge() -> Judgment:
	var offset := absf(offset_to_beat())
	if offset <= params.perfect_window:
		return Judgment.PERFECT
	if offset <= params.good_window:
		return Judgment.GOOD
	return Judgment.MISS


## Clic de metrónomo sintetizado (seno con caída rápida) para no depender de assets.
static func _make_click() -> AudioStreamWAV:
	const RATE := 44100
	var samples := int(RATE * 0.04)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t := float(i) / RATE
		var s := sin(TAU * 1600.0 * t) * exp(-t * 90.0)
		data.encode_s16(i * 2, int(s * 26000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
