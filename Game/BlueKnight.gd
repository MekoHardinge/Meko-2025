extends CharacterBody2D

@onready var label = $Label
@onready var navigation_agent_2d = $NavigationAgent2D
@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_range = $AttackRange

const SPEED = 100.0
const REPATH_INTERVAL = 0.5
const STUCK_CHECK_INTERVAL = 0.5
const STUCK_THRESHOLD = 1.0
const MIN_MOVEMENT_DELTA = 6.0
const MAX_HEALTH = 100
const ATTACK_INTERVAL = 1.0

var health = MAX_HEALTH
var selected = false
var move_velocity = Vector2.ZERO
var target_position = Vector2.ZERO

var repath_timer = 0.0
var stuck_timer = 0.0
var last_position = Vector2.ZERO
var current_target = null
var is_attacking = false
var attack_cooldown = 0.0

var targets_in_range: Array = []

func _ready():
	add_to_group("unit")
	navigation_agent_2d.velocity_computed.connect(_on_velocity_computed)
	navigation_agent_2d.avoidance_enabled = true
	navigation_agent_2d.path_desired_distance = 4.0
	navigation_agent_2d.target_desired_distance = 8.0
	navigation_agent_2d.max_speed = SPEED
	last_position = global_position

	attack_range.body_entered.connect(_on_attack_range_entered)
	attack_range.body_exited.connect(_on_attack_range_exited)

func _process(_delta):
	label.visible = selected

func _physics_process(delta):
	attack_cooldown -= delta

	# Attack logic
	if targets_in_range.size() > 0:
		select_closest_target()
		if attack_cooldown <= 0.0 and is_instance_valid(current_target):
			perform_attack()
			attack_cooldown = ATTACK_INTERVAL
		move_velocity = Vector2.ZERO
	else:
		current_target = null
		is_attacking = false

		# Movement logic
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

	velocity = move_velocity
	move_and_slide()

	# Animation logic
	if is_attacking:
		pass  # Attack animations are handled separately
	elif move_velocity.length() > 5:
		animated_sprite.flip_h = move_velocity.x < 0
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

func _on_attack_range_entered(body):
	if body.is_in_group("goblin") and not targets_in_range.has(body):
		targets_in_range.append(body)

func _on_attack_range_exited(body):
	if targets_in_range.has(body):
		targets_in_range.erase(body)
	if body == current_target:
		current_target = null
		is_attacking = false

func select_closest_target():
	var closest_dist = INF
	var closest = null
	for target in targets_in_range:
		if not is_instance_valid(target):
			continue
		var dist = global_position.distance_to(target.global_position)
		if dist < closest_dist:
			closest = target
			closest_dist = dist
	current_target = closest
	is_attacking = current_target != null

func perform_attack():
	if not is_instance_valid(current_target):
		is_attacking = false
		return

	var to_target = current_target.global_position - global_position
	var abs_dir = to_target.abs()

	var attack_anim = ""
	if abs_dir.x > abs_dir.y:
		animated_sprite.flip_h = to_target.x < 0
		attack_anim = "AttackRight" + str(randi() % 2 + 1)
	else:
		animated_sprite.flip_h = false
		attack_anim = "AttackUp" + str(randi() % 2 + 1) if to_target.y < 0 else "AttackDown" + str(randi() % 2 + 1)


	animated_sprite.play(attack_anim)

	if current_target.has_method("take_damage"):
		current_target.take_damage(10)

func take_damage(amount: int):
	health -= amount
	modulate = Color(1, 0.5, 0.5)
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1, 1, 1)

	if health <= 0:
		die()

func die():
	queue_free()
