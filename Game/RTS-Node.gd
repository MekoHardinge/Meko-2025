extends Node2D

var sel_start = Vector2.ZERO
var sel_end = Vector2.ZERO
var is_selecting = false

var form_start = Vector2.ZERO
var form_end = Vector2.ZERO
var is_forming = false

var active_selected_groups := {}

func _ready():
	for button in get_tree().get_nodes_in_group("buttons"):
		button.connect("selection_changed", Callable(self, "_on_button_selection_changed"))

func _on_button_selection_changed(selected_groups: Array, selected: bool) -> void:
	for group_name in selected_groups:
		if selected:
			active_selected_groups[group_name] = true
		else:
			active_selected_groups.erase(group_name)

	# Clear all selections first
	for ctrl in get_tree().get_nodes_in_group("unit_controller"):
		ctrl.selected = false
		# If still in any active group, mark selected
		for group_name in active_selected_groups.keys():
			if ctrl.is_in_group(group_name):
				ctrl.selected = true
				break

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_selecting = true
				sel_start = get_global_mouse_position()
				sel_end = sel_start
				queue_redraw()
			else:
				if is_selecting:
					_select_units()
				is_selecting = false
				queue_redraw()

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_forming = true
				form_start = get_global_mouse_position()
				form_end = form_start
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
		draw_rect(r, Color(0.3, 0.6, 1.0, 0.2), true)
		draw_rect(r, Color(1, 1, 1), false, 2)

	if is_forming:
		var r2 = Rect2(form_start, form_end - form_start).abs()
		draw_rect(r2, Color(1.0, 0.6, 0.2, 0.2), true)
		draw_rect(r2, Color(1, 0.5, 0), false, 2)

		var selected_units = []
		for ctrl in get_tree().get_nodes_in_group("unit_controller"):
			if ctrl.selected:
				selected_units.append(ctrl)

		var unit_count = selected_units.size()
		if unit_count == 0:
			return

		var aspect = r2.size.x / r2.size.y if r2.size.y != 0 else 1.0

		if aspect >= 1.0:
			var unit_width = r2.size.x / unit_count
			for i in range(unit_count):
				var unit_rect = Rect2(
					r2.position.x + i * unit_width,
					r2.position.y,
					unit_width,
					r2.size.y
				)
				_draw_unit_preview(selected_units[i], unit_rect)
		else:
			var unit_height = r2.size.y / unit_count
			for i in range(unit_count):
				var unit_rect = Rect2(
					r2.position.x,
					r2.position.y + i * unit_height,
					r2.size.x,
					unit_height
				)
				_draw_unit_preview(selected_units[i], unit_rect)

	for ctrl in get_tree().get_nodes_in_group("unit_controller"):
		if ctrl.selected and ctrl.has_method("last_formation_rect") and ctrl.last_formation_rect.size != Vector2.ZERO:
			_draw_unit_preview(ctrl, ctrl.last_formation_rect)

func _draw_unit_preview(ctrl, rect):
	var cnt = ctrl.knights.size()
	if cnt == 0:
		return

	var aspect_ratio = rect.size.x / rect.size.y if rect.size.y != 0 else 1.0
	var rows = int(ceil(sqrt(cnt / aspect_ratio)))
	rows = max(rows, 1)
	var cols = int(ceil(cnt / float(rows)))

	var cell_w = rect.size.x / cols
	var cell_h = rect.size.y / rows

	var unit_index = 0
	for row in range(rows):
		var units_this_row = min(cols, cnt - unit_index)
		for col in range(units_this_row):
			var x = rect.position.x + col * cell_w + cell_w * 0.5
			var y = rect.position.y + row * cell_h + cell_h * 0.5
			draw_circle(Vector2(x, y), 5, Color(1, 1, 0.3, 0.8))
			unit_index += 1

func _select_units():
	var r = Rect2(sel_start, sel_end - sel_start).abs()
	var margin = 6.0
	var expanded_r = Rect2(r.position - Vector2(margin, margin), r.size + Vector2(margin * 2, margin * 2))

	for ctrl in get_tree().get_nodes_in_group("unit_controller"):
		ctrl.selected = false
		for k in ctrl.knights:
			if expanded_r.has_point(k.global_position):
				ctrl.selected = true
				break

func _form_units(rect: Rect2):
	var selected_units = []
	for ctrl in get_tree().get_nodes_in_group("unit_controller"):
		if ctrl.selected:
			selected_units.append(ctrl)

	var unit_count = selected_units.size()
	if unit_count == 0:
		return

	var aspect = rect.size.x / rect.size.y if rect.size.y != 0 else 1.0

	if aspect >= 1.0:
		var unit_width = rect.size.x / unit_count
		for i in range(unit_count):
			var unit_rect = Rect2(
				rect.position.x + i * unit_width,
				rect.position.y,
				unit_width,
				rect.size.y
			)
			selected_units[i].form_to_rect(unit_rect)
	else:
		var unit_height = rect.size.y / unit_count
		for i in range(unit_count):
			var unit_rect = Rect2(
				rect.position.x,
				rect.position.y + i * unit_height,
				rect.size.x,
				unit_height
			)
			selected_units[i].form_to_rect(unit_rect)
