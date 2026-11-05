extends RefCounted
## Shortest walkable floor paths: a visibility graph over the corners of every
## collider footprint, inflated by a walker's clearance. Coordinates are x/z metres.
const CLEARANCE := 0.35
const CORNER := 0.42  # graph corners sit just outside the inflated footprints
var obstacles: Array[Rect2] = []
var bounds := Rect2()
var graph := AStar2D.new()
var corners := 0

## Registers a box collider footprint; heights are the caller's concern.
func add_obstacle(centre: Vector3, size: Vector3) -> void:
	obstacles.append(Rect2(centre.x - size.x / 2, centre.z - size.z / 2, size.x, size.z).grow(CLEARANCE))

func build(walkable: Rect2) -> void:
	bounds = walkable
	graph.clear()
	for rect in obstacles:
		var outer = rect.grow(CORNER - CLEARANCE)
		for point in [outer.position, Vector2(outer.end.x, outer.position.y), outer.end, Vector2(outer.position.x, outer.end.y)]:
			if bounds.has_point(point) and not blocked(point):
				graph.add_point(graph.get_point_count(), point)
	corners = graph.get_point_count()
	for a in range(corners):
		for b in range(a + 1, corners):
			if clear(graph.get_point_position(a), graph.get_point_position(b)):
				graph.connect_points(a, b)

func blocked(point: Vector2) -> bool:
	for rect in obstacles:
		if rect.has_point(point) and not _on_edge(point, rect):
			return true
	return false

static func _on_edge(point: Vector2, rect: Rect2) -> bool:
	return minf(minf(point.x - rect.position.x, rect.end.x - point.x), minf(point.y - rect.position.y, rect.end.y - point.y)) < 0.000001

## True when the segment never enters an inflated footprint's interior, other
## than footprints listed in `exempt` (those already containing an endpoint).
func clear(a: Vector2, b: Vector2, exempt: Array = []) -> bool:
	for rect in obstacles:
		if not rect in exempt and _crosses(a, b, rect):
			return false
	return true

func _containing(point: Vector2) -> Array:
	return obstacles.filter(func(rect): return rect.has_point(point))

static func _crosses(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	# Liang-Barsky clip; grazing an edge does not count as entering.
	var d := b - a
	var p := [-d.x, d.x, -d.y, d.y]
	var q := [a.x - rect.position.x, rect.end.x - a.x, a.y - rect.position.y, rect.end.y - a.y]
	var t0 := 0.0
	var t1 := 1.0
	for i in range(4):
		if is_zero_approx(p[i]):
			if q[i] <= 0.000001:
				return false
		elif p[i] < 0:
			t0 = maxf(t0, q[i] / p[i])
		else:
			t1 = minf(t1, q[i] / p[i])
	return t1 - t0 > 0.000001

## Waypoints after `from`, ending at `to`; empty when no walkable path exists.
func route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var path: Array[Vector3] = []
	var start := Vector2(from.x, from.z)
	var goal := Vector2(to.x, to.z)
	# A walker brushing a shelf may start or stop inside its clearance; let it step out.
	var exempt := [_containing(start), _containing(goal)]
	if clear(start, goal, exempt[0] + exempt[1]):
		path.append(to)
		return path
	var ids := [corners, corners + 1]
	graph.add_point(ids[0], start)
	graph.add_point(ids[1], goal)
	for end in range(2):
		for corner in range(corners):
			if clear(graph.get_point_position(ids[end]), graph.get_point_position(corner), exempt[end]):
				graph.connect_points(ids[end], corner)
	var found := graph.get_point_path(ids[0], ids[1])
	for id in ids:
		graph.remove_point(id)
	for index in range(1, found.size()):
		path.append(Vector3(found[index].x, to.y, found[index].y))
	return path
