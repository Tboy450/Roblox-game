extends RefCounted
const State = preload("res://scripts/retail_state.gd")
const Guide = preload("res://scripts/first_day_guide.gd")
const Settings = preload("res://scripts/player_settings.gd")

static func _key(world, code: Key) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	world._unhandled_input(event)

static func run(check: Callable, directory: String) -> void:
	var state = State.new()
	check.call(Guide.current(state, "absent").step == 1, "Fresh first-day guide starts with ordering")
	state.assign_shelf("beans", "soap")
	state.order_case("soap")
	check.call(Guide.current(state, "absent").step == 2 and Guide.current(state, "absent").target == "receiving", "Pending case points guide to Receiving")
	state.tick(4)
	check.call(Guide.current(state, "absent").step == 3, "Arrived delivery advances collection guidance")
	state.collect_case()
	check.call(Guide.current(state, "absent").step == 4 and Guide.current(state, "absent").target == "shelf", "Stocking guide follows the product's reassigned shelf")
	state.restock("soap")
	check.call(Guide.current(state, "absent").step == 5, "Stocked goods advance opening guidance")
	var resumed = State.new()
	resumed.apply_save(state.save_data())
	check.call(Guide.current(resumed, "absent").step == 5, "Resumed first-day progress does not restart the guide")
	state.open_store()
	var order = state.reserve(1, "soap")
	check.call(Guide.current(state, "walking_to_checkout").step == 6 and Guide.current(state, "waiting_at_checkout").title == "Serve your first shopper", "Guide distinguishes approaching and ready shoppers")
	state.cancel(order)
	check.call(Guide.current(state, "leaving").step == 6, "Cancelled purchase does not claim tutorial sale completion")
	order = state.reserve(1, "soap")
	state.checkout(order)
	check.call(Guide.current(state, "leaving").step == 7, "A completed sale advances closing guidance")
	var saved_sale = State.new()
	saved_sale.apply_save(state.save_data())
	check.call(Guide.current(saved_sale, "absent").title == "Finish your resumed day", "Saved sale explains how to finish a resumed closed day")
	state.close_store()
	check.call(Guide.current(state, "absent").step == 8, "Closed report completes the first-day guide")
	var unchanged = JSON.stringify(state.save_data())
	Guide.current(state, "absent")
	check.call(JSON.stringify(state.save_data()) == unchanged, "Guide inspection never changes inventory or accounts")
	state.next_day()
	check.call(Guide.current(state, "absent").is_empty(), "First-day guide leaves later days unobstructed")
	var full = State.new()
	for count in range(2):
		full.order_case()
		full.tick(4)
		full.collect_case()
		if count == 0:
			full.restock()
	check.call(Guide.current(full, "absent").title == "Make room for your case", "A full shelf with carried goods gives a useful recovery prompt")
	var settings = Settings.new()
	check.call(not settings.set_value("guide_enabled", 1), "Guide preference must be a real boolean")
	settings.set_value("guide_enabled", false)
	var path = directory.path_join("guide-settings.cfg")
	settings.save_file(path)
	var loaded = Settings.new()
	check.call(loaded.load_file(path) and loaded.values.guide_enabled == false, "Hidden guide preference survives settings reload")
	var old_config = ConfigFile.new()
	old_config.set_value("controls", "move_speed", 5.0)
	old_config.save(path)
	check.call(loaded.load_file(path) and loaded.values.guide_enabled == true, "Older preferences receive the new guide's default")

static func scene_checks(world, check: Callable, directory: String) -> void:
	if is_instance_valid(world.shopper):
		world.shopper.queue_free()
	world.shopper = null
	world.shopper_phase = "absent"
	world.shopper_order = -1
	world.shopper_path.clear()
	world.shopper_choice = 0
	world.state = State.new()
	world.state.changed.connect(world._on_state_changed)
	world.persistence_enabled = false
	world.preferences.values = Settings.DEFAULTS.duplicate()
	world.pause_menu.guide_toggle.button_pressed = true
	world.set_paused(false)
	world._refresh()
	check.call(world.guide_panel.visible and "1 OF 8" in world.guide_panel.heading.text and not world.guide_marker.visible, "Scene shows first objective without an irrelevant world marker")
	world.state.assign_shelf("beans", "soap")
	world.state.order_case("soap")
	check.call("2 OF 8" in world.guide_panel.heading.text and world.guide_marker.visible and is_equal_approx(world.guide_marker.position.x, -8), "Incoming-case marker points to the actual receiving table")
	world.state.tick(4)
	world.player.position = Vector3(-8, 0.3, 8.5)
	world.perform_action("receiving")
	check.call("4 OF 8" in world.guide_panel.heading.text and is_equal_approx(world.guide_marker.position.x, -7), "Collected goods move the guide marker to their reassigned shelf")
	world.player.position = Vector3(-7, 0.3, 5.7)
	world.perform_action("shelf")
	check.call("5 OF 8" in world.guide_panel.heading.text and not world.guide_marker.visible, "Stocking advances the on-screen opening objective")
	world.state.open_store()
	for step in range(1000):
		world.simulate(0.1)
		if world.shopper_phase == "waiting_at_checkout":
			break
	check.call("Serve your first shopper" in world.guide_title.text and world.guide_marker.visible and world.guide_marker.position.x > 4, "Ready shopper displays the register objective and marker")
	var before = JSON.stringify(world.state.save_data())
	_key(world, KEY_H)
	check.call(not world.guide_panel.visible and not world.guide_marker.visible and JSON.stringify(world.state.save_data()) == before, "H hides guidance without changing the store")
	_key(world, KEY_H)
	world.set_paused(true)
	check.call(not world.guide_panel.visible and not world.guide_marker.visible, "Pause hides guide overlays and world markers")
	world.set_paused(false)
	check.call(world.guide_panel.visible and world.guide_marker.visible, "Resume restores the current guidance")
	world.persistence_enabled = true
	world.settings_path = directory.path_join("scene-guide.cfg")
	world.pause_menu.guide_toggle.button_pressed = false
	var preferences = Settings.new()
	check.call(preferences.load_file(world.settings_path) and preferences.values.guide_enabled == false, "Pause-menu guide toggle persists through the real settings path")
	world.pause_menu.guide_toggle.button_pressed = true
	world.persistence_enabled = false
	world.player.position = Vector3(3.7, 0.3, 6.2)
	world.perform_action("checkout")
	check.call("7 OF 8" in world.guide_panel.heading.text and not world.guide_marker.visible, "Actual checkout advances the guide to closing")
	world.state.close_store()
	world._layout_hud()
	check.call("8 OF 8" in world.guide_panel.heading.text and world.guide_panel.position.y >= world.report_panel.position.y + world.report_panel.get_combined_minimum_size().y, "First-day completion sits below the daily report")
	world.state.next_day()
	check.call(not world.guide_panel.visible and not world.guide_marker.visible, "Next day removes the completed guide")
