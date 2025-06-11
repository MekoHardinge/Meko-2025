# UnitController.gd

extends Node2D

@export var spacing := 32

var selected := false
var knights: Array[CharacterBody2D] = []
var last_formation_rect: Rect2 = Rect2()  # << Add this

func _ready():
	add_to_group("unit_controller")
	for child in get_children():
		if child is CharacterBody2D:
			knights.append(child)

func form_to_rect(rect: Rect2):
	var cnt = knights.size()
	if cnt == 0:
		return

	last_formation_rect = rect  # << Store it

	var cols = int(ceil(sqrt(cnt)))
	var rows = int(ceil(cnt / float(cols)))
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
