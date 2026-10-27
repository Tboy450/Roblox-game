extends RefCounted
const State = preload("res://scripts/retail_state.gd")
const Saves = preload("res://scripts/save_store.gd")
const Settings = preload("res://scripts/player_settings.gd")

static func _key(world, code: Key, global_input: bool = false) -> void:
	var event = InputEventKey.new()
	event.pressed = true
	event.keycode = code
	if global_input:
		world._input(event)
	else:
		world._unhandled_input(event)

static func run(check: Callable, directory: String) -> void:
	var state = State.new()
	check.call(state.assign_shelf("beans", "soap") and state.slot_for_product("soap") == "beans" and state.slot_for_product("beans") == "soap", "Two empty shelves swap assignments one-to-one")
	check.call(state.cash == 50000 and state.prices.soap == 299 and state.stocks.soap == 0, "Reassignment does not alter money, price or stock")
	check.call(not state.assign_shelf("missing", "soap") and not state.assign_shelf("beans", "missing"), "Invalid shelf assignments are rejected")
	state.open_store()
	check.call(not state.assign_shelf("oats", "beans"), "Store must be closed before a shelf swap")
	state.close_store()
	state.order_case("soap")
	state.tick(4)
	state.collect_case()
	state.restock("soap")
	check.call(not state.assign_shelf("beans", "oats") and not state.assign_shelf("oats", "soap"), "Either stocked shelf blocks a swap")
	var reserved = State.new()
	reserved.stocks.soap = 1
	reserved.open_store()
	reserved.reserve(1, "soap")
	reserved.is_open = false
	check.call(not reserved.assign_shelf("soap", "beans"), "An unpaid basket blocks reassignment even if visible stock is zero")
	var snapshot = state.save_data()
	var restored = State.new()
	check.call(restored.apply_save(snapshot).is_empty() and restored.shelf_assignments == state.shelf_assignments and restored.stocks.soap == 12, "Version-2 save restores shelf assignments with product inventory")
	var baseline = JSON.stringify(restored.save_data())
	for mapping in [{"beans": "soap", "oats": "soap", "soap": "beans"}, {"beans": "beans"}, {"beans": "unknown", "oats": "oats", "soap": "soap"}]:
		var bad = snapshot.duplicate(true)
		bad.shelf_assignments = mapping
		check.call(not restored.apply_save(bad).is_empty() and JSON.stringify(restored.save_data()) == baseline, "Invalid shelf mapping is rejected without modifying live progress")
	var legacy = State.new()
	var migration = Saves.load_into(legacy, "res://tests/fixtures/save-v1.json")
	check.call(migration.ok and legacy.cash == 47077 and legacy.day == 3 and legacy.prices.oats == 289, "Existing version-1 save migrates without losing money, day or prices")
	check.call(legacy.shelf_assignments == {"beans": "beans", "oats": "oats", "soap": "soap"} and legacy.save_data().version == 2, "Legacy save receives the original shelf layout and upgrades its schema")
	var migrated_path = directory.path_join("migrated.json")
	check.call(Saves.save(legacy, migrated_path).ok and Saves.load_into(State.new(), migrated_path).ok, "Migrated progress can be saved and loaded with the new format")
	var preferences = Settings.new()
	check.call(not preferences.set_value("ui_scale", 4) and not preferences.set_value("unknown", 1), "Unsupported settings and extreme scaling are rejected")
	preferences.set_value("sensitivity", 0.0035)
	preferences.set_value("move_speed", 5.1)
	preferences.set_value("ui_scale", 1.2)
	var settings_path = directory.path_join("preferences.cfg")
	check.call(preferences.save_file(settings_path), "Control preferences save separately")
	var loaded = Settings.new()
	check.call(loaded.load_file(settings_path) and is_equal_approx(loaded.values.move_speed, 5.1) and is_equal_approx(loaded.values.ui_scale, 1.2), "Control preferences survive a file round-trip")
	var malformed = ConfigFile.new()
	malformed.set_value("controls", "sensitivity", 0.005)
	malformed.set_value("controls", "ui_scale", false)
	malformed.save(settings_path)
	var settings_baseline = loaded.values.duplicate()
	check.call(not loaded.load_file(settings_path) and loaded.values == settings_baseline, "Invalid preferences cannot partially apply settings")

static func scene_checks(world, check: Callable, directory: String) -> void:
	world.state = State.new()
	world.state.changed.connect(world._on_state_changed)
	world.persistence_enabled = false
	world.save_countdown = 0.75
	world.state.order_case()
	_key(world, KEY_ESCAPE, true)
	check.call(world.game_paused and world.pause_menu.visible and not world.player.controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Esc opens pause/settings and releases movement and mouse capture")
	var before_position = world.player.position
	var before_rotation = world.player.rotation
	world._process(10)
	world.simulate(10)
	world.player._physics_process(1)
	var mouse = InputEventMouseMotion.new()
	mouse.relative = Vector2(50, 20)
	world.player._unhandled_input(mouse)
	world.player.apply_look(mouse.relative)
	_key(world, KEY_O)
	_key(world, KEY_BRACKETRIGHT)
	check.call(world.state.delivery_seconds == 4 and not world.state.is_open and world.state.prices.beans == 149 and world.save_countdown == 0.75, "Paused delivery, trading controls and autosave timer remain frozen")
	check.call(world.player.position == before_position and world.player.rotation == before_rotation, "Paused character cannot move or look")
	world.pause_menu.buttons.Resume.pressed.emit()
	world.simulate(1)
	check.call(not world.game_paused and world.player.controls_enabled and world.state.delivery_seconds == 3 and not world.pause_menu.panel.visible and world.get_viewport().gui_get_focus_owner() == null, "Resume button restores gameplay, timing and keyboard focus")
	_key(world, KEY_ESCAPE, true)
	world.state.tick(3)
	world.player.position = Vector3(-8, 0.3, 8.5)
	check.call(not world.perform_action("receiving") and world.state.receiving == 12, "Paused physical interactions cannot collect goods")
	world.persistence_enabled = true
	world.settings_path = directory.path_join("scene-settings.cfg")
	world.save_path = directory.path_join("pause-save.json")
	Saves.save(world.state, world.save_path)
	var old_progress = FileAccess.get_file_as_string(world.save_path)
	world.pause_menu.sliders.sensitivity.value = 0.004
	world.pause_menu.sliders.move_speed.value = 5.5
	world.pause_menu.sliders.ui_scale.value = 1.25
	check.call(is_equal_approx(world.player.sensitivity, 0.004) and is_equal_approx(world.player.move_speed, 5.5), "Settings sliders update the real character controller")
	check.call(FileAccess.file_exists(world.settings_path) and FileAccess.get_file_as_string(world.save_path) == old_progress, "Changing settings writes preferences without overwriting store progress")
	world.pause_menu.layout(Vector2(1280, 720), 1.25)
	var menu_rect = Rect2(world.pause_menu.panel.position * 1.25, world.pause_menu.panel.size * 1.25)
	check.call(menu_rect.position.x >= 0 and menu_rect.position.y >= 0 and menu_rect.end.x <= 1280 and menu_rect.end.y <= 720, "Pause menu fits the viewport at maximum supported UI scale")
	world.pause_menu.buttons["Save progress"].pressed.emit()
	check.call(world.pause_menu.status.text == "Progress saved.", "Paused save button writes progress")
	world.pause_menu.buttons["Load progress"].pressed.emit()
	check.call(world.game_paused and world.pause_menu.visible and not world.player.controls_enabled and world.pause_menu.status.text.begins_with("Loaded"), "Paused load button restores progress without resuming movement")
	_key(world, KEY_ESCAPE, true)
	var yaw_before = world.player.rotation.y
	mouse.relative = Vector2(10, 0)
	# Headless display drivers cannot capture an OS mouse. Exercise the same look
	# operation used by captured mouse events without depending on an OS cursor.
	world.player.apply_look(mouse.relative)
	check.call(is_equal_approx(world.player.rotation.y - yaw_before, -0.04), "Configured mouse sensitivity changes actual camera rotation")
	world.persistence_enabled = false
	world.state = State.new()
	world.state.changed.connect(world._on_state_changed)
	world.save_countdown = -1
	world.shopper_choice = 0
	world.player.position = Vector3(-7, 0.3, 5.7)
	world.player.rotation = Vector3.ZERO
	world.player.camera.rotation = Vector3.ZERO
	_key(world, KEY_3)
	_key(world, KEY_R)
	check.call(world.state.slot_for_product("soap") == "beans" and "Cedar Hand Soap" in world.shelf_signs.beans.text and "Harvest Beans" in world.shelf_signs.soap.text, "Nearby R action swaps shelf labels to the selected goods")
	_key(world, KEY_B)
	world.simulate(4)
	world.player.position = Vector3(-8, 0.3, 8.5)
	world.perform_action("receiving")
	world.player.position = Vector3(-7, 0.3, 5.7)
	check.call(world.perform_action("shelf") and world.state.stocks.soap == 12, "Reassigned physical shelf receives the matching case")
	var placed_on_left = true
	for product in world.stock_root.get_children():
		placed_on_left = placed_on_left and product.get_meta("product_id") == "soap" and product.position.x < -5
	check.call(placed_on_left and world.stock_root.get_child_count() == 12, "Stock geometry follows the reassigned shelf location")
	world.state.open_store()
	for step in range(1000):
		world.simulate(0.1)
		if world.shopper_phase == "waiting_at_checkout":
			break
	check.call(world.shopper_product == "soap" and world.shopper_slot == "beans" and world.shopper_phase == "waiting_at_checkout", "Shopper finds reassigned stock and follows its physical shelf route")
	world.player.position = Vector3(3.7, 0.3, 6.2)
	check.call(world.perform_action("checkout") and world.state.cash == 48799, "Reassigned product still checks out with its correct price and cost")
	world.preferences.values = Settings.DEFAULTS.duplicate()
	world._apply_settings()
