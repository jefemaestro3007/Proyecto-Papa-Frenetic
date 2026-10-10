class_name RhythmHud
extends Control
## HUD de ritmo: indicador de compás, combo, puntaje y textos de juicio flotantes.

const BEATS_PER_BAR := 4
const JUDGMENT_TEXT := {
	ConductorClock.Judgment.PERFECT: "¡PERFECTO!",
	ConductorClock.Judgment.GOOD: "BIEN",
	ConductorClock.Judgment.MISS: "FUERA",
}
const JUDGMENT_COLOR := {
	ConductorClock.Judgment.PERFECT: FreneticPalette.YELLOW,
	ConductorClock.Judgment.GOOD: FreneticPalette.CREAM,
	ConductorClock.Judgment.MISS: Color(0.6, 0.58, 0.68),
}

var tracker: RhythmTracker
var _combo_label: Label
var _score_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_label = _make_label(44)
	_combo_label.position = Vector2(24.0, 56.0)
	_score_label = _make_label(24)
	_score_label.position = Vector2(26.0, 112.0)


func _process(_delta: float) -> void:
	if tracker != null:
		_combo_label.text = "x%d COMBO" % tracker.combo if tracker.combo > 1 else ""
		_combo_label.scale = Vector2.ONE * (1.0 + 0.12 * Conductor.pulse(10.0) * minf(tracker.combo, 1.0))
		_score_label.text = "%d pts  ·  x%d" % [tracker.score, tracker.multiplier()]
	queue_redraw()


## Indicador de compás: cuatro marcas abajo al centro, la actual late.
func _draw() -> void:
	var current := posmod(Conductor.beat_index(), BEATS_PER_BAR)
	var pulse := Conductor.pulse(8.0)
	var center := Vector2(size.x * 0.5, size.y - 60.0)
	for i in BEATS_PER_BAR:
		var x := center.x + (i - (BEATS_PER_BAR - 1) * 0.5) * 44.0
		var active := i == current
		var half := 10.0 + (8.0 * pulse if active else 0.0)
		var rect := Rect2(x - half, center.y - half, half * 2.0, half * 2.0)
		draw_rect(rect, FreneticPalette.YELLOW if active else FreneticPalette.NAVY)
		draw_rect(rect, FreneticPalette.INK, false, 3.0)


## Texto de juicio que sube y se desvanece desde una posición de pantalla.
func popup(judgment: int, screen_position: Vector2, points: int) -> void:
	var label := _make_label(34)
	label.text = JUDGMENT_TEXT[judgment] + ("  +%d" % points if points > 0 else "")
	label.add_theme_color_override("font_color", JUDGMENT_COLOR[judgment])
	label.position = screen_position + Vector2(-80.0, -200.0)
	label.rotation = randf_range(-0.12, 0.12)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 70.0, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", FreneticPalette.CREAM)
	label.add_theme_color_override("font_outline_color", FreneticPalette.INK)
	label.add_theme_constant_override("outline_size", 10)
	add_child(label)
	return label
