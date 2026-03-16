class_name BoardPathfinder
extends RefCounted

var state: BoardState = null

func _init(new_state: BoardState = null) -> void:
	state = new_state

func has_valid_connection() -> bool:
	return get_path_cells().size() > 0

func get_path_cells() -> Array[Vector2i]:
	if state == null:
		return []

	var open_cells: Array[Vector2i] = [state.start_cell]
	var dist: Dictionary = {}
	var came_from: Dictionary = {}
	var visited: Dictionary = {}

	var start_key: String = state.cell_key(state.start_cell)
	var chest_key: String = state.cell_key(state.chest_cell)

	dist[start_key] = 0.0

	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	while not open_cells.is_empty():
		var best_index: int = 0
		var best_cell: Vector2i = open_cells[0]
		var best_key: String = state.cell_key(best_cell)
		var best_cost: float = float(dist.get(best_key, 999999999.0))

		for i in range(1, open_cells.size()):
			var candidate: Vector2i = open_cells[i]
			var candidate_key: String = state.cell_key(candidate)
			var candidate_cost: float = float(dist.get(candidate_key, 999999999.0))

			if candidate_cost < best_cost:
				best_index = i
				best_cell = candidate
				best_key = candidate_key
				best_cost = candidate_cost

		open_cells.remove_at(best_index)

		if visited.has(best_key):
			continue

		visited[best_key] = true

		if best_key == chest_key:
			break

		for dir in dirs:
			var next_cell: Vector2i = best_cell + dir
			if not state.is_cell_inside(next_cell):
				continue
			if not state.is_cell_traversable(next_cell):
				continue

			var next_key: String = state.cell_key(next_cell)
			if visited.has(next_key):
				continue

			var move_cost: float = state.get_cell_path_cost(next_cell)
			var tentative_cost: float = best_cost + move_cost
			var old_cost: float = float(dist.get(next_key, 999999999.0))

			if tentative_cost < old_cost:
				dist[next_key] = tentative_cost
				came_from[next_key] = best_key

				if not open_cells.has(next_cell):
					open_cells.append(next_cell)

	if not visited.has(chest_key):
		return []

	var reverse_path: Array[Vector2i] = []
	var current_key: String = chest_key

	while true:
		reverse_path.append(state.cell_from_key(current_key))

		if current_key == start_key:
			break

		if not came_from.has(current_key):
			return []

		current_key = str(came_from[current_key])

	reverse_path.reverse()
	return reverse_path
