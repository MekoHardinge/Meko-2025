extends Node2D

var selectionStartPoint = Vector2.ZERO
var leftMousePressed = false
var leftMouseReleased = false
var leftMouseLongPressed = false

@onready var long_left_click_timer = $LongLeftClickTimer

func _ready():
	long_left_click_timer.timeout.connect(_on_long_left_click_timer_timeout)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			leftMousePressed = true
			long_left_click_timer.start()
		else:
			leftMouseReleased = true
			long_left_click_timer.stop()
			leftMouseLongPressed = false

func _process(delta):
	if leftMouseLongPressed and selectionStartPoint == Vector2.ZERO:
		selectionStartPoint = get_global_mouse_position()
	elif leftMouseReleased:
		if selectionStartPoint != Vector2.ZERO:
			_select_units()
			selectionStartPoint = Vector2.ZERO
		else:
			_set_move_target()

	queue_redraw()
	leftMousePressed = false
	leftMouseReleased = false

func _draw():
	if selectionStartPoint == Vector2.ZERO:
		return

	var mousePos = get_global_mouse_position()
	var rect = Rect2(selectionStartPoint, mousePos - selectionStartPoint).abs()
	draw_rect(rect, Color(1, 1, 1, 0), false, 2.0)

func _select_units():
	var mousePos = get_global_mouse_position()
	var rect = Rect2(selectionStartPoint, mousePos - selectionStartPoint).abs()
	var units = get_tree().get_nodes_in_group("unit")

	for unit in units:
		unit.selected = rect.has_point(unit.global_position)

func _set_move_target():
	for unit in get_tree().get_nodes_in_group("unit"):
		if unit.selected:
			unit.set_target_position(get_global_mouse_position())

func _on_long_left_click_timer_timeout():
	leftMouseLongPressed = true
