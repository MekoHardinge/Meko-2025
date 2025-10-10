extends CharacterBody2D

@onready var nav = $NavigationAgent2D

const SPEED = 100.0
const REPATH_TIME = 0.5
const STUCK_TIME = 1.0
const RANDOM_OFFSET_RADIUS = 84
const BROADCAST_INTERVAL = 3.0

var target_position = Vector2.ZERO

var last_position = Vector2.ZERO
var time_stuck = 0.0
var time_since_repath = 0.0
var time_since_broadcast = 0.0

var unit_id = ""
var is_engaged = false

func _ready():
	add_to_group("unit")
	nav.max_speed = SPEED
	nav.target_desired_distance = 10.0
	nav.path_desired_distance = 4.0
	nav.avoidance_enabled = true

	last_position = global_position

	if unit_id == "":
		unit_id = str(get_instance_id())

func _physics_process(delta):
	time_since_repath += delta
	time_since_broadcast += delta

	if time_since_repath >= REPATH_TIME and target_position != Vector2.ZERO:
		time_since_repath = 0.0
		nav.set_target_position(target_position)

	var move_vel = Vector2.ZERO
	if not nav.is_navigation_finished():
		var next_point = nav.get_next_path_position()
		move_vel = (next_point - global_position).normalized() * SPEED
		velocity = move_vel
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	if move_vel.length() > 0.1:
		if global_position.distance_to(last_position) < 1.5:
			time_stuck += delta
			if time_stuck > STUCK_TIME:
				var rand_offset = Vector2(randf() * 2 - 1, randf() * 2 - 1).normalized() * RANDOM_OFFSET_RADIUS
				nav.set_target_position(global_position + rand_offset)
				time_stuck = 0.0
				time_since_repath = 0.0
		else:
			time_stuck = 0.0
	last_position = global_position

	if time_since_broadcast >= BROADCAST_INTERVAL:
		time_since_broadcast = 0.0
		broadcast_info()

func set_target_position(pos: Vector2):
	target_position = pos
	time_since_repath = REPATH_TIME

func broadcast_info():
	print("Knight ID:", unit_id)
	print(" - Position:", global_position)
	print(" - In Combat:", is_engaged)
