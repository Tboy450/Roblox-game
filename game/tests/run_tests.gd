extends SceneTree
const State = preload("res://scripts/retail_state.gd")
const Progression = preload("res://tests/progression_tests.gd")
const Usability = preload("res://tests/usability_tests.gd")
const GuideTests = preload("res://tests/guide_tests.gd")
const PanelTests = preload("res://tests/panel_tests.gd")
const PriceTagTests = preload("res://tests/price_tag_tests.gd")
const BindingTests = preload("res://tests/binding_tests.gd")
var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _inventory(state) -> int:
	return state.shelf + state.carried + state.receiving + state.incoming + state.reserved_units() + state.sold

func _ledger_tests() -> void:
	var state = State.new()
	check(state.reserve() == -1, "Closed store cannot reserve stock")
	check(state.order_case(), "First supplier case can be ordered")
	check(not state.order_case(), "Pending delivery cannot be overwritten or billed twice")
	check(state.cash == 49160 and state.purchases == 840, "Supplier cost is charged in integer cents")
	check(_inventory(state) == 12, "Inventory conserved while delivery is in transit")
	state.tick(-10)
	check(state.incoming == 12, "Negative delta cannot complete a delivery")
	state.tick(4)
	check(state.receiving == 12 and state.incoming == 0, "Delivery moves from transit into receiving")
	check(state.collect_case() and not state.collect_case(), "A case is collected once")
	check(state.restock() == 12 and state.restock() == 0, "Stocking cannot create units")
	state.open_store()
	check(state.reserve(-3) == -1 and state.reserve(13) == -1, "Invalid and oversized baskets are rejected")
	var order = state.reserve(2)
	check(order > 0 and state.shelf == 10 and _inventory(state) == 12, "Customer reservation conserves total units")
	check(state.order_case(), "Next case may be purchased after first is collected")
	state.tick(4)
	check(state.collect_case() and state.restock() == 0, "Reserved slots cannot be filled and then overfilled on cancellation")
	check(state.cancel(order) and not state.cancel(order), "Cancellation returns units exactly once")
	check(state.shelf == 12 and state.carried == 12 and _inventory(state) == 24, "Cancellation does not overfill shelf")
	order = state.reserve(3)
	check(state.checkout(order), "Reserved basket completes")
	check(not state.checkout(order), "Duplicate checkout cannot generate another sale")
	check(state.revenue == 447 and state.cost_of_goods == 210 and state.sold == 3, "Revenue and cost reconcile")
	check(state.restock() == 3 and _inventory(state) == 24, "Sold units release shelf capacity")
	order = state.reserve(1)
	var summary = state.close_store()
	check(state.orders.is_empty() and state.shelf == 12, "Close refunds all unpaid reservations")
	check(not state.cancel(order) and not state.checkout(order), "Closed basket cannot refund or pay twice")
	check(summary.gross_profit == 237, "Gross profit uses cost of goods sold, not all purchased inventory")
	check(summary.cash_change == summary.revenue - summary.purchases, "Daily cash movement reconciles purchases and sales")
	var cash_before = state.cash
	check(state.next_day() and not state.next_day(), "Next day starts once per closed report")
	check(state.cash == cash_before and state.shelf == 12 and state.carried == 9, "Day transition preserves cash and unsold inventory")
	check(state.revenue == 0 and state.purchases == 0 and state.sold == 0, "Daily counters reset")
	state.cash = 839
	check(not state.order_case() and state.cash == 839, "Insufficient funds cannot create a case or debit cash")

func _asset_stats(node: Node) -> Dictionary:
	var stats = {"meshes": 0, "triangles": 0, "materials": 0, "colored": 0}
	if node is MeshInstance3D:
		stats.meshes += 1
		for surface in range(node.mesh.get_surface_count()):
			stats.triangles += node.mesh.surface_get_array_index_len(surface) / 3
			var material = node.get_active_material(surface)
			if material != null:
				stats.materials += 1
				if material is BaseMaterial3D and absf(material.albedo_color.r - material.albedo_color.g) > 0.025:
					stats.colored += 1
	for child in node.get_children():
		var child_stats = _asset_stats(child)
		for key in stats:
			stats[key] += child_stats[key]
	return stats

func _run() -> void:
	_ledger_tests()
	var test_directory = ProjectSettings.globalize_path("res://").path_join("../builds/save-tests-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]).simplify_path()
	DirAccess.make_dir_recursive_absolute(test_directory)
	Progression.run(check, test_directory)
	Usability.run(check, test_directory)
	GuideTests.run(check, test_directory)
	BindingTests.run(check, test_directory)
	var world = load("res://main.tscn").instantiate()
	world.persistence_enabled = false
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	await process_frame
	await physics_frame
	var checkout = _asset_stats(world.get_node("BlenderCheckout"))
	var shelf = _asset_stats(world.get_node("HoudiniShelf"))
	var shell = _asset_stats(world.get_node("HoudiniStoreShell"))
	check(checkout.meshes >= 80 and checkout.triangles > 20000, "Actual Blender checkout geometry imported")
	check(checkout.materials >= 80 and checkout.colored > 0, "Checkout material colors survived actual Godot import")
	check(shelf.triangles > 10000 and shelf.colored > 0, "Actual Houdini shelf geometry and materials imported")
	check(shell.triangles > 0 and shell.colored > 0, "Houdini shell geometry and materials imported")
	var space = world.get_world_3d().direct_space_state
	var floor_hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-2, 4, 7), Vector3(-2, -1, 7)))
	check(not floor_hit.is_empty() and floor_hit.collider.name == "StoreFloor", "Physics floor matches the imported slab height")
	var shelf_hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-7, 1.5, 6), Vector3(-7, 1.5, 3)))
	check(not shelf_hit.is_empty() and str(shelf_hit.collider.name).begins_with("ShelfCollision"), "Shelf has a separate collision proxy")
	var checkout_hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(5, 1, 9), Vector3(5, 1, 6)))
	check(not checkout_hit.is_empty() and checkout_hit.collider.name == "CheckoutCabinet", "Checkout has its own collision proxy")
	check(world.state.order_case(), "Playable scene can order a case")
	world.simulate(4.0)
	world.player.position = Vector3(-8, 0.3, 8.5)
	check(world.perform_action("receiving"), "Player can collect delivered case nearby")
	world.player.position = Vector3(-7, 0.3, 5.7)
	check(world.perform_action("shelf") and world.stock_root.get_child_count() == 12, "Restocking drives twelve product visuals with labels")
	world.state.open_store()
	for index in range(600):
		world.simulate(0.1)
		if world.shopper_phase == "waiting_at_checkout":
			break
	check(world.shopper_phase == "waiting_at_checkout" and world.state.shelf == 11, "Shopper walks from entrance to stocked goods and checkout")
	world.player.position = Vector3(-9, 0.3, -7)
	check(not world.perform_action("checkout"), "Out-of-range register action is rejected")
	world.player.position = Vector3(3.7, 0.3, 6.2)
	check(world.perform_action("checkout"), "Nearby player can complete the shopper's sale")
	check(not world.perform_action("checkout") and world.state.revenue == 149, "Repeated register interaction cannot duplicate a sale")
	world.state.close_store()
	for index in range(300):
		world.simulate(0.1)
	check(world.shopper_phase == "absent" and world.state.orders.is_empty(), "Closing lets shopper exit and clears reservations")
	check(world.state.cash == 49309, "Complete playable slice reconciles $500 - $8.40 + $1.49")
	world.state.open_store()
	check(world.state.last_report.is_empty(), "Reopening hides the closed-day report")
	for index in range(600):
		world.simulate(0.1)
		if world.shopper_phase == "walking_to_checkout":
			break
	check(world.state.reserved_units() == 1, "Second shopper has an unpaid reservation while walking")
	world.state.close_store()
	world.simulate(0.1)
	check(world.state.shelf == 11 and world.state.orders.is_empty() and world.shopper_phase == "leaving", "Closing mid-shopping restores stock and sends customer out")
	for index in range(300):
		world.simulate(0.1)
	check(world.shopper_phase == "absent" and world.state.cash == 49309, "Unpaid shopper exits without changing cash")
	# Let the real character controller fall onto the real floor.
	world.player.position = Vector3(-3, 3, 7)
	world.player.velocity = Vector3.ZERO
	world.player.set_physics_process(true)
	for index in range(100):
		await physics_frame
	world.player.set_physics_process(false)
	check(absf(world.player.position.y - 0.28) < 0.08, "Character controller lands on the imported store's floor")
	Progression.scene_checks(world, check, test_directory)
	Usability.scene_checks(world, check, test_directory)
	GuideTests.scene_checks(world, check, test_directory)
	PanelTests.scene_checks(world, check, test_directory)
	PriceTagTests.scene_checks(world, check, test_directory)
	BindingTests.scene_checks(world, check, test_directory)
	var result = {"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"checkout": checkout, "shelf": shelf, "shell": shell,
		"scope": "Headless engine import, physics and retail loop; human playtesting and multiplayer remain pending."}
	var report_directory = ProjectSettings.globalize_path("res://").path_join("../builds").simplify_path()
	DirAccess.make_dir_recursive_absolute(report_directory)
	var file = FileAccess.open(report_directory.path_join("test-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	world.queue_free()
	await process_frame
	print("STANDALONE_TEST_RESULT ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
