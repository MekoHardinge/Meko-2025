extends Node2D

@export var spacing := 32

var selected := false
var knights: Array[CharacterBody2D] = []
var last_formation_rect: Rect2 = Rect2()

func _ready():
	add_to_group("unit_controller")
	for child in get_children():
		if child is CharacterBody2D:
			knights.append(child)

func form_to_rect(rect: Rect2):
	var cnt = knights.size()
	if cnt == 0:
		return

	last_formation_rect = rect

	var grid = get_grid_by_rect(cnt, rect.size)
	var cols = grid.x
	var rows = grid.y
	var cell_w = rect.size.x / cols
	var cell_h = rect.size.y / rows

	var i = 0
	for row in range(rows):
		var units_this_row = min(cols, cnt - i)
		# Center units horizontally in this row
		var row_width = units_this_row * cell_w
		var start_x = rect.position.x + (rect.size.x - row_width) * 0.5
		for col in range(units_this_row):
			var target = Vector2(
				start_x + col * cell_w + cell_w * 0.5,
				rect.position.y + row * cell_h + cell_h * 0.5
			)
			knights[i].set_target_position(target)
			i += 1

func get_grid_by_rect(unit_count: int, size: Vector2) -> Vector2i:
	if size == Vector2.ZERO or unit_count == 0:
		return Vector2i(1, unit_count)

	var best_cols = 1
	var best_rows = unit_count
	var best_error = INF

	for cols in range(1, unit_count + 1):
		var rows = int(ceil(unit_count / float(cols)))
		var grid_ratio = cols / float(rows)
		var aspect_ratio = size.x / size.y
		var error = abs(grid_ratio - aspect_ratio)

		var balance_penalty = abs((cols * rows) - unit_count)
		var total_error = error + balance_penalty * 1  # penalize unused cells lightly

		if total_error < best_error:
			best_error = total_error
			best_cols = cols
			best_rows = rows

	return Vector2i(best_cols, best_rows)
