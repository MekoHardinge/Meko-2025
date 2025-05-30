extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D
@onready var label = $Label
@onready var navigation_agent_2d = $NavigationAgent2D

const SPEED = 200.0
var selected = false

func _ready():
	add_to_group("unit")

func _process(delta):
	label.visible = selected

func _physics_process(delta):
	if navigation_agent_2d.is_navigation_finished():
		velocity = Vector2.ZERO
	else:
		var next_point = navigation_agent_2d.get_next_path_position()
		var direction = (next_point - global_position).normalized()
		velocity = direction * SPEED
		move_and_slide()

func set_target_position(position):
	navigation_agent_2d.set_target_position(position)

func _on_navigation_agent_2d_target_reached():
	# Optional idle behavior
	pass
