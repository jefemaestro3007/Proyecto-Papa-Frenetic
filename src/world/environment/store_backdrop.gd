@tool
class_name StoreBackdrop
extends DepthCanvas
## Lo que en Bienestar U está a una sola profundidad, dibujado una vez en coordenadas del plano
## jugable y en trozos (ChunkedView): un DepthPlane lo escala hacia el punto de fuga en cada frame.
## - WALL: pared del fondo de cada piso con zócalo, franja de color, puertas de vidrio de entrada y
##   salida, estanterías de pared con el letrero de la sección y los locales del centro comercial.
## - GONDOLAS: cabeceras de las góndolas (estantes con productos de frente).
## - FREEZERS: frente de los freezers verticales (cerrados; abrirlos lo dibuja StoreDepthView).

enum Kind { WALL, GONDOLAS, FREEZERS }

const GLASS := Color("bfe6ef")

var kind := Kind.WALL
var _data: BienestarMapData
var _params: BienestarParams


func setup(data: BienestarMapData, params: BienestarParams, style: ArtStyle, p_kind: Kind) -> void:
	_data = data
	_params = params
	_style = style
	kind = p_kind
	queue_redraw()


## Estático: solo se redibuja al cambiar el estilo (no cada frame como las vistas en perspectiva).
func _process(_delta: float) -> void:
	pass


func _draw() -> void:
	if _data == null or _style == null:
		return
	match kind:
		Kind.WALL:
			for span in _data.sections:
				if _owns(Vector2(span.x0, _data.surface_y(span.floor))):
					_draw_wall_span(span)
			if _data.mall:
				for store in _data.stores:
					if _owns(Vector2(store.x0, _data.surface_y(store.floor))):
						_draw_store(store, 0.0)
			else:
				for f in _data.floors.size():
					var floor := _data.floors[f]
					_draw_wall_shelves(f, floor.left, floor.right, floor.y, floor.ceiling, 0.0)
		Kind.GONDOLAS:
			for gondola in _data.gondolas:
				if _owns(Vector2(gondola.x0, _data.surface_y(gondola.floor))):
					_draw_gondola_front(gondola)
		Kind.FREEZERS:
			for freezer in _data.freezers:
				if _owns(freezer.rect.position):
					_draw_freezer_front(freezer)


## Tramo de pared de una sección: con aberturas (puertas de vidrio) en la entrada y la salida.
func _draw_wall_span(span: BienestarMapData.SectionSpan) -> void:
	var floor := _data.floors[span.floor]
	var y := floor.y
	var top := floor.ceiling
	var x0 := span.x0
	var x1 := span.x1
	var x := x0
	for opening: Vector2 in _wall_openings(span.floor):
		if opening.y < x0 or opening.x > x1:
			continue
		if opening.x > x:
			draw_rect(Rect2(x, top, opening.x - x, y - top), _style.wall_paper)
		_draw_glass_doors(Vector2(maxf(opening.x, x0), minf(opening.y, x1)), y, top, 0.0)
		x = maxf(x, opening.y)
	if x < x1:
		draw_rect(Rect2(x, top, x1 - x, y - top), _style.wall_paper)
	draw_rect(Rect2(x0, y - 50.0, x1 - x0, 50.0), _style.structure_dark)
	if not _data.mall:
		var band := y - (y - top) * 0.62
		draw_rect(Rect2(x0, band - 26.0, x1 - x0, 26.0), Color(_style.accent, 0.55))


## Cabecera: estantes con productos de frente.
func _draw_gondola_front(gondola: BienestarMapData.Gondola) -> void:
	var y := _data.surface_y(gondola.floor)
	var height := gondola.height * (0.55 if gondola.fallen else 1.0)
	var rect := Rect2(gondola.x0, y - height, gondola.x1 - gondola.x0, height)
	draw_rect(rect, _style.furniture)
	draw_rect(rect, _style.outline, false, maxf(_style.outline_width * 0.6, 1.5))
	var face := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)])
	var shelves := 4
	for s in shelves:
		var v0 := (s + 0.2) / shelves
		var v1 := (s + 0.85) / shelves
		for c in 5:
			if _hash(gondola.variant, 500 + s * 11 + c) % 100 > int(_params.product_density * 100.0):
				continue
			_fill_sub(face, (c + 0.12) / 5.0, v0, (c + 0.88) / 5.0, v1, _product_color(_hash(gondola.variant, 900 + s * 5 + c)))
		_fill_sub(face, 0.0, v1 + 0.04, 1.0, v1 + 0.08, _style.furniture_dark)
	if gondola.fallen:
		for k in 6:
			var px := lerpf(gondola.x0, gondola.x1, (k + 0.5) / 6.0)
			draw_circle(Vector2(px, y - 8.0), 9.0, _product_color(_hash(gondola.variant, k)))


## Freezer vertical cerrado: cartel luminoso, vidrio con estantes y productos.
func _draw_freezer_front(freezer: BienestarMapData.Freezer) -> void:
	var rect := freezer.rect
	var body := _style.paper.lerp(GLASS, 0.35)
	draw_rect(rect, body)
	draw_rect(rect, _style.outline, false, maxf(_style.outline_width * 0.6, 1.5))
	var face := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)])
	_fill_sub(face, 0.06, 0.04, 0.94, 0.14, Color("4fb3c9"))
	_fill_sub(face, 0.1, 0.18, 0.9, 0.94, GLASS.darkened(0.25))
	for s in 4:
		var v := 0.22 + s * 0.18
		for c in 3:
			_fill_sub(face, 0.16 + c * 0.24, v, 0.34 + c * 0.24, v + 0.1, _product_color(_hash(freezer.variant, s * 3 + c)))


## Estanterías de pared del supermercado: por sección, un letrero grande con el rubro y estantes
## con productos a lo largo de la pared del fondo (las puertas de entrada y salida quedan libres).
func _draw_wall_shelves(f: int, x0: float, x1: float, y: float, top: float, depth: float) -> void:
	for span in _data.sections:
		if span.floor != f or span.x1 < x0 or span.x0 > x1:
			continue
		var title := _section_title(span.type)
		if title.is_empty() or not _owns(Vector2(span.x0, y)):
			continue
		var a := maxf(span.x0 + 80.0, x0)
		var b := minf(span.x1 - 80.0, x1)
		if b <= a:
			continue
		var shelf_top := y - (y - top) * 0.5
		_quad(_p(Vector2(a, shelf_top), depth), _p(Vector2(b, shelf_top), depth), _p(Vector2(b, y - 50.0), depth),
				_p(Vector2(a, y - 50.0), depth), _style.furniture_dark)
		for s in 3:
			var sy := shelf_top + (y - 50.0 - shelf_top) * (s + 0.3) / 3.0
			var xx := a + 10.0
			var k := 0
			while xx < b - 40.0:
				if _hash(int(xx), s) % 100 < int(_params.product_density * 100.0):
					_quad(_p(Vector2(xx, sy), depth), _p(Vector2(xx + 34.0, sy), depth), _p(Vector2(xx + 34.0, sy + 38.0), depth),
							_p(Vector2(xx, sy + 38.0), depth), _product_color(_hash(int(xx) + k, s)))
				xx += 44.0
				k += 1
			draw_line(_p(Vector2(a, sy + 42.0), depth), _p(Vector2(b, sy + 42.0), depth), _style.furniture, 3.0)
		# Letrero del rubro, centrado en la sección.
		var center := (span.x0 + span.x1) * 0.5
		if center > x0 and center < x1:
			var sign_y := shelf_top - 120.0
			var w := 520.0
			var c0 := _p(Vector2(center - w * 0.5, sign_y), depth)
			var c2 := _p(Vector2(center + w * 0.5, sign_y + 70.0), depth)
			draw_rect(Rect2(c0, c2 - c0), _style.outline)
			draw_rect(Rect2(c0, c2 - c0).grow(-4.0), _section_color(span.type))
			_text(title, (c0 + c2) * 0.5, 40.0 * (1.0 - depth), _style.outline)


static func _section_title(type: BienestarMapData.Section) -> String:
	match type:
		BienestarMapData.Section.AISLES:
			return "ABARROTES"
		BienestarMapData.Section.FREEZERS:
			return "CONGELADOS"
		BienestarMapData.Section.PRODUCE:
			return "FRUTAS Y VERDURAS"
		BienestarMapData.Section.WET:
			return "LIMPIEZA"
		BienestarMapData.Section.CARTS:
			return "TODO EN OFERTA"
		BienestarMapData.Section.CHECKOUTS:
			return "CAJAS"
	return ""


static func _section_color(type: BienestarMapData.Section) -> Color:
	match type:
		BienestarMapData.Section.FREEZERS:
			return Color("4fb3c9")
		BienestarMapData.Section.PRODUCE:
			return Color("8fbf4d")
		BienestarMapData.Section.CARTS:
			return Color("ef6657")
		BienestarMapData.Section.CHECKOUTS:
			return Color("eee6dc")
	return Color("ffd400")


## Tramos de la pared del fondo que son puertas de vidrio (entrada y salida).
func _wall_openings(f: int) -> Array:
	var out: Array = []
	for span in _data.sections:
		if span.floor != f:
			continue
		if span.type == BienestarMapData.Section.ENTRANCE:
			out.append(Vector2(span.x0 + 120.0, span.x0 + 520.0))
		elif span.type == BienestarMapData.Section.EXIT:
			out.append(Vector2(span.x1 - 560.0, span.x1 - 120.0))
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return out


## Puertas automáticas de vidrio: se ve el cielo rojo de afuera (no se pinta el fondo).
func _draw_glass_doors(span: Vector2, y: float, top: float, depth: float) -> void:
	var door_top := y - minf(320.0, (y - top) * 0.7)
	_quad(_p(Vector2(span.x, top), depth), _p(Vector2(span.y, top), depth), _p(Vector2(span.y, door_top), depth),
			_p(Vector2(span.x, door_top), depth), _style.wall_paper)
	var ink := _style.outline
	var mid := (span.x + span.y) * 0.5
	for xx: float in [span.x, mid, span.y]:
		draw_line(_p(Vector2(xx, door_top), depth), _p(Vector2(xx, y), depth), _style.structure_light, 6.0 * (1.0 - depth))
	draw_line(_p(Vector2(span.x, door_top), depth), _p(Vector2(span.y, door_top), depth), _style.structure_light,
			10.0 * (1.0 - depth))
	_quad(_p(Vector2(span.x, door_top), depth), _p(Vector2(span.y, door_top), depth), _p(Vector2(span.y, y), depth),
			_p(Vector2(span.x, y), depth), Color(GLASS, 0.12))
	draw_line(_p(Vector2(span.x + 30.0, door_top + 30.0), depth), _p(Vector2(span.x + 120.0, y - 60.0), depth),
			Color(1.0, 1.0, 1.0, 0.25), 3.0)
	_text("BIENESTAR U", _p(Vector2(mid, door_top - 40.0), depth), 40.0 * (1.0 - depth), _style.accent, 6)


func _draw_store(store: BienestarMapData.Store, depth: float) -> void:
	var y := _data.surface_y(store.floor)
	var top := _data.floors[store.floor].ceiling
	var room := y - top
	var sign_y := y - room * 0.82
	var front := Rect2(store.x0, sign_y, store.x1 - store.x0, room * 0.82)
	var a := _p(front.position, depth)
	var b := _p(Vector2(front.end.x, front.position.y), depth)
	var c := _p(front.end, depth)
	var d := _p(Vector2(front.position.x, front.end.y), depth)
	var face := PackedVector2Array([a, b, c, d])
	# Letrero con el nombre y vidriera (o cortina baja si está cerrado).
	_fill_sub(face, 0.0, 0.0, 1.0, 0.16, store.color.darkened(0.15))
	_quad_outline(face[0], face[1], face[2], face[3], _style.outline, 2.0)
	_text(store.name, _sub(face, 0.0, 0.0, 1.0, 0.16)[0].lerp(_sub(face, 0.0, 0.0, 1.0, 0.16)[2], 0.5),
			34.0 * (1.0 - depth), _style.outline)
	if store.closed:
		_fill_sub(face, 0.02, 0.18, 0.98, 1.0, _style.rock_light.darkened(0.2))
		for k in 10:
			var v := 0.2 + k * 0.08
			var line := _sub(face, 0.02, v, 0.98, v)
			draw_line(line[0], line[1], _style.rock.darkened(0.3), 2.0)
	else:
		_fill_sub(face, 0.04, 0.2, 0.62, 0.96, Color(GLASS, 0.18))
		_fill_sub(face, 0.68, 0.3, 0.94, 1.0, _style.structure_dark)
		if store.name == "PATIO DE COMIDAS":
			# Pizarras de menú con papas fritas y precios en vez de vidriera.
			for k in 3:
				var u := 0.08 + k * 0.3
				_fill_sub(face, u, 0.24, u + 0.24, 0.6, _style.structure_dark)
				var board := _sub(face, u, 0.24, u + 0.24, 0.6)
				var center := (board[0] + board[2]) * 0.5
				for fry in 4:
					draw_rect(Rect2(center + Vector2(-18.0 + fry * 10.0, -40.0), Vector2(6.0, 34.0)), Color("f2c14e"))
				draw_rect(Rect2(center + Vector2(-26.0, -8.0), Vector2(52.0, 30.0)), Color("d8433a"))
				_text(["$990", "$1.490", "2x1"][k], center + Vector2(0.0, 44.0), 28.0, _style.paper)
			return
		# Maniquíes y cajas en la vidriera (siluetas).
		for k in 3:
			var u := 0.1 + k * 0.17
			var head := _sub(face, u, 0.4, u + 0.05, 0.47)
			draw_circle((head[0] + head[2]) * 0.5, (head[1].x - head[0].x) * 0.5, Color(_style.paper, 0.5))
			_fill_sub(face, u - 0.01, 0.48, u + 0.06, 0.92, Color(store.color, 0.4))
