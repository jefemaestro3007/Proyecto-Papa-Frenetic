@tool
class_name StoreFixturesView
extends DepthCanvas
## Plano jugable de Bienestar U en perspectiva: sólidos (pallets, puestos de fruta, freezers
## horizontales, cajas con cinta, maceteros, freidoras) como prismas cortos cuyo frente es la
## colisión exacta; racks con su carga (tiemblan y cuentan los beats) y derrumbados; piso mojado;
## carritos (estacionados y el que maneja el jugador); cortinas metálicas con su cuenta atrás; aceite
## de las freidoras y la decoración sin colisión. Lee el estado de BienestarWorld.

const Block := BienestarMapData.Block
const Prop := BienestarMapData.Prop
const BLOCK_DEPTH := 0.07
const PROP_DEPTH := Vector2(0.02, 0.06)
const RACK_COLOR := Color("f29b38")
const CARDBOARD := Color("c9955b")
const STEEL := Color("aeb3c2")
const OIL := Color("f2c14e")
const WARNING := Color("ff5a4a")

var _data: BienestarMapData
var _world: BienestarWorld
var _params: BienestarParams
var _blocks := SpatialIndex.new()
var _racks := SpatialIndex.new()
var _props := SpatialIndex.new()
var _wet := SpatialIndex.new()
var _shutters := SpatialIndex.new()


func setup(data: BienestarMapData, world: BienestarWorld, params: BienestarParams, style: ArtStyle) -> void:
	_data = data
	_world = world
	_params = params
	_style = style
	z_index = -2
	for index: SpatialIndex in [_blocks, _racks, _props, _wet, _shutters]:
		index.clear()
	for i in data.blocks.size():
		_blocks.add(i, data.blocks[i].rect.get_center())
	for i in data.racks.size():
		_racks.add(i, data.racks[i].rect.get_center())
	for i in data.props.size():
		_props.add(i, data.props[i].rect.get_center())
	for i in data.wet.size():
		_wet.add(i, data.wet[i].get_center())
	for i in data.shutters.size():
		_shutters.add(i, Vector2(data.shutters[i].x, data.surface_y(data.shutters[i].floor)))
	queue_redraw()


func _draw() -> void:
	if _data == null or _style == null:
		return
	_begin_frame()
	var view := screen.grow(300.0)
	for i in _wet.query(view):
		_draw_wet(_data.wet[i])
	for i in _props.query(view):
		_draw_prop(_data.props[i])
	for i in _sorted_blocks(_blocks.query(view)):
		_draw_block(_data.blocks[i])
	for i in _racks.query(view):
		_draw_rack(i)
	if _world != null:
		for cart in _world.parked:
			if view.has_point(cart):
				_draw_cart(cart, 1.0, 0.0)
		if _world.riding and _world.player != null:
			var player := _world.player
			_draw_cart(player.global_position + Vector2(-player.facing * 10.0, 0.0), -player.facing,
					player.global_position.x * 0.05)
	for i in _shutters.query(view):
		_draw_shutter(i)
	for i in _data.fryers.size():
		if _data.fryers[i].rect.intersects(view):
			_draw_fryer(i)


## De afuera hacia el centro, como las góndolas (lo cercano al punto de fuga tapa costados).
func _sorted_blocks(indices: PackedInt32Array) -> Array:
	var list: Array = Array(indices)
	list.sort_custom(func(a: int, b: int) -> bool:
		return absf(_data.blocks[a].rect.get_center().x - vp.x) > absf(_data.blocks[b].rect.get_center().x - vp.x))
	return list


# --- Sólidos ------------------------------------------------------------------------------

func _draw_block(block: Block) -> void:
	var rect := block.rect
	match block.kind:
		Block.Kind.WALL:
			draw_rect(rect, _style.structure)
			draw_rect(Rect2(rect.position, Vector2(8.0, rect.size.y)), _style.edge)
		Block.Kind.PALLET:
			_draw_pallet(block)
		Block.Kind.STAND:
			_draw_stand(block)
		Block.Kind.CHEST_FREEZER:
			var body := _style.paper.lerp(Color("bfe6ef"), 0.3)
			var face := _prism(rect, 0.0, BLOCK_DEPTH * 1.6, body, body.darkened(0.3), Color("bfe6ef").lightened(0.2))
			_fill_sub(face, 0.05, 0.12, 0.95, 0.3, Color("4fb3c9"))
			_text("HELADOS", (face[0] + face[2]) * 0.5 + Vector2(0.0, 10.0), 22.0, _style.outline)
		Block.Kind.COUNTER:
			_draw_counter(block)
		Block.Kind.PLANTER:
			var face := _prism(rect, 0.0, BLOCK_DEPTH, _style.structure_light, _style.structure, _style.structure_light.lightened(0.1))
			_fill_sub(face, 0.0, 0.0, 1.0, 0.12, _style.edge)
			for k in 5:
				var base := Vector2(rect.position.x + rect.size.x * (0.15 + k * 0.17), rect.position.y)
				var tip := base + Vector2(sin(k * 1.7 + block.variant) * 20.0, -60.0 - (k % 2) * 30.0)
				draw_line(base, tip, Color("8fbf4d"), 7.0)
				draw_circle(tip, 10.0, Color("8fbf4d").darkened(0.2))
		Block.Kind.FRYER:
			var face := _prism(rect, 0.0, BLOCK_DEPTH * 1.4, STEEL, STEEL.darkened(0.35), STEEL.lightened(0.2))
			_fill_sub(face, 0.0, 0.0, 1.0, 0.1, _style.structure_dark)
			_fill_sub(face, 0.05, 0.25, 0.95, 0.9, STEEL.darkened(0.15))
			_text("PAPAS FRITAS", (face[0] + face[2]) * 0.5 + Vector2(0.0, 6.0), 22.0, _style.outline)
		_:
			_prism(rect, 0.0, BLOCK_DEPTH, _style.furniture, _style.furniture_dark, _style.furniture.lightened(0.1))


## Pallet de madera con cajas apiladas y cinta de embalar.
func _draw_pallet(block: Block) -> void:
	var rect := block.rect
	var base := Rect2(rect.position.x, rect.end.y - 18.0, rect.size.x, 18.0)
	var boxes := Rect2(rect.position.x + 6.0, rect.position.y, rect.size.x - 12.0, rect.size.y - 18.0)
	_prism(base, 0.0, BLOCK_DEPTH, Color("8a5a35"), Color("6b4428"), Color("a06d43"))
	var face := _prism(boxes, 0.0, BLOCK_DEPTH * 0.9, CARDBOARD, CARDBOARD.darkened(0.3), CARDBOARD.lightened(0.15))
	var rows := maxi(1, int(boxes.size.y / 45.0))
	var cols := maxi(1, int(boxes.size.x / 60.0))
	for r in range(1, rows):
		var line := _sub(face, 0.0, float(r) / rows, 1.0, float(r) / rows)
		draw_line(line[0], line[1], _style.outline, 2.0)
	for c in range(1, cols):
		var line := _sub(face, float(c) / cols, 0.0, float(c) / cols, 1.0)
		draw_line(line[0], line[1], _style.outline, 2.0)
	var tape := _sub(face, 0.47, 0.0, 0.53, 1.0)
	_quad(tape[0], tape[1], tape[2], tape[3], Color(_style.accent, 0.7))


## Puesto de fruta: cajón de madera con una pirámide de frutas encima.
func _draw_stand(block: Block) -> void:
	var rect := block.rect
	var wood := Color("a06d43")
	var face := _prism(rect, 0.0, BLOCK_DEPTH * 1.5, wood, wood.darkened(0.3), Color("6b4428"))
	for k in 3:
		var line := _sub(face, 0.0, 0.3 + k * 0.25, 1.0, 0.3 + k * 0.25)
		draw_line(line[0], line[1], wood.darkened(0.4), 3.0)
	var fruit := _product_color(block.variant)
	var radius := 15.0
	var row := 0
	var count := int(rect.size.x / (radius * 2.0))
	while count > 0 and row < 3:
		for k in count:
			var at := Vector2(rect.position.x + radius * (1.0 + row) + k * radius * 2.0, rect.position.y - radius * (1.0 + row * 1.7))
			draw_circle(at, radius, fruit)
			draw_arc(at, radius, 0.0, TAU, 12, _style.outline, 2.0, true)
			draw_circle(at + Vector2(-5.0, -5.0), 4.0, Color(1.0, 1.0, 1.0, 0.35))
		count -= 1
		row += 1
	_text("$990 KG" if block.variant % 2 == 0 else "OFERTA", (face[0] + face[2]) * 0.5, 20.0, _style.paper, 4)


## Caja registradora: mostrador con la cinta arriba (franjas que avanzan en el beat) y la máquina.
func _draw_counter(block: Block) -> void:
	var rect := block.rect
	var face := _prism(rect, 0.0, BLOCK_DEPTH * 1.6, _style.furniture, _style.furniture_dark, _style.structure_dark)
	_fill_sub(face, 0.0, 0.0, 1.0, 0.14, _style.edge)
	# Franjas de la cinta (sobre la cara de arriba si se ve, si no en el borde del frente).
	var travel := _world.belt_travel if _world != null else 0.0
	var top := rect.position.y
	var stripe := 40.0
	var offset := fposmod(travel, stripe)
	var x := rect.position.x + offset
	while x < rect.end.x - 30.0:
		var a := _p(Vector2(x, top), 0.0)
		var b := _p(Vector2(x, top), BLOCK_DEPTH * 1.2 if top > vp.y else 0.0) + Vector2(0.0, 0.0 if top > vp.y else 8.0)
		draw_line(a, b, _style.outline, 3.0)
		x += stripe
	# Registradora al final y una flecha que dice hacia dónde lleva la cinta.
	var register := Rect2(rect.end.x - 70.0, top - 60.0, 56.0, 60.0)
	var screen_face := _prism(register, 0.0, BLOCK_DEPTH, _style.structure_dark, _style.outline, _style.structure)
	_fill_sub(screen_face, 0.12, 0.12, 0.88, 0.45, Color("8fe388"))
	var arrow := _p(Vector2(rect.get_center().x, rect.position.y + 48.0), 0.0)
	var lit := _world != null and _world.belts_moving()
	var color := _style.accent if lit else Color(_style.accent, 0.35)
	draw_colored_polygon(PackedVector2Array([arrow + Vector2(30.0, 0.0), arrow + Vector2(0.0, -14.0),
			arrow + Vector2(0.0, 14.0)]), color)
	draw_rect(Rect2(arrow + Vector2(-34.0, -6.0), Vector2(34.0, 12.0)), color)


# --- Racks --------------------------------------------------------------------------------

func _draw_rack(index: int) -> void:
	var rack := _data.racks[index]
	var floor_y := _data.surface_y(rack.floor)
	var rect := rack.rect
	var down := _world != null and _world.rack_down[index]
	if down:
		_draw_rack_down(index, rect, floor_y)
		return
	var load := _world.rack_load(index) if _world != null else 0.0
	# Tiembla más cuanto más cargado está (y en el beat).
	var pulse := Conductor.pulse(8.0) if not Engine.is_editor_hint() else 0.0
	var shake := Vector2(sin(Time.get_ticks_msec() * 0.06 + index) * 6.0 * load * load * (0.5 + pulse), 0.0)
	var post := 18.0
	for x: float in [rect.position.x, rect.end.x - post]:
		_prism(Rect2(x + shake.x * 0.3, rect.position.y, post, floor_y - rect.position.y), 0.0, 0.05, RACK_COLOR,
				RACK_COLOR.darkened(0.35), RACK_COLOR.lightened(0.2))
	var beam := Rect2(rect.position + shake, rect.size)
	_prism(beam, 0.0, 0.06, RACK_COLOR, RACK_COLOR.darkened(0.35), RACK_COLOR.lightened(0.25))
	# Cajas cargadas sobre la viga.
	var x := rect.position.x + 14.0
	var k := 0
	while x < rect.end.x - 50.0:
		var h := 50.0 + float(_hash(rack.variant, k) % 40)
		var w := 60.0 + float(_hash(rack.variant, k + 50) % 50)
		w = minf(w, rect.end.x - 14.0 - x)
		var box := Rect2(Vector2(x, rect.position.y - h) + shake * (1.0 + 0.5 * (k % 2)), Vector2(w, h))
		var face := _prism(box, 0.0, 0.05, CARDBOARD, CARDBOARD.darkened(0.3), CARDBOARD.lightened(0.15))
		var tape := _sub(face, 0.0, 0.42, 1.0, 0.56)
		_quad(tape[0], tape[1], tape[2], tape[3], Color(_style.accent, 0.6))
		x += w + 6.0
		k += 1
	# Luces de carga: una por beat que aguanta; se ponen rojas al llenarse.
	if _params != null:
		var total := _params.rack_collapse_beats
		var used := _world.rack_stress[index] if _world != null else 0
		for i in total:
			var at := Vector2(rect.get_center().x + (i - (total - 1) * 0.5) * 16.0, rect.end.y + 16.0) + shake
			var on := i < used
			draw_circle(at, 6.0, _style.outline)
			draw_circle(at, 4.5, (WARNING if load > 0.6 else _style.accent) if on else _style.structure_dark)


## Rack derrumbado: parantes doblados, viga caída y una pila de cajas rotas (los escombros).
func _draw_rack_down(index: int, rect: Rect2, floor_y: float) -> void:
	var age := _world.rack_age[index] if _world != null else 1.0
	var fall := clampf(age / 0.25, 0.0, 1.0)
	var post := 18.0
	for side in 2:
		var x := rect.position.x if side == 0 else rect.end.x - post
		var lean := (0.35 if side == 0 else -0.35) * fall
		draw_set_transform(Vector2(x + post * 0.5, floor_y), lean)
		draw_rect(Rect2(-post * 0.5, -(floor_y - rect.position.y), post, floor_y - rect.position.y), RACK_COLOR.darkened(0.2))
		draw_rect(Rect2(-post * 0.5, -(floor_y - rect.position.y), post, floor_y - rect.position.y), _style.outline, false, 2.0)
		draw_set_transform(Vector2.ZERO)
	var beam_y := lerpf(rect.position.y, floor_y - 70.0, fall)
	draw_set_transform(Vector2(rect.get_center().x, beam_y), 0.12 * fall)
	draw_rect(Rect2(-rect.size.x * 0.5, 0.0, rect.size.x, rect.size.y), RACK_COLOR)
	draw_rect(Rect2(-rect.size.x * 0.5, 0.0, rect.size.x, rect.size.y), _style.outline, false, 2.0)
	draw_set_transform(Vector2.ZERO)
	var pile := Rect2(rect.position.x + 20.0, floor_y - BienestarWorld.DEBRIS_HEIGHT, rect.size.x - 40.0,
			BienestarWorld.DEBRIS_HEIGHT)
	if fall >= 1.0:
		_prism(pile, 0.0, 0.06, CARDBOARD.darkened(0.15), CARDBOARD.darkened(0.4), CARDBOARD)
		for k in int(pile.size.x / 50.0):
			var at := Vector2(pile.position.x + 25.0 + k * 50.0, pile.position.y - 6.0 - float(_hash(k, index) % 20))
			var box := Rect2(at - Vector2(22.0, 18.0), Vector2(44.0, 36.0))
			draw_set_transform(box.get_center(), (float(_hash(index, k) % 60) - 30.0) * 0.02)
			draw_rect(Rect2(-box.size * 0.5, box.size), CARDBOARD)
			draw_rect(Rect2(-box.size * 0.5, box.size), _style.outline, false, 2.0)
			draw_set_transform(Vector2.ZERO)
			draw_circle(at + Vector2(14.0, 20.0), 7.0, _product_color(_hash(k, 7)))


# --- Piso mojado, carritos, decoración ----------------------------------------------------------

func _draw_wet(rect: Rect2) -> void:
	var y := rect.end.y - 6.0
	var shine := 0.3 + 0.35 * (Conductor.pulse(6.0) if not Engine.is_editor_hint() else 0.0)
	var water := Color("4fb3c9")
	_quad(Vector2(rect.position.x, y), Vector2(rect.end.x, y), _p(Vector2(rect.end.x - 20.0, y), 0.05),
			_p(Vector2(rect.position.x + 20.0, y), 0.05), Color(water, 0.35))
	draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(water.lightened(0.4), 0.8), 3.0)
	# Reflejos que corren con el beat.
	for k in 3:
		var u := fposmod(0.2 + k * 0.33 + Conductor.beat_position() * 0.05, 1.0) if not Engine.is_editor_hint() else 0.3 * k
		var x := lerpf(rect.position.x + 20.0, rect.end.x - 60.0, u)
		draw_line(_p(Vector2(x, y), 0.02), _p(Vector2(x + 40.0, y), 0.02), Color(1.0, 1.0, 1.0, shine), 3.0)


## Carrito en el plano de juego: `origin` son los pies (la manija), `facing` hacia dónde mira el
## canasto (-1 izquierda) y `spin` gira las ruedas.
func _draw_cart(origin: Vector2, facing: float, spin: float) -> void:
	draw_set_transform(origin, 0.0, Vector2(-facing, 1.0))
	EnemyCostume.cart(self, Vector2.ZERO, 120.0, _style.outline, clampf(_style.outline_width * 0.75, 2.0, 4.0), 0.0, spin)
	draw_set_transform(Vector2.ZERO)


func _draw_prop(prop: Prop) -> void:
	var rect := prop.rect
	var ink := _style.outline
	match prop.type:
		Prop.Type.CART_CORRAL:
			var face := _prism(rect, PROP_DEPTH.x, PROP_DEPTH.y + 0.04, Color(_style.structure_light, 0.4),
					_style.structure, _style.structure_light)
			for k in 4:
				var at := Vector2(rect.position.x + 50.0 + k * 60.0, rect.end.y)
				draw_set_transform(_p(at, PROP_DEPTH.y), 0.0, Vector2(0.75, 0.75))
				EnemyCostume.cart(self, Vector2.ZERO, 120.0, ink, 2.0, 0.0, 0.0)
				draw_set_transform(Vector2.ZERO)
			_text("CARRITOS", (face[0] + face[1]) * 0.5 + Vector2(0.0, -16.0), 22.0, _style.paper, 4)
		Prop.Type.STANDEE:
			# Cartel de pie en A: "¡CUIDADO! PISO MOJADO" o bienvenida.
			var face := _prism(rect, PROP_DEPTH.x, PROP_DEPTH.y, _style.accent, _style.accent.darkened(0.3), _style.accent)
			var center := (face[0] + face[2]) * 0.5
			draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, -26.0), center + Vector2(-22.0, 12.0),
					center + Vector2(22.0, 12.0)]), ink)
			_text("!", center + Vector2(0.0, 0.0), 26.0, _style.accent)
			_text("PISO MOJADO", Vector2(center.x, face[2].y - 14.0), 14.0, ink)
		Prop.Type.PRICE_STAND:
			# Cartel de bienvenida con las ofertas del día.
			_prism(Rect2(rect.get_center().x - 5.0, rect.position.y + 60.0, 10.0, rect.size.y - 60.0), PROP_DEPTH.x,
					PROP_DEPTH.y, ink, ink, ink)
			var face := _prism(Rect2(rect.position, Vector2(rect.size.x, 110.0)), PROP_DEPTH.x, PROP_DEPTH.y,
					_style.paper, _style.paper.darkened(0.3), _style.paper)
			_fill_sub(face, 0.0, 0.0, 1.0, 0.25, Color("d8433a"))
			_text("OFERTAS", (face[0] + face[1]) * 0.5 + Vector2(0.0, 14.0), 20.0, _style.paper)
			_text("PAPAS $990", _sub(face, 0.0, 0.45, 1.0, 0.45)[0].lerp(_sub(face, 0.0, 0.45, 1.0, 0.45)[1], 0.5),
					16.0, ink)
			_text("¡BIENVENIDOS!", _sub(face, 0.0, 0.75, 1.0, 0.75)[0].lerp(_sub(face, 0.0, 0.75, 1.0, 0.75)[1], 0.5),
					14.0, Color("d8433a"))
		Prop.Type.MOP_BUCKET:
			var face := _prism(Rect2(rect.position.x, rect.end.y - 50.0, rect.size.x, 50.0), PROP_DEPTH.x, PROP_DEPTH.y,
					_style.accent, _style.accent.darkened(0.3), _style.accent.lightened(0.2))
			draw_line(face[0] + Vector2(20.0, 0.0), face[0] + Vector2(60.0, -rect.size.y), Color("a06d43"), 6.0)
		Prop.Type.SCALE:
			_prism(Rect2(rect.get_center().x - 6.0, rect.position.y + 30.0, 12.0, rect.size.y - 30.0), PROP_DEPTH.x,
					PROP_DEPTH.y, STEEL, STEEL.darkened(0.3), STEEL)
			var dish := _p(rect.position + Vector2(rect.size.x * 0.5, 30.0), PROP_DEPTH.x)
			draw_circle(dish, 26.0, STEEL)
			draw_arc(dish, 26.0, 0.0, TAU, 16, ink, 2.0, true)
		Prop.Type.DISPLAY:
			var face := _prism(rect, PROP_DEPTH.x, PROP_DEPTH.y, _style.furniture, _style.furniture_dark, _style.furniture.lightened(0.1))
			for s in 3:
				for c in 3:
					_fill_sub(face, 0.1 + c * 0.28, 0.1 + s * 0.3, 0.32 + c * 0.28, 0.32 + s * 0.3,
							_product_color(_hash(prop.variant, s * 3 + c)))
		Prop.Type.BENCH:
			_prism(Rect2(rect.position.x, rect.end.y - 50.0, rect.size.x, 14.0), PROP_DEPTH.x, PROP_DEPTH.y + 0.03,
					Color("a06d43"), Color("6b4428"), Color("c08a5a"))
			for x: float in [rect.position.x + 14.0, rect.end.x - 24.0]:
				_prism(Rect2(x, rect.end.y - 36.0, 10.0, 36.0), PROP_DEPTH.x, PROP_DEPTH.y, ink, ink, ink)
		Prop.Type.PLANT:
			var pot := Rect2(rect.position.x + 30.0, rect.end.y - 50.0, rect.size.x - 60.0, 50.0)
			_prism(pot, PROP_DEPTH.x, PROP_DEPTH.y, _style.structure_light, _style.structure, _style.structure_light)
			for k in 6:
				var base := Vector2(pot.get_center().x, pot.position.y)
				var tip := base + Vector2.from_angle(-PI * (0.15 + k * 0.14)) * (60.0 + (k % 3) * 18.0)
				draw_line(_p(base, PROP_DEPTH.x), _p(tip, PROP_DEPTH.x), Color("8fbf4d"), 8.0)
		Prop.Type.KIOSK:
			var face := _prism(rect, PROP_DEPTH.x, PROP_DEPTH.y + 0.04, _style.accent, _style.accent.darkened(0.35),
					_style.accent.lightened(0.15))
			_fill_sub(face, 0.08, 0.15, 0.92, 0.5, _style.structure_dark)
			_text("CELULARES", (face[0] + face[1]) * 0.5 + Vector2(0.0, 18.0), 20.0, ink)
		Prop.Type.TABLE:
			_prism(Rect2(rect.position.x, rect.position.y, rect.size.x, 12.0), PROP_DEPTH.x, PROP_DEPTH.y + 0.04,
					_style.paper, _style.paper.darkened(0.3), _style.paper)
			_prism(Rect2(rect.get_center().x - 6.0, rect.position.y + 12.0, 12.0, rect.size.y - 12.0), PROP_DEPTH.x,
					PROP_DEPTH.y, ink, ink, ink)
		_:
			_prism(rect, PROP_DEPTH.x, PROP_DEPTH.y, _style.furniture, _style.furniture_dark, _style.furniture)


# --- Cortinas y freidoras ----------------------------------------------------------------------

func _draw_shutter(index: int) -> void:
	var shutter := _data.shutters[index]
	var floor_y := _data.surface_y(shutter.floor)
	var ceiling := _data.floors[shutter.floor].ceiling
	var gap := _world.shutter_gap(index) if _world != null else floor_y - ceiling
	var bottom := floor_y - gap
	var frame := Rect2(shutter.x - 30.0, ceiling, shutter.width + 60.0, 70.0)
	# Caja de la cortina con el nombre del local y los rieles a los lados.
	var face := _prism(frame, 0.0, 0.05, _style.structure_light, _style.structure, _style.structure_light)
	_text(shutter.store, (face[0] + face[2]) * 0.5, 16.0, _style.paper, 3)
	for x: float in [shutter.x - 8.0, shutter.x + shutter.width]:
		draw_rect(Rect2(x, ceiling + 70.0, 8.0, floor_y - ceiling - 70.0), _style.structure_dark)
	if bottom > ceiling + 70.0:
		var slats := Rect2(shutter.x, ceiling + 70.0, shutter.width, bottom - ceiling - 70.0)
		var metal := _style.rock_light
		draw_rect(slats, metal)
		var y := slats.position.y + 14.0
		while y < slats.end.y:
			draw_line(Vector2(slats.position.x, y), Vector2(slats.end.x, y), metal.darkened(0.35), 3.0)
			y += 16.0
		draw_rect(slats, _style.outline, false, 2.0)
		draw_rect(Rect2(slats.position.x - 4.0, slats.end.y - 10.0, slats.size.x + 8.0, 10.0), _style.outline)
		# Franjas de peligro en el borde de abajo.
		var stripe := Rect2(slats.position.x, slats.end.y - 22.0, slats.size.x, 12.0)
		draw_rect(stripe, _style.accent)
	var left := _world.shutter_beats_left(index) if _world != null else -1
	if left > 0:
		var at := Vector2(shutter.x + shutter.width * 0.5, ceiling + 110.0)
		var blink := Conductor.pulse(6.0) > 0.4
		_text(str(left), at, 44.0, WARNING if blink else _style.accent, 8)


func _draw_fryer(index: int) -> void:
	var fryer := _data.fryers[index]
	var rect := fryer.rect
	# Canastos de papas fritas humeando sobre el mostrador.
	for k in maxi(1, int((rect.size.x - 40.0) / 130.0)):
		var basket := Rect2(rect.position.x + 40.0 + k * 130.0, rect.position.y - 34.0, 90.0, 34.0)
		_prism(basket, 0.0, 0.05, STEEL.darkened(0.2), STEEL.darkened(0.45), OIL)
		for f in 5:
			var base := Vector2(basket.position.x + 12.0 + f * 16.0, basket.position.y + 4.0)
			draw_rect(Rect2(base - Vector2(3.0, 24.0), Vector2(6.0, 24.0)), OIL)
	var splash := _world.fryer_splash(index) if _world != null else 0.0
	var every := maxi(_params.fryer_every, 1) if _params != null else 2
	var next := posmod(-(Conductor.beat_index() + 1 + fryer.phase), every) if not Engine.is_editor_hint() else 1
	if splash <= 0.0 and next == 0:
		# Aviso: burbujas el beat anterior a salpicar.
		for k in 6:
			var at := Vector2(rect.position.x + 50.0 + k * 40.0, rect.position.y - 40.0 - 20.0 * Conductor.phase())
			draw_circle(at, 6.0, Color(OIL, 0.8))
	if splash > 0.0:
		var area := _world.fryer_area(index)
		for k in 14:
			var u := float(_hash(index, k) % 100) / 100.0
			var start := Vector2(rect.position.x + rect.size.x * u, rect.position.y - 20.0)
			var direction := Vector2(lerpf(-1.0, 1.0, u) * area.size.x * 0.6, -area.size.y)
			var p := start + direction * splash + Vector2(0.0, area.size.y * 1.6 * splash * splash)
			draw_circle(p, 7.0, OIL)
			draw_arc(p, 7.0, 0.0, TAU, 8, _style.outline, 2.0, true)
