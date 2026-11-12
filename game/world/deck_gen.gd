class_name DeckGen
## Pure, seedable deck generator (DESIGN.md §6.2). Produces plain data only — the DeckBuilder
## turns a layout into nodes. Unit tests run this on hundreds of seeds.

const CELL := 4.0
const SOLID := 0
const FLOOR := 1

const H_CORRIDOR := 4.0
const H_ROOM := 6.0
const H_ARENA := 9.0

## Generates a valid layout. Retries with derived seeds until all invariants hold.
static func generate(seed_value: int, deck_index: int) -> Dictionary:
	for attempt in 64:
		var layout := _try_generate(seed_value * 7919 + attempt * 104729, deck_index)
		if not layout.is_empty() and validate(layout).is_empty():
			layout.seed = seed_value
			layout.attempt = attempt
			return layout
	push_error("DeckGen: failed to generate a valid deck for seed %d" % seed_value)
	return {}

static func _try_generate(s: int, deck_index: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var theme: Dictionary = ThemeData.deck(deck_index)
	var w: int = theme.size
	var h: int = theme.size
	var target: int = theme.rooms
	var is_boss := deck_index >= ThemeData.DECKS.size() - 1

	# 1. Room placement by rejection sampling.
	var rects: Array[Rect2i] = []
	if is_boss:
		# Boss deck: one big arena in the middle plus satellites.
		rects.append(Rect2i(w / 2 - 6, h / 2 - 6, 12, 12))
	var tries := 0
	while rects.size() < target and tries < 1500:
		tries += 1
		var big := rng.randf() < 0.25
		var rw := rng.randi_range(6, 9) if big else rng.randi_range(3, 6)
		var rh := rng.randi_range(6, 9) if big else rng.randi_range(3, 6)
		var r := Rect2i(rng.randi_range(1, w - rw - 1), rng.randi_range(1, h - rh - 1), rw, rh)
		var ok := true
		for o in rects:
			if r.grow(2).intersects(o):
				ok = false
				break
		if ok:
			rects.append(r)
	if rects.size() < mini(target, 6):
		return {}

	var n := rects.size()
	var centers: Array[Vector2i] = []
	for r in rects:
		centers.append(r.position + r.size / 2)

	# 2. Connectivity: Prim MST on Manhattan distance + ~20% extra loop edges.
	var edges: Array = []
	var in_tree := {0: true}
	while in_tree.size() < n:
		var best := Vector3i(-1, -1, 1 << 30)
		for a in in_tree:
			for b in n:
				if in_tree.has(b):
					continue
				var d := _manhattan(centers[a], centers[b])
				if d < best.z:
					best = Vector3i(a, b, d)
		edges.append(Vector2i(best.x, best.y))
		in_tree[best.y] = true
	var extra: Array = []
	for a in n:
		for b in range(a + 1, n):
			if not _has_edge(edges, a, b):
				extra.append(Vector3i(a, b, _manhattan(centers[a], centers[b])))
	extra.sort_custom(func(p, q): return p.z < q.z)
	var loops := maxi(1, int(round(n * 0.2)))
	for i in mini(loops, extra.size()):
		if rng.randf() < 0.85:
			edges.append(Vector2i(extra[i].x, extra[i].y))

	# 3. Graph analysis: start, lift (farthest), vault (off critical path), uplink.
	var adj := _adjacency(n, edges)
	var start := 0 if is_boss else rng.randi_range(0, n - 1)
	if is_boss:
		# start in the satellite farthest from the arena; arena is the "lift"/boss room.
		var dist_b := _bfs(adj, 0)
		start = _argmax(dist_b, [])
	var dist_s := _bfs(adj, start)
	var lift := 0 if is_boss else _argmax(dist_s, [start])
	var path := _shortest_path(adj, start, lift)
	var vault := -1
	var best_score := -1.0
	for i in n:
		if i in path:
			continue
		var score := float(dist_s[i]) + rng.randf() * 0.5
		if score > best_score:
			best_score = score
			vault = i
	if vault == -1:
		return {}
	var uplink := -1
	var best_up := -1.0
	for i in n:
		if i == start or i == lift or i == vault:
			continue
		var area := float(rects[i].size.x * rects[i].size.y)
		var sc := area + rng.randf() * 10.0 + float(dist_s[i]) * 3.0
		if sc > best_up:
			best_up = sc
			uplink = i
	if uplink == -1:
		return {}

	var types: Array[StringName] = []
	types.resize(n)
	for i in n:
		types[i] = &"hub"
	types[start] = &"start"
	types[lift] = &"boss" if is_boss else &"lift"
	types[vault] = &"vault"
	types[uplink] = &"uplink"
	# arenas: the largest remaining rooms; caches: leaf rooms.
	var order := range(n)
	order.sort_custom(func(a, b): return rects[a].get_area() > rects[b].get_area())
	var arenas := 0
	for i in order:
		if types[i] == &"hub" and arenas < 2 + deck_index / 2 and rects[i].get_area() >= 30:
			types[i] = &"arena"
			arenas += 1
	for i in n:
		if types[i] == &"hub" and adj[i].size() == 1 and rng.randf() < 0.7:
			types[i] = &"cache"

	# 4. Carve grid.
	var cells := PackedByteArray()
	cells.resize(w * h)
	var room_id := PackedInt32Array()
	room_id.resize(w * h)
	room_id.fill(-1)
	var ceil_h := PackedFloat32Array()
	ceil_h.resize(w * h)
	for i in n:
		var r := rects[i]
		var ht := H_ARENA if types[i] in [&"arena", &"uplink", &"boss"] else H_ROOM
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var k := y * w + x
				cells[k] = FLOOR
				room_id[k] = i
				ceil_h[k] = ht
	for e in edges:
		_carve_corridor(cells, ceil_h, w, h, centers[e.x], centers[e.y], rng.randi_range(0, 1) == 0, rng.randi_range(1, 2))

	# 5. Props (cover/pillars) — kept off doorways and room centres.
	var blocked := PackedByteArray()
	blocked.resize(w * h)
	var props: Array = []
	for i in n:
		var t := types[i]
		var density := 0.0
		match t:
			&"arena", &"boss": density = 0.09
			&"hub", &"uplink": density = 0.06
			&"vault", &"cache": density = 0.04
			&"lift": density = 0.03
		if density <= 0.0:
			continue
		var r := rects[i]
		for y in range(r.position.y + 1, r.end.y - 1):
			for x in range(r.position.x + 1, r.end.x - 1):
				var c := Vector2i(x, y)
				if c == centers[i] or (c - centers[i]).length_squared() <= 1:
					continue
				if _near_doorway(cells, room_id, w, h, x, y, i):
					continue
				if rng.randf() < density:
					var kind := &"crate"
					var roll := rng.randf()
					if t in [&"arena", &"boss"] and roll < 0.3 and ceil_h[y * w + x] > H_ROOM:
						kind = &"pillar"
					elif roll < 0.5:
						kind = &"barrier"
					props.append({"cell": c, "kind": kind, "rot": rng.randi_range(0, 3)})
					blocked[y * w + x] = 1

	# 6. Light strips + lights + spawn cells.
	var rooms: Array = []
	for i in n:
		var r := rects[i]
		var spawns: Array[Vector2i] = []
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if blocked[y * w + x] == 0:
					spawns.append(Vector2i(x, y))
		rooms.append({"rect": r, "type": types[i], "center": centers[i], "spawns": spawns,
			"ceil": ceil_h[centers[i].y * w + centers[i].x]})

	return {
		"w": w, "h": h, "cells": cells, "room_id": room_id, "ceil": ceil_h, "blocked": blocked,
		"rooms": rooms, "edges": edges, "props": props, "deck": deck_index,
		"start": start, "lift": lift, "vault": vault, "uplink": uplink, "boss": is_boss,
	}

static func _carve_corridor(cells: PackedByteArray, ceil_h: PackedFloat32Array, w: int, h: int,
		a: Vector2i, b: Vector2i, x_first: bool, width: int) -> void:
	var corner := Vector2i(b.x, a.y) if x_first else Vector2i(a.x, b.y)
	for seg in [[a, corner], [corner, b]]:
		var p: Vector2i = seg[0]
		var q: Vector2i = seg[1]
		var step := Vector2i(signi(q.x - p.x), signi(q.y - p.y))
		var cur := p
		while true:
			for dx in width:
				for dy in width:
					var x := clampi(cur.x + dx, 1, w - 2)
					var y := clampi(cur.y + dy, 1, h - 2)
					var k := y * w + x
					if cells[k] == SOLID:
						cells[k] = FLOOR
						ceil_h[k] = H_CORRIDOR
			if cur == q:
				break
			cur += step

static func _near_doorway(cells: PackedByteArray, room_id: PackedInt32Array, w: int, h: int, x: int, y: int, rid: int) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var k := ny * w + nx
			if cells[k] == FLOOR and room_id[k] != rid:
				return true
	return false

static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func _has_edge(edges: Array, a: int, b: int) -> bool:
	for e in edges:
		if (e.x == a and e.y == b) or (e.x == b and e.y == a):
			return true
	return false

static func _adjacency(n: int, edges: Array) -> Array:
	var adj := []
	for i in n:
		adj.append([])
	for e in edges:
		adj[e.x].append(e.y)
		adj[e.y].append(e.x)
	return adj

static func _bfs(adj: Array, src: int) -> Array:
	var dist := []
	dist.resize(adj.size())
	dist.fill(-1)
	dist[src] = 0
	var q := [src]
	while not q.is_empty():
		var u: int = q.pop_front()
		for v in adj[u]:
			if dist[v] == -1:
				dist[v] = dist[u] + 1
				q.append(v)
	return dist

static func _argmax(dist: Array, exclude: Array) -> int:
	var best := -1
	for i in dist.size():
		if i in exclude:
			continue
		if best == -1 or dist[i] > dist[best]:
			best = i
	return best

static func _shortest_path(adj: Array, a: int, b: int) -> Array:
	var prev := {a: -1}
	var q := [a]
	while not q.is_empty():
		var u: int = q.pop_front()
		if u == b:
			break
		for v in adj[u]:
			if not prev.has(v):
				prev[v] = u
				q.append(v)
	var path := []
	var cur := b
	while cur != -1 and prev.has(cur):
		path.push_front(cur)
		cur = prev[cur]
	return path

# ---------------------------------------------------------------- queries

static func cell_to_world(c: Vector2i, y: float = 0.0) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, y, (c.y + 0.5) * CELL)

static func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))

static func is_walkable(layout: Dictionary, c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= layout.w or c.y >= layout.h:
		return false
	var k: int = c.y * layout.w + c.x
	return layout.cells[k] == FLOOR and layout.blocked[k] == 0

## Flood fill over walkable cells from a start cell. Returns a set (Dictionary) of reached cells.
static func flood(layout: Dictionary, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var q := [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: Vector2i = c + d
			if not seen.has(nc) and is_walkable(layout, nc):
				seen[nc] = true
				q.append(nc)
	return seen

## Returns a list of invariant violations (empty when the layout is valid).
static func validate(layout: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	var rooms: Array = layout.rooms
	for i in rooms.size():
		for j in range(i + 1, rooms.size()):
			if (rooms[i].rect as Rect2i).intersects(rooms[j].rect):
				errs.append("rooms %d and %d overlap" % [i, j])
	var start_c: Vector2i = rooms[layout.start].center
	if not is_walkable(layout, start_c):
		errs.append("start centre blocked")
		return errs
	var reach := flood(layout, start_c)
	for i in rooms.size():
		if not reach.has(rooms[i].center):
			errs.append("room %d (%s) unreachable" % [i, rooms[i].type])
	for key in ["vault", "uplink", "lift"]:
		if layout[key] < 0:
			errs.append("missing %s" % key)
	if layout.vault == layout.lift or layout.vault == layout.start:
		errs.append("vault coincides with start/lift")
	return errs
