extends SceneTree
## Programmatic engine render, invoked from CLI; no UI automation or editor.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var world = load("res://main.tscn").instantiate()
	world.persistence_enabled = false
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	world.player.position = Vector3(-2.8, 0.3, 7.7)
	world.player.rotation.y = 0.0
	world.player.camera.rotation.x = -0.08
	for product in world.Catalog.IDS:
		world.state.order_case(product)
		world.state.tick(4.0)
		world.state.collect_case()
		world.state.restock(product)
	world.state.open_store()
	world._message("Prototype review: three products stocked, editable prices, store open.")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var destination = ProjectSettings.globalize_path("res://../builds/godot-preview.png")
	var result = image.save_png(destination)
	print("PREVIEW_RESULT ", result, " ", image.get_size())
	world.player.position = Vector3(-6.4, 0.3, 5.9)
	world.player.camera.look_at(Vector3(-7, 0.95, 4.56))
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var tags_result = root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../builds/godot-price-tags-preview.png"))
	print("PRICE_TAGS_PREVIEW_RESULT ", tags_result)
	if tags_result != OK:
		result = tags_result
	world.player.position = Vector3(2.5, 0.3, 8.7)
	world.player.camera.look_at(Vector3(5.1, 1.1, 6.4))
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var checkout = root.get_texture().get_image()
	var checkout_result = checkout.save_png(ProjectSettings.globalize_path("res://../builds/godot-checkout-preview.png"))
	print("CHECKOUT_PREVIEW_RESULT ", checkout_result, " ", checkout.get_size())
	if checkout_result != OK:
		result = checkout_result
	world.pause_menu.sliders.ui_scale.value = 1.25
	world.set_paused(true)
	for frame in range(8):
		world._layout_hud()
		await process_frame
	await RenderingServer.frame_post_draw
	var settings_image = root.get_texture().get_image()
	var settings_result = settings_image.save_png(ProjectSettings.globalize_path("res://../builds/godot-settings-preview.png"))
	print("SETTINGS_PREVIEW_RESULT ", settings_result, " ", settings_image.get_size())
	if settings_result != OK:
		result = settings_result
	world.set_paused(false)
	var order = world.state.reserve(1, "beans")
	world.state.checkout(order)
	world.state.close_store()
	world._message("Prototype review: daily report complete.")
	for frame in range(8):
		world._layout_hud()
		await process_frame
	await RenderingServer.frame_post_draw
	var report_result = root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../builds/godot-day-report-preview.png"))
	print("DAY_REPORT_PREVIEW_RESULT ", report_result)
	if report_result != OK:
		result = report_result
	world.compact_panels()
	for frame in range(8):
		world._layout_hud()
		await process_frame
	await RenderingServer.frame_post_draw
	var compact_result = root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../builds/godot-compact-preview.png"))
	print("COMPACT_PREVIEW_RESULT ", compact_result)
	if compact_result != OK:
		result = compact_result
	quit(result)
