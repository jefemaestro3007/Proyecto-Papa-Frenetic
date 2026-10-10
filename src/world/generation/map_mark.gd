class_name MapMark
extends RefCounted
## Marca decorativa de un mapa (sangre, grietas, papeles...). `weight` (0..1) permite que
## cada estilo muestre solo una fracción (p. ej. sangre: weight < blood_amount) sin regenerar.

enum Type { BLOOD, CRACK, STAIN, RUBBLE, POSTER, GRAFFITI, WALL_UNIT, BONES, PAPERS }

var type: Type
var position: Vector2
var size: float
var weight: float
var variant: int


func _init(p_type: Type, p_position: Vector2, p_size: float, p_weight: float, p_variant: int) -> void:
	type = p_type
	position = p_position
	size = p_size
	weight = p_weight
	variant = p_variant


## Las que se apoyan sobre el suelo; el resto va en paredes o fachadas.
static func on_floor(mark_type: Type) -> bool:
	return mark_type == Type.RUBBLE or mark_type == Type.BONES or mark_type == Type.PAPERS
