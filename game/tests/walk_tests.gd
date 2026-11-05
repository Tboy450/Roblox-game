extends RefCounted
## Automated walk-throughs with the real character capsule and colliders. This
## checks reachability; it is not a substitute for human playtesting.
const State = preload("res://scripts/retail_state.gd")
const Catalog = preload("res://scripts/catalog.gd")
const SPAWN := Vector3(-2.8, 0.3, 7.7)
const RECEIVING_STAND := Vector3(-8, 0.3, 8.5)

## Steers the real controller along waypoints at its configured speed.
static func _walk(world, path: Array[Vector3], seconds: float) -> bool:
	var player = world.player
	for step in range(int(seconds * 60)):
		if path.is_empty():
			return true
		var flat := Vector3(path[0].x - player.position.x, 0, path[0].z - player.position.z)
		if flat.length() < 0.12:
			path.pop_front()
			continue
		player.velocity = flat.normalized() * player.move_speed + Vector3.DOWN
		player.move_and_slide()
	return path.is_empty()

static func _arrive(world, target: Vector3) -> bool:
	var reached := _walk(world, world.routes.route(world.player.position, target), 20.0)
	# Face the shelf or table ahead (-Z), as a player would before pressing E.
	world.player.rotation = Vector3.ZERO
	world.player.camera.rotation = Vector3.ZERO
	return reached and absf(world.player.position.y - 0.28) < 0.08

static func scene_checks(world, check: Callable, _directory: String) -> void:
	if is_instance_valid(world.shopper):
		world.shopper.queue_free()
	world.shopper = null
	world.shopper_phase = "absent"
	world.state = State.new()
	world.state.changed.connect(world._on_state_changed)
	world.persistence_enabled = false
	# Control: head-on into the beans shelf face, the capsule must stop at its collider.
	world.player.position = Vector3(-7, 0.3, 5.7)
	world.player.velocity = Vector3.ZERO
	var into_shelf: Array[Vector3] = [Vector3(-7, 0.3, 3.0)]
	check.call(not _walk(world, into_shelf, 5.0) and world.player.position.z > 4.7, "Walking head-on into a shelf is stopped by its real collider")
	world.player.position = SPAWN
	var reached := true
	var facing := true
	for slot in Catalog.IDS:
		reached = _arrive(world, world.stand_point(slot)) and reached
		var target: Dictionary = world.nearest_target()
		facing = facing and target.get("slot", "") == slot
	check.call(reached, "The player capsule walks planned routes to every shelf, including the middle row")
	check.call(facing, "Arriving at each shelf puts its stocking prompt in reach and view")
	world.player.position = SPAWN
	world.state.order_case("honey")
	world.simulate(4.0)
	var collected: bool = _arrive(world, RECEIVING_STAND) and world.perform_action("receiving")
	var stocked: bool = _arrive(world, world.stand_point("honey")) and world.perform_action("shelf_honey")
	check.call(collected and stocked and world.state.stocks.honey == 12 and world.state.carried == 0, "A honey case is collected and stocked entirely on foot")
