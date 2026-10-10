class_name PromoterEnemy
extends ThrowerEnemy
## Promotora de degustación (Bienestar U): la tiradora vestida, con delantal y bandeja. Lanza
## igual, al ritmo, pero sus muestras van en llamas: al impactar te queman unos beats y si caen al
## piso dejan fuego (lo resuelve el combate con `FloorHazards`).


func _init() -> void:
	super()
	costume = &"promotora"
