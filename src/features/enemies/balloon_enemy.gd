class_name BalloonEnemy
extends FlyingEnemy
## Globos de oferta (Bienestar U): la voladora colgada de globos. Vuela hacia ti igual, pero al
## acercarse se infla y explota en el beat siguiente con un área grande; si te toca antes, explota
## en el acto. Golpearla no la mata: sale despedida, deja de perseguir y explota unos dos beats
## después (con cuenta atrás), así hay tiempo de alejarse. La explosión le quita una vida a todo
## lo que alcanza (y otros globos golpeados así también se encienden: reacción en cadena).

## Explotó en el aire (el combate aplica el daño de área).
signal detonated(balloon: BalloonEnemy)

## Distancia al jugador a la que se arma.
var trigger_distance := 150.0
## Mientras está armada se acerca más lento.
var armed_speed_scale := 0.4

## Beats de mecha cuando la golpean (explota en el beat que cae cerca de ese plazo).
var struck_fuse_beats := 2.0
## Velocidad con la que sale despedida al golpearla.
var struck_push := 520.0

var _fuse_left := -1.0
var _fuse_total := 1.0
var _struck := false


func _init() -> void:
	super()
	costume = &"globos"


func is_armed() -> bool:
	return _fuse_left >= 0.0


## La golpearon: es una bomba con mecha (no persigue ni se puede volver a golpear).
func is_struck() -> bool:
	return _struck


func is_hittable() -> bool:
	return super() and not _struck


## Beats enteros que faltan para explotar (para la cuenta atrás).
func beats_left() -> int:
	return ceili(_fuse_left / Conductor.beat_length()) if is_armed() else 0


## Un golpe la enciende en vez de matarla: sale despedida y explota en unos dos beats.
func receive_hit(direction: float, _strong: bool, _damage := 1) -> bool:
	if not active or _struck:
		return false
	_struck = true
	_flash = 1.0
	_hurt_left = HURT_POSE_SECONDS
	scale = Vector2(1.3, 0.75)
	velocity = Vector2(signf(direction) if direction != 0.0 else 1.0, -0.6).normalized() * struck_push
	_arm(struck_fuse_beats)
	return false


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
		if _struck:
			_drift(delta)
			return
		var speed := fly_speed
		fly_speed = speed * armed_speed_scale
		super(delta)
		fly_speed = speed
		return
	super(delta)
	if _awake and body_center().distance_to(target.global_position + target_offset) <= trigger_distance:
		_arm()


## Se arma para explotar en el beat que cae a unos `beats` (por defecto el siguiente, con al menos
## tres cuartos de beat de aviso).
func _arm(beats := 1.0) -> void:
	var beat := Conductor.beat_length()
	var left := (1.0 - Conductor.phase()) * beat + (ceilf(beats) - 1.0) * beat
	if left < beat * (beats - 0.25):
		left += beat
	_fuse_left = left
	_fuse_total = left


## Despedida tras el golpe: frena de a poco sin atravesar el escenario.
func _drift(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, struck_push * 1.4 * delta)
	var next := position + velocity * delta
	if _blocker(next).has_area():
		velocity = -velocity * 0.4
	else:
		position = next


## Cuenta atrás en beats sobre los globos mientras está encendida por un golpe.
func _draw_indicators(_center: Vector2) -> void:
	if not _struck or not is_armed():
		return
	var font := MenuStyle.font()
	var label := str(maxi(beats_left(), 1))
	var size := 54
	var at := Vector2(-font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5, _top_y - 70.0)
	draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, FreneticPalette.INK)
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color("ff5a4a") if Conductor.pulse(6.0) > 0.4 else FreneticPalette.YELLOW)
