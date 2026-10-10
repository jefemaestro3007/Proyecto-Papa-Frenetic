extends SceneTree
## Genera los sprites de enemigos, efectos (stomp, tajo) e interfaz (papa del calor) a partir de los
## dibujos de `assets_src/sprites/`.
## Cada enemigo tiene tres poses (base, ataque, herido) dibujadas en el mismo lienzo: se recortan con
## el mismo rectángulo para que no salten al cambiar de pose, con el ancla (los pies) abajo al
## centro del cuerpo de la pose base, y se escalan a la altura que tienen en el juego.
## Ejecutar (y después `--import`):
##   godot --headless --path . --script res://tools/scripts/build_enemy_sprites.gd

const SOURCE := "res://assets_src/sprites/"
const OUTPUT := "res://assets/textures/sprites/enemies/"
const FX_OUTPUT := "res://assets/textures/sprites/fx/"
const UI_OUTPUT := "res://assets/textures/ui/"
## Secuencias de la interfaz: nombre → (cantidad de frames, altura en pantalla). Se recortan todos
## con el mismo rectángulo para conservar cómo cambian de tamaño (la papa se hincha al calentarse).
const UI_SEQUENCES := {"papa_calor": [5, 150.0]}
const POSES: Array[String] = ["base", "ataque", "herido"]
## Archivo de origen (sin extensión) → id del enemigo en el juego (`Enemy.enemy_type`) y altura en
## pantalla en px.
const ENEMIES := {
	"normal": ["normal", 96.0],
	"tanque": ["tank", 132.0],
	"embestidora": ["charger", 104.0],
	"tiradora": ["thrower", 112.0],
	"voladora": ["flyer", 78.0],
}
## Efectos: archivo → altura en pantalla. Se recortan a su contenido con el ancla abajo al centro.
const EFFECTS := {"stomp_flecha": 150.0, "stomp_nube": 70.0, "ataque_swing": 96.0}
## Se guardan al doble de resolución; el juego los dibuja a 0,5.
const SUPERSAMPLE := 2.0
## Corte cresta/cuerpo de la tiradora fijado a mano donde la detección falla (cresta inclinada).
const THROWER_NECK := {"herido": 0.36}

var _failures := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FX_OUTPUT))
	for source: String in ENEMIES:
		var frames: Array[Image] = []
		for pose in POSES:
			var image := _load(SOURCE + "enemies/" + source + "_" + pose)
			if image == null:
				break
			frames.append(image)
		if frames.size() != POSES.size():
			continue
		if not "--original" in OS.get_cmdline_user_args():
			for i in POSES.size():
				_recolor(source, POSES[i], frames[i])
		var union := frames[0].get_used_rect()
		for image in frames:
			union = union.merge(image.get_used_rect())
		var anchor_x := frames[0].get_used_rect().get_center().x
		var target: float = ENEMIES[source][1] * SUPERSAMPLE
		for i in POSES.size():
			var out := _crop_anchor_scale(frames[i], union, anchor_x, target / union.size.y)
			_save(out, OUTPUT + "%s_%s" % [ENEMIES[source][0], POSES[i]])
	for effect: String in EFFECTS:
		var image := _load(SOURCE + "fx/" + effect)
		if image == null:
			continue
		_remove_specks(image)
		var used := image.get_used_rect()
		_save(_crop_anchor_scale(image, used, used.get_center().x, EFFECTS[effect] * SUPERSAMPLE / used.size.y),
				FX_OUTPUT + effect)
	for sequence: String in UI_SEQUENCES:
		var count: int = UI_SEQUENCES[sequence][0]
		var frames: Array[Image] = []
		for i in count:
			var image := _load(SOURCE + "ui/%s_%d" % [sequence, i + 1])
			if image != null:
				frames.append(image)
		if frames.size() != count:
			continue
		var union := frames[0].get_used_rect()
		for image in frames:
			union = union.merge(image.get_used_rect())
		var scale: float = UI_SEQUENCES[sequence][1] * SUPERSAMPLE / union.size.y
		for i in count:
			_save(_crop_anchor_scale(frames[i], union, union.get_center().x, scale), UI_OUTPUT + "%s_%d" % [sequence, i + 1])
	print("build_enemy_sprites: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


# --- Variaciones de color (experimento) ----------------------------------------------
# Para diferenciar a las papas sin dibujar sprites nuevos. `-- --original` las desactiva.

## Rojo de los dibujos (piel de las papas rojas); las líneas negras no cuentan.
func _is_red(c: Color) -> bool:
	return c.a8 > 16 and (c.h < 0.07 or c.h > 0.93) and c.s > 0.35 and c.v > 0.2


func _is_line(c: Color) -> bool:
	return c.a8 > 16 and c.v < 0.2


## Cambia el color conservando la textura: el brillo del píxel escala el color destino.
func _tint(c: Color, target: Color) -> Color:
	var k := clampf(c.v / 0.62, 0.45, 1.5)
	return Color(minf(target.r * k, 1.0), minf(target.g * k, 1.0), minf(target.b * k, 1.0), c.a)


func _recolor(source: String, pose: String, image: Image) -> void:
	match source:
		"tiradora":
			_recolor_thrower(image, THROWER_NECK.get(pose, -1.0))
		"embestidora":
			_recolor_charger(image)
		"tanque":
			_recolor_tank(image)


## Tiradora: cuerpo del color de la papa común; la cresta (arriba del cuello) sigue roja.
## `neck_at` (0-1 desde arriba del dibujo) fija el corte a mano; negativo = buscarlo.
func _recolor_thrower(image: Image, neck_at: float) -> void:
	var skin := _potato_skin()
	var used := image.get_used_rect()
	# La cresta está arriba a la derecha y el cuerpo sobresale hacia la izquierda: el cuello es la
	# fila donde el borde izquierdo del dibujo salta más hacia afuera (en la mitad de arriba).
	var lefts := PackedInt32Array()
	for y in range(used.position.y, used.end.y):
		var left := used.end.x
		for x in range(used.position.x, used.end.x, 2):
			if image.get_pixel(x, y).a8 > 16:
				left = x
				break
		lefts.append(left)
	var neck := used.position.y + used.size.y / 3
	var jump := 0
	const STEP := 30
	for i in range(0, mini(lefts.size() - STEP, used.size.y * 55 / 100)):
		if lefts[i] - lefts[i + STEP] > jump:
			jump = lefts[i] - lefts[i + STEP]
			neck = used.position.y + i + STEP / 2
	if neck_at >= 0.0:
		neck = used.position.y + int(used.size.y * neck_at)
	const BLEND := 30.0
	for y in range(used.position.y, used.end.y):
		var weight := clampf((y - neck + BLEND * 0.5) / BLEND, 0.0, 1.0)
		if weight <= 0.0:
			continue
		for x in range(used.position.x, used.end.x):
			var c := image.get_pixel(x, y)
			if _is_red(c):
				image.set_pixel(x, y, c.lerp(_tint(c, skin), weight))


## Color medio de la piel de la papa común (la foto), para que la tiradora sea "de la misma papa".
func _potato_skin() -> Color:
	var image := _load(SOURCE + "enemies/normal_base")
	var sum := Color(0, 0, 0, 0)
	var count := 0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var c := image.get_pixel(x, y)
			if c.a8 > 200 and c.s > 0.3 and c.v > 0.3:
				sum += c
				count += 1
	return Color(sum.r / count, sum.g / count, sum.b / count) if count > 0 else Color("c4893a")


## Embestidora: la papa de adelante (la del contorno negro, a la izquierda) se vuelve negra y sus
## líneas rojas; la de atrás sigue roja. La de adelante se encuentra rellenando desde su interior
## hasta su contorno; como el contorno a mano tiene huecos, antes se engrosan las líneas.
func _recolor_charger(image: Image) -> void:
	var used := image.get_used_rect()
	var w := image.get_width()
	const CLOSE := 20
	# Nunca pasa de este punto hacia la derecha (la papa de atrás).
	var limit_x := used.position.x + int(used.size.x * 0.6)
	var lines := PackedByteArray()
	lines.resize(w * image.get_height())
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			if _is_line(image.get_pixel(x, y)):
				lines[y * w + x] = 1
	var barrier := _dilate(lines, w, image.get_height(), used, CLOSE)
	var seed := Vector2i(used.position.x + used.size.x / 5, used.position.y + int(used.size.y * 0.62))
	while seed.x < used.end.x and (barrier[seed.y * w + seed.x] != 0 or not _is_red(image.get_pixelv(seed))):
		seed.x += 2
	var front := {}
	var stack: Array[Vector2i] = [seed]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if front.has(p) or not used.has_point(p) or barrier[p.y * w + p.x] != 0 \
				or image.get_pixelv(p).a8 <= 16:
			continue
		front[p] = true
		stack.append_array([p + Vector2i.LEFT, p + Vector2i.RIGHT, p + Vector2i.UP, p + Vector2i.DOWN])
	# Recupera la franja que quedó bajo las líneas engrosadas (sin cruzar al otro lado del contorno).
	var grown := front.duplicate()
	var ring: Array = front.keys()
	for _step in CLOSE + 1:
		var next: Array = []
		for p: Vector2i in ring:
			for q: Vector2i in [p + Vector2i.LEFT, p + Vector2i.RIGHT, p + Vector2i.UP, p + Vector2i.DOWN]:
				if not grown.has(q) and used.has_point(q) and _is_red(image.get_pixelv(q)):
					grown[q] = true
					next.append(q)
		ring = next
	for p: Vector2i in grown:
		image.set_pixelv(p, _tint(image.get_pixelv(p), Color(0.16, 0.14, 0.15)))
	# Líneas de la papa de adelante (contorno y cara) en rojo, para que se vean sobre el negro.
	_lines_to_red(image, grown, CLOSE)


## Dilata una máscara (máximo en un cuadrado de lado 2r+1), por filas y columnas.
func _dilate(mask: PackedByteArray, w: int, h: int, area: Rect2i, r: int) -> PackedByteArray:
	var rows := PackedByteArray()
	rows.resize(w * h)
	for y in range(area.position.y, area.end.y):
		var last := -100000
		for x in range(area.position.x, area.end.x):
			if mask[y * w + x] != 0:
				last = x
			if x - last <= r:
				rows[y * w + x] = 1
		last = 100000
		for x in range(area.end.x - 1, area.position.x - 1, -1):
			if mask[y * w + x] != 0:
				last = x
			if last - x <= r:
				rows[y * w + x] = 1
	var out := PackedByteArray()
	out.resize(w * h)
	for x in range(area.position.x, area.end.x):
		var last := -100000
		for y in range(area.position.y, area.end.y):
			if rows[y * w + x] != 0:
				last = y
			if y - last <= r:
				out[y * w + x] = 1
		last = 100000
		for y in range(area.end.y - 1, area.position.y - 1, -1):
			if rows[y * w + x] != 0:
				last = y
			if last - y <= r:
				out[y * w + x] = 1
	return out



## Tanque: negro con las líneas rojas y un contorno rojo alrededor.
func _recolor_tank(image: Image) -> void:
	var used := image.get_used_rect()
	var body := {}
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			var c := image.get_pixel(x, y)
			if _is_red(c):
				image.set_pixel(x, y, _tint(c, Color(0.16, 0.14, 0.15)))
				body[Vector2i(x, y)] = true
	_lines_to_red(image, body, 10)
	_outline(image, Color("d8261c"), 16)


## Pasa a rojo las líneas negras que están a menos de `reach` px de la región.
func _lines_to_red(image: Image, region: Dictionary, reach: int) -> void:
	var red := Color("e3321f")
	var used := image.get_used_rect()
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			var c := image.get_pixel(x, y)
			# Los píxeles recién oscurecidos de la región no son líneas.
			if region.has(Vector2i(x, y)) or not _is_line(c):
				continue
			for d in [Vector2i(reach, 0), Vector2i(-reach, 0), Vector2i(0, reach), Vector2i(0, -reach)]:
				if region.has(Vector2i(x, y) + d):
					image.set_pixel(x, y, Color(red, c.a))
					break


## Contorno de color alrededor de todo el dibujo (por detrás).
func _outline(image: Image, color: Color, width: int) -> void:
	var source := image.duplicate() as Image
	var w := image.get_width()
	var h := image.get_height()
	var used := source.get_used_rect().grow(width).intersection(Rect2i(0, 0, w, h))
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			if source.get_pixel(x, y).a8 > 128:
				continue
			var near := false
			for angle in 12:
				var d := Vector2(width, 0).rotated(TAU * angle / 12.0)
				var p := Vector2i(x + roundi(d.x), y + roundi(d.y))
				if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and source.get_pixelv(p).a8 > 128:
					near = true
					break
			if near:
				var c := source.get_pixel(x, y)
				image.set_pixel(x, y, color.blend(c) if c.a8 > 0 else color)


func _load(path_without_extension: String) -> Image:
	for extension in [".png", ".webp"]:
		var path := ProjectSettings.globalize_path(path_without_extension + extension)
		if FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			image.convert(Image.FORMAT_RGBA8)
			return image
	_fail("falta " + path_without_extension + " (.png o .webp)")
	return null


## Recorta `rect`, centra `anchor_x` en el ancho y escala.
func _crop_anchor_scale(image: Image, rect: Rect2i, anchor_x: int, scale: float) -> Image:
	var half := maxi(anchor_x - rect.position.x, rect.end.x - anchor_x)
	var canvas := Image.create_empty(half * 2, rect.size.y, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(image, rect, Vector2i(half - (anchor_x - rect.position.x), 0))
	canvas.resize(maxi(roundi(canvas.get_width() * scale), 2), maxi(roundi(canvas.get_height() * scale), 2),
			Image.INTERPOLATE_LANCZOS)
	return canvas


func _save(image: Image, path: String) -> void:
	image.save_png(ProjectSettings.globalize_path(path + ".png"))
	print("  %s: %dx%d" % [path.get_file(), image.get_width(), image.get_height()])


func _fail(message: String) -> void:
	_failures += 1
	printerr("  FALLO: ", message)


## Borra manchas sueltas (un trazo perdido agrandaría el recorte y correría el ancla).
func _remove_specks(image: Image) -> void:
	var w := image.get_width()
	var used := image.get_used_rect()
	var seen := {}
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			var start := Vector2i(x, y)
			if seen.has(start) or image.get_pixelv(start).a8 <= 16:
				continue
			var component: Array[Vector2i] = []
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				component.append(p)
				for q: Vector2i in [p + Vector2i.LEFT, p + Vector2i.RIGHT, p + Vector2i.UP, p + Vector2i.DOWN]:
					if not seen.has(q) and used.has_point(q) and image.get_pixelv(q).a8 > 16:
						seen[q] = true
						stack.append(q)
			if component.size() < 300:
				for p in component:
					image.set_pixelv(p, Color.TRANSPARENT)
