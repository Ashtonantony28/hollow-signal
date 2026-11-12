class_name NavGrid
extends RefCounted
## Grid pathfinding over the deck's cell layout (AStarGrid2D). Cheaper and more deterministic
## than runtime navmesh baking, and the layout is already a grid.

var layout: Dictionary
var astar := AStarGrid2D.new()

func _init(l: Dictionary) -> void:
	layout = l
	astar.region = Rect2i(0, 0, l.w, l.h)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in l.h:
		for x in l.w:
			if not DeckGen.is_walkable(l, Vector2i(x, y)):
				astar.set_point_solid(Vector2i(x, y), true)

func nearest_walkable(c: Vector2i) -> Vector2i:
	if DeckGen.is_walkable(layout, c):
		return c
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if DeckGen.is_walkable(layout, n):
					return n
	return c

## World-space waypoints from `from` to `to` (cell centres, endpoint replaced by exact target).
func path_world(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := nearest_walkable(DeckGen.world_to_cell(from))
	var b := nearest_walkable(DeckGen.world_to_cell(to))
	var out := PackedVector3Array()
	if not astar.is_in_boundsv(a) or not astar.is_in_boundsv(b):
		return out
	if astar.is_point_solid(a) or astar.is_point_solid(b):
		return out
	var ids := astar.get_id_path(a, b)
	for i in range(1, ids.size()):
		out.append(DeckGen.cell_to_world(ids[i]))
	if out.size() > 0:
		out[out.size() - 1] = Vector3(to.x, 0, to.z)
	return out
