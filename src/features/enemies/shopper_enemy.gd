class_name ShopperEnemy
extends Enemy
## Cliente (Bienestar U): la papa común vestida, con su bolsa de compras siempre en la mano.
## Persigue igual que la común; al morir se le caen las compras y el piso queda resbaloso unos
## beats (lo resuelve el combate con `FloorHazards`).

## Murió con los pies en `feet`: ahí quedan las compras.
signal spilled(feet: Vector2)


func _init() -> void:
	costume = &"cliente"


func defeat(direction := 0.0, strong := false) -> void:
	if not active:
		return
	var feet := global_position
	super(direction, strong)
	spilled.emit(feet)
