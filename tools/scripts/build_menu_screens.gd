extends SceneTree
## Convierte las pantallas del menú (PSD de `assets_src/ui/menu/`) en PNG para el juego
## (`assets/textures/ui/menu/`). Godot no lee PSD: se decodifica la imagen compuesta que guarda
## todo PSD al final del archivo (RGB de 8 bits, cruda o comprimida con RLE/PackBits). También
## imprime las capas con su rectángulo, para ubicar los botones. Ejecutar (y después `--import`):
##   godot --headless --path . --script res://tools/scripts/build_menu_screens.gd

const SOURCE := "res://assets_src/ui/menu/"
const OUTPUT := "res://assets/textures/ui/menu/"
## Capas que se exportan aparte (y no van en la pantalla base): archivo → { salida: prefijo de capa }.
## Las papas de LOADING se animan por separado.
const SPLIT := {
	"cargando": {"cargando_fase_1": "FASE 1", "cargando_fase_2": "FASE 2", "cargando_fase_3": "FASE 3"},
}

var _failures := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var dir := DirAccess.open(ProjectSettings.globalize_path(SOURCE))
	for file in dir.get_files():
		if file.get_extension() != "psd":
			continue
		var bytes := FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(SOURCE + file))
		var outputs := _decode(bytes, file)
		for out_name: String in outputs:
			var image: Image = outputs[out_name]
			image.save_png(ProjectSettings.globalize_path(OUTPUT + out_name + ".png"))
			print("  %s → %s.png (%dx%d)" % [file, out_name, image.get_width(), image.get_height()])
	print("build_menu_screens: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


## Devuelve { nombre de salida: Image }: la pantalla base y, si corresponde, las capas aparte.
func _decode(b: PackedByteArray, file: String) -> Dictionary:
	if b.size() < 26 or b.slice(0, 4).get_string_from_ascii() != "8BPS":
		return _fail_empty(file + ": no es un PSD")
	var channels := _u16(b, 12)
	var height := _u32(b, 14)
	var width := _u32(b, 18)
	var depth := _u16(b, 22)
	var mode := _u16(b, 24)
	if depth != 8 or mode != 3:
		return _fail_empty("%s: solo RGB de 8 bits (profundidad %d, modo %d)" % [file, depth, mode])
	var p := 26
	p += 4 + _u32(b, p) # datos de modo de color
	p += 4 + _u32(b, p) # recursos de imagen
	var layers_length := _u32(b, p)
	var layers := _read_layers(b, p + 4, file)
	var base := file.get_basename()
	if not layers.is_empty():
		var outputs := {}
		var split: Dictionary = SPLIT.get(base, {})
		var rest := []
		for layer in layers:
			var target := base
			for out_name: String in split:
				if String(layer.name).begins_with(split[out_name]):
					target = out_name
			if target == base:
				rest.append(layer)
			else:
				if not outputs.has(target):
					outputs[target] = []
				outputs[target].append(layer)
		for out_name: String in outputs:
			outputs[out_name] = _compose(outputs[out_name], width, height)
		outputs[base] = _compose(rest, width, height)
		return outputs
	p += 4 + layers_length
	var compression := _u16(b, p)
	p += 2
	var planes: Array[PackedByteArray] = []
	var used := mini(channels, 4)
	if compression == 0:
		for c in used:
			planes.append(b.slice(p + c * width * height, p + (c + 1) * width * height))
	elif compression == 1:
		var counts := PackedInt32Array()
		for i in channels * height:
			counts.append(_u16(b, p + i * 2))
		p += channels * height * 2
		for c in channels:
			var plane := PackedByteArray()
			plane.resize(width * height)
			for y in height:
				var row_end := p + counts[c * height + y]
				_unpack_row(b, p, row_end, plane, y * width, width)
				p = row_end
			if c < used:
				planes.append(plane)
	else:
		return _fail_empty("%s: compresión %d no soportada" % [file, compression])
	var rgba := PackedByteArray()
	rgba.resize(width * height * 4)
	for i in width * height:
		rgba[i * 4] = planes[0][i]
		rgba[i * 4 + 1] = planes[1][i]
		rgba[i * 4 + 2] = planes[2][i]
		rgba[i * 4 + 3] = planes[3][i] if used > 3 else 255
	return {base: Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, rgba)}


## PackBits: n en 0..127 → copiar n+1 bytes; n en -127..-1 → repetir el siguiente 1-n veces.
func _unpack_row(b: PackedByteArray, from: int, to: int, out: PackedByteArray, at: int, width: int) -> void:
	var p := from
	var o := at
	var end := at + width
	while p < to and o < end:
		var n := b[p]
		p += 1
		if n < 128:
			for k in n + 1:
				if o < end:
					out[o] = b[p + k]
					o += 1
			p += n + 1
		elif n > 128:
			for k in 257 - n:
				if o < end:
					out[o] = b[p]
					o += 1
			p += 1


## Lee las capas (nombre, rectángulo, opacidad, visibilidad y píxeles) y las imprime. Las capas de
## texto exportadas desde Figma no siempre están en la imagen compuesta, así que la pantalla se arma
## componiendo las capas.
func _read_layers(b: PackedByteArray, p: int, file: String) -> Array:
	var layers := []
	if _u32(b, p) == 0:
		return layers
	p += 4
	var count := absi(_s16(b, p))
	p += 2
	print("  %s: %d capas" % [file, count])
	for i in count:
		var layer := {}
		layer.top = _s32(b, p)
		layer.left = _s32(b, p + 4)
		layer.bottom = _s32(b, p + 8)
		layer.right = _s32(b, p + 12)
		var layer_channels := _u16(b, p + 16)
		p += 18
		var channels := []
		for c in layer_channels:
			channels.append([_s16(b, p), _u32(b, p + 2)])
			p += 6
		layer.channels = channels
		layer.opacity = b[p + 8]
		layer.hidden = b[p + 10] & 0x02 != 0
		p += 12
		var extra := _u32(b, p)
		p += 4
		var extra_end := p + extra
		p += 4 + _u32(b, p) # máscara
		p += 4 + _u32(b, p) # rangos de fusión
		var name_length := b[p]
		layer.name = b.slice(p + 1, p + 1 + name_length).get_string_from_utf8()
		print("    - '%s' x=%d y=%d %dx%d%s" % [layer.name, layer.left, layer.top, layer.right - layer.left,
				layer.bottom - layer.top, " (oculta)" if layer.hidden else ""])
		p = extra_end
		layers.append(layer)
	# Datos de píxeles de cada canal, en el mismo orden que los registros.
	for layer in layers:
		var w: int = layer.right - layer.left
		var h: int = layer.bottom - layer.top
		var planes := {}
		for channel in layer.channels:
			var id: int = channel[0]
			var length: int = channel[1]
			var end := p + length
			if w > 0 and h > 0 and id >= -1 and id <= 2 and length >= 2:
				planes[id] = _read_plane(b, p, w, h)
			p = end
		layer.planes = planes
	return layers


func _read_plane(b: PackedByteArray, p: int, w: int, h: int) -> PackedByteArray:
	var compression := _u16(b, p)
	p += 2
	if compression == 0:
		return b.slice(p, p + w * h)
	var plane := PackedByteArray()
	plane.resize(w * h)
	if compression != 1:
		return plane
	var counts := PackedInt32Array()
	for y in h:
		counts.append(_u16(b, p + y * 2))
	p += h * 2
	for y in h:
		_unpack_row(b, p, p + counts[y], plane, y * w, w)
		p += counts[y]
	return plane


## Compone las capas visibles (modo normal, con su opacidad) de abajo hacia arriba.
func _compose(layers: Array, width: int, height: int) -> Image:
	var canvas := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for layer in layers:
		var w: int = layer.right - layer.left
		var h: int = layer.bottom - layer.top
		if layer.hidden or w <= 1 or h <= 1 or not layer.planes.has(0):
			continue
		var planes: Dictionary = layer.planes
		var data := PackedByteArray()
		data.resize(w * h * 4)
		for i in w * h:
			data[i * 4] = planes[0][i]
			data[i * 4 + 1] = planes[1][i] if planes.has(1) else planes[0][i]
			data[i * 4 + 2] = planes[2][i] if planes.has(2) else planes[0][i]
			var a: int = planes[-1][i] if planes.has(-1) else 255
			data[i * 4 + 3] = a * layer.opacity / 255
		var image := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
		canvas.blend_rect(image, Rect2i(0, 0, w, h), Vector2i(layer.left, layer.top))
	return canvas


func _u16(b: PackedByteArray, p: int) -> int:
	return (b[p] << 8) | b[p + 1]


func _s16(b: PackedByteArray, p: int) -> int:
	var v := _u16(b, p)
	return v - 65536 if v >= 32768 else v


func _u32(b: PackedByteArray, p: int) -> int:
	return (b[p] << 24) | (b[p + 1] << 16) | (b[p + 2] << 8) | b[p + 3]


func _s32(b: PackedByteArray, p: int) -> int:
	var v := _u32(b, p)
	return v - 4294967296 if v >= 2147483648 else v


func _fail_empty(message: String) -> Dictionary:
	_failures += 1
	printerr("  FALLO: ", message)
	return {}
