extends Node2D

var selection_start = Vector2.ZERO
var selection_end = Vector2.ZERO
var is_selecting = false
var left_mouse_held = false

@onready var long_left_click_timer = $LongLeftClickTimer
@onready var selection_area = $SelectionArea

func _ready():
	long_left_click_timer.timeout.connect(_on_long_left_click_timer_timeout)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				left_mouse_held = true
				long_left_click_timer.start()
			else:
				left_mouse_held = false
				long_left_click_timer.stop()

				if is_selecting:
					_select_units()
					is_selecting = false
					selection_start = Vector2.ZERO
					selection_end = Vector2.ZERO

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_issue_move_command(get_global_mouse_position())

func _process(_delta):
	if is_selecting:
		selection_end = get_global_mouse_position()
	queue_redraw()

func _draw():
	if is_selecting:
		var rect = Rect2(selection_start, selection_end - selection_start).abs()
		draw_rect(rect, Color(0.3, 0.6, 1.0, 0.2), true)
		draw_rect(rect, Color(1, 1, 1), false, 1.5)

func _on_long_left_click_timer_timeout():
	if left_mouse_held:
		is_selecting = true
		selection_start = get_global_mouse_position()
		selection_end = selection_start

func _select_units():
	var rect = Rect2(selection_start, selection_end - selection_start).abs()
	for unit in get_tree().get_nodes_in_group("unit"):
		unit.selected = rect.has_point(unit.global_position)

func _issue_move_command(position: Vector2):
	var selected_units := []
	for unit in get_tree().get_nodes_in_group("unit"):
		if unit.selected:
			selected_units.append(unit)

	if selected_units.is_empty():
		return

	var unit_count = selected_units.size()
	var spacing = 40
	var columns = int(ceil(sqrt(unit_count)))
	var rows = int(ceil(unit_count / float(columns)))
	var offset_origin = Vector2(columns - 1, rows - 1) * spacing * 0.5

	for i in unit_count:
		var row = i / columns
		var col = i % columns
		var offset = Vector2(col * spacing, row * spacing) - offset_origin
		offset += Vector2(randf_range(-4, 4), randf_range(-4, 4))
		selected_units[i].set_target_position(position + offset)
