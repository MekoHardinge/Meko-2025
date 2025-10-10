extends Node2D

@export var formation_id: String = "Formation"  # Unique ID, set this per formation in the editor
@export var spacing := 32

var selected := false
var knights: Array[CharacterBody2D] = []
var last_formation_rect: Rect2 = Rect2()

var is_engaged := false  # Combat status placeholder

var _broadcast_timer := 0.0
const BROADCAST_INTERVAL := 3.0  # seconds

# AI-accessible properties (added)
var average_position: Vector2 = Vector2.ZERO
var unit_count: int = 0
# Optional explicit flag (useful to differentiate player formations from AI ones)
@export var is_player := true

func _ready():
	add_to_group("unit_controller")
	for child in get_children():
		if child is CharacterBody2D:
			knights.append(child)

func _process(delta):
	_broadcast_timer += delta
	if _broadcast_timer >= BROADCAST_INTERVAL:
		_broadcast_timer = 0.0
		broadcast_status()

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

func broadcast_status():
	# Update AI-accessible status BEFORE the existing prints
	var total_pos = Vector2.ZERO
	var count = 0
	for child in get_children():
		if child is CharacterBody2D:
			total_pos += child.global_position
			count += 1

	var avg_pos = Vector2.ZERO
	if count > 0:
		avg_pos = total_pos / count

	# update properties the AI will read
	average_position = avg_pos
	unit_count = count
	# is_engaged remains your placeholder unless you implement detection elsewhere

	print("---- Status of ", formation_id, " ----")
	print("Average Unit Position:", avg_pos)
	print("Unit Count (children):", count)
	print("In Combat:", is_engaged)  # Placeholder, implement your logic to update this later
