class_name SfxPlayer
extends Node
## Efectos de sonido de la partida. Carga los `SoundEffect` de `DIRECTORY` agrupados por prefijo y
## `play(grupo)` toca una variante al azar (sin repetir la anterior si hay más de una). Usa un pool
## de reproductores para que los sonidos se superpongan sin cortarse. En headless no suena, pero
## registra lo pedido en `history` (para los tests).

const DIRECTORY := "res://src/shared/resources/sfx/"
const VOICES := 8
const HISTORY_SIZE := 32

## Grupo → Array[SoundEffect].
var groups := {}
## Últimos grupos pedidos, del más viejo al más nuevo.
var history: Array[StringName] = []

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for file in ResourceLoader.list_directory(DIRECTORY):
		if not file.ends_with(".tres"):
			continue
		var effect := load(DIRECTORY + file) as SoundEffect
		if effect == null or effect.stream == null:
			continue
		var group := StringName(file.get_basename().get_slice("_", 0))
		if not groups.has(group):
			groups[group] = []
		groups[group].append(effect)
	for _i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = GameSettings.SFX_BUS
		add_child(player)
		_players.append(player)


func play(group: StringName) -> void:
	var effects: Array = groups.get(group, [])
	if effects.is_empty():
		return
	history.append(group)
	if history.size() > HISTORY_SIZE:
		history.pop_front()
	var params := Conductor.params
	if not params.sfx_enabled or not ConductorClock._can_play_audio():
		return
	var index := _rng.randi_range(0, effects.size() - 1)
	if effects.size() > 1 and index == _last.get(group, -1):
		index = (index + 1) % effects.size()
	_last[group] = index
	var effect: SoundEffect = effects[index]
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = effect.stream
	player.volume_db = params.sfx_volume_db + effect.volume_db
	player.pitch_scale = 1.0 + _rng.randf_range(-effect.pitch_variation, effect.pitch_variation)
	player.play()
