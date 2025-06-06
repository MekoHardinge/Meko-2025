extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D
@onready var navigation_agent_2d = $NavigationAgent2D
@onready var detection_area = $DetectionArea
@onready var attack_range = $AttackRange

const SPEED = 80.0
const ATTACK_MOVE_THRESHOLD = 10.0
const STOP_DISTANCE = 20.0
const MAX_HEALTH = 50

var move_velocity = Vector2.ZERO
var target_unit = null
var is_attacking = false
var health = MAX_HEALTH

func _ready():
	add_to_group("goblin")
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	navigation_agent_2d.velocity_computed.connect(_on_velocity_computed)
	attack_range.body_entered.connect(_on_attack_range_entered)
	attack_range.body_exited.connect(_on_attack_range_exited)

func _physics_process(_delta):
	if is_attacking:
		move_velocity = Vector2.ZERO
	else:
		if target_unit and is_instance_valid(target_unit):
			var to_target = target_unit.global_position - global_position
			var distance = to_target.length()
			if distance > STOP_DISTANCE:
				var offset_target = target_unit.global_position - to_target.normalized() * STOP_DISTANCE
				navigation_agent_2d.set_target_position(offset_target)
			else:
				navigation_agent_2d.set_target_position(global_position)

		if navigation_agent_2d.is_navigation_finished():
			move_velocity = Vector2.ZERO
		else:
			var next_point = navigation_agent_2d.get_next_path_position()
			var direction = (next_point - global_position).normalized()
			move_velocity = direction * SPEED

	velocity = move_velocity
	move_and_slide()

	if move_velocity.length() > 5:
		sprite.play("Walk")
		sprite.flip_h = move_velocity.x < 0
	else:
		if not is_attacking:
			sprite.play("Idle")

func _on_velocity_computed(safe_velocity):
	move_velocity = safe_velocity

func _on_body_entered(body):
	if body.is_in_group("unit") and target_unit == null:
		target_unit = body

func _on_body_exited(body):
	if body == target_unit:
		target_unit = null
		is_attacking = false

func _on_attack_range_entered(body):
	if body == target_unit and move_velocity.length() < ATTACK_MOVE_THRESHOLD:
		is_attacking = true
		attack_target()

func _on_attack_range_exited(body):
	if body == target_unit:
		is_attacking = false

func attack_target():
	if not is_attacking or not is_instance_valid(target_unit):
		is_attacking = false
		return

	if move_velocity.length() > ATTACK_MOVE_THRESHOLD:
		is_attacking = false
		return

	var to_target = target_unit.global_position - global_position
	var abs_dir = to_target.abs()

	if abs_dir.x > abs_dir.y:
		sprite.flip_h = to_target.x < 0
		sprite.play("AttackRight")
	else:
		sprite.flip_h = false
		if to_target.y < 0:
			sprite.play("AttackUp")
		else:
			sprite.play("AttackDown")

	await get_tree().create_timer(0.6).timeout

	if is_attacking and is_instance_valid(target_unit) and move_velocity.length() < ATTACK_MOVE_THRESHOLD:
		if target_unit.has_method("take_damage"):
			target_unit.take_damage(10)
		attack_target()

func take_damage(amount: int):
	health -= amount
	modulate = Color(1, 0.4, 0.4)
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1, 1, 1)

	if health <= 0:
		die()

func die():
	queue_free()
