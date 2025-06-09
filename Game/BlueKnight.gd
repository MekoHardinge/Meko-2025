extends CharacterBody2D

@onready var label = $Label
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_range = $AttackRange
@onready var collision_shape = $CollisionShape2D

const SPEED = 100.0
const REPATH_INTERVAL = 0.3
const ATTACK_INTERVAL = 1.0
const MAX_HEALTH = 100

# Avoidance constants
const AVOID_RADIUS = 48.0
const AVOID_FORCE_MAX = 300.0
const AVOID_SMOOTHING = 8.0
const MIN_SEPARATION = 24.0

# Stuck detection constants
const STUCK_CHECK_INTERVAL = 0.5
const STUCK_DISTANCE_THRESHOLD = 4.0
const STUCK_RESET_TIME = 2.0

# Attack damage
const ATTACK_DAMAGE = 10

var health = MAX_HEALTH
var selected = false
var target_position = Vector2.ZERO
var current_target = null
var is_attacking = false
var attack_cooldown = 0.0
var repath_timer = 0.0

var targets_in_range: Array = []

# Used for stuck detection
var stuck_timer = 0.0
var stuck_position = Vector2.ZERO
var stuck_reset_timer = 0.0

# Reference to all knights in the scene for avoidance
var all_knights := []

# Current velocity applied to the body
var current_velocity = Vector2.ZERO
# Smoothed avoidance velocity
var avoidance_velocity = Vector2.ZERO

func _ready():
	add_to_group("unit")

	# Configure navigation agent
	navigation_agent.avoidance_enabled = false  # We'll handle avoidance ourselves
	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = 8.0
	navigation_agent.max_speed = SPEED

	attack_range.body_entered.connect(_on_attack_range_entered)
	attack_range.body_exited.connect(_on_attack_range_exited)

	# Get all knights (units) in the scene for avoidance calculation
	all_knights = get_tree().get_nodes_in_group("unit")

	# Initialize stuck detection
	stuck_position = global_position

func _process(_delta):
	label.visible = selected

func _physics_process(delta):
	attack_cooldown -= delta
	repath_timer -= delta
	stuck_timer += delta

	# Stuck detection: if position hasn't changed much for a while, reset navigation target
	if stuck_timer >= STUCK_CHECK_INTERVAL:
		var dist_moved = global_position.distance_to(stuck_position)
		if dist_moved < STUCK_DISTANCE_THRESHOLD:
			stuck_reset_timer += stuck_timer
			if stuck_reset_timer >= STUCK_RESET_TIME:
				# Reset target to current position to force path recalculation
				navigation_agent.set_target_position(global_position)
				repath_timer = 0.0
				stuck_reset_timer = 0.0
		else:
			stuck_reset_timer = 0.0
		stuck_timer = 0.0
		stuck_position = global_position

	# Handle attacking
	if targets_in_range.size() > 0:
		select_closest_target()
		if attack_cooldown <= 0.0 and is_instance_valid(current_target):
			perform_attack()
			attack_cooldown = ATTACK_INTERVAL
		current_velocity = Vector2.ZERO
		# When attacking, don't move
	else:
		current_target = null
		is_attacking = false

		# Repath periodically to update path if target moves
		if repath_timer <= 0.0:
			navigation_agent.set_target_position(target_position)
			repath_timer = REPATH_INTERVAL

		# Calculate direction toward next path point
		var move_direction = Vector2.ZERO
		if not navigation_agent.is_navigation_finished():
			var next_point = navigation_agent.get_next_path_position()
			var to_next = next_point - global_position
			if to_next.length() > 1:
				move_direction = to_next.normalized()
			else:
				move_direction = Vector2.ZERO

		# Calculate avoidance vector to move around other knights
		var avoid_vec = compute_avoidance_vector()

		# Blend movement and avoidance with smoothing
		avoidance_velocity = avoidance_velocity.lerp(avoid_vec * SPEED, delta * AVOID_SMOOTHING)


		# Combine navigation and avoidance vectors with weights
		var combined_velocity = (move_direction * SPEED) + avoidance_velocity

		# Clamp speed to max SPEED
		if combined_velocity.length() > SPEED:
			combined_velocity = combined_velocity.normalized() * SPEED

		current_velocity = combined_velocity

	# Apply velocity and move the character
	velocity = current_velocity
	move_and_slide()

	# Update animations
	update_animation()

func update_animation():
	if is_attacking:
		# Attack animation is handled in perform_attack()
		return
	elif velocity.length() > 5:
		animated_sprite.flip_h = velocity.x < 0
		animated_sprite.play("Walk")
	else:
		animated_sprite.play("Idle")

func compute_avoidance_vector() -> Vector2:
	# Calculate repulsion vector from other knights within AVOID_RADIUS
	var avoidance = Vector2.ZERO
	for knight in all_knights:
		if knight == self:
			continue
		if not is_instance_valid(knight):
			continue

		var offset = global_position - knight.global_position
		var dist = offset.length()
		if dist < AVOID_RADIUS and dist > 0:
			# Calculate repulsion strength, stronger when closer
			var strength = clamp((AVOID_RADIUS - dist) / AVOID_RADIUS, 0, 1)
			# Apply stronger repulsion when closer than minimum separation
			if dist < MIN_SEPARATION:
				strength = 1.0
			avoidance += offset.normalized() * strength * AVOID_FORCE_MAX
	return avoidance

func set_target_position(pos: Vector2):
	# Add some random offset to prevent knights stacking on exact same spot
	target_position = pos + Vector2(randf_range(-16, 16), randf_range(-16, 16))
	navigation_agent.set_target_position(target_position)
	repath_timer = 0.0

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
	var closest = null
	var closest_dist = INF
	for target in targets_in_range:
		if is_instance_valid(target):
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
		current_target.take_damage(ATTACK_DAMAGE)

func take_damage(amount: int):
	health -= amount
	modulate = Color(1, 0.5, 0.5)
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1, 1, 1)
	if health <= 0:
		die()

func die():
	queue_free()
