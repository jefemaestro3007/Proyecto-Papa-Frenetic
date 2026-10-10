class_name GuardEnemy
extends TankEnemy
## Guardia (Bienestar U): el tanque vestido de seguridad. Conserva su vida alta pero corre muy
## rápido; al alcanzarte te empuja hacia la papa más cercana y, si no hay otra cerca, te cobra más
## calor (lo resuelve el combate). Después de alcanzarte descansa un momento.

var rest_seconds := 0.8
var _rest_left := 0.0


func _init() -> void:
	super()
	costume = &"guardia"


## Alcanzó al jugador: se queda quieto un momento (si no, lo volvería a tocar enseguida).
func rest() -> void:
	_rest_left = rest_seconds


func is_resting() -> bool:
	return _rest_left > 0.0


func _move(delta: float) -> void:
	if _rest_left > 0.0:
		_rest_left = maxf(_rest_left - delta, 0.0)
		return
	super(delta)
