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

# Compute columns and rows based on both unit count and rect shape
func get_grid_by_rect(unit_count: int, size: Vector2) -> Vector2i:
	if size.y == 0:
		return Vector2i(unit_count, 1)

	var ratio = size.x / size.y
	var cols = clamp(int(round(sqrt(unit_count * ratio))), 1, unit_count)
	var rows = int(ceil(unit_count / float(cols)))
	return Vector2i(cols, rows)

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

	for i in range(cnt):
		var row = i / cols
		var col = i % cols
		var target = rect.position + Vector2(
			col * cell_w + cell_w * 0.5,
			row * cell_h + cell_h * 0.5
		)
		knights[i].set_target_position(target)
