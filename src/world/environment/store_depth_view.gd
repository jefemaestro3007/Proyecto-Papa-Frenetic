@tool
class_name StoreDepthView
extends DepthCanvas
## Interior de Bienestar U en perspectiva: lo que cambia con la cámara y se redibuja cada frame
## (solo lo visible). Lo que está a una sola profundidad (pared del fondo, frentes de góndolas y
## freezers) es estático en StoreBackdrop dentro de un DepthPlane. Dos pasadas:
## - BACK (detrás de los frentes): piso de baldosas y techo con tubos hacia el punto de fuga,
##   tragaluces, paredes de los extremos y los costados y techos de góndolas y freezers.
## - FRONT: freezers abiertos (puerta, luz, vapor), escaleras mecánicas, cortes de las losas y del
##   techo del edificio, y los carteles colgantes (precios que se balancean, prismas de OFERTA).

const TILE := 160.0
const TUBE_EVERY := 360.0
const GONDOLA_FRONT := 0.1
const FREEZER_DEPTH := Vector2(0.015, 0.11)
const ESCALATOR_DEPTH := Vector2(0.05, 0.16)
const SIGN_DEPTH := 0.035
const ROOF := 150.0
const GLASS := Color("bfe6ef")
const EXIT_GREEN := Color("3fbf6a")

enum Pass { BACK, FRONT }

var pass_kind := Pass.BACK
var _data: BienestarMapData
var _world: BienestarWorld
var _params: BienestarParams
var _gondolas := SpatialIndex.new()
var _freezers := SpatialIndex.new()
var _escalators := SpatialIndex.new()
var _signs := SpatialIndex.new()


func setup(data: BienestarMapData, world: BienestarWorld, params: BienestarParams, style: ArtStyle, p_pass: Pass) -> void:
	_data = data
	_world = world
	_params = params
	_style = style
	pass_kind = p_pass
	for index: SpatialIndex in [_gondolas, _freezers, _escalators, _signs]:
		index.clear()
	for i in data.gondolas.size():
		_gondolas.add(i, Vector2((data.gondolas[i].x0 + data.gondolas[i].x1) * 0.5, data.surface_y(data.gondolas[i].floor)))
	for i in data.freezers.size():
		_freezers.add(i, data.freezers[i].rect.get_center())
	for i in data.escalators.size():
		_escalators.add(i, (data.escalators[i].foot + data.escalators[i].top) * 0.5)
	for i in data.signs.size():
		_signs.add(i, data.signs[i].position)
	queue_redraw()


func _draw() -> void:
	if _data == null or _style == null:
		return
	_begin_frame()
	var depth := _data.depth
	var wide := screen.grow_individual(screen.size.x * 0.6, 900.0, screen.size.x * 0.6, 900.0)
	if pass_kind == Pass.BACK:
		for f in _data.floors.size():
			var floor := _data.floors[f]
			if floor.y < screen.position.y - 200.0 or floor.ceiling > screen.end.y + 200.0:
				continue
			_draw_room(f, floor, depth)
		for i in _sorted(_gondolas.query(wide), func(i: int) -> float: return (_data.gondolas[i].x0 + _data.gondolas[i].x1) * 0.5):
			_draw_gondola(_data.gondolas[i], depth)
		for i in _freezers.query(wide):
			_draw_freezer_sides(i)
		return
	for i in _freezers.query(wide):
		_draw_freezer_state(i)
	for i in _escalators.query(wide):
		_draw_escalator(i)
	_draw_fronts()
	for i in _signs.query(screen.grow(300.0)):
		_draw_sign(_data.signs[i])


## Índices ordenados de afuera hacia el punto de fuga: lo más cercano al centro va encima (tapa el
## costado de lo que está más afuera, como en la realidad).
func _sorted(indices: PackedInt32Array, x_of: Callable) -> Array:
	var left: Array = []
	var right: Array = []
	for i in indices:
		if x_of.call(i) < vp.x:
			left.append(i)
		else:
			right.append(i)
	left.sort_custom(func(a: int, b: int) -> bool: return x_of.call(a) < x_of.call(b))
	right.sort_custom(func(a: int, b: int) -> bool: return x_of.call(a) > x_of.call(b))
	return left + right


# --- Habitación (pared, piso, techo) ------------------------------------------------------

func _draw_room(f: int, floor: BienestarMapData.Floor, depth: float) -> void:
	var range := _x_range(depth)
	var x0 := maxf(floor.left, range.x)
	var x1 := minf(floor.right, range.y)
	if x1 <= x0:
		return
	var y := floor.y
	var top := floor.ceiling
	# Piso: solo si está por debajo del ojo.
	if y > vp.y:
		_draw_floor_plane(floor, x0, x1, depth)
	# Techo: solo si está por encima del ojo; los tragaluces quedan abiertos al cielo.
	if top < vp.y:
		_draw_ceiling(f, floor, x0, x1, depth)
	# Paredes de los extremos: se ve la cara de adentro cuando el extremo está a un lado del ojo.
	for side in 2:
		var wx := floor.left if side == 0 else floor.right
		if (side == 0 and wx < vp.x and wx > screen.position.x - 2000.0) or (side == 1 and wx > vp.x and wx < screen.end.x + 2000.0):
			var shade := _style.wall_paper.darkened(0.25)
			_quad(Vector2(wx, top), _p(Vector2(wx, top), depth), _p(Vector2(wx, y), depth), Vector2(wx, y), shade)
			_quad_outline(Vector2(wx, top), _p(Vector2(wx, top), depth), _p(Vector2(wx, y), depth), Vector2(wx, y),
					_style.outline, 3.0)
			draw_line(Vector2(wx, y - 50.0), _p(Vector2(wx, y - 50.0), depth), _style.structure_dark, 4.0)


func _draw_floor_plane(floor: BienestarMapData.Floor, x0: float, x1: float, depth: float) -> void:
	var y := floor.y
	var tile := _style.floor_color
	_quad(Vector2(x0, y), Vector2(x1, y), _p(Vector2(x1, y), depth), _p(Vector2(x0, y), depth), tile)
	# Baldosas: filas hacia el fondo y líneas que convergen en el punto de fuga.
	var line := Color(_style.structure_light, 0.35)
	var rows := [0.035, 0.08, 0.135, 0.2, 0.28, 0.37]
	var lines := PackedVector2Array()
	for i in rows.size():
		var d: float = rows[i] * depth / 0.45
		if d >= depth:
			break
		lines.append_array([_p(Vector2(x0, y), d), _p(Vector2(x1, y), d)])
	# Damero: una de cada dos baldosas de la primera fila, más clara (le da volumen al piso).
	var start := floorf(x0 / TILE) * TILE
	var xx := start
	var d0: float = rows[0] * depth / 0.45
	var d1: float = rows[1] * depth / 0.45
	while xx <= x1:
		lines.append_array([Vector2(xx, y), _p(Vector2(xx, y), depth)])
		if posmod(int(xx / TILE), 2) == 0:
			_batch_quad(_p(Vector2(xx, y), d0), _p(Vector2(xx + TILE, y), d0), _p(Vector2(xx + TILE, y), d1),
					_p(Vector2(xx, y), d1), Color(_style.structure_light, 0.12))
		xx += TILE
	_flush()
	draw_multiline(lines, line, 2.0)
	# Huecos del atrio: el vacío hacia el piso de abajo.
	for hole in floor.holes:
		if hole.y < x0 or hole.x > x1:
			continue
		_quad(Vector2(hole.x, y), Vector2(hole.y, y), _p(Vector2(hole.y, y), depth * 0.5),
				_p(Vector2(hole.x, y), depth * 0.5), _style.structure_dark.darkened(0.5))
	# Reflejo de la luz del techo en el piso, que late con el beat.
	var pulse := Conductor.pulse(6.0) if not Engine.is_editor_hint() else 0.0
	_quad(Vector2(x0, y), Vector2(x1, y), _p(Vector2(x1, y), depth * 0.15), _p(Vector2(x0, y), depth * 0.15),
			Color(1.0, 1.0, 1.0, 0.03 + 0.04 * pulse))


func _draw_ceiling(f: int, floor: BienestarMapData.Floor, x0: float, x1: float, depth: float) -> void:
	var top := floor.ceiling
	var skylights: Array[Vector2] = []
	for skylight in _data.skylights:
		if int(skylight.x) == f and skylight.z > x0 and skylight.y < x1:
			skylights.append(Vector2(skylight.y, skylight.z))
	skylights.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var ceiling := _style.structure_dark
	var x := x0
	for skylight in skylights:
		if skylight.x > x:
			_quad(Vector2(x, top), Vector2(skylight.x, top), _p(Vector2(skylight.x, top), depth), _p(Vector2(x, top), depth), ceiling)
		# Marco del tragaluz: vigas que cruzan el vidrio (el cielo se ve entre ellas).
		for k in 5:
			var d := depth * k / 4.0
			draw_line(_p(Vector2(skylight.x, top), d), _p(Vector2(skylight.y, top), d), _style.outline, 4.0)
		draw_line(Vector2(skylight.x, top), _p(Vector2(skylight.x, top), depth), _style.outline, 4.0)
		draw_line(Vector2(skylight.y, top), _p(Vector2(skylight.y, top), depth), _style.outline, 4.0)
		x = maxf(x, skylight.y)
	if x < x1:
		_quad(Vector2(x, top), Vector2(x1, top), _p(Vector2(x1, top), depth), _p(Vector2(x, top), depth), ceiling)
	# Vigas del techo que se alejan hacia el fondo (marcan la perspectiva).
	var beams := PackedVector2Array()
	var beam := floorf(x0 / (TUBE_EVERY * 2.0)) * TUBE_EVERY * 2.0 + TUBE_EVERY
	while beam < x1:
		beams.append_array([Vector2(beam, top), _p(Vector2(beam, top), depth)])
		beam += TUBE_EVERY * 2.0
	if not beams.is_empty():
		draw_multiline(beams, _style.structure, 6.0)
	# Tubos fluorescentes en filas hacia el fondo; algunos muertos, todos titilan con el beat.
	var pulse := Conductor.pulse(5.0) if not Engine.is_editor_hint() else 0.5
	var tx := floorf(x0 / TUBE_EVERY) * TUBE_EVERY
	while tx < x1:
		var lit := true
		for skylight in skylights:
			if tx > skylight.x - 80.0 and tx < skylight.y + 80.0:
				lit = false
		var dead := _hash(int(tx), f) % 100 < int(_params.ruin * 40.0)
		if lit:
			for row in 3:
				var d0 := depth * (0.12 + row * 0.27)
				var d1 := d0 + depth * 0.1
				var color := Color(0.25, 0.25, 0.3) if dead else Color(1.0, 0.98, 0.9, 0.7 + 0.3 * pulse)
				_batch_quad(_p(Vector2(tx - 70.0, top), d0), _p(Vector2(tx + 70.0, top), d0), _p(Vector2(tx + 70.0, top), d1),
						_p(Vector2(tx - 70.0, top), d1), color)
		tx += TUBE_EVERY
	_flush()


# --- Góndolas y freezers (supermercado) ---------------------------------------------------

func _draw_gondola(gondola: BienestarMapData.Gondola, depth: float) -> void:
	var y := _data.surface_y(gondola.floor)
	var height := gondola.height * (0.55 if gondola.fallen else 1.0)
	var rect := Rect2(gondola.x0, y - height, gondola.x1 - gondola.x0, height)
	var d0 := GONDOLA_FRONT
	var d1 := depth - 0.01
	var body := _style.furniture
	_prism(rect, d0, d1, body, body.darkened(0.3), body.lightened(0.15), true, false)
	# Productos en el costado visible: filas que se alejan hacia el fondo.
	var side_x := -1.0
	if rect.end.x < vp.x:
		side_x = rect.end.x
	elif rect.position.x > vp.x:
		side_x = rect.position.x
	var shelves := 4
	if side_x >= 0.0:
		for s in shelves:
			var sy := rect.position.y + rect.size.y * (s + 0.25) / shelves
			var cells := 4
			for c in cells:
				if _hash(gondola.variant, s * 31 + c) % 100 > int(_params.product_density * 100.0):
					continue
				var da := lerpf(d0, d1, (c + 0.1) / cells)
				var db := lerpf(d0, d1, (c + 0.9) / cells)
				var color := _product_color(_hash(gondola.variant, s * 7 + c))
				_quad(_p(Vector2(side_x, sy), da), _p(Vector2(side_x, sy), db), _p(Vector2(side_x, sy + 34.0), db),
						_p(Vector2(side_x, sy + 34.0), da), color)
			draw_line(_p(Vector2(side_x, sy + 38.0), d0), _p(Vector2(side_x, sy + 38.0), d1), _style.furniture_dark, 3.0)



func _draw_freezer_sides(index: int) -> void:
	var freezer := _data.freezers[index]
	var body := _style.paper.lerp(GLASS, 0.35)
	_prism(freezer.rect, FREEZER_DEPTH.x, FREEZER_DEPTH.y, body, body.darkened(0.3), body.lightened(0.1), true, false)


## Lo que cambia con el beat sobre el frente estático: vidrio iluminado, puerta abierta y vapor; o
## apagado si ya se vació.
func _draw_freezer_state(index: int) -> void:
	var freezer := _data.freezers[index]
	var face := PackedVector2Array([_p(freezer.rect.position, FREEZER_DEPTH.x),
			_p(Vector2(freezer.rect.end.x, freezer.rect.position.y), FREEZER_DEPTH.x), _p(freezer.rect.end, FREEZER_DEPTH.x),
			_p(Vector2(freezer.rect.position.x, freezer.rect.end.y), FREEZER_DEPTH.x)])
	if _world != null and _world.freezer_left[index] <= 0.0:
		_fill_sub(face, 0.1, 0.18, 0.9, 0.94, Color(_style.outline, 0.35))
		return
	if _world == null or not _world.freezer_open(index):
		return
	_fill_sub(face, 0.1, 0.18, 0.9, 0.94, Color(1.0, 1.0, 1.0, 0.35))
	# Puerta abierta hacia el jugador (profundidad negativa: sale del plano) y vapor frío.
	var hinge_top := freezer.rect.position + Vector2(0.0, freezer.rect.size.y * 0.18)
	var hinge_bottom := Vector2(freezer.rect.position.x, freezer.rect.end.y - 8.0)
	var swing := -0.06
	var door := PackedVector2Array([_p(hinge_top, FREEZER_DEPTH.x), _p(hinge_top + Vector2(freezer.rect.size.x * 0.35, 0.0), swing),
			_p(hinge_bottom + Vector2(freezer.rect.size.x * 0.35, 0.0), swing), _p(hinge_bottom, FREEZER_DEPTH.x)])
	_face(door[0], door[1], door[2], door[3], Color(GLASS, 0.5), _style.outline, 2.0, true)
	var time := Time.get_ticks_msec() / 1000.0
	for k in 5:
		var rise := fposmod(time * 0.6 + k * 0.2, 1.0)
		var at := Vector2(freezer.rect.position.x + freezer.rect.size.x * (0.2 + 0.15 * k), freezer.rect.end.y - 20.0 - rise * 120.0)
		draw_circle(at, 18.0 + rise * 20.0, Color(1.0, 1.0, 1.0, 0.18 * (1.0 - rise)))


# --- Locales y escaleras mecánicas (centro comercial) ---------------------------------------

func _draw_escalator(index: int) -> void:
	var escalator := _data.escalators[index]
	var foot := escalator.foot
	var top := escalator.top
	var d0 := ESCALATOR_DEPTH.x
	var d1 := ESCALATOR_DEPTH.y
	var bar := floori(Conductor.beat_position() / ConductorClock.BEATS_PER_BAR) if not Engine.is_editor_hint() else 0
	var up := escalator.going_up(bar, _params.escalator_bars)
	var flip_soon := not Engine.is_editor_hint() and escalator.going_up(bar + 1, _params.escalator_bars) != up
	var metal := _style.rock_light
	# Peldaños (cara de arriba de la escalera) con franjas que avanzan en el sentido actual.
	var truss := Vector2(0.0, 70.0)
	_quad(_p(foot, d0), _p(top, d0), _p(top, d1), _p(foot, d1), metal.darkened(0.15))
	var time := Time.get_ticks_msec() / 1000.0 if not Engine.is_editor_hint() else 0.0
	var steps := 14
	for k in steps:
		var s := fposmod(k / float(steps) + time * 0.6 * (1.0 if up else -1.0) * (1.0 if top.x > foot.x else 1.0), 1.0)
		var p := foot.lerp(top, s)
		draw_line(_p(p, d0), _p(p, d1), _style.outline, 2.0)
	# Estructura de abajo y baranda de vidrio con pasamanos.
	_quad(_p(foot, d0), _p(top, d0), _p(top + truss, d0), _p(foot + truss, d0), _style.structure)
	_quad_outline(_p(foot, d0), _p(top, d0), _p(top + truss, d0), _p(foot + truss, d0), _style.outline, 2.0)
	var rail := Vector2(0.0, -90.0)
	_quad(_p(foot, d0), _p(top, d0), _p(top + rail, d0), _p(foot + rail, d0), Color(GLASS, 0.2))
	draw_line(_p(foot + rail, d0), _p(top + rail, d0), _style.outline, 6.0)
	# Flechas al pie y arriba: verde si sube, roja si baja; titilan el compás antes de cambiar.
	var blink := flip_soon and Conductor.pulse(4.0) > 0.4
	var color := (EXIT_GREEN if up else Color("ef6657")) if not blink else _style.accent
	for point: Vector2 in [foot, top]:
		var at := point + Vector2(0.0, -150.0)
		var box := Rect2(at - Vector2(26.0, 26.0), Vector2(52.0, 52.0))
		draw_rect(box, _style.outline)
		draw_rect(box.grow(-4.0), color)
		var tip := at + Vector2(0.0, -14.0 if up else 14.0)
		draw_colored_polygon(PackedVector2Array([tip, at + Vector2(-12.0, 0.0 if up else 0.0) + Vector2(0.0, 8.0 if up else -8.0),
				at + Vector2(12.0, 8.0 if up else -8.0)]), _style.paper)


# --- Plano de corte: losas y techo del edificio ---------------------------------------------

func _draw_fronts() -> void:
	var edge := _style.edge
	for slab in _data.slabs:
		if not slab.intersects(screen):
			continue
		var rect := slab.intersection(screen.grow(40.0))
		draw_rect(rect, _style.structure)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 8.0)), edge)
		draw_rect(Rect2(rect.position + Vector2(0.0, 8.0), Vector2(rect.size.x, 10.0)), _style.structure_dark)
	var top_floor := _data.floors[-1]
	var roof := Rect2(top_floor.left - 60.0, top_floor.ceiling - ROOF, top_floor.right - top_floor.left + 120.0, ROOF)
	if roof.intersects(screen):
		var rect := roof.intersection(screen.grow(40.0))
		draw_rect(rect, _style.structure)
		draw_rect(Rect2(Vector2(rect.position.x, roof.position.y), Vector2(rect.size.x, 10.0)), edge)
		draw_rect(Rect2(Vector2(rect.position.x, roof.end.y - 14.0), Vector2(rect.size.x, 14.0)), _style.structure_dark)
	# Cortes del techo de cada piso del centro comercial (debajo de la losa de arriba ya hay losa).


# --- Carteles colgantes ---------------------------------------------------------------------

func _draw_sign(sign: BienestarMapData.HangingSign) -> void:
	var f := _data.floor_at(sign.position + Vector2(0.0, 300.0))
	var ceiling := _data.floors[maxi(f, 0)].ceiling
	var anchor := _p(Vector2(sign.position.x, ceiling), SIGN_DEPTH)
	var at := _p(sign.position, SIGN_DEPTH)
	var beat := Conductor.beat_position() if not Engine.is_editor_hint() else 0.0
	var swing := sin(beat * PI + sign.variant % 7) * 0.08
	var ink := _style.outline
	match sign.type:
		BienestarMapData.HangingSign.Type.OFFER:
			draw_line(anchor, at + Vector2(0.0, -40.0), ink, 2.0)
			_draw_offer_prism(at, beat)
		BienestarMapData.HangingSign.Type.EXIT:
			draw_line(anchor + Vector2(-60.0, 0.0), at + Vector2(-60.0, -30.0), ink, 2.0)
			draw_line(anchor + Vector2(60.0, 0.0), at + Vector2(60.0, -30.0), ink, 2.0)
			var box := Rect2(at - Vector2(110.0, 32.0), Vector2(220.0, 64.0))
			draw_rect(box, ink)
			draw_rect(box.grow(-5.0), EXIT_GREEN.lightened(0.15 * Conductor.pulse(5.0)) if not Engine.is_editor_hint() else EXIT_GREEN)
			_text(sign.text + " →", at, 34.0, _style.paper)
		_:
			var size := Vector2(200.0, 64.0) if sign.type == BienestarMapData.HangingSign.Type.AISLE else Vector2(130.0, 70.0)
			var xform := Transform2D(swing, at)
			draw_line(anchor + Vector2(-size.x * 0.35, 0.0), xform * Vector2(-size.x * 0.35, -size.y * 0.5), ink, 2.0)
			draw_line(anchor + Vector2(size.x * 0.35, 0.0), xform * Vector2(size.x * 0.35, -size.y * 0.5), ink, 2.0)
			draw_set_transform(at, swing)
			var box := Rect2(-size * 0.5, size)
			if sign.type == BienestarMapData.HangingSign.Type.AISLE:
				draw_rect(box, ink)
				draw_rect(box.grow(-4.0), _style.structure)
				draw_rect(Rect2(box.position + Vector2(4.0, 4.0), Vector2(size.x - 8.0, 8.0)), _style.accent)
				_text(sign.text, Vector2(0.0, 6.0), 22.0, _style.paper)
			else:
				draw_rect(box, ink)
				draw_rect(box.grow(-4.0), _style.accent)
				_text(sign.text, Vector2(0.0, 2.0), 30.0, Color("d8433a"))
			draw_set_transform(Vector2.ZERO)


## Prisma de tres caras que gira un cuarto de vuelta en cada beat (rápido al empezar el beat).
func _draw_offer_prism(at: Vector2, beat: float) -> void:
	var faces: Array[String] = ["OFERTA", "2x1", "-50%", "LLEVE 3"]
	var colors: Array[Color] = [Color("d8433a"), _style.accent, _style.paper, Color("4fb3c9")]
	var whole := floorf(beat)
	var turn := whole + smoothstep(0.0, 0.3, beat - whole)
	var angle := turn * PI * 0.5
	var width := 190.0
	var height := 70.0
	var ink := _style.outline
	for k in 4:
		var a0 := angle + k * PI * 0.5
		var a1 := a0 + PI * 0.5
		# Cara visible si mira hacia la cámara (su normal tiene componente hacia nosotros).
		if cos(a0 + PI * 0.25) <= 0.0:
			continue
		var x0 := sin(a0) * width * 0.5
		var x1 := sin(a1) * width * 0.5
		var left := minf(x0, x1)
		var right := maxf(x0, x1)
		if right - left < 2.0:
			continue
		var rect := Rect2(at.x + left, at.y - height * 0.5, right - left, height)
		var shade := cos(a0 + PI * 0.25)
		draw_rect(rect, colors[k].darkened(0.35 * (1.0 - shade)))
		draw_rect(rect, ink, false, 3.0)
		if right - left > 60.0:
			var font_size := 30.0 * clampf((right - left) / width, 0.4, 1.0)
			_text(faces[k], rect.get_center(), font_size, ink if k != 0 else _style.paper)
