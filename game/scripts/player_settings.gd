extends RefCounted
const DEFAULT_PATH := "user://cornerfield-settings.cfg"
const BOOL_KEYS := ["guide_enabled", "dashboard_collapsed", "guide_collapsed", "report_collapsed"]
const DEFAULTS := {"sensitivity": 0.002, "move_speed": 4.2, "ui_scale": 1.0, "guide_enabled": true, "dashboard_collapsed": true, "guide_collapsed": false, "report_collapsed": false}
const LIMITS := {"sensitivity": Vector2(0.0005, 0.006), "move_speed": Vector2(2.0, 6.5), "ui_scale": Vector2(0.8, 1.25)}
var values: Dictionary = DEFAULTS.duplicate()

static func valid(key: String, value: Variant) -> bool:
	if key in BOOL_KEYS:
		return value is bool
	return LIMITS.has(key) and (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value)) and float(value) >= LIMITS[key].x - 0.000001 and float(value) <= LIMITS[key].y + 0.000001

func set_value(key: String, value: Variant) -> bool:
	if not valid(key, value):
		return false
	values[key] = value
	return true

func save_file(path: String = DEFAULT_PATH) -> bool:
	var config = ConfigFile.new()
	for key in DEFAULTS:
		if not valid(key, values.get(key)):
			return false
		config.set_value("controls", key, values[key])
	return config.save(path) == OK

func load_file(path: String = DEFAULT_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var config = ConfigFile.new()
	if config.load(path) != OK:
		return false
	var candidate: Dictionary = {}
	for key in DEFAULTS:
		var value = config.get_value("controls", key, DEFAULTS[key])
		if not valid(key, value):
			return false
		candidate[key] = value if key in BOOL_KEYS else float(value)
	values = candidate
	return true
