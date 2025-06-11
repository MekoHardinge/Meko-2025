extends CharacterBody2D

@onready var nav    = $NavigationAgent2D
@onready var sprite = $AnimatedSprite2D

const SPEED = 100.0

var target_position = Vector2.ZERO
var selected        = false  # controlled by the controller

func _ready():
	nav.max_speed = SPEED
	nav.target_desired_distance = 4.0
	nav.path_desired_distance = 4.0
	nav.avoidance_enabled = false

func _physics_process(_delta):
	if target_position != Vector2.ZERO:
		nav.set_target_position(target_position)
		if not nav.is_navigation_finished():
			var dir = (nav.get_next_path_position() - global_position).normalized()
			velocity = dir * SPEED
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO

	# Move the knight using the velocity property
	move_and_slide()

	# Animate sprite based on movement
	if velocity.length() > 5:
		sprite.flip_h = velocity.x < 0
		sprite.play("Walk")
	else:
		sprite.play("Idle")

func set_target_position(pos: Vector2):
	target_position = pos
