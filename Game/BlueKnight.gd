extends CharacterBody2D

@onready var label = $Label
@onready var navigation_agent_2d = $NavigationAgent2D

const SPEED = 200.0
var selected = false
var move_velocity = Vector2.ZERO

func _ready():
	add_to_group("unit")
	navigation_agent_2d.velocity_computed.connect(_on_velocity_computed)

func _process(_delta):
	# Show label only if selected
	label.visible = selected

func _physics_process(_delta):
	if navigation_agent_2d.is_navigation_finished():
		move_velocity = Vector2.ZERO
	else:
		var next_point = navigation_agent_2d.get_next_path_position()
		var direction = (next_point - global_position).normalized()
		move_velocity = direction * SPEED

	# Apply movement correctly for CharacterBody2D
	velocity = move_velocity
	move_and_slide()

func _on_velocity_computed(safe_velocity):
	move_velocity = safe_velocity

func set_target_position(position):
	navigation_agent_2d.set_target_position(position)
