extends SceneTree
## Genera los sprites de enemigos y del stomp a partir de los dibujos de `assets_src/sprites/`.
## Cada enemigo tiene tres poses (base, ataque, herido) dibujadas en el mismo lienzo: se recortan con
## el mismo rectángulo para que no salten al cambiar de pose, con el ancla (los pies) abajo al
## centro del cuerpo de la pose base, y se escalan a la altura que tienen en el juego.
## Ejecutar (y después `--import`):
##   godot --headless --path . --script res://tools/scripts/build_enemy_sprites.gd

const SOURCE := "res://assets_src/sprites/"
const OUTPUT := "res://assets/textures/sprites/enemies/"
const FX_OUTPUT := "res://assets/textures/sprites/fx/"
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
const EFFECTS := {"stomp_flecha": 150.0, "stomp_nube": 70.0}
## Se guardan al doble de resolución; el juego los dibuja a 0,5.
const SUPERSAMPLE := 2.0

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
		var used := image.get_used_rect()
		_save(_crop_anchor_scale(image, used, used.get_center().x, EFFECTS[effect] * SUPERSAMPLE / used.size.y),
				FX_OUTPUT + effect)
	print("build_enemy_sprites: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


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
