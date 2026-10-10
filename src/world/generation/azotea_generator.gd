class_name AzoteaGenerator
extends RefCounted
## Genera una ciudad en ruinas a partir de AzoteaParams. Sin nodos ni estado global:
## todo el azar sale de un único RandomNumberGenerator sembrado con `params.seed`.

const ROOF_DEPTH := 1400.0
const SNAP := 20.0
## La primera azotea es una zona segura: siempre ancha y a la altura base.
const START_ROOF_WIDTH := 1400.0
const SPAWN_OFFSET := 900.0
## Los detalles usan su propio RNG: añadir o cambiar detalles nunca altera el trazado del mapa.
const DETAIL_SALT := 0x0de7a11

const PROP_WEIGHTS := {
	AzoteaMapData.Prop.Type.AC_UNIT: 0.16,
	AzoteaMapData.Prop.Type.WATER_TANK: 0.08,
	AzoteaMapData.Prop.Type.ANTENNA: 0.1,
	AzoteaMapData.Prop.Type.VENT: 0.13,
	AzoteaMapData.Prop.Type.CHIMNEY: 0.07,
	AzoteaMapData.Prop.Type.STAIR_HUT: 0.06,
	AzoteaMapData.Prop.Type.SKYLIGHT: 0.07,
	AzoteaMapData.Prop.Type.BILLBOARD: 0.05,
	AzoteaMapData.Prop.Type.BARREL: 0.1,
	AzoteaMapData.Prop.Type.CRATES: 0.08,
	AzoteaMapData.Prop.Type.SATELLITE_DISH: 0.05,
	AzoteaMapData.Prop.Type.PIPE_RUN: 0.05,
}
## Rangos de tamaño (ancho, alto) por tipo: [mín, máx].
const PROP_SIZES := {
	AzoteaMapData.Prop.Type.AC_UNIT: [Vector2(80.0, 50.0), Vector2(110.0, 64.0)],
	AzoteaMapData.Prop.Type.WATER_TANK: [Vector2(80.0, 150.0), Vector2(110.0, 200.0)],
	AzoteaMapData.Prop.Type.ANTENNA: [Vector2(24.0, 140.0), Vector2(24.0, 240.0)],
	AzoteaMapData.Prop.Type.VENT: [Vector2(30.0, 40.0), Vector2(44.0, 70.0)],
	AzoteaMapData.Prop.Type.CHIMNEY: [Vector2(40.0, 90.0), Vector2(60.0, 140.0)],
	AzoteaMapData.Prop.Type.STAIR_HUT: [Vector2(120.0, 110.0), Vector2(160.0, 130.0)],
	AzoteaMapData.Prop.Type.SKYLIGHT: [Vector2(90.0, 26.0), Vector2(140.0, 34.0)],
	AzoteaMapData.Prop.Type.BILLBOARD: [Vector2(220.0, 200.0), Vector2(320.0, 260.0)],
	AzoteaMapData.Prop.Type.BARREL: [Vector2(40.0, 54.0), Vector2(46.0, 62.0)],
	AzoteaMapData.Prop.Type.CRATES: [Vector2(50.0, 50.0), Vector2(110.0, 104.0)],
	AzoteaMapData.Prop.Type.SATELLITE_DISH: [Vector2(56.0, 64.0), Vector2(72.0, 84.0)],
	AzoteaMapData.Prop.Type.PIPE_RUN: [Vector2(150.0, 30.0), Vector2(300.0, 44.0)],
}
const MARK_WEIGHTS := {
	MapMark.Type.BLOOD: 0.18,
	MapMark.Type.CRACK: 0.18,
	MapMark.Type.STAIN: 0.14,
	MapMark.Type.RUBBLE: 0.12,
	MapMark.Type.POSTER: 0.12,
	MapMark.Type.GRAFFITI: 0.1,
	MapMark.Type.WALL_UNIT: 0.08,
	MapMark.Type.BONES: 0.08,
}


static func generate(params: AzoteaParams) -> AzoteaMapData:
	var rng := RandomNumberGenerator.new()
	rng.seed = params.seed

	# Campo compartido: define el relieve de las azoteas y la altura del skyline,
	# así mapa y fondo "respiran" con el mismo perfil.
	var field := FastNoiseLite.new()
	field.seed = params.seed
	field.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	field.frequency = 0.0007

	var data := AzoteaMapData.new()
	_build_roofs(data, params, rng, field)
	data.far = build_skyline(rng, field, params.skyline_width, params.ruin, params.broken_windows,
			690.0, Vector2(160.0, 470.0), Vector2(90.0, 240.0), 0.0)
	data.near = build_skyline(rng, field, params.skyline_width, params.ruin, params.broken_windows,
			760.0, Vector2(90.0, 330.0), Vector2(140.0, 320.0), 5000.0)
	_build_details(data, params)
	return data


static func _build_details(data: AzoteaMapData, params: AzoteaParams) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = params.seed ^ DETAIL_SALT
	for r in data.roofs.size():
		var roof := data.roofs[r]
		_place_props(data, rng, roof, r, params.detail_density)
		_place_marks(data, rng, roof, params.marks_per_roof)
	for r in range(1, data.roofs.size()):
		var a := data.roofs[r - 1]
		var b := data.roofs[r]
		if b.position.x - a.end.x > 10.0 and rng.randf() < params.cable_chance:
			var from := Vector2(a.end.x - rng.randf_range(30.0, 120.0), a.position.y - rng.randf_range(150.0, 230.0))
			var to := Vector2(b.position.x + rng.randf_range(30.0, 120.0), b.position.y - rng.randf_range(150.0, 230.0))
			data.cables.append(AzoteaMapData.Cable.new(from, to, rng.randf_range(30.0, 90.0),
					a.position.y, b.position.y))


## Objetos de izquierda a derecha sin solaparse, dentro de la azotea.
static func _place_props(data: AzoteaMapData, rng: RandomNumberGenerator, roof: Rect2, roof_index: int,
		density: float) -> void:
	var x := roof.position.x + 40.0
	var right := roof.end.x - 40.0
	while x < right:
		if rng.randf() >= density:
			x += rng.randf_range(60.0, 160.0)
			continue
		var type: AzoteaMapData.Prop.Type = _weighted_pick(rng, PROP_WEIGHTS)
		var sizes: Array = PROP_SIZES[type]
		var size := Vector2(rng.randf_range(sizes[0].x, sizes[1].x), rng.randf_range(sizes[0].y, sizes[1].y))
		if x + size.x > right:
			break
		data.props.append(AzoteaMapData.Prop.new(type, Rect2(x, roof.position.y - size.y, size.x, size.y),
				rng.randi(), roof_index))
		x += size.x + rng.randf_range(20.0, 90.0)


## Marcas: escombros sobre el techo; sangre, grietas y manchas en la fachada.
static func _place_marks(data: AzoteaMapData, rng: RandomNumberGenerator, roof: Rect2, max_count: int) -> void:
	for i in rng.randi_range(max_count / 2, max_count):
		var type: MapMark.Type = _weighted_pick(rng, MARK_WEIGHTS)
		var x := rng.randf_range(roof.position.x + 30.0, roof.end.x - 30.0)
		var y := roof.position.y
		if not MapMark.on_floor(type):
			# Franja de fachada que la cámara suele mostrar bajo el borde.
			y += rng.randf_range(50.0, 260.0)
		data.marks.append(MapMark.new(type, Vector2(x, y), rng.randf_range(0.6, 1.4),
				rng.randf(), rng.randi()))


static func _weighted_pick(rng: RandomNumberGenerator, weights: Dictionary) -> Variant:
	var total := 0.0
	for key in weights:
		total += weights[key]
	var roll := rng.randf() * total
	for key in weights:
		roll -= weights[key]
		if roll <= 0.0:
			return key
	return weights.keys().back()


static func _build_roofs(data: AzoteaMapData, params: AzoteaParams, rng: RandomNumberGenerator,
		field: FastNoiseLite) -> void:
	var width_max: float = maxf(params.roof_width_min, params.roof_width_max)
	var x := -600.0
	var prev_top := params.roof_base_y
	var lowest := params.roof_base_y
	for i in params.roof_count:
		var w := snappedf(rng.randf_range(params.roof_width_min, width_max), SNAP)
		var top := params.roof_base_y + field.get_noise_1d(x + w * 0.5) * params.roof_height_variation
		# Nunca subir más de lo que se puede saltar.
		top = maxf(top, prev_top - params.max_step)
		top = snappedf(top, SNAP)
		if i == 0:
			w = maxf(w, START_ROOF_WIDTH)
			top = params.roof_base_y
		data.roofs.append(Rect2(x, top, w, ROOF_DEPTH))
		prev_top = top
		lowest = maxf(lowest, top)
		x += w
		if rng.randf() < params.gap_chance:
			x += snappedf(rng.randf_range(params.gap_max * 0.4, params.gap_max), SNAP)

	data.spawn = Vector2(data.roofs[0].position.x + SPAWN_OFFSET, data.roofs[0].position.y - 60.0)
	data.kill_y = lowest + 900.0


## Capa de skyline en ruinas; la usan todas las zonas que ven la ciudad de fondo.
static func build_skyline(rng: RandomNumberGenerator, field: FastNoiseLite, width: float, ruin: float,
		broken_windows: float, base_y: float, height_range: Vector2, width_range: Vector2,
		field_offset: float) -> AzoteaMapData.SkylineData:
	var layer := AzoteaMapData.SkylineData.new()
	layer.width = width
	var bottom := base_y + 900.0
	var x := 0.0
	while x < layer.width:
		var w := minf(rng.randf_range(width_range.x, width_range.y), layer.width - x)
		var shaped := (field.get_noise_1d(x + field_offset) + 1.0) * 0.5
		var h := lerpf(height_range.x, height_range.y, lerpf(rng.randf(), shaped, 0.6))
		var top := base_y - h
		var outline := PackedVector2Array()
		if w >= 8.0:
			outline = _ruined_outline(rng, x, x + w, top, bottom, h, ruin)
			layer.buildings.append(outline)
		_add_windows(layer, rng, outline, x, w, top, base_y, broken_windows)
		# Edificios pegados o con un callejón estrecho.
		x += w + (rng.randf_range(0.0, 30.0) if rng.randf() < 0.3 else 0.0)
	return layer


## Silueta con techo dentado: escalones rotos, esquinas colapsadas y algún tanque/antena.
static func _ruined_outline(rng: RandomNumberGenerator, x0: float, x1: float, top: float,
		bottom: float, h: float, ruin: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(x0, bottom))
	var w := x1 - x0
	var collapse_left := rng.randf() < ruin * 0.5
	var collapse_right := not collapse_left and rng.randf() < ruin * 0.5
	var segments := maxi(2, int(w / 28.0))
	for j in segments + 1:
		var t := float(j) / segments
		var y := top
		if rng.randf() < ruin * 0.6:
			y += rng.randf_range(0.0, h * 0.12)
		if collapse_left:
			y += (1.0 - t) * (1.0 - t) * h * 0.45
		if collapse_right:
			y += t * t * h * 0.45
		# Dientes verticales: escalón seco en lugar de pendiente suave.
		var px := x0 + w * t
		if j > 0 and rng.randf() < ruin * 0.35 and not is_equal_approx(pts[pts.size() - 1].y, y):
			pts.append(Vector2(px, pts[pts.size() - 1].y))
		pts.append(Vector2(px, y))

	if not collapse_left and not collapse_right and rng.randf() < 0.25:
		_add_rooftop_prop(pts, rng)

	pts.append(Vector2(x1, bottom))
	return pts


## Inserta un tanque de agua o antena dentro de un tramo del techo, sin romper el orden en x.
static func _add_rooftop_prop(pts: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	var i := rng.randi_range(2, pts.size() - 2)
	var a := pts[i - 1]
	var b := pts[i]
	var span := b.x - a.x
	if span < 8.0:
		return
	var tank := rng.randf() < 0.5
	var half := (span * 0.45) if tank else 3.0
	var mid := (a.x + b.x) * 0.5
	var height := rng.randf_range(20.0, 50.0) if tank else rng.randf_range(60.0, 120.0)
	var peak := minf(a.y, b.y) - height
	var prop := PackedVector2Array([
		Vector2(mid - half, lerpf(a.y, b.y, 0.5 - half / span)), Vector2(mid - half, peak),
		Vector2(mid + half, peak), Vector2(mid + half, lerpf(a.y, b.y, 0.5 + half / span))])
	for k in prop.size():
		pts.insert(i + k, prop[k])


## Rejilla de ventanas; solo se conservan las que caen por completo dentro de la silueta
## (en edificios derrumbados no quedan ventanas flotando en el cielo).
static func _add_windows(layer: AzoteaMapData.SkylineData, rng: RandomNumberGenerator,
		outline: PackedVector2Array, x: float, w: float, top: float, base_y: float, broken: float) -> void:
	const INSET := 3.0
	const CELL := Vector2(24.0, 30.0)
	const SIZE := Vector2(12.0, 16.0)
	var cols := int((w - 16.0) / CELL.x)
	var rows := int((base_y - top - 40.0) / CELL.y)
	if cols <= 0 or rows <= 0:
		return
	var margin := (w - cols * CELL.x) * 0.5
	for r in rows:
		for c in cols:
			if rng.randf() < broken:
				continue
			var rect := Rect2(Vector2(x + margin + c * CELL.x + 6.0, top + 40.0 + r * CELL.y), SIZE)
			if _rect_inside(rect.grow(INSET), outline):
				layer.windows.append(rect)


static func _rect_inside(rect: Rect2, polygon: PackedVector2Array) -> bool:
	if polygon.is_empty():
		return false
	# Lo que queda del rectángulo al restarle la silueta: vacío = está completamente dentro.
	var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)])
	return Geometry2D.clip_polygons(corners, polygon).is_empty()
