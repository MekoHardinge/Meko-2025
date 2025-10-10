extends Node2D

@export var formation_id: String = "EnemyFormation"

# Base spacing (per-soldier unit). Multiply this by state-specific multipliers below.
@export var spacing: float = 40.0

# Decision / behavior tuning
@export var decision_interval: float = 3.0
@export var engagement_distance: float = 250.0
@export var flank_distance: float = 150.0
@export var retreat_ratio: float = 0.75

# Spacing multipliers for each state (tweakable in inspector)
@export var hold_spacing_mul: float = 0.9
@export var advance_spacing_mul: float = 1.4
@export var flank_spacing_mul: float = 1.6
@export var retreat_spacing_mul: float = 2.0

# Smoothing for spacing changes (higher = faster)
@export var spacing_lerp_speed: float = 6.0

# Debugging
@export var debug: bool = true
@export var debug_summary_interval: float = 10.0

# Selection manager expects this
var selected: bool = false

# Internal state
var knights: Array[CharacterBody2D] = []
var target_formation: Node = null
var _decision_timer: float = 0.0
var state: String = "HOLD"
var prev_state: String = ""
var target_position: Vector2 = Vector2.ZERO

# Spacing smoothing
var current_spacing: float
var _summary_timer: float = 0.0

const MAX_TARGET_DISTANCE: float = 10000.0

func _ready() -> void:
	add_to_group("unit_controller")
	for child in get_children():
		if child is CharacterBody2D:
			knights.append(child)
	current_spacing = spacing * hold_spacing_mul
	if debug:
		print("[AI][", formation_id, "] ready — knights:", knights.size(), " base_spacing:", spacing)

func _process(delta: float) -> void:
	_decision_timer += delta
	_summary_timer += delta

	# smooth spacing toward target each frame
	var target_spacing: float = _get_spacing_for_state(state)
	current_spacing = lerp(current_spacing, target_spacing, clamp(spacing_lerp_speed * delta, 0.0, 1.0))

	if _decision_timer >= decision_interval:
		_decision_timer = 0.0
		_ai_decide_action()

	# occasional high-level summary (non-spam)
	if debug and _summary_timer >= debug_summary_interval:
		_summary_timer = 0.0
		_debug_summary()

	_move_knights_to_target()

# Choose multiplier based on current state
func _get_spacing_for_state(s: String) -> float:
	if s == "ADVANCE":
		return spacing * advance_spacing_mul
	if s == "FLANK":
		return spacing * flank_spacing_mul
	if s == "RETREAT":
		return spacing * retreat_spacing_mul
	# HOLD or default
	return spacing * hold_spacing_mul

# compute formation center from knights (global positions)
func _compute_formation_center() -> Vector2:
	var c: Vector2 = Vector2.ZERO
	var cnt: int = knights.size()
	if cnt == 0:
		return global_position
	for k in knights:
		c += k.global_position
	return c / float(max(1, cnt))

func _ai_decide_action() -> void:
	# gather candidate player formations with valid data
	var player_formations: Array = []
	for ctrl in get_tree().get_nodes_in_group("unit_controller"):
		if ctrl == self:
			continue
		if "is_player" in ctrl and ctrl.is_player:
			if "unit_count" in ctrl and int(ctrl.unit_count) > 0 and "average_position" in ctrl:
				player_formations.append(ctrl)
		elif "average_position" in ctrl and "unit_count" in ctrl and int(ctrl.unit_count) > 0:
			player_formations.append(ctrl)

	if player_formations.size() == 0:
		_set_state("HOLD")
		target_position = _compute_formation_center()
		if debug:
			print("[AI][", formation_id, "] no player formations -> HOLD | center:", _vecp(target_position))
		return

	# find closest player formation (by average_position)
	var closest: Node = null
	var closest_dist: float = INF
	var my_center: Vector2 = _compute_formation_center()
	for f in player_formations:
		if not ("average_position" in f):
			continue
		var d: float = my_center.distance_to(f.average_position)
		if d < closest_dist:
			closest = f
			closest_dist = d

	if closest == null:
		_set_state("HOLD")
		target_position = my_center
		if debug:
			print("[AI][", formation_id, "] closest invalid -> HOLD")
		return

	target_formation = closest

	# safe reads
	var enemy_count: int = 0
	if "unit_count" in target_formation:
		enemy_count = int(target_formation.unit_count)
	var own_count: int = knights.size()
	var in_combat: bool = false
	if "is_engaged" in target_formation:
		in_combat = bool(target_formation.is_engaged)

	var player_center: Vector2 = target_formation.average_position

	# guard invalid player_center
	if not _is_valid_point(player_center):
		_set_state("HOLD")
		target_position = my_center
		if debug:
			print("[AI][", formation_id, "] invalid player_center -> HOLD")
		return

	# Decision rules
	if own_count < enemy_count * retreat_ratio:
		_set_state("RETREAT")
		var away_dir: Vector2 = (my_center - player_center).normalized()
		if away_dir.length() < 0.001:
			away_dir = Vector2(1, 0)
		target_position = my_center + away_dir * 200.0
		_safe_finalize_target_and_print("RETREAT", player_center, closest_dist, own_count, enemy_count, in_combat, my_center, target_position)
		return

	if in_combat and own_count >= enemy_count * 0.9:
		_set_state("FLANK")
		var dir: Vector2 = (player_center - my_center).normalized()
		if dir.length() < 0.001:
			dir = Vector2(1, 0)
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		if randi() % 2 == 0:
			perp *= -1
		# increase flank distance slightly based on unit count (bigger groups → wider flank)
		var dynamic_flank: float = flank_distance + clamp(float(own_count - 4) * 6.0, 0.0, 200.0)
		target_position = player_center + perp * dynamic_flank
		_safe_finalize_target_and_print("FLANK", player_center, closest_dist, own_count, enemy_count, in_combat, my_center, target_position)
		return

	if closest_dist > engagement_distance:
		_set_state("ADVANCE")
		# advance directly to player center (fine for now)
		target_position = player_center
		_safe_finalize_target_and_print("ADVANCE", player_center, closest_dist, own_count, enemy_count, in_combat, my_center, target_position)
		return

	_set_state("HOLD")
	target_position = my_center
	_safe_finalize_target_and_print("HOLD", player_center, closest_dist, own_count, enemy_count, in_combat, my_center, target_position)

# ensure target sane, clamp if needed, and print one compact line
func _safe_finalize_target_and_print(decision: String, player_center: Vector2, dist: float, own_count: int, enemy_count: int, in_combat: bool, my_center: Vector2, tgt: Vector2) -> void:
	if not _is_valid_point(tgt):
		target_position = my_center
		if debug:
			print("[AI][", formation_id, "] invalid target -> fallback center", " center:", _vecp(my_center))
		return
	if my_center.distance_to(tgt) > MAX_TARGET_DISTANCE:
		var dir: Vector2 = (tgt - my_center).normalized()
		target_position = my_center + dir * MAX_TARGET_DISTANCE
	else:
		target_position = tgt

	if debug:
		_print_decision_compact(decision, player_center, dist, own_count, enemy_count, in_combat, my_center, target_position)

# compact decision print including spacing info
func _print_decision_compact(decision: String, player_center: Vector2, dist: float, own_count: int, enemy_count: int, in_combat: bool, my_center: Vector2, tgt: Vector2) -> void:
	prev_state = state
	var pid: String = "unknown"
	if target_formation != null and "formation_id" in target_formation:
		pid = str(target_formation.formation_id)
	var s: String = "[AI][" + formation_id + "] " + decision
	s += " | player=" + pid + " dist=" + str(int(round(dist)))
	s += " | own=" + str(own_count) + " enemy=" + str(enemy_count)
	s += " | in_combat=" + str(in_combat)
	s += " | spacing=" + str(_round1(current_spacing))
	s += " | my_center=" + _vecp(my_center)
	s += " | player_center=" + _vecp(player_center)
	s += " | tgt=" + _vecp(tgt)
	print(s)
	# sample knight positions (up to 3) to check nav snapping
	var sample_n: int = min(3, knights.size())
	for i in range(sample_n):
		var kp: Vector2 = knights[i].global_position
		print("[AI][" + formation_id + "] knight[" + str(i) + "] pos=" + _vecp(kp) + " -> assigned_preview_index=" + str(i))

func _move_knights_to_target() -> void:
	if knights.size() == 0:
		return

	var cnt: int = knights.size()
	# compute formation rectangle using current_spacing (smoothed)
	var spacing_used: float = max(1.0, current_spacing)
	var formation_width: float = max(spacing_used, spacing_used * sqrt(cnt))
	var formation_height: float = max(spacing_used, spacing_used * ceil(cnt / float(max(1, int(sqrt(max(1, cnt)))))))
	var formation_rect: Rect2 = Rect2(
		target_position - Vector2(formation_width/2.0, formation_height/2.0),
		Vector2(formation_width, formation_height)
	)

	var grid: Vector2i = get_grid_by_rect(cnt, formation_rect.size)
	var cols: int = grid.x
	var rows: int = grid.y
	var cell_w: float = formation_rect.size.x / float(max(1, cols))
	var cell_h: float = formation_rect.size.y / float(max(1, rows))

	var i: int = 0
	for row in range(rows):
		var units_this_row: int = min(cols, cnt - i)
		var row_width: float = units_this_row * cell_w
		var start_x: float = formation_rect.position.x + (formation_rect.size.x - row_width) * 0.5
		for col in range(units_this_row):
			var pos: Vector2 = Vector2(
				start_x + col * cell_w + cell_w * 0.5,
				formation_rect.position.y + row * cell_h + cell_h * 0.5
			)
			knights[i].set_target_position(pos)
			i += 1

func _debug_summary() -> void:
	if not debug:
		return
	var pf: String = "none"
	if target_formation != null and "formation_id" in target_formation:
		pf = str(target_formation.formation_id)
	print("[AI][" + formation_id + "] SUMMARY | state=" + state + " knights=" + str(knights.size()) + " spacing=" + str(_round1(current_spacing)) + " target_form=" + pf + " target_pos=" + _vecp(target_position))
	var nearby: int = 0
	for ctrl in get_tree().get_nodes_in_group("unit_controller"):
		if ctrl == self:
			continue
		if "average_position" in ctrl and "unit_count" in ctrl and int(ctrl.unit_count) > 0:
			nearby += 1
	print("[AI][" + formation_id + "] nearby_player_formations=" + str(nearby))

# helpers
func _is_valid_point(p: Vector2) -> bool:
	if p == null:
		return false
	if p.x != p.x or p.y != p.y:
		return false
	if p.length() > 1e8:
		return false
	return true

func _vecp(p: Vector2) -> String:
	return "(" + str(int(round(p.x))) + "," + str(int(round(p.y))) + ")"

func _round1(v: float) -> float:
	return floor(v * 10.0 + 0.5) / 10.0

func _set_state(new_state: String) -> void:
	if state != new_state:
		if debug:
			print("[AI][" + formation_id + "] STATE: " + state + " -> " + new_state)
	prev_state = state
	state = new_state

# get_grid_by_rect (unchanged algorithm from your code)
func get_grid_by_rect(unit_count: int, size: Vector2) -> Vector2i:
	if size == Vector2.ZERO or unit_count == 0:
		return Vector2i(1, unit_count)
	var best_cols: int = 1
	var best_rows: int = unit_count
	var best_error: float = INF
	for cols in range(1, unit_count + 1):
		var rows: int = int(ceil(unit_count / float(cols)))
		var grid_ratio: float = float(cols) / float(rows)
		var aspect_ratio: float = size.x / size.y
		var error: float = abs(grid_ratio - aspect_ratio)
		var balance_penalty: int = abs((cols * rows) - unit_count)
		var total_error: float = error + float(balance_penalty) * 1.0
		if total_error < best_error:
			best_error = total_error
			best_cols = cols
			best_rows = rows
	return Vector2i(best_cols, best_rows)
