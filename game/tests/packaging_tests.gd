extends RefCounted
const State = preload("res://scripts/retail_state.gd")
const Catalog = preload("res://scripts/catalog.gd")
## Front art u-range per product: wrap labels centre on u = 0.5, the carton front is the atlas's left half.
const FRONT_U := {"beans": Vector2(0.4, 0.6), "oats": Vector2(0.0, 0.5), "soap": Vector2(0.4, 0.6)}

static func _meshes(node: Node) -> Array:
	var found: Array = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_meshes(child))
	return found

static func _local(mesh: MeshInstance3D, root: Node3D) -> Transform3D:
	var transform = Transform3D.IDENTITY
	var node: Node = mesh
	while node != root:
		transform = node.transform * transform
		node = node.get_parent()
	return transform

static func _bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh in _meshes(root):
		var box: AABB = _local(mesh, root) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds

static func scene_checks(world, check: Callable, _directory: String) -> void:
	var textured := true
	var fits := true
	var facing := true
	var triangles := 0
	for product in Catalog.IDS:
		var model = world.merchandise[product].instantiate() as Node3D
		var size: AABB = _bounds(model)
		fits = fits and size.size.x <= 0.25 and size.size.z <= 0.25 and size.size.y > 0.25 and size.size.y < 0.6
		fits = fits and absf(size.position.y) < 0.003 and absf(size.get_center().x) < 0.01 and absf(size.get_center().z) < 0.01
		var label_found := false
		for mesh in _meshes(model):
			var transform = _local(mesh, model)
			for surface in range(mesh.mesh.get_surface_count()):
				var arrays = mesh.mesh.surface_get_arrays(surface)
				triangles += mesh.mesh.surface_get_array_index_len(surface) / 3
				var material = mesh.get_active_material(surface) as BaseMaterial3D
				if material == null or material.albedo_texture == null:
					continue
				label_found = label_found or material.albedo_texture.get_width() >= 512
				# Printed surface turned toward the aisle (+Z) must carry the front of the pack.
				var front_u := 0.0
				var count := 0
				for index in range(arrays[Mesh.ARRAY_VERTEX].size()):
					if (transform.basis * arrays[Mesh.ARRAY_NORMAL][index]).normalized().z > 0.9:
						front_u += arrays[Mesh.ARRAY_TEX_UV][index].x
						count += 1
				front_u /= maxi(count, 1)
				facing = facing and count > 0 and front_u >= FRONT_U[product].x and front_u <= FRONT_U[product].y
		textured = textured and label_found
		model.free()
	check.call(textured, "Each product imports Blender packaging with its printed label texture")
	check.call(fits, "Packaging fits one shelf facing and stands on its own base origin")
	check.call(facing, "Printed pack fronts face the aisle after glTF axis conversion")
	check.call(triangles < 5000, "Three packaging models stay within a 5,000-triangle budget")
	if is_instance_valid(world.shopper):
		world.shopper.queue_free()
	world.shopper = null
	world.shopper_phase = "absent"
	world.state = State.new()
	world.state.changed.connect(world._on_state_changed)
	world.persistence_enabled = false
	for product in Catalog.IDS:
		world.state.stocks[product] = 12
	world._refresh()
	var on_decks := true
	var shared := {}
	for unit in world.stock_root.get_children():
		var bounds: AABB = unit.global_transform * _bounds(unit)
		var tier := roundi((bounds.position.y - 0.28 - 0.71 * world.UNIT) / (2.45 * world.UNIT))
		var deck_top: float = 0.28 + (0.71 + tier * 2.45) * world.UNIT
		var next_deck: float = deck_top + 2.45 * world.UNIT - 0.12 * world.UNIT
		on_decks = on_decks and tier >= 0 and tier < 4 and absf(bounds.position.y - deck_top) < 0.002 and bounds.end.y < next_deck - 0.05
		on_decks = on_decks and bounds.end.z < 4.546 and bounds.position.z > 3.6
		var mesh: Mesh = _meshes(unit)[0].mesh
		shared[unit.get_meta("product_id")] = shared.get(unit.get_meta("product_id"), {})
		shared[unit.get_meta("product_id")][mesh] = true
	var reused := shared.size() == 3
	for product in shared:
		reused = reused and shared[product].size() == 1
	check.call(world.stock_root.get_child_count() == 36 and on_decks, "Stocked packs rest on deck tops, clear the deck above and stay behind the price rail")
	check.call(reused, "Every stocked unit of a product reuses one imported mesh")
