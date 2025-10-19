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
			if is_instance_valid(child) and child.is_inside_tree():
				knights.append(child)

func _process(delta):
	# keep list clean every frame so AI reads accurate counts
	_cleanup_dead_knights()

	_broadcast_timer += delta
	if _broadcast_timer >= BROADCAST_INTERVAL:
		_broadcast_timer = 0.0
		broadcast_status()

func form_to_rect(rect: Rect2):
	# sanitize list first
	_cleanup_dead_knights()

	var cnt = knights.size()
	if cnt == 0:
		last_formation_rect = rect
		return

	last_formation_rect = rect

	var grid = get_grid_by_rect(cnt, rect.size)
	var cols = grid.x
	var rows = grid.y
	var cell_w = rect.size.x / float(cols)
	var cell_h = rect.size.y / float(rows)

	var i = 0
	for row in range(rows):
		var units_this_row = min(cols, cnt - i)
		# Center units horizontally in this row
		var row_width = units_this_row * cell_w
		var start_x = rect.position.x + (rect.size.x - row_width) * 0.5
		for col in range(units_this_row):
			# guard index
			if i >= knights.size():
				break
			var unit = knights[i]
			# ensure unit valid; if not, remove it and continue
			if not is_instance_valid(unit) or not unit.is_inside_tree():
				knights.remove_at(i)
				cnt = knights.size()
				i -= 1
				continue

			var target = Vector2(
				start_x + col * cell_w + cell_w * 0.5,
				rect.position.y + row * cell_h + cell_h * 0.5
			)
			# safe call
			if unit.has_method("set_target_position"):
				unit.set_target_position(target)
			elif "formation_target" in unit:
				unit.formation_target = target
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
		var total_error = error + float(balance_penalty) * 1  # penalize unused cells lightly

		if total_error < best_error:
			best_error = total_error
			best_cols = cols
			best_rows = rows

	return Vector2i(best_cols, best_rows)

func broadcast_status():
	# keep list clean
	_cleanup_dead_knights()

	# Update AI-accessible status BEFORE the existing prints
	var total_pos = Vector2.ZERO
	var count = 0
	for child in get_children():
		if child is CharacterBody2D and is_instance_valid(child):
			total_pos += child.global_position
			count += 1

	var avg_pos = Vector2.ZERO
	if count > 0:
		avg_pos = total_pos / float(count)

	# update properties the AI will read
	average_position = avg_pos
	unit_count = count
	# is_engaged remains your placeholder unless you implement detection elsewhere

	print("---- Status of ", formation_id, " ----")
	print("Average Unit Position:", avg_pos)
	print("Unit Count (children):", count)
	print("In Combat:", is_engaged)  # Placeholder, implement your logic to update this later

# Called by units when they die so formation removes references quickly and safely
func on_unit_died(unit: Node) -> void:
	for i in range(knights.size() - 1, -1, -1):
		if knights[i] == unit:
			knights.remove_at(i)
			# keep your debug behavior if you want - not removing prints unless they exist
			# (you can enable debug prints by adding a debug flag if desired)
			break

# Safe periodic cleanup for formations: removes freed or detached units
func _cleanup_dead_knights() -> void:
	for i in range(knights.size() - 1, -1, -1):
		var k = knights[i]
		if not is_instance_valid(k) or not k.is_inside_tree():
			knights.remove_at(i)
