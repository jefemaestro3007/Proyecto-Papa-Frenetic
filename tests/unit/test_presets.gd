extends SceneTree
## Tests de presets por sección. Ejecutar:
##   godot --headless --path . --script res://tests/unit/test_presets.gd

const SECTIONS := {
	"mapa": "res://src/world/generation/azotea_params.gd",
	"cielo": "res://src/world/environment/sky_params.gd",
	"iluminacion": "res://src/world/environment/lighting_params.gd",
	"jugador": "res://src/features/player/resources/player_params.gd",
	"ritmo": "res://src/features/rhythm/rhythm_params.gd",
	"efectos": "res://src/features/combat/impact_fx_params.gd",
}
const TMP_DIR := "user://test_presets/"

var _failures := 0


func _initialize() -> void:
	_test_shipped_presets_load()
	_test_export_roundtrip()
	print("test_presets: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("  FALLO: ", message)


func _test_shipped_presets_load() -> void:
	for folder in SECTIONS:
		var paths := DebugSection._list_presets(folder)
		_check(not paths.is_empty(), "%s: no hay presets" % folder)
		for path in paths:
			var preset := load(path) as Resource
			_check(preset != null and preset.get_script().resource_path == SECTIONS[folder],
					"%s: tipo incorrecto" % path)


func _test_export_roundtrip() -> void:
	var source := PlayerParams.new()
	source.max_speed = 777.0
	source.fast_fall_enabled = false
	source.jump_cut = 0.35
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	var path := TMP_DIR + "roundtrip.tres"
	_check(ResourceSaver.save(source.duplicate(), path) == OK, "no se pudo guardar")

	var target := PlayerParams.new()
	DebugSection.copy_into(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE), target)
	_check(is_equal_approx(target.max_speed, 777.0), "max_speed no se copió")
	_check(not target.fast_fall_enabled, "fast_fall_enabled no se copió")
	_check(is_equal_approx(target.jump_cut, 0.35), "jump_cut no se copió")
	DirAccess.remove_absolute(path)
