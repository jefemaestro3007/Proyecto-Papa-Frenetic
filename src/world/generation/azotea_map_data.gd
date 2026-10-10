class_name AzoteaMapData
extends RefCounted
## Resultado puro de AzoteaGenerator: geometría de juego (azoteas) y de fondo (skyline).

## Cada azotea es el rectángulo sólido del edificio; `position.y` es la superficie pisable.
var roofs: Array[Rect2] = []
var spawn: Vector2 = Vector2.ZERO
## Y por debajo de la cual se considera caída al vacío.
var kill_y: float = 0.0
var far: SkylineData = SkylineData.new()
var near: SkylineData = SkylineData.new()


class SkylineData:
	extends RefCounted
	var buildings: Array[PackedVector2Array] = []
	var windows: Array[Rect2] = []
	var width: float = 0.0
