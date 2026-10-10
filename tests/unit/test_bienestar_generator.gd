extends SceneTree
## Tests de BienestarGenerator (nivel 3). Ejecutar:
##   godot --headless --path . --script res://tests/unit/test_bienestar_generator.gd

const SEEDS := 150
const Block := BienestarMapData.Block

var _failures := 0
var _count := {}


func _initialize() -> void:
	_test_same_seed_same_store()
	for mode in [BienestarParams.Mode.SUPERMARKET, BienestarParams.Mode.MALL]:
		for s in range(1, SEEDS + 1):
			var params := BienestarParams.new()
			params.seed = s
			params.mode = mode
			# Variación de tamaños para cubrir los extremos.
			params.sections = 3 + s % 12
			params.floors = 2 + s % 4
			params.escalators_per_floor = 1 + s % 3
			params.shutter_chance = float(s % 5) / 4.0
			params.hole_chance = float(s % 4) / 3.0
			_check_store(BienestarGenerator.generate(params), params)
	print("test_bienestar_generator: %s · %d tiendas · %s" % ["OK" if _failures == 0 else "%d FALLOS" % _failures,
			SEEDS * 2, _count])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		if _failures < 40:
			printerr("  FALLO: ", message)


func _test_same_seed_same_store() -> void:
	for mode in [0, 1]:
		var params := BienestarParams.new()
		params.seed = 777
		params.mode = mode
		var a := BienestarGenerator.generate(params)
		var b := BienestarGenerator.generate(params)
		_check(a.solids == b.solids and a.slabs == b.slabs, "misma seed => mismos sólidos (modo %d)" % mode)
		_check(a.racks.size() == b.racks.size() and a.escalators.size() == b.escalators.size()
				and a.shutters.size() == b.shutters.size(), "misma seed => mismas mecánicas (modo %d)" % mode)


func _check_store(data: BienestarMapData, params: BienestarParams) -> void:
	var tag := "seed %d modo %d" % [params.seed, params.mode]
	_check(data.blocks.size() == data.solids.size(), "%s: cada sólido tiene su tipo" % tag)
	_check(data.goal.has_area(), "%s: hay salida" % tag)
	var top := data.floors.size() - 1
	_check(data.floor_at(data.spawn) == 0, "%s: se entra por el piso 0" % tag)
	_check(data.floor_at(data.goal.end - Vector2(10.0, 2.0)) == top, "%s: la salida está en el último piso" % tag)
	_count["racks"] = _count.get("racks", 0) + data.racks.size()
	_count["escaleras"] = _count.get("escaleras", 0) + data.escalators.size()
	_count["cortinas"] = _count.get("cortinas", 0) + data.shutters.size()
	_count["huecos"] = _count.get("huecos", 0) + data.floors.reduce(func(n: int, f: BienestarMapData.Floor) -> int:
			return n + f.holes.size(), 0)
	# Todo lo que se apoya en el piso se puede saltar (salto base 216 px).
	for block in data.blocks:
		if block.kind == Block.Kind.WALL:
			continue
		_check(block.rect.size.y <= BienestarGenerator.OBSTACLE_MAX + 0.1, "%s: %s de %.0f px de alto" % [
				tag, Block.Kind.keys()[block.kind], block.rect.size.y])
		var f := data.floor_at(block.rect.end - Vector2(1.0, 1.0))
		_check(f >= 0 and absf(block.rect.end.y - data.surface_y(f)) < 0.5, "%s: el sólido se apoya en un piso" % tag)
		if f >= 0:
			_check(not data.floors[f].has_hole(block.rect.position.x) and not data.floors[f].has_hole(block.rect.end.x),
					"%s: sólido sobre un hueco" % tag)
		_check(not block.rect.has_point(data.spawn + Vector2(0.0, -10.0)), "%s: sólido en la entrada" % tag)
	# Entre dos obstáculos del mismo piso queda lugar para aterrizar (o están pegados como un bloque).
	var sorted := data.blocks.filter(func(b: Block) -> bool: return b.kind != Block.Kind.WALL)
	sorted.sort_custom(func(a: Block, b: Block) -> bool:
		return a.rect.end.y < b.rect.end.y or (a.rect.end.y == b.rect.end.y and a.rect.position.x < b.rect.position.x))
	for i in range(1, sorted.size()):
		var a: Block = sorted[i - 1]
		var b: Block = sorted[i]
		if absf(a.rect.end.y - b.rect.end.y) < 0.5:
			var gap := b.rect.position.x - a.rect.end.x
			_check(gap >= BienestarGenerator.LANDING - 0.1, "%s: hueco de %.0f px entre %s y %s" % [tag, gap,
					Block.Kind.keys()[a.kind], Block.Kind.keys()[b.kind]])
	# Racks: viga a la altura fija, piso libre debajo y tramo entre los parantes despejado.
	for rack in data.racks:
		var floor_y := data.surface_y(rack.floor)
		_check(is_equal_approx(floor_y - rack.rect.position.y, BienestarGenerator.RACK_Y), "%s: viga a 180 px" % tag)
		for solid in data.solids:
			_check(not (solid.end.y > rack.rect.end.y and solid.position.x < rack.rect.end.x and solid.end.x > rack.rect.position.x
					and absf(solid.end.y - floor_y) < 0.5), "%s: sólido debajo de un rack" % tag)
	if not data.mall:
		_check(data.floors.size() == 1, "%s: el supermercado tiene un piso" % tag)
		_check(not data.freezers.is_empty(), "%s: siempre hay congelados" % tag)
		_check(not data.belts.is_empty(), "%s: siempre hay cajas con cinta" % tag)
		_check(not data.carts.is_empty(), "%s: hay carritos" % tag)
		return
	# Centro comercial: al menos una escalera mecánica por par de pisos, dentro del edificio y con
	# sus extremos sobre piso (no sobre un hueco, ni pegados a una cortina).
	for f in top:
		var found := data.escalators.filter(func(e: BienestarMapData.Escalator) -> bool: return e.floor == f)
		_check(not found.is_empty(), "%s: sin escalera entre los pisos %d y %d" % [tag, f, f + 1])
	for escalator in data.escalators:
		var lower := data.floors[escalator.floor]
		var upper := data.floors[escalator.floor + 1]
		_check(is_equal_approx(escalator.foot.y, lower.y) and is_equal_approx(escalator.top.y, upper.y), "%s: escalera entre pisos" % tag)
		for point: Vector2 in [escalator.foot, escalator.top]:
			var floor := lower if point == escalator.foot else upper
			_check(point.x > floor.left + 300.0 and point.x < floor.right - 300.0, "%s: escalera dentro del edificio" % tag)
			_check(not floor.has_hole(point.x - 80.0) and not floor.has_hole(point.x + 80.0), "%s: escalera junto a un hueco" % tag)
			for shutter in data.shutters:
				if data.floors[shutter.floor] == floor:
					_check(absf(shutter.x - point.x) > 150.0, "%s: escalera pegada a una cortina" % tag)
		# Cambia de sentido: en algún momento sube.
		var ups := 0
		for bar in params.escalator_bars * 2:
			ups += 1 if escalator.going_up(bar, params.escalator_bars) else 0
		_check(ups > 0 and ups < params.escalator_bars * 2, "%s: la escalera cambia de sentido" % tag)
	for f in data.floors.size():
		for hole in data.floors[f].holes:
			_check(f > 0, "%s: el piso 0 no tiene huecos" % tag)
			_check(hole.y - hole.x <= 360.0, "%s: hueco saltable (%.0f px)" % [tag, hole.y - hole.x])
			_check(not (f == top and data.goal.position.x < hole.y + 200.0 and data.goal.end.x > hole.x - 200.0),
					"%s: hueco junto a la salida" % tag)
	for shutter in data.shutters:
		_check(not data.floors[shutter.floor].has_hole(shutter.x), "%s: cortina sobre un hueco" % tag)
	if params.food_court:
		_check(not data.fryers.is_empty(), "%s: el patio de comidas tiene freidoras" % tag)
