extends Button

@onready var sprite := $Sprite
var original_position: Vector2
@export var group_name: String = ""

var ignore_signal := false  # Flag to ignore signal when setting pressed programmatically

func _ready():
	toggle_mode = true
	toggled.connect(_on_toggled)
	original_position = sprite.position

	if get_button_group():
		get_button_group().set_exclusive(false)  # Allow multiple toggled buttons

	var ignore_groups = ["button"]
	for g in get_groups():
		if g not in ignore_groups:
			group_name = g
			break
	print("Button group_name set to:", group_name)

func _on_toggled(button_pressed: bool) -> void:
	if ignore_signal:
		return  # Skip if signal was caused programmatically

	print("Button toggled:", button_pressed, "Group:", group_name)
	if button_pressed:
		sprite.position.y = original_position.y - 1
	else:
		sprite.position = original_position

	for unit in get_tree().get_nodes_in_group("unit_controller"):
		if unit.is_in_group(group_name):
			unit.selected = button_pressed

func _set_pressed_no_signal(pressed: bool) -> void:
	if pressed == is_pressed():
		return
	ignore_signal = true
	set_pressed(pressed)
	ignore_signal = false
