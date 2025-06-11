# RTSController.gd
extends Node2D

var sel_start      = Vector2.ZERO
var sel_end        = Vector2.ZERO
var is_selecting   = false

var form_start     = Vector2.ZERO
var form_end       = Vector2.ZERO
var is_forming     = false

func _input(event):
	if event is InputEventMouseButton:
		# LEFT button: start/end selection
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_selecting = true
				sel_start    = get_global_mouse_position()
				sel_end      = sel_start
				queue_redraw()
			else:
				if is_selecting:
					_select_units()
				is_selecting = false
				queue_redraw()

		# RIGHT button: start/end formation drag
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_forming = true
				form_start = get_global_mouse_position()
				form_end   = form_start
				queue_redraw()
			else:
				if is_forming:
					_form_units(Rect2(form_start, form_end - form_start).abs())
				is_forming = false
				queue_redraw()

	elif event is InputEventMouseMotion:
		if is_selecting:
			sel_end = get_global_mouse_position()
			queue_redraw()
		if is_forming:
			form_end = get_global_mouse_position()
			queue_redraw()

func _draw():
	if is_selecting:
		var r = Rect2(sel_start, sel_end - sel_start).abs()
		draw_rect(r, Color(0.3,0.6,1,0.2), true)
		draw_rect(r, Color(1,1,1), false, 2)
	if is_forming:
		var r2 = Rect2(form_start, form_end - form_start).abs()
		draw_rect(r2, Color(1,0.6,0.2,0.2), true)
		draw_rect(r2, Color(1,0.5,0), false, 2)

func _select_units():
	var r = Rect2(sel_start, sel_end - sel_start).abs()
	for ctrl in get_tree().get_nodes_in_group("unit_controller"):
		ctrl.selected = false
		# if any knight in this controller is inside r, select the whole unit
		for k in ctrl.knights:
			if r.has_point(k.global_position):
				ctrl.selected = true
				break

func _form_units(rect: Rect2):
	for ctrl in get_tree().get_nodes_in_group("unit_controller"):
		if ctrl.selected:
			ctrl.form_to_rect(rect)
