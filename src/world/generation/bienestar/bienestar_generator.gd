class_name BienestarGenerator
extends RefCounted
## Genera Bienestar U (nivel 3) a partir de BienestarParams, sin nodos ni estado global: todo el
## azar sale de RNGs sembrados con `params.seed`.
## - Supermercado: un piso largo de izquierda a derecha. Entrada → secciones (pasillos con racks,
##   congelados, frutas y verduras, piso mojado, carritos) → cajas con cinta → salida.
## - Centro comercial: varios pisos con locales al fondo, escaleras mecánicas entre pisos, huecos
##   del atrio, cortinas metálicas que cruzan el pasillo y patio de comidas arriba. Se entra abajo
##   a la izquierda y se sale arriba a la derecha.
## Alturas pensadas para el salto base (216 px): obstáculos ≤ OBSTACLE_MAX, vigas de rack a RACK_Y.

const Section := BienestarMapData.Section
const Prop := BienestarMapData.Prop
const HangingSign := BienestarMapData.HangingSign
const Block := BienestarMapData.Block

const SNAP := 10.0
const WALL := 60.0
const SLAB := 40.0
const GROUND_DEPTH := 600.0
## Cara de arriba de la viga de un rack (sobre el piso) y su grosor.
const RACK_Y := 180.0
const RACK_BEAM := 16.0
const OBSTACLE_MIN := 60.0
const OBSTACLE_MAX := 150.0
## Hueco libre mínimo entre obstáculos (para aterrizar y tomar impulso).
const LANDING := 160.0
const GONDOLA_STEP := 420.0
const GONDOLA_WIDTH := 260.0
const FREEZER_WIDTH := 150.0
const FREEZER_HEIGHT := 290.0
const COUNTER := Vector2(340.0, 100.0)
const ESCALATOR_RUN := 560.0
## Lo que se aleja todo (escaleras, huecos, cortinas) de los puntos clave.
const KEEP_CLEAR := 260.0
## Los detalles usan su propio RNG: cambiarlos nunca altera el trazado.
const DETAIL_SALT := 0x5a1e
const LAYOUT_SALT := 0xb1e5

const CATEGORIES: Array[String] = ["LÁCTEOS", "PANADERÍA", "BEBIDAS", "SNACKS", "LIMPIEZA", "CONSERVAS",
		"PAPAS FRITAS", "CEREALES", "MASCOTAS", "PERFUMERÍA", "ARROZ Y FIDEOS", "DULCES", "CONGELADOS", "TÉ Y CAFÉ"]
const STORE_NAMES: Array[String] = ["PAPAS & CO", "TODO A $990", "ZAPATERÍA EL TUBÉRCULO", "FARMACIA BIEN",
		"ÓPTICA OJO DE PAPA", "JUGUETERÍA FRITA", "ELECTRO PURÉ", "LIBRERÍA LA CÁSCARA", "MODA ALMIDÓN",
		"CELULARES YA", "PELUQUERÍA RIZOS", "DEPORTES TRAMPOLÍN", "BAZAR TODO SUELTO", "CAFÉ AL BEAT",
		"PERFUMES AROMA", "MASCOTAS FELICES", "ROPA DE CAMA", "RELOJERÍA TIC TAC"]
const STORE_COLORS: Array[Color] = [Color("ffd400"), Color("4fb3c9"), Color("8fbf4d"), Color("ef6657"),
		Color("eee6dc"), Color("c98bdb"), Color("f29b38")]
const PRICES: Array[String] = ["$990", "$1.490", "$2x1", "$590", "-30%", "$3.990", "LLEVE 3", "$790"]


static func generate(params: BienestarParams) -> BienestarMapData:
	var data := BienestarMapData.new()
	data.depth = params.depth
	data.mall = params.is_mall()
	var rng := RandomNumberGenerator.new()
	rng.seed = params.seed ^ LAYOUT_SALT
	var detail := RandomNumberGenerator.new()
	detail.seed = params.seed ^ DETAIL_SALT
	if data.mall:
		_build_mall(data, params, rng, detail)
	else:
		_build_supermarket(data, params, rng, detail)
	_build_lanes(data)
	data.bounds = _bounds(data)
	return data


# --- Supermercado --------------------------------------------------------------------

static func _build_supermarket(data: BienestarMapData, params: BienestarParams, rng: RandomNumberGenerator,
		detail: RandomNumberGenerator) -> void:
	var order := _supermarket_order(params, rng)
	var x := 0.0
	var spans: Array[Vector3] = []
	for type: Section in order:
		var width := _section_width(type, params, rng)
		spans.append(Vector3(type, x, x + width))
		x += width
	var floor := BienestarMapData.Floor.new(0.0, -params.ceiling_height, 0.0, x)
	data.floors.append(floor)
	data.slabs.append(Rect2(-WALL - 400.0, 0.0, x + WALL * 2.0 + 800.0, GROUND_DEPTH))
	_solid(data, Rect2(-WALL, floor.ceiling, WALL, -floor.ceiling), Block.Kind.WALL, 0)
	_solid(data, Rect2(x, floor.ceiling, WALL, -floor.ceiling), Block.Kind.WALL, 1)
	var aisle := 1
	for span in spans:
		var type: Section = int(span.x)
		data.sections.append(BienestarMapData.SectionSpan.new(type, 0, span.y, span.z))
		match type:
			Section.ENTRANCE:
				_entrance(data, 0, span.y, span.z, detail)
			Section.AISLES:
				aisle = _aisles(data, params, span.y, span.z, aisle, rng, detail)
			Section.FREEZERS:
				_freezers(data, span.y, span.z, rng, detail)
			Section.PRODUCE:
				_produce(data, params, span.y, span.z, rng, detail)
			Section.WET:
				_wet_section(data, span.y, span.z, rng, detail)
			Section.CARTS:
				_cart_run(data, span.y, span.z, rng, detail)
			Section.CHECKOUTS:
				_checkouts(data, params, span.y, span.z, detail)
			Section.EXIT:
				_exit(data, 0, span.y, span.z)
		# Tragaluces: el cielo rojo por el techo, uno por sección como mucho.
		if type != Section.FREEZERS and detail.randf() < 0.6:
			var w := detail.randf_range(260.0, 520.0)
			var at := detail.randf_range(span.y + 80.0, maxf(span.y + 80.0, span.z - w - 80.0))
			data.skylights.append(Vector3(0, at, at + w))
		_hanging_signs(data, params, 0, span.y, span.z, type, detail)


## Entrada, secciones al azar sin repetir dos seguidas (con al menos un pasillo y congelados),
## cajas y salida.
static func _supermarket_order(params: BienestarParams, rng: RandomNumberGenerator) -> Array:
	var weights := {
		Section.AISLES: params.aisle_weight, Section.FREEZERS: params.freezer_weight,
		Section.PRODUCE: params.produce_weight, Section.WET: params.wet_weight, Section.CARTS: params.cart_weight,
	}
	var middle: Array = []
	var count := maxi(params.sections - 3, 2)
	for i in count:
		var pick: Section = _weighted(rng, weights, middle[-1] if not middle.is_empty() else -1)
		middle.append(pick)
	# Siempre hay pasillos y congelados (las mecánicas principales).
	for required: Section in [Section.AISLES, Section.FREEZERS]:
		if not middle.has(required):
			middle[rng.randi_range(0, middle.size() - 1)] = required
	return [Section.ENTRANCE] + middle + [Section.CHECKOUTS, Section.EXIT]


static func _section_width(type: Section, params: BienestarParams, rng: RandomNumberGenerator) -> float:
	match type:
		Section.ENTRANCE:
			return 1400.0
		Section.AISLES:
			return _snap(rng.randi_range(4, 7) * GONDOLA_STEP + 200.0)
		Section.FREEZERS:
			return _snap(rng.randi_range(6, 10) * (FREEZER_WIDTH + 20.0) + 360.0)
		Section.PRODUCE:
			return _snap(rng.randf_range(1400.0, 1900.0))
		Section.WET:
			return _snap(rng.randf_range(1000.0, 1400.0))
		Section.CARTS:
			return _snap(rng.randf_range(1900.0, 2500.0))
		Section.CHECKOUTS:
			return params.checkouts * (COUNTER.x + 200.0) + 300.0
		Section.EXIT:
			return 1000.0
	return 1200.0


static func _entrance(data: BienestarMapData, f: int, x0: float, x1: float, detail: RandomNumberGenerator) -> void:
	var y := data.floors[f].y
	data.spawn = Vector2(x0 + 260.0, y - 2.0)
	data.props.append(Prop.new(Prop.Type.CART_CORRAL, Rect2(x0 + 480.0, y - 120.0, 300.0, 120.0), detail.randi()))
	if not data.mall:
		data.carts.append(Vector2(x0 + 900.0, y))
	data.props.append(Prop.new(Prop.Type.PRICE_STAND, Rect2(x1 - 300.0, y - 190.0, 120.0, 190.0), detail.randi()))


static func _exit(data: BienestarMapData, f: int, x0: float, x1: float) -> void:
	var y := data.floors[f].y
	data.goal = Rect2(x1 - 460.0, y - 320.0, 340.0, 320.0)
	data.signs.append(HangingSign.new(HangingSign.Type.EXIT, Vector2(x1 - 290.0, y - 420.0), "SALIDA", 0))


## Góndolas al fondo (una cabecera por pasillo) y, en el plano de juego, racks sobre el pasillo
## con pallets entre ellos. Devuelve el próximo número de pasillo.
static func _aisles(data: BienestarMapData, params: BienestarParams, x0: float, x1: float, aisle: int,
		rng: RandomNumberGenerator, detail: RandomNumberGenerator) -> int:
	var y := data.floors[0].y
	var x := x0 + 100.0
	while x + GONDOLA_WIDTH < x1 - 60.0:
		var category := CATEGORIES[detail.randi_range(0, CATEGORIES.size() - 1)]
		data.gondolas.append(BienestarMapData.Gondola.new(0, x, x + GONDOLA_WIDTH, detail.randf_range(300.0, 380.0), aisle,
				category, detail.randf() < params.ruin * 0.3, detail.randi()))
		data.signs.append(HangingSign.new(HangingSign.Type.AISLE, Vector2(x + GONDOLA_WIDTH * 0.5,
				data.floors[0].ceiling + 150.0), "%d · %s" % [aisle, category], detail.randi()))
		aisle += 1
		x += GONDOLA_STEP
	# Plano de juego: tramos alternando rack (pasillo libre debajo) y obstáculos.
	x = x0 + 160.0
	while x < x1 - 300.0:
		if rng.randf() < params.rack_chance:
			var width := _snap(rng.randf_range(300.0, 520.0))
			if x + width > x1 - 160.0:
				break
			data.racks.append(BienestarMapData.Rack.new(0, Rect2(x, y - RACK_Y, width, RACK_BEAM), rng.randi()))
			x += width + _snap(rng.randf_range(LANDING, LANDING + 160.0))
		else:
			var size := Vector2(_snap(rng.randf_range(90.0, 170.0)), _snap(rng.randf_range(OBSTACLE_MIN, OBSTACLE_MAX)))
			if x + size.x > x1 - 160.0:
				break
			_solid(data, Rect2(x, y - size.y, size.x, size.y), Block.Kind.PALLET, detail.randi())
			x += size.x + _snap(rng.randf_range(LANDING + 40.0, LANDING + 240.0))
		if detail.randf() < params.spill_chance * 0.6:
			_add_wet(data, 0, x - 40.0, detail.randf_range(160.0, 260.0))
	return aisle


## Freezers verticales al fondo (abren con el beat) y algún freezer horizontal para saltar.
static func _freezers(data: BienestarMapData, x0: float, x1: float, rng: RandomNumberGenerator,
		detail: RandomNumberGenerator) -> void:
	var y := data.floors[0].y
	var x := x0 + 180.0
	var i := 0
	while x + FREEZER_WIDTH < x1 - 180.0:
		data.freezers.append(BienestarMapData.Freezer.new(0, Rect2(x, y - FREEZER_HEIGHT, FREEZER_WIDTH, FREEZER_HEIGHT),
				rng.randi_range(0, 3), detail.randi()))
		x += FREEZER_WIDTH + 20.0
		i += 1
	# Freezers horizontales (sólidos bajos) repartidos: obligan a saltar frente a los verticales.
	var chests := rng.randi_range(1, 2) if x1 - x0 >= 1900.0 else 1
	for k in chests:
		var cx := _snap(lerpf(x0 + 400.0, x1 - 600.0, (k + 0.5) / chests))
		_solid(data, Rect2(cx, y - 90.0, 240.0, 90.0), Block.Kind.CHEST_FREEZER, detail.randi())


static func _produce(data: BienestarMapData, params: BienestarParams, x0: float, x1: float, rng: RandomNumberGenerator,
		detail: RandomNumberGenerator) -> void:
	var y := data.floors[0].y
	var x := x0 + 220.0
	while x < x1 - 420.0:
		var size := Vector2(_snap(rng.randf_range(180.0, 260.0)), _snap(rng.randf_range(80.0, 120.0)))
		_solid(data, Rect2(x, y - size.y, size.x, size.y), Block.Kind.STAND, detail.randi())
		x += size.x + _snap(rng.randf_range(LANDING + 60.0, LANDING + 260.0))
		if detail.randf() < 0.5:
			data.props.append(Prop.new(Prop.Type.SCALE, Rect2(x - 120.0, y - 130.0, 60.0, 130.0), detail.randi()))
	# Los rociadores de la verdura dejan el piso mojado.
	if detail.randf() < 0.5 + params.spill_chance:
		_add_wet(data, 0, detail.randf_range(x0 + 300.0, x1 - 600.0), detail.randf_range(220.0, 380.0))


static func _wet_section(data: BienestarMapData, x0: float, x1: float, rng: RandomNumberGenerator,
		detail: RandomNumberGenerator) -> void:
	var y := data.floors[0].y
	var x := x0 + 160.0
	while x < x1 - 300.0:
		var width := _snap(rng.randf_range(260.0, 460.0))
		width = minf(width, x1 - 160.0 - x)
		data.props.append(Prop.new(Prop.Type.STANDEE, Rect2(x - 70.0, y - 110.0, 60.0, 110.0), detail.randi()))
		_add_wet(data, 0, x, width)
		x += width + _snap(rng.randf_range(160.0, 300.0))
	data.props.append(Prop.new(Prop.Type.MOP_BUCKET, Rect2(x1 - 220.0, y - 90.0, 80.0, 90.0), detail.randi()))


static func _cart_run(data: BienestarMapData, x0: float, x1: float, rng: RandomNumberGenerator,
		detail: RandomNumberGenerator) -> void:
	var y := data.floors[0].y
	data.carts.append(Vector2(x0 + 220.0, y))
	if rng.randf() < 0.5:
		data.carts.append(Vector2(x0 + 520.0, y))
	data.props.append(Prop.new(Prop.Type.CART_CORRAL, Rect2(x0 + 60.0, y - 120.0, 260.0, 120.0), detail.randi()))
	var x := x0 + 800.0
	while x < x1 - 300.0:
		data.props.append(Prop.new(Prop.Type.DISPLAY, Rect2(x, y - 150.0, 120.0, 150.0), detail.randi()))
		x += detail.randf_range(380.0, 700.0)


static func _checkouts(data: BienestarMapData, params: BienestarParams, x0: float, x1: float,
		detail: RandomNumberGenerator) -> void:
	var y := data.floors[0].y
	var x := x0 + 200.0
	for i in params.checkouts:
		var rect := Rect2(x, y - COUNTER.y, COUNTER.x, COUNTER.y)
		_solid(data, rect, Block.Kind.COUNTER, detail.randi())
		data.belts.append(BienestarMapData.Belt.new(0, rect, 1.0))
		data.signs.append(HangingSign.new(HangingSign.Type.PRICE, Vector2(x + COUNTER.x * 0.5,
				data.floors[0].ceiling + 220.0), "CAJA %d" % (i + 1), detail.randi()))
		x += COUNTER.x + 200.0


static func _add_wet(data: BienestarMapData, f: int, x: float, width: float) -> void:
	var y := data.floors[f].y
	data.wet.append(Rect2(_snap(x), y - 24.0, _snap(width), 30.0))


## Carteles colgantes de precio y de OFERTA (prismas que giran) repartidos por la sección.
static func _hanging_signs(data: BienestarMapData, params: BienestarParams, f: int, x0: float, x1: float, type: Section,
		detail: RandomNumberGenerator) -> void:
	if type == Section.EXIT or type == Section.AISLES:
		return
	var floor := data.floors[f]
	var x := x0 + detail.randf_range(150.0, 400.0)
	while x < x1 - 200.0:
		if detail.randf() < params.sign_density:
			var offer := detail.randf() < 0.35
			data.signs.append(HangingSign.new(HangingSign.Type.OFFER if offer else HangingSign.Type.PRICE,
					Vector2(x, floor.ceiling + detail.randf_range(130.0, 200.0)),
					"OFERTA" if offer else PRICES[detail.randi_range(0, PRICES.size() - 1)], detail.randi()))
		x += detail.randf_range(380.0, 720.0)


# --- Centro comercial ------------------------------------------------------------------

static func _build_mall(data: BienestarMapData, params: BienestarParams, rng: RandomNumberGenerator,
		detail: RandomNumberGenerator) -> void:
	var count := maxi(params.sections, 3)
	var widths: Array[float] = []
	var width := 0.0
	for i in count:
		widths.append(_snap(rng.randf_range(1300.0, 1800.0)))
		width += widths[-1]
	var top := params.floors - 1
	data.spawn = Vector2(260.0, -2.0)
	for f in params.floors:
		var y := -f * params.floor_height
		var ceiling := y - params.floor_height + SLAB if f < top else y - params.floor_height * 1.3
		data.floors.append(BienestarMapData.Floor.new(y, ceiling, 0.0, width))
	# Secciones por piso: entrada abajo a la izquierda, salida arriba a la derecha, patio de comidas
	# en el último piso.
	for f in params.floors:
		var x := 0.0
		var food := -1
		if f == top and params.food_court:
			food = rng.randi_range(1, count - 2)
		for i in count:
			var type := Section.STORES
			if f == 0 and i == 0:
				type = Section.ENTRANCE
			elif f == top and i == count - 1:
				type = Section.EXIT
			elif i == food:
				type = Section.FOOD_COURT
			data.sections.append(BienestarMapData.SectionSpan.new(type, f, x, x + widths[i]))
			x += widths[i]
	_place_escalators(data, params, rng)
	for span in data.sections:
		match span.type:
			Section.ENTRANCE:
				_entrance(data, span.floor, span.x0, span.x1, detail)
			Section.EXIT:
				_exit(data, span.floor, span.x0, span.x1)
			Section.FOOD_COURT:
				_food_court(data, params, span, rng, detail)
		if span.type != Section.FOOD_COURT:
			_stores(data, params, span, detail)
		if span.type == Section.STORES:
			_mall_section(data, params, span, rng, detail)
		_hanging_signs(data, params, span.floor, span.x0, span.x1, span.type, detail)
		if span.floor == top and detail.randf() < 0.8:
			var w := detail.randf_range(400.0, 800.0)
			data.skylights.append(Vector3(top, span.x0 + 100.0, minf(span.x0 + 100.0 + w, span.x1 - 100.0)))
	_build_slabs(data, width)


## Escaleras mecánicas: por cada par de pisos, `escalators_per_floor` en secciones distintas, lejos
## de la entrada, la salida y entre sí. Al menos una siempre.
static func _place_escalators(data: BienestarMapData, params: BienestarParams, rng: RandomNumberGenerator) -> void:
	var width := data.floors[0].right
	for f in data.floors.size() - 1:
		var placed: Array[float] = []
		var tries := 0
		while placed.size() < params.escalators_per_floor and tries < 60:
			tries += 1
			var dir := 1.0 if rng.randf() < 0.5 else -1.0
			var foot := _snap(rng.randf_range(600.0, width - 600.0))
			var top := foot + dir * ESCALATOR_RUN
			if top < 400.0 or top > width - 400.0:
				continue
			var lo := minf(foot, top)
			var hi := maxf(foot, top)
			if placed.any(func(other: float) -> bool: return absf(other - (lo + hi) * 0.5) < ESCALATOR_RUN + KEEP_CLEAR * 2.0):
				continue
			if absf(foot - data.spawn.x) < KEEP_CLEAR and f == 0:
				continue
			if f == 0 and lo < 1300.0:
				continue
			if f + 1 == data.floors.size() - 1 and hi > width - 900.0:
				continue
			placed.append((lo + hi) * 0.5)
			data.escalators.append(BienestarMapData.Escalator.new(f, Vector2(foot, data.floors[f].y),
					Vector2(top, data.floors[f + 1].y), rng.randf() < 0.5, rng.randi_range(0, params.escalator_bars - 1)))
		if placed.is_empty():
			# Último recurso: una escalera en el medio.
			var foot := _snap(width * 0.5)
			data.escalators.append(BienestarMapData.Escalator.new(f, Vector2(foot, data.floors[f].y),
					Vector2(foot + ESCALATOR_RUN, data.floors[f + 1].y), true, 0))


## Si `x` en el piso `f` está lejos de escaleras, cortinas, entrada y salida.
static func _clear_at(data: BienestarMapData, f: int, x0: float, x1: float) -> bool:
	for escalator in data.escalators:
		for point: Vector2 in [escalator.foot, escalator.top]:
			var point_floor := escalator.floor if point == escalator.foot else escalator.floor + 1
			if point_floor == f and point.x > x0 - KEEP_CLEAR and point.x < x1 + KEEP_CLEAR:
				return false
		# La escalera pasa por detrás de la losa de arriba: ahí no hay hueco.
		var lo := minf(escalator.foot.x, escalator.top.x)
		var hi := maxf(escalator.foot.x, escalator.top.x)
		if escalator.floor + 1 == f and x1 > lo - 60.0 and x0 < hi + 60.0:
			return false
	for shutter in data.shutters:
		if shutter.floor == f and shutter.x > x0 - KEEP_CLEAR and shutter.x < x1 + KEEP_CLEAR:
			return false
	if f == 0 and data.spawn.x > x0 - KEEP_CLEAR * 2.0 and data.spawn.x < x1 + KEEP_CLEAR * 2.0:
		return false
	if data.goal.has_area() and f == data.floors.size() - 1 and data.goal.end.x > x0 - KEEP_CLEAR \
			and data.goal.position.x < x1 + KEEP_CLEAR:
		return false
	for floor_hole in data.floors[f].holes:
		if x1 > floor_hole.x - LANDING and x0 < floor_hole.y + LANDING:
			return false
	return true


## Sección de locales: cortina que cruza el pasillo, hueco del atrio, maceteros y bancas.
static func _mall_section(data: BienestarMapData, params: BienestarParams, span: BienestarMapData.SectionSpan, rng: RandomNumberGenerator,
		detail: RandomNumberGenerator) -> void:
	var f := span.floor
	var y := data.floors[f].y
	if rng.randf() < params.shutter_chance:
		var x := _snap(rng.randf_range(span.x0 + 300.0, span.x1 - 300.0))
		if _clear_at(data, f, x - 20.0, x + 20.0):
			var name := STORE_NAMES[detail.randi_range(0, STORE_NAMES.size() - 1)]
			data.shutters.append(BienestarMapData.Shutter.new(f, x, 40.0, rng.randi_range(0, 31), name))
	if f > 0 and rng.randf() < params.hole_chance:
		var w := _snap(rng.randf_range(260.0, 340.0))
		var x := _snap(rng.randf_range(span.x0 + 200.0, span.x1 - 200.0 - w))
		if _clear_at(data, f, x, x + w):
			data.floors[f].holes.append(Vector2(x, x + w))
	var x := span.x0 + detail.randf_range(150.0, 350.0)
	while x < span.x1 - 250.0:
		var roll := rng.randf()
		if roll < 0.3 and _clear_at(data, f, x, x + 160.0):
			var h := _snap(rng.randf_range(70.0, 110.0))
			_solid(data, Rect2(x, y - h, 160.0, h), Block.Kind.PLANTER, detail.randi())
			x += 160.0
		elif roll < 0.55:
			data.props.append(Prop.new(Prop.Type.BENCH if detail.randf() < 0.5 else Prop.Type.PLANT,
					Rect2(x, y - 110.0, 140.0, 110.0), detail.randi()))
			x += 140.0
		elif roll < 0.65:
			data.props.append(Prop.new(Prop.Type.KIOSK, Rect2(x, y - 200.0, 180.0, 200.0), detail.randi()))
			x += 180.0
		x += rng.randf_range(LANDING + 120.0, LANDING + 420.0)


## Patio de comidas: mostradores de freidoras (sólidos que salpican aceite) y mesas.
static func _food_court(data: BienestarMapData, params: BienestarParams, span: BienestarMapData.SectionSpan, rng: RandomNumberGenerator,
		detail: RandomNumberGenerator) -> void:
	var f := span.floor
	var y := data.floors[f].y
	var x := span.x0 + 200.0
	var phase := 0
	while x < span.x1 - 500.0:
		if _clear_at(data, f, x, x + 300.0):
			var rect := Rect2(x, y - 110.0, 300.0, 110.0)
			_solid(data, rect, Block.Kind.FRYER, detail.randi())
			data.fryers.append(BienestarMapData.Fryer.new(f, rect, phase % maxi(params.fryer_every, 1)))
			phase += 1
		x += 300.0 + _snap(rng.randf_range(LANDING + 80.0, LANDING + 200.0))
		if x < span.x1 - 300.0 and detail.randf() < 0.7:
			data.props.append(Prop.new(Prop.Type.TABLE, Rect2(x - 150.0, y - 80.0, 110.0, 80.0), detail.randi()))
	# Siempre al menos una freidora: si las escaleras ocupan el lugar, la primera x libre de sus pies.
	if phase == 0:
		var cx := span.x0 + 100.0
		while cx < span.x1 - 340.0:
			var free := true
			for escalator in data.escalators:
				for point: Vector2 in [escalator.foot, escalator.top]:
					if absf(point.y - y) < 1.0 and point.x > cx - 150.0 and point.x < cx + 370.0:
						free = false
			if free:
				var rect := Rect2(cx, y - 110.0, 220.0, 110.0)
				_solid(data, rect, Block.Kind.FRYER, detail.randi())
				data.fryers.append(BienestarMapData.Fryer.new(f, rect, 0))
				break
			cx += 100.0
	data.stores.append(BienestarMapData.Store.new(f, span.x0 + 80.0, span.x1 - 80.0, "PATIO DE COMIDAS", Color("f29b38"),
			false, detail.randi()))


static func _stores(data: BienestarMapData, params: BienestarParams, span: BienestarMapData.SectionSpan, detail: RandomNumberGenerator) -> void:
	var x := span.x0 + 60.0
	while x < span.x1 - 400.0:
		var w := minf(detail.randf_range(480.0, 760.0), span.x1 - 60.0 - x)
		var name := STORE_NAMES[detail.randi_range(0, STORE_NAMES.size() - 1)]
		if span.type == Section.ENTRANCE or span.type == Section.EXIT:
			name = "BIENESTAR U"
		data.stores.append(BienestarMapData.Store.new(span.floor, x, x + w, name,
				STORE_COLORS[detail.randi_range(0, STORE_COLORS.size() - 1)], detail.randf() < params.ruin * 0.6,
				detail.randi()))
		x += w + detail.randf_range(40.0, 120.0)


## Losas: el piso 0 es suelo macizo; los demás, losas finas con los huecos del atrio recortados.
static func _build_slabs(data: BienestarMapData, width: float) -> void:
	data.slabs.append(Rect2(-WALL - 400.0, 0.0, width + WALL * 2.0 + 800.0, GROUND_DEPTH))
	for f in range(1, data.floors.size()):
		var floor := data.floors[f]
		var holes := floor.holes.duplicate()
		holes.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var x := -WALL
		for hole: Vector2 in holes:
			data.slabs.append(Rect2(x, floor.y, hole.x - x, SLAB))
			x = hole.y
		data.slabs.append(Rect2(x, floor.y, width + WALL - x, SLAB))
	for floor in data.floors:
		_solid(data, Rect2(-WALL, floor.ceiling, WALL, floor.y - floor.ceiling), Block.Kind.WALL, 0)
		_solid(data, Rect2(width, floor.ceiling, WALL, floor.y - floor.ceiling), Block.Kind.WALL, 1)


# --- Común -------------------------------------------------------------------------------

static func _solid(data: BienestarMapData, rect: Rect2, kind: Block.Kind, variant: int) -> void:
	data.solids.append(rect)
	data.blocks.append(Block.new(kind, rect, variant))


## Carriles de las papas: tramos de cada piso sin sólidos, huecos ni cortinas, de al menos 300 px.
static func _build_lanes(data: BienestarMapData) -> void:
	for f in data.floors.size():
		var floor := data.floors[f]
		var cuts: Array[Vector2] = []
		for solid in data.solids:
			if absf(solid.end.y - floor.y) < 1.0 and solid.size.y < floor.y - floor.ceiling - 1.0:
				cuts.append(Vector2(solid.position.x - 40.0, solid.end.x + 40.0))
		for hole in floor.holes:
			cuts.append(Vector2(hole.x - 40.0, hole.y + 40.0))
		for shutter in data.shutters:
			if shutter.floor == f:
				cuts.append(Vector2(shutter.x - 60.0, shutter.x + shutter.width + 60.0))
		for belt in data.belts:
			if belt.floor == f:
				cuts.append(Vector2(belt.rect.position.x - 40.0, belt.rect.end.x + 40.0))
		cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var x := floor.left + 60.0
		for cut in cuts:
			if cut.x - x >= 300.0:
				data.lanes.append(Vector3(f, x, cut.x))
			x = maxf(x, cut.y)
		if floor.right - 60.0 - x >= 300.0:
			data.lanes.append(Vector3(f, x, floor.right - 60.0))


static func _bounds(data: BienestarMapData) -> Rect2:
	var top := data.floors[-1].ceiling - 200.0
	var right := data.floors[0].right
	return Rect2(-WALL - 200.0, top, right + WALL * 2.0 + 400.0, -top + 200.0)


static func _weighted(rng: RandomNumberGenerator, weights: Dictionary, avoid: int) -> int:
	var total := 0.0
	for key: int in weights:
		if key != avoid:
			total += weights[key]
	if total <= 0.0:
		return weights.keys()[0]
	var roll := rng.randf() * total
	for key: int in weights:
		if key == avoid:
			continue
		roll -= weights[key]
		if roll <= 0.0:
			return key
	return weights.keys()[-1]


static func _snap(value: float) -> float:
	return roundf(value / SNAP) * SNAP
