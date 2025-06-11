# UnitController.gd
extends Node2D

@export var spacing := 64

var selected := false
var knights: Array[CharacterBody2D] = []

func _ready():
	add_to_group("unit_controller")
	for child in get_children():
		if child is CharacterBody2D:
			knights.append(child)

# Called by RTSController when you drag‐release the formation rectangle
func form_to_rect(rect: Rect2) -> void:
	if not selected or knights.is_empty():
		return

	var cnt = knights.size()
	# Compute formation grid based on rectangle aspect ratio
	var aspect = rect.size.x / rect.size.y
	# More columns if rectangle is wide, more rows if tall
	var cols = int(ceil(sqrt(cnt * aspect)))
	var rows = int(ceil(cnt / float(cols)))

	# Calculate each cell size within the rect
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
