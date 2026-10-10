class_name AzoteaGenerator
extends RefCounted
## Genera una ciudad en ruinas a partir de AzoteaParams. Sin nodos ni estado global:
## todo el azar sale de un único RandomNumberGenerator sembrado con `params.seed`.

const ROOF_DEPTH := 1400.0
const SNAP := 20.0
## La primera azotea es una zona segura: siempre ancha y a la altura base.
const START_ROOF_WIDTH := 1400.0
const SPAWN_OFFSET := 900.0


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
	data.far = _build_skyline(params, rng, field, 690.0, Vector2(160.0, 470.0), Vector2(90.0, 240.0), 0.0)
	data.near = _build_skyline(params, rng, field, 760.0, Vector2(90.0, 330.0), Vector2(140.0, 320.0), 5000.0)
	return data


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


static func _build_skyline(params: AzoteaParams, rng: RandomNumberGenerator, field: FastNoiseLite,
		base_y: float, height_range: Vector2, width_range: Vector2, field_offset: float) -> AzoteaMapData.SkylineData:
	var layer := AzoteaMapData.SkylineData.new()
	layer.width = params.skyline_width
	var bottom := base_y + 900.0
	var x := 0.0
	while x < layer.width:
		var w := minf(rng.randf_range(width_range.x, width_range.y), layer.width - x)
		var shaped := (field.get_noise_1d(x + field_offset) + 1.0) * 0.5
		var h := lerpf(height_range.x, height_range.y, lerpf(rng.randf(), shaped, 0.6))
		var top := base_y - h
		if w >= 8.0:
			layer.buildings.append(_ruined_outline(rng, x, x + w, top, bottom, h, params.ruin))
		_add_windows(layer, rng, x, w, top, base_y, params.broken_windows)
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


static func _add_windows(layer: AzoteaMapData.SkylineData, rng: RandomNumberGenerator, x: float,
		w: float, top: float, base_y: float, broken: float) -> void:
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
			var pos := Vector2(x + margin + c * CELL.x + 6.0, top + 40.0 + r * CELL.y)
			layer.windows.append(Rect2(pos, SIZE))
