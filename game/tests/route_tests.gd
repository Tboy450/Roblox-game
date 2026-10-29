extends RefCounted
const State = preload("res://scripts/retail_state.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Settings = preload("res://scripts/player_settings.gd")
const Routes = preload("res://scripts/store_routes.gd")
const SHOPPER_RADIUS := 0.22

## Footprints of the scene's real box colliders at body height, grown by a radius.
static func _footprints(world, radius: float) -> Array[Rect2]:
	var found: Array[Rect2] = []
	for body in world.get_children():
		if not body is StaticBody3D:
			continue
		for shape in body.get_children():
			if shape is CollisionShape3D and shape.shape is BoxShape3D:
				var centre: Vector3 = body.global_position + shape.position
				var size: Vector3 = shape.shape.size
				if centre.y - size.y / 2 < 1.9 and centre.y + size.y / 2 > 0.35:
					found.append(Rect2(centre.x - size.x / 2, centre.z - size.z / 2, size.x, size.z).grow(radius))
	return found

static func _walkable(from: Vector3, to: Vector3, path: Array[Vector3], footprints: Array[Rect2]) -> bool:
	if path.is_empty() or not path[-1].is_equal_approx(to):
		return false
	var previous := Vector2(from.x, from.z)
	for point in path:
		var next := Vector2(point.x, point.z)
		for rect in footprints:
			if Routes._crosses(previous, next, rect):
				return false
		previous = next
	return true

static func run(check: Callable, _directory: String) -> void:
	var routes = Routes.new()
	routes.add_obstacle(Vector3(0, 1, 0), Vector3(2, 2, 2))
	routes.build(Rect2(-10, -10, 20, 20))
	var around: Array[Vector3] = routes.route(Vector3(-3, 0, 0), Vector3(3, 0, 0))
	var length := 0.0
	var previous := Vector3(-3, 0, 0)
	for point in around:
		length += previous.distance_to(point)
		previous = point
	check.call(around.size() > 1 and around[-1] == Vector3(3, 0, 0) and length > 6.0 and length < 8.0, "Planner detours around a blocking obstacle by a short path")
	check.call(routes.route(Vector3(-3, 0, 5), Vector3(3, 0, 5)).size() == 1, "Planner walks straight when the way is clear")
	check.call(not Routes._crosses(Vector2(-2, 1.35), Vector2(2, 1.35), Rect2(-1.35, -1.35, 2.7, 2.7)) and Routes._crosses(Vector2(-2, 0.5), Vector2(2, 0.5), Rect2(-1.35, -1.35, 2.7, 2.7)), "Grazing an inflated edge is allowed; entering it is not")
	var walled = Routes.new()
	walled.add_obstacle(Vector3(0, 1, 0), Vector3(0.2, 2, 20))
	walled.build(Rect2(-5, -5, 10, 10))
	check.call(walled.route(Vector3(-2, 0, 0), Vector3(2, 0, 0)).is_empty(), "A fully blocked destination reports no route")
	var keys := true
	for index in range(Catalog.IDS.size()):
		keys = keys and Settings.ACTIONS.has("select_%d" % (index + 1))
	check.call(keys, "Every catalog product has its own rebindable select key")

static func scene_checks(world, check: Callable, _directory: String) -> void:
	var homes := {}
	var real := true
	for product in Catalog.IDS:
		var home := Vector2(Catalog.PRODUCTS[product].shelf_x, Catalog.PRODUCTS[product].shelf_z)
		real = real and home in world.GONDOLAS and not homes.has(home)
		homes[home] = product
	check.call(real, "Every product's home shelf is a distinct real gondola")
	var footprints := _footprints(world, SHOPPER_RADIUS)
	var walkable := true
	for slot in Catalog.IDS:
		var stand: Vector3 = world.stand_point(slot)
		for leg in [[world.SHOP_DOOR, stand], [stand, world.CHECKOUT_QUEUE], [stand, world.SHOP_DOOR], [world.CHECKOUT_QUEUE, world.SHOP_DOOR]]:
			walkable = walkable and _walkable(leg[0], leg[1], world.routes.route(leg[0], leg[1]), footprints)
	check.call(walkable, "Door, shelf, checkout and exit routes for every slot avoid all real colliders")
	if is_instance_valid(world.shopper):
		world.shopper.queue_free()
	world.state = State.new()
	world.state.changed.connect(world._on_state_changed)
	world.persistence_enabled = false
	world.state.stocks.soap = 12
	world.state.open_store()
	world.arrival_timer = 0.0
	world.simulate(0.1)
	world.shopper.position = world.stand_point("soap")
	world.state.close_store()
	world.simulate(0.1)
	check.call(world.shopper_phase == "leaving" and _walkable(world.shopper.position, world.SHOP_DOOR, world.shopper_path, footprints), "Closing mid-visit sends a soap shopper out around the checkout")
	for step in range(400):
		if not is_instance_valid(world.shopper):
			break
		world.simulate(0.1)
	check.call(not is_instance_valid(world.shopper) and world.state.orders.is_empty(), "The shopper walks the planned route out of the store")
