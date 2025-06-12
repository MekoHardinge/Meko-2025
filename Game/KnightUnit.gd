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

func get_adaptive_grid(cnt: int, size: Vector2) -> Vector2i:
	if cnt == 0:
		return Vector2i(0, 0)

	# Avoid division by zero by clamping height
	var height = size.y
	if height < 0.01:
		height = 0.01

	var aspect_ratio = size.x / height
	var rows = int(round(sqrt(cnt / aspect_ratio)))
	rows = max(rows, 1)

	var cols = int(ceil(cnt / rows))

	while cols / rows > aspect_ratio * 1.1:
		rows += 1
		cols = int(ceil(cnt / rows))

	return Vector2i(cols, rows)

func form_to_rect(rect: Rect2):
	var cnt = knights.size()
	if cnt == 0:
		return

	last_formation_rect = rect

	var grid = get_adaptive_grid(cnt, rect.size)
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
