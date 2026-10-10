class_name StartScreenArt
extends Control
## Pantalla de inicio: la protagonista arriba, vibrando al ritmo de la música del menú; debajo el
## título del juego y START (capas del PSD de inicio exportadas aparte por build_menu_screens.gd).
## Coordenadas del diseño (1440×1024); el botón lo pone MainMenu sobre `START_RECT`.

const PORTRAIT := "res://assets/textures/ui/protagonista_retrato.png"
const TITLE := "res://assets/textures/ui/menu/inicio_titulo.png"
const START := "res://assets/textures/ui/menu/inicio_start.png"
## Rectángulos de las capas en el PSD.
const TITLE_SOURCE := Rect2(398, 122, 644, 403)
const START_SOURCE := Rect2(682, 715, 84, 36)
## Dónde van en esta pantalla (el título al 78 %, montado sobre el busto).
const PORTRAIT_RECT := Rect2(475, 0, 490, 490)
const TITLE_RECT := Rect2(469, 430, 502, 314)
const START_RECT := Rect2(678, 790, 84, 36)
## Fondo de la pantalla (si falta, queda el gris del diseño).
const BACKGROUND := "res://assets/textures/ui/menu/inicio_fondo.png"
## El corte del busto se desvanece hacia abajo (sirve sobre cualquier fondo).
const FADE_SHADER := preload("res://src/ui/menus/fade_bottom.gdshader")

var _portrait: TextureRect
var _title: TextureRect
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_portrait = _image(load(PORTRAIT), PORTRAIT_RECT)
	_portrait.pivot_offset = Vector2(PORTRAIT_RECT.size.x * 0.5, PORTRAIT_RECT.size.y)
	var fade := ShaderMaterial.new()
	fade.shader = FADE_SHADER
	_portrait.material = fade
	_title = _image(_crop(TITLE, TITLE_SOURCE), TITLE_RECT)
	_title.pivot_offset = TITLE_RECT.size * 0.5
	_image(_crop(START, START_SOURCE), START_RECT)


## Idle al ritmo: en cada beat se aplasta y rebota, se inclina hacia un lado distinto y tiembla;
## el título late un poco.
func _process(_delta: float) -> void:
	var pulse := Conductor.pulse(6.0)
	var side := 1.0 if Conductor.beat_index() % 2 == 0 else -1.0
	var breath := sin(Time.get_ticks_msec() / 1000.0 * 2.0) * 0.01
	_portrait.scale = Vector2(1.0 + 0.045 * pulse + breath, 1.0 - 0.035 * pulse - breath)
	_portrait.rotation = side * 0.03 * pulse
	_portrait.position = PORTRAIT_RECT.position + Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-3.0, 3.0)) * pulse
	_title.scale = Vector2.ONE * (1.0 + 0.025 * pulse)


func _image(texture: Texture2D, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	# Primero el modo de ajuste: si no, el tamaño mínimo es el de la textura y no se puede achicar.
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = texture
	image.position = rect.position
	image.size = rect.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	return image


## Recorta una capa exportada a lienzo completo.
static func _crop(path: String, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	atlas.region = region
	return atlas
