@tool
class_name RhythmParams
extends Resource
## Tempo y tolerancias del juicio de ritmo. Sección "Ritmo" del menú de debug.

@export_range(60.0, 240.0) var bpm: float = 170.0
@export var metronome_enabled: bool = true
@export_range(-40.0, 6.0) var metronome_volume_db: float = -10.0
## Compensación de latencia de entrada/audio, en segundos (positivo = el jugador llega tarde).
@export_range(-0.2, 0.2) var input_offset: float = 0.0
## Ventanas de juicio a cada lado del beat, en segundos.
@export_range(0.01, 0.2) var perfect_window: float = 0.06
@export_range(0.02, 0.3) var good_window: float = 0.13
## Beats sin ninguna acción a tiempo antes de perder el combo.
@export_range(1, 16) var combo_timeout_beats: int = 4
