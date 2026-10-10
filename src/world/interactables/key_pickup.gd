class_name KeyPickup
extends Node2D
## Llave de color que flota y late con el beat; se recoge al pasar cerca.

signal collected(key_id: int)

const PICK_DISTANCE := 60.0

var key_id := 0
var collector: Node2D
var _taken := false


func _process(_delta: float) -> void:
	if _taken:
		return
	if collector != null and collector.global_position.distance_to(global_position) < PICK_DISTANCE:
		_taken = true
		collected.emit(key_id)
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2.ONE * 1.8, 0.15)
		tween.tween_property(self, "modulate:a", 0.0, 0.2)
		tween.tween_callback(queue_free)
	queue_redraw()


func _draw() -> void:
	var color: Color = WallDoorNode.KEY_COLORS[key_id % WallDoorNode.KEY_COLORS.size()]
	var pulse := Conductor.pulse(6.0) if not Engine.is_editor_hint() else 0.0
	var bob := Vector2(0.0, sin(Time.get_ticks_msec() / 300.0) * 6.0)
	draw_circle(bob, 30.0 + pulse * 10.0, Color(color, 0.18 + 0.2 * pulse))
	draw_circle(bob + Vector2(-12.0, 0.0), 11.0, color)
	draw_circle(bob + Vector2(-12.0, 0.0), 4.0, Color(0.0, 0.0, 0.0, 0.6))
	draw_line(bob + Vector2(-2.0, 0.0), bob + Vector2(22.0, 0.0), color, 6.0)
	draw_line(bob + Vector2(14.0, 0.0), bob + Vector2(14.0, 9.0), color, 5.0)
	draw_line(bob + Vector2(20.0, 0.0), bob + Vector2(20.0, 7.0), color, 5.0)
