extends CharacterBody2D

@onready var nav: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Movement / Pathing
@export var SPEED: float = 90.0
@export var REPATH_TIME: float = 0.5
@export var STUCK_TIME: float = 1.0
@export var RANDOM_OFFSET_RADIUS: float = 64.0

# Combat
@export var ENGAGE_RADIUS: float = 250.0
@export var ATTACK_CONTACT_RADIUS: float = 18.0
@export var MELEE_RANGE: float = 22.0          # fallback distance check
@export var MELEE_CLOSE: float = 26.0         # deterministic close-distance to force damage
@export var ATTACK_DAMAGE: int = 12
@export var ATTACK_COOLDOWN: float = 1.2

# Health
@export var MAX_HEALTH: int = 80

# Internal state
var health: int
var formation_target: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var last_position: Vector2 = Vector2.ZERO
var time_stuck: float = 0.0
var time_since_repath: float = 0.0

# Combat timing/state
var attack_timer: float = 0.0
var attack_target: CharacterBody2D = null  # actively updated to nearest knight
var in_combat: bool = false

# dying guard
var _is_dying: bool = false

# contact shape
var _attack_shape: CircleShape2D

# Stall detection
const NO_DAMAGE_TIMEOUT := 2.0
var time_since_last_successful_damage: float = 0.0

# Target switching/hysteresis tuning (same values as knights)
const TARGET_SWITCH_COOLDOWN := 0.45
const TARGET_BETTER_DISTANCE_FACTOR := 0.75
const FINISH_HP_THRESHOLD := 25

var _last_target_switch_time: float = -999.0

func _ready() -> void:
	add_to_group("unit")
	add_to_group("goblin")
	add_to_group("goblins")

	health = MAX_HEALTH
	last_position = global_position
	_attack_shape = CircleShape2D.new()
	_attack_shape.radius = ATTACK_CONTACT_RADIUS

	time_since_last_successful_damage = 0.0

	if is_instance_valid(nav):
		nav.max_speed = SPEED
		nav.target_desired_distance = 8.0
		nav.path_desired_distance = 4.0
		nav.avoidance_enabled = true

	print("[GOBLIN] ready:", name, "health:", health)

func _physics_process(delta: float) -> void:
	time_since_repath += delta
	attack_timer -= delta
	time_since_last_successful_damage += delta
	_last_target_switch_time += delta

	if health <= 0:
		_die_and_cleanup()
		return

	# Continuously update nearest enemy target (with hysteresis)
	_update_nearest_enemy_with_hysteresis()

	# validate attack_target
	if attack_target and not is_instance_valid(attack_target):
		attack_target = null
		in_combat = false
		print("[GOBLIN] lost target (freed) ->", name)

	if attack_target and is_instance_valid(attack_target):
		_handle_combat_behavior(delta)
	else:
		in_combat = false
		_follow_formation(delta)

	# Animation update (plays "Walk" when moving; flips horizontally appropriately)
	_update_animation()

	_handle_stuck_detection(delta)

	# stall handling
	if in_combat and time_since_last_successful_damage >= NO_DAMAGE_TIMEOUT:
		_force_unblock_and_retarget()

# Hysteresis-aware retargeting
func _update_nearest_enemy_with_hysteresis() -> void:
	var best: CharacterBody2D = null
	var best_d: float = ENGAGE_RADIUS
	for unit in get_tree().get_nodes_in_group("knight"):
		if not is_instance_valid(unit) or unit == self:
			continue
		var d: float = global_position.distance_to(unit.global_position)
		if d < best_d:
			best_d = d
			best = unit
	for unit in get_tree().get_nodes_in_group("knights"):
		if not is_instance_valid(unit) or unit == self:
			continue
		var d2: float = global_position.distance_to(unit.global_position)
		if d2 < best_d:
			best_d = d2
			best = unit

	if best == null:
		return

	if attack_target == null:
		attack_target = best
		_last_target_switch_time = 0.0
		print("[GOBLIN] target_acquired:", name, "->", attack_target.name)
		return

	if best == attack_target:
		return

	# keep current target if very low hp
	var keep_current_due_to_low_hp := false
	if "health" in attack_target and int(attack_target.health) <= FINISH_HP_THRESHOLD:
		keep_current_due_to_low_hp = true

	if _last_target_switch_time < TARGET_SWITCH_COOLDOWN and not keep_current_due_to_low_hp:
		var curr_d = global_position.distance_to(attack_target.global_position)
		if best_d > curr_d * TARGET_BETTER_DISTANCE_FACTOR:
			return

	if "health" in best and "health" in attack_target:
		var best_hp = int(best.health)
		var cur_hp = int(attack_target.health)
		if best_hp * 1.0 <= cur_hp * 0.6:
			attack_target = best
			_last_target_switch_time = 0.0
			print("[GOBLIN] switch_to_lowerhp:", name, "->", attack_target.name)
			return

	var curr_d2 = global_position.distance_to(attack_target.global_position)
	if best_d <= curr_d2 * TARGET_BETTER_DISTANCE_FACTOR:
		attack_target = best
		_last_target_switch_time = 0.0
		print("[GOBLIN] target_acquired:", name, "->", attack_target.name)

func _handle_combat_behavior(_delta: float) -> void:
	if not is_instance_valid(attack_target):
		attack_target = null
		in_combat = false
		return

	var dist: float = global_position.distance_to(attack_target.global_position)
	if dist > ENGAGE_RADIUS * 1.5:
		attack_target = null
		in_combat = false
		print("[GOBLIN] target_out_of_range:", name)
		return

	target_position = attack_target.global_position
	if is_instance_valid(nav):
		nav.set_target_position(target_position)

	var move_vel: Vector2 = Vector2.ZERO
	if is_instance_valid(nav) and not nav.is_navigation_finished():
		var next_point: Vector2 = nav.get_next_path_position()
		move_vel = (next_point - global_position).normalized() * SPEED
		velocity = move_vel
	else:
		if dist > MELEE_RANGE and is_instance_valid(nav):
			nav.set_target_position(target_position)
			var direct = (target_position - global_position)
			if direct.length() > 0.1:
				velocity = direct.normalized() * SPEED
			else:
				velocity = Vector2.ZERO
		else:
			velocity = Vector2.ZERO

	move_and_slide()

	# ATTACK: deterministic close-range hit OR collider-based fallback
	if attack_timer <= 0.0:
		# 1) direct close-distance deterministic hit (most reliable)
		if is_instance_valid(attack_target):
			var direct_dist := global_position.distance_to(attack_target.global_position)
			if direct_dist <= MELEE_CLOSE:
				_apply_damage_to_unit(attack_target)
				return

		# 2) collider-based selection among touched units (if any)
		var touched_colliders: Array = _query_attack_colliders()
		var touched_units: Array = []
		for col in touched_colliders:
			var u = _resolve_unit_from_collider(col)
			if u and is_instance_valid(u) and u != self:
				if not touched_units.has(u):
					touched_units.append(u)

		var chosen_unit: CharacterBody2D = null

		# Prefer the assigned attack_target if present among touched units
		if attack_target and is_instance_valid(attack_target) and touched_units.has(attack_target):
			chosen_unit = attack_target
		else:
			# choose lowest-HP touched unit (finish quicker), fallback to closest
			var best_d: float = INF
			var best_hp: int = 999999
			for u in touched_units:
				if "health" in u:
					var uh = int(u.health)
					if uh < best_hp:
						best_hp = uh
						best_d = global_position.distance_to(u.global_position)
						chosen_unit = u
					elif uh == best_hp:
						var dd = global_position.distance_to(u.global_position)
						if dd < best_d:
							best_d = dd
							chosen_unit = u
				else:
					var dd2 = global_position.distance_to(u.global_position)
					if dd2 < best_d:
						best_d = dd2
						chosen_unit = u

		# Fallback: if no touched units but within MELEE_RANGE, attack assigned target
		if not chosen_unit and dist <= MELEE_RANGE and attack_target and is_instance_valid(attack_target):
			chosen_unit = attack_target

		if chosen_unit and is_instance_valid(chosen_unit):
			_apply_damage_to_unit(chosen_unit)

func _apply_damage_to_unit(chosen_unit: CharacterBody2D) -> void:
	if not is_instance_valid(chosen_unit):
		return
	var before_hp := -1
	if "health" in chosen_unit:
		before_hp = int(chosen_unit.health)

	if chosen_unit.has_method("take_damage"):
		chosen_unit.take_damage(ATTACK_DAMAGE, self)
	else:
		if "health" in chosen_unit:
			chosen_unit.health -= ATTACK_DAMAGE
			if chosen_unit.health <= 0:
				if chosen_unit.has_method("die"):
					chosen_unit.die(self)
				elif is_instance_valid(chosen_unit):
					chosen_unit.queue_free()

	attack_timer = ATTACK_COOLDOWN
	in_combat = true
	if get_parent() and "is_engaged" in get_parent():
		get_parent().is_engaged = true

	# Successful damage -> reset stall timer and print compact info
	time_since_last_successful_damage = 0.0
	print("[GOBLIN][ATTACK] ", name, "->", chosen_unit.name, " dmg=", ATTACK_DAMAGE, " hp_before=", before_hp, " hp_after=", (chosen_unit.health if "health" in chosen_unit else "unknown"))

	# If chosen unit died, retarget immediately
	if (not is_instance_valid(chosen_unit)) or ("health" in chosen_unit and int(chosen_unit.health) <= 0):
		if chosen_unit == attack_target:
			attack_target = null
		_update_nearest_enemy_with_hysteresis()

func _query_attack_colliders() -> Array:
	var space := get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = _attack_shape
	params.transform = Transform2D(0.0, global_position)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.exclude = [self]
	var results: Array = space.intersect_shape(params, 64)
	var colliders: Array = []
	for r in results:
		if typeof(r) == TYPE_DICTIONARY and r.has("collider"):
			var col = r["collider"]
			if is_instance_valid(col):
				colliders.append(col)
	return colliders

func _resolve_unit_from_collider(collider: Object) -> CharacterBody2D:
	var cur = collider
	var depth = 0
	while cur and depth < 12:
		if cur is CharacterBody2D:
			return cur
		if typeof(cur) == TYPE_OBJECT and cur.has_method("take_damage"):
			return cur
		if typeof(cur) == TYPE_OBJECT and "health" in cur and cur is Node:
			return cur
		if cur is Node:
			cur = cur.get_parent()
		else:
			break
		depth += 1
	return null

func _force_unblock_and_retarget() -> void:
	time_since_last_successful_damage = 0.0
	print("[GOBLIN] forcing unblock/repath ->", name)
	var rand_offset = Vector2(randf() * 2 - 1, randf() * 2 - 1).normalized() * (RANDOM_OFFSET_RADIUS * 0.5)
	if is_instance_valid(nav):
		nav.set_target_position(global_position + rand_offset)
	_update_nearest_enemy_with_hysteresis()
	if attack_target and is_instance_valid(attack_target) and is_instance_valid(nav):
		nav.set_target_position(attack_target.global_position)

func _follow_formation(_delta: float) -> void:
	if formation_target != Vector2.ZERO:
		target_position = formation_target

	if time_since_repath >= REPATH_TIME and target_position != Vector2.ZERO:
		time_since_repath = 0.0
		if is_instance_valid(nav):
			nav.set_target_position(target_position)

	if is_instance_valid(nav) and not nav.is_navigation_finished():
		var next_point: Vector2 = nav.get_next_path_position()
		velocity = (next_point - global_position).normalized() * SPEED
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func take_damage(amount: int, attacker: Node = null) -> void:
	health -= int(amount)
	in_combat = true
	if get_parent() and "is_engaged" in get_parent():
		get_parent().is_engaged = true
	print("[GOBLIN][DAMAGE] ", name, " took=", amount, " from=", (attacker.name if attacker and attacker is Node else "unknown"), " hp_after=", health)
	# defender got hit — reset their stall timer
	time_since_last_successful_damage = 0.0
	if health <= 0:
		die(attacker)

func die(_attacker: Node = null) -> void:
	if _is_dying:
		return
	_is_dying = true

	var p: Node = get_parent()
	if p and p.has_method("on_unit_died"):
		p.on_unit_died(self)

	if is_in_group("unit"):
		remove_from_group("unit")
	if is_in_group("goblin"):
		remove_from_group("goblin")
	if is_in_group("goblins"):
		remove_from_group("goblins")

	print("[GOBLIN] died:", name)
	queue_free()

func _die_and_cleanup() -> void:
	die(null)

func set_target_position(pos: Vector2) -> void:
	formation_target = pos
	time_since_repath = REPATH_TIME

func _handle_stuck_detection(delta: float) -> void:
	if velocity.length() > 0.1:
		if global_position.distance_to(last_position) < 1.5:
			time_stuck += delta
			if time_stuck > STUCK_TIME:
				var rand_offset: Vector2 = Vector2(randf() * 2 - 1, randf() * 2 - 1).normalized() * RANDOM_OFFSET_RADIUS
				if is_instance_valid(nav):
					nav.set_target_position(global_position + rand_offset)
				time_stuck = 0.0
				time_since_repath = 0.0
		else:
			time_stuck = 0.0
	last_position = global_position

func _update_animation() -> void:
	# Play Walk when moving; flip horizontally so that facing direction matches velocity.x
	if not sprite:
		return
	var frames = null
	if "frames" in sprite:
		frames = sprite.frames

	var moving := velocity.length() > 5.0
	if moving:
		# apply deadzone to avoid jitter
		if abs(velocity.x) > 2.0:
			sprite.flip_h = velocity.x < 0
		if frames and frames.has_animation("Walk"):
			sprite.play("Walk")
		else:
			if sprite.has_method("play"):
				sprite.play("Walk")
	else:
		if frames and frames.has_animation("Idle"):
			sprite.play("Idle")
		else:
			if sprite.has_method("play"):
				sprite.play("Idle")

func _on_navigation_agent_2d_target_reached() -> void:
	velocity = Vector2.ZERO
