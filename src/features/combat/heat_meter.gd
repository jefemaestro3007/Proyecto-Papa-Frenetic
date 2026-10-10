class_name HeatMeter
extends Node
## Calor de la "papa caliente" (0-100), traído del prototipo `feature/gameplay-prototype`.
## Sube solo con el tiempo, al fallar el ritmo y al recibir golpes; baja al acertar.
## Al llegar a 100 no explota de inmediato: se enciende una mecha. Un acierto que enfríe por
## debajo de 100 la apaga, pero la mecha no se recarga: la próxima vez sigue donde quedó.
## Si la mecha llega a 0, la papa explota (game over).

signal heat_changed(heat: float)
signal overheat_started(fuse_left: float)
signal overheat_ended(fuse_left: float)
signal exploded

const MAX_HEAT := 100.0

var params := CombatParams.new()
var heat := 0.0
var fuse_left := 10.0
var overheated := false
var finished := false


func _ready() -> void:
	reset()


func reset() -> void:
	heat = 0.0
	fuse_left = params.fuse_seconds
	overheated = false
	finished = false
	heat_changed.emit(heat)


## Avanza el calor pasivo y, con la mecha encendida, la consume.
func advance(delta: float) -> void:
	if finished or delta <= 0.0 or not params.heat_enabled:
		return
	var remaining := delta
	if not overheated:
		var rate := params.passive_heating
		var to_max := (MAX_HEAT - heat) / rate if rate > 0.0 else INF
		if remaining < to_max:
			_set_heat(heat + rate * remaining)
			remaining = 0.0
		else:
			remaining -= to_max
			_set_heat(MAX_HEAT)
	# El tiempo que sobra tras llegar a 100 ya quema la mecha.
	if overheated and remaining > 0.0:
		fuse_left = maxf(fuse_left - remaining, 0.0)
		if fuse_left <= 0.0:
			_explode()


## Resultado de una acción al ritmo. `scale` ajusta cuánto pesa (p. ej. moverse pesa menos que
## atacar); `can_heat` = false para acciones que solo pueden enfriar.
func apply_judgment(judgment: int, scale := 1.0, can_heat := true) -> float:
	var amount := 0.0
	match judgment:
		ConductorClock.Judgment.PERFECT:
			amount = -params.perfect_cooling * scale
		ConductorClock.Judgment.GOOD:
			amount = -params.good_cooling * scale
		_:
			amount = params.miss_heating * scale if can_heat else 0.0
	change(amount)
	return amount


## Suma (o resta) calor directo: golpes, proyectiles, caídas al vacío.
func change(amount: float) -> void:
	if finished or amount == 0.0 or not params.heat_enabled:
		return
	_set_heat(heat + amount)


## 0 por debajo del umbral de tensión, 1 al llegar a 100 (y durante la mecha).
func intensity() -> float:
	if overheated:
		return 1.0
	var threshold := params.intensity_threshold
	return clampf((heat - threshold) / maxf(MAX_HEAT - threshold, 0.001), 0.0, 1.0)


func _set_heat(value: float) -> void:
	heat = clampf(value, 0.0, MAX_HEAT)
	heat_changed.emit(heat)
	if heat >= MAX_HEAT:
		if not overheated:
			overheated = true
			overheat_started.emit(fuse_left)
			if fuse_left <= 0.0:
				_explode()
	elif overheated:
		overheated = false
		overheat_ended.emit(fuse_left)


func _explode() -> void:
	if finished:
		return
	finished = true
	exploded.emit()
	# Sin game over (pruebas): la papa explota pero el calor vuelve a empezar.
	if not params.game_over_enabled:
		reset()
