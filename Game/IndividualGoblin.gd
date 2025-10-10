extends CharacterBody2D

@onready var nav = $NavigationAgent2D

const SPEED = 80.0
const REPATH_TIME = 0.5
const STUCK_TIME = 1.0
const RANDOM_OFFSET_RADIUS = 64
const COMBAT_RANGE = 48.0

var target_position: Vector2 = Vector2.ZERO
var last_position: Vector2 = Vector2.ZERO
var time_stuck: float = 0.0
var time_since_repath: float = 0.0

var health: int = 100
var is_engaged: bool = false
var attack_target: CharacterBody2D = null

func _ready():
	add_to_group("enemy_unit")
	nav.max_speed = SPEED
	nav.target_desired_distance = 10.0
	nav.path_desired_distance = 4.0
	nav.avoidance_enabled = true
	last_position = global_position

func _physics_process(delta):
	time_since_repath += delta

	# Combat check
	_update_combat()

	# Movement
	if attack_target and is_instance_valid(attack_target):
		target_position = attack_target.global_position

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

	# Stuck detection
	if move_vel.length() > 0.1 and global_position.distance_to(last_position) < 1.5:
		time_stuck += delta
		if time_stuck > STUCK_TIME:
			var rand_offset = Vector2(randf() * 2 - 1, randf() * 2 - 1).normalized() * RANDOM_OFFSET_RADIUS
			nav.set_target_position(global_position + rand_offset)
			time_stuck = 0.0
			time_since_repath = 0.0
	else:
		time_stuck = 0.0

	last_position = global_position

func _update_combat():
	if health <= 0:
		queue_free()
		return

	# Find nearest enemy (player knights)
	if not attack_target or not is_instance_valid(attack_target):
		attack_target = _find_nearest_enemy()

	if attack_target and is_instance_valid(attack_target):
		var dist = global_position.distance_to(attack_target.global_position)
		is_engaged = dist <= COMBAT_RANGE
		if is_engaged:
			_attack(attack_target)

func _attack(enemy: CharacterBody2D):
	if not is_instance_valid(enemy):
		return
	enemy.health -= 10
	if enemy.health <= 0:
		enemy.queue_free()
		attack_target = null

func _find_nearest_enemy() -> CharacterBody2D:
	var nearest = null
	var nearest_dist = INF
	for unit in get_tree().get_nodes_in_group("unit"): # Player knights are in "unit"
		if not is_instance_valid(unit):
			continue
		var d = global_position.distance_to(unit.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = unit
	return nearest

func set_target_position(pos: Vector2):
	target_position = pos
	time_since_repath = REPATH_TIME
