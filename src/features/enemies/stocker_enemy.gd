class_name StockerEnemy
extends ChargerEnemy
## Reponedor (Bienestar U): la embestidora vestida, con gorra y carrito. Al verte avisa como ella,
## pero primero lanza el carrito por su carril y se lanza detrás `lead_seconds` después. Tras el
## aturdimiento saca otro carrito.

## Suelta el carrito (lo crea el combate: `ShoppingCart`).
signal cart_thrown(stocker: StockerEnemy)

var has_cart := true
## Tiempo entre lanzar el carrito y lanzarse ella.
var lead_seconds := 0.4


func _init() -> void:
	super()
	costume = &"reponedor"


func _move(delta: float) -> void:
	# Al terminar el aviso con carrito: lo lanza y vuelve a esperar antes de cargar.
	if state == State.WINDUP and has_cart and _state_time - delta <= 0.0:
		has_cart = false
		_charge_direction = facing
		cart_thrown.emit(self)
		_enter(State.WINDUP, lead_seconds)
		return
	var before := state
	super(delta)
	if before == State.RECOVER and state == State.IDLE:
		has_cart = true
