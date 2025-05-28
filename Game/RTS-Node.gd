extends Node2D

@onready var selection_area = $"../SelectionArea"
@onready var collision_shape_2d = $"../SelectionArea/CollisionShape2D"

var selectionStartPoint = Vector2.ZERO

func _input(event):
	if (selectionStartPoint == Vector2.ZERO && event is InputEventMouseButton
		&& event.button_index == 1 && event.is_pressed()):
			selectionStartPoint = get_global_mouse_position()
	elif (selectionStartPoint != Vector2.ZERO && event is InputEventMouseButton
		&& event.button_index == 1):
			_select_units()
			selectionStartPoint = Vector2.ZERO


func _process(delta):
	queue_redraw()

func _draw():
	if selectionStartPoint == Vector2.ZERO: return
	
	var mousePosition = get_global_mouse_position()
	var startX = selectionStartPoint.x
	var startY = selectionStartPoint.y
	var endX = mousePosition.x
	var endY = mousePosition.y
	
	var lineWidth = 3.0
	var lineColor = Color.WHITE
	
	draw_line(Vector2(startX,startY), Vector2(endX, startY), lineColor, lineWidth)
	draw_line(Vector2(startX,startY), Vector2(startX, endY), lineColor, lineWidth)
	draw_line(Vector2(endX,startY), Vector2(endX, endY), lineColor, lineWidth)
	draw_line(Vector2(startX,endY), Vector2(endX, endY), lineColor, lineWidth)

func _select_units():
	var size = abs(get_global_mouse_position() - selectionStartPoint)
	
	var areaPosition  = _get_rect_start_position()
	selection_area.global_position = areaPosition
	collision_shape_2d.global_position = areaPosition + size / 2
	collision_shape_2d.shape.size = size
	
	await get_tree().create_timer(0.04).timeout
	
	var units = get_tree().get_nodes_in_group("unit")
	
func _get_rect_start_position():
	var newPosition
	var mousePosition = get_global_mouse_position()
	
	if selectionStartPoint.x < mousePosition.x:
		newPosition.x = selectionStartPoint.x
	else: newPosition.x = mousePosition.x
	
	if selectionStartPoint.y < mousePosition.y:
		newPosition.y = selectionStartPoint.y
	else: newPosition.y = mousePosition.y
	
	return newPosition
