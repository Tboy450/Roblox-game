extends RefCounted
const DEFAULT_PATH := "user://cornerfield-settings.cfg"
const BOOL_KEYS := ["guide_enabled", "dashboard_collapsed", "guide_collapsed", "report_collapsed"]
const DEFAULTS := {"sensitivity": 0.002, "move_speed": 4.2, "ui_scale": 1.0, "guide_enabled": true, "dashboard_collapsed": true, "guide_collapsed": false, "report_collapsed": false}
const LIMITS := {"sensitivity": Vector2(0.0005, 0.006), "move_speed": Vector2(2.0, 6.5), "ui_scale": Vector2(0.8, 1.25)}
## Rebindable gameplay keys, stored as physical keycodes so defaults keep their
## position on any layout. Esc, Tab and F2 stay fixed for pause and panel control.
const ACTIONS := {
	"move_forward": ["Move forward", KEY_W], "move_back": ["Move back", KEY_S],
	"move_left": ["Move left", KEY_A], "move_right": ["Move right", KEY_D],
	"interact": ["Interact", KEY_E], "toggle_guide": ["Show / hide guide", KEY_H],
	"select_1": ["Select beans", KEY_1], "select_2": ["Select oats", KEY_2],
	"select_3": ["Select soap", KEY_3], "select_4": ["Select honey", KEY_4],
	"buy_case": ["Order case", KEY_B],
	"price_down": ["Price −10¢", KEY_BRACKETLEFT], "price_up": ["Price +10¢", KEY_BRACKETRIGHT],
	"open_close": ["Open / close", KEY_O], "next_day": ["Next day", KEY_N],
	"reassign_shelf": ["Swap empty shelf", KEY_R], "save_game": ["Save", KEY_F5],
	"load_game": ["Load", KEY_F9],
}
const RESERVED_KEYS := [KEY_ESCAPE, KEY_TAB, KEY_F2]
## Keys offered to actions added after a settings file was written when their default is taken.
const SPARE_KEYS := [KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_G, KEY_J, KEY_L, KEY_U, KEY_Y]
var values: Dictionary = DEFAULTS.duplicate()
var bindings: Dictionary = default_bindings()

static func valid(key: String, value: Variant) -> bool:
	if key in BOOL_KEYS:
		return value is bool
	return LIMITS.has(key) and (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value)) and float(value) >= LIMITS[key].x - 0.000001 and float(value) <= LIMITS[key].y + 0.000001

static func default_bindings() -> Dictionary:
	var result := {}
	for action in ACTIONS:
		result[action] = ACTIONS[action][1]
	return result

static func valid_key(code: Variant) -> bool:
	if typeof(code) != TYPE_INT or code <= 0 or code in RESERVED_KEYS:
		return false
	# Physical keys are Latin-1 or Godot's special-key block; this also excludes modifier masks.
	if code > 0xFF and (code <= KEY_SPECIAL or code > (KEY_SPECIAL | 0xFF)):
		return false
	return OS.find_keycode_from_string(OS.get_keycode_string(code)) == code

## Every action needs its own usable key; a partial or duplicated map is rejected.
static func valid_bindings(candidate: Dictionary) -> bool:
	var used := {}
	for action in ACTIONS:
		if not valid_key(candidate.get(action)) or used.has(candidate[action]):
			return false
		used[candidate[action]] = true
	return candidate.size() == ACTIONS.size()

static func event_code(event: InputEventKey) -> int:
	return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode

## The key's printed label on the current layout; headless runs have no layout.
static func key_name(code: int) -> String:
	var label := code
	if DisplayServer.get_name() != "headless":
		label = DisplayServer.keyboard_get_label_from_physical(code)
		if label == KEY_NONE:
			label = code
	return String.chr(label).to_upper() if label > 32 and label < 127 else OS.get_keycode_string(label)

func key_label(action: String) -> String:
	return key_name(bindings[action])

func labels() -> Dictionary:
	var result := {}
	for action in ACTIONS:
		result[action] = key_label(action)
	return result

func action_for_key(code: int) -> String:
	for action in bindings:
		if bindings[action] == code:
			return action
	return ""

func action_for(event: InputEvent) -> String:
	if event is InputEventKey and event.pressed and not event.echo:
		return action_for_key(event_code(event))
	return ""

## A key already in use swaps with the rebound action's previous key.
func bind(action: String, code: int) -> bool:
	if not ACTIONS.has(action) or not valid_key(code):
		return false
	var other = action_for_key(code)
	if not other.is_empty():
		bindings[other] = bindings[action]
	bindings[action] = code
	return true

func reset_bindings() -> void:
	bindings = default_bindings()

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
	if not valid_bindings(bindings):
		return false
	for action in ACTIONS:
		config.set_value("bindings", action, bindings[action])
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
	var keys: Dictionary = {}
	var added: Array = []
	for action in ACTIONS:
		if config.has_section_key("bindings", action):
			keys[action] = config.get_value("bindings", action)
		else:
			added.append(action)
	# Actions newer than the file take their default, or the first spare key still free.
	for action in added:
		for code in [ACTIONS[action][1]] + SPARE_KEYS:
			if not code in keys.values():
				keys[action] = code
				break
	if not valid_bindings(keys):
		return false
	values = candidate
	bindings = keys
	return true
