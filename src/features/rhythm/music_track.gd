@tool
class_name MusicTrack
extends Resource
## Una canción del juego con su tempo. El `Conductor` la reproduce en bucle y sigue su posición
## de reproducción: los beats del juego caen sobre los de la música.
## El BPM y el primer beat se midieron analizando el audio (las canciones vienen de LMMS, a
## tempo fijo y sin silencio al inicio).

@export var title: String = ""
@export var stream: AudioStream
@export_range(60.0, 240.0, 0.01) var bpm: float = 120.0
## Segundos desde el inicio del archivo hasta el primer beat.
@export_range(0.0, 5.0, 0.001) var first_beat: float = 0.0
@export_range(-40.0, 12.0) var volume_db: float = 0.0


## Beats completos que dura la canción (el bucle se cuenta en beats enteros para no desfasar).
func length_beats() -> int:
	if stream == null:
		return 0
	return maxi(roundi((stream.get_length() - first_beat) * bpm / 60.0), 1)
