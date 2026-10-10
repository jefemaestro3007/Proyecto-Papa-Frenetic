class_name BalloonEnemy
extends FlyingEnemy
## Globos de oferta (Bienestar U): la voladora colgada de globos. Vuela hacia ti igual, pero al
## acercarse se infla y explota en el beat siguiente con un área grande; si te toca antes, explota
## en el acto. Si la derrotas antes de que explote, solo se revientan los globos.

## Explotó en el aire (el combate aplica el daño de área).
signal detonated(balloon: BalloonEnemy)

## Distancia al jugador a la que se arma.
var trigger_distance := 150.0
## Mientras está armada se acerca más lento.
var armed_speed_scale := 0.4

var _fuse_left := -1.0
var _fuse_total := 1.0


func _init() -> void:
	super()
	costume = &"globos"


func is_armed() -> bool:
	return _fuse_left >= 0.0


## 0 al armarse, 1 al explotar.
func arm_progress() -> float:
	return 1.0 - _fuse_left / _fuse_total if is_armed() else 0.0


## Explota ya (al tocar al jugador o desde el combate).
func detonate() -> void:
	if not active:
		return
	detonated.emit(self)
	defeat(0.0, true)


func _move(delta: float) -> void:
	if is_armed():
		_fuse_left -= delta
		if _fuse_left <= 0.0:
			detonate()
			return
		var speed := fly_speed
		fly_speed = speed * armed_speed_scale
		super(delta)
		fly_speed = speed
		return
	super(delta)
	if _awake and body_center().distance_to(target.global_position + target_offset) <= trigger_distance:
		_arm()


## Se arma para explotar en un beat (al menos tres cuartos de beat de aviso).
func _arm() -> void:
	var beat := Conductor.beat_length()
	var left := (1.0 - Conductor.phase()) * beat
	if left < beat * 0.75:
		left += beat
	_fuse_left = left
	_fuse_total = left
