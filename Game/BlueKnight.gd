extends CharacterBody2D

@onready var label = $Label
@onready var navigation_agent_2d = $NavigationAgent2D
@onready var animated_sprite = $AnimatedSprite2D

const SPEED = 100.0
const REPATH_INTERVAL = 0.5
const STUCK_CHECK_INTERVAL = 0.5
const STUCK_THRESHOLD = 1.0  # seconds
const MIN_MOVEMENT_DELTA = 6.0  # pixels

var selected = false
var move_velocity = Vector2.ZERO
var target_position = Vector2.ZERO

var repath_timer = 0.0
var stuck_timer = 0.0
var last_position = Vector2.ZERO

func _ready():
	add_to_group("unit")
	navigation_agent_2d.velocity_computed.connect(_on_velocity_computed)
	navigation_agent_2d.avoidance_enabled = true
	navigation_agent_2d.path_desired_distance = 4.0
	navigation_agent_2d.target_desired_distance = 8.0
	navigation_agent_2d.max_speed = SPEED
	last_position = global_position

func _process(_delta):
	label.visible = selected

func _physics_process(delta):
	repath_timer -= delta
	stuck_timer += delta

	if not navigation_agent_2d.is_navigation_finished():
		if repath_timer <= 0.0:
			navigation_agent_2d.set_target_position(target_position)
			repath_timer = REPATH_INTERVAL

		var next_point = navigation_agent_2d.get_next_path_position()
		var direction = (next_point - global_position).normalized()
		move_velocity = direction * SPEED
	else:
		move_velocity = Vector2.ZERO

	# STUCK CHECK
	if stuck_timer >= STUCK_CHECK_INTERVAL:
		var dist_moved = global_position.distance_to(last_position)
		if dist_moved < MIN_MOVEMENT_DELTA:
			if stuck_timer >= STUCK_THRESHOLD:
				navigation_agent_2d.set_target_position(global_position)
				move_velocity = Vector2.ZERO
				target_position = global_position
		else:
			stuck_timer = 0.0
			last_position = global_position

	# Movement and animation
	velocity = move_velocity
	move_and_slide()

	if abs(velocity.x) > 5:
		animated_sprite.flip_h = velocity.x < 0

	if velocity.length() > 5:
		animated_sprite.play("Walk")
	else:
		animated_sprite.play("Idle")

func _on_velocity_computed(safe_velocity):
	move_velocity = safe_velocity

func set_target_position(position: Vector2):
	var offset = Vector2(randf_range(-16, 16), randf_range(-16, 16))
	target_position = position + offset
	navigation_agent_2d.set_target_position(target_position)
	repath_timer = 0.0
	stuck_timer = 0.0
	last_position = global_position
