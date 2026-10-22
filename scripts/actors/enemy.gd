class_name Enemy
extends CharacterBody3D
## Every enemy is a (former) person: it has a name, a personality and last
## words. Strong ones always leave their soul behind. With `is_phantom` the
## enemy is a hallucination: it looks real but deals no damage and dissolves.

signal killed(enemy: Enemy)

enum State { RISING, CHASE, WINDUP, RECOVER, SLAM, DYING }

const KINDS := {
	"hollow": {"hp": 45.0, "speed": 3.4, "damage": 9.0, "strong": false, "scale": 1.0, "range": 1.7,
		"color": Color(0.42, 0.44, 0.5), "eye": Color(0.4, 0.9, 1.0), "windup": 0.45},
	"wraith": {"hp": 30.0, "speed": 5.3, "damage": 7.0, "strong": false, "scale": 0.9, "range": 1.6,
		"color": Color(0.18, 0.13, 0.26), "eye": Color(0.85, 0.35, 1.0), "windup": 0.35, "float": true},
	"warden": {"hp": 150.0, "speed": 2.8, "damage": 18.0, "strong": true, "scale": 1.35, "range": 2.3,
		"color": Color(0.42, 0.18, 0.15), "eye": Color(1.0, 0.35, 0.1), "windup": 0.6},
	"knight": {"hp": 700.0, "speed": 3.2, "damage": 28.0, "strong": true, "scale": 1.9, "range": 3.0,
		"color": Color(0.2, 0.19, 0.24), "eye": Color(1.0, 0.1, 0.2), "windup": 0.75, "boss": true},
}

var world  # World node
var kind := "hollow"
var spec: Dictionary
var victim: Dictionary = {}
var is_phantom := false
var max_hp := 40.0
var hp := 40.0
var dmg := 8.0
var speed := 3.0
var state := State.RISING
var state_t := 0.0
var knock := Vector3.ZERO
var target = null  # Player or GhostMinion
var slam_cd := 6.0
var phantom_life := 12.0

var visual: Node3D
var arm_l: Node3D
var arm_r: Node3D
var eye_mat: StandardMaterial3D
var name_label: Label3D
var hit_overlay: StandardMaterial3D
var _flash := 0.0
var _bob := 0.0
var _slam_disc: MeshInstance3D


## Call before adding to the tree.
func setup(p_kind: String, wave: int, p_world, phantom := false) -> void:
	kind = p_kind
	world = p_world
	is_phantom = phantom
	spec = KINDS[kind]
	var hp_scale := 1.0 + Cfg.gf("waves.hp_scale_per_wave") * (wave - 1)
	var dmg_scale := 1.0 + Cfg.gf("waves.damage_scale_per_wave") * (wave - 1)
	max_hp = spec.hp * hp_scale
	hp = max_hp
	dmg = spec.damage * dmg_scale
	speed = spec.speed * randf_range(0.9, 1.1)
	victim = Lore.make_victim(kind)


func _ready() -> void:
	if not is_phantom:
		add_to_group("enemies")
	else:
		add_to_group("phantoms")
		add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var s: float = spec.scale
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42 * s
	shape.height = 1.8 * s
	cs.shape = shape
	cs.position.y = 0.9 * s
	add_child(cs)
	_build_visual()
	# Rise out of the grave.
	visual.position.y = -2.0 * s
	state = State.RISING
	state_t = 0.0


func is_strong() -> bool:
	return spec.strong


func is_boss() -> bool:
	return spec.get("boss", false)


func radius() -> float:
	return 0.42 * float(spec.scale)


func display_name() -> String:
	return str(victim.get("name", "?"))


# --------------------------------------------------------------------------
# Visual
# --------------------------------------------------------------------------

func _build_visual() -> void:
	visual = Node3D.new()
	var s: float = spec.scale
	visual.scale = Vector3(s, s, s)
	add_child(visual)
	var body_col: Color = spec.color
	var body := Build.mat(body_col, 0.85)
	var dark := Build.mat(body_col.darkened(0.5), 0.9)
	eye_mat = StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ec: Color = spec.eye
	eye_mat.albedo_color = ec * 3.0
	hit_overlay = StandardMaterial3D.new()
	hit_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hit_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hit_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hit_overlay.albedo_color = Color(1, 1, 1, 0)

	var parts: Array[MeshInstance3D] = []
	match kind:
		"hollow":
			parts.append(Build.part(visual, Build.capsule(0.3, 1.3), body, Vector3(0, 0.95, 0), Vector3(12, 0, 0)))
			parts.append(Build.part(visual, Build.sphere(0.24), dark, Vector3(0, 1.6, -0.12)))
			parts.append(Build.part(visual, Build.cylinder(0.05, 0.3, 0.45, 8), dark, Vector3(0, 1.72, -0.08)))
		"wraith":
			parts.append(Build.part(visual, Build.cylinder(0.18, 0.55, 1.5, 10), Build.soul_mat(body_col.lightened(0.3), Color(0.6, 0.2, 1.0), 1.2, 0.8), Vector3(0, 1.0, 0)))
			parts.append(Build.part(visual, Build.sphere(0.25), dark, Vector3(0, 1.8, 0)))
			parts.append(Build.part(visual, Build.cylinder(0.02, 0.3, 0.5, 8), dark, Vector3(0, 1.95, 0.02)))
		"warden":
			parts.append(Build.part(visual, Build.capsule(0.38, 1.4), body, Vector3(0, 1.0, 0)))
			parts.append(Build.part(visual, Build.box(Vector3(1.1, 0.3, 0.5)), dark, Vector3(0, 1.45, 0)))
			parts.append(Build.part(visual, Build.sphere(0.26), dark, Vector3(0, 1.8, 0)))
			parts.append(Build.part(visual, Build.cylinder(0.0, 0.08, 0.35, 5), dark, Vector3(-0.18, 2.05, 0), Vector3(0, 0, 25)))
			parts.append(Build.part(visual, Build.cylinder(0.0, 0.08, 0.35, 5), dark, Vector3(0.18, 2.05, 0), Vector3(0, 0, -25)))
		"knight":
			parts.append(Build.part(visual, Build.capsule(0.36, 1.3), body, Vector3(0, 1.0, 0)))
			parts.append(Build.part(visual, Build.box(Vector3(0.9, 0.6, 0.45)), Build.mat(Color(0.18, 0.17, 0.2), 0.35, Color.BLACK, 0.0, 0.8), Vector3(0, 1.3, 0)))
			parts.append(Build.part(visual, Build.box(Vector3(0.36, 0.42, 0.38)), Build.mat(Color(0.2, 0.2, 0.22), 0.3, Color.BLACK, 0.0, 0.9), Vector3(0, 1.8, 0)))
			parts.append(Build.part(visual, Build.cylinder(0.0, 0.06, 0.5, 5), dark, Vector3(-0.22, 2.1, 0), Vector3(0, 0, 35)))
			parts.append(Build.part(visual, Build.cylinder(0.0, 0.06, 0.5, 5), dark, Vector3(0.22, 2.1, 0), Vector3(0, 0, -35)))
			# Tattered cape.
			parts.append(Build.part(visual, Build.box(Vector3(0.8, 1.3, 0.04)), Build.mat(Color(0.25, 0.02, 0.05), 1.0), Vector3(0, 0.95, 0.26), Vector3(-8, 0, 0)))
	# Eyes.
	var eye_y := 1.62 if kind == "hollow" else (1.82 if kind != "knight" else 1.82)
	var eye_z := -0.33 if kind == "hollow" else (-0.2 if kind != "knight" else -0.2)
	Build.part(visual, Build.sphere(0.04, 6), eye_mat, Vector3(-0.08, eye_y, eye_z))
	Build.part(visual, Build.sphere(0.04, 6), eye_mat, Vector3(0.08, eye_y, eye_z))
	# Arms on pivots (used for attack animation).
	arm_l = Node3D.new()
	arm_l.position = Vector3(-0.38, 1.4, 0)
	visual.add_child(arm_l)
	arm_r = Node3D.new()
	arm_r.position = Vector3(0.38, 1.4, 0)
	visual.add_child(arm_r)
	parts.append(Build.part(arm_l, Build.capsule(0.08, 0.85), body, Vector3(0, -0.38, 0)))
	parts.append(Build.part(arm_r, Build.capsule(0.08, 0.85), body, Vector3(0, -0.38, 0)))
	match kind:
		"warden":
			parts.append(Build.part(arm_r, Build.box(Vector3(0.22, 0.22, 1.0)), dark, Vector3(0, -0.8, -0.4)))
		"knight":
			var sword := Build.part(arm_r, Build.box(Vector3(0.1, 0.06, 1.8)), Build.mat(Color(0.5, 0.5, 0.55), 0.25, Color(0.8, 0.1, 0.15), 1.5, 0.9), Vector3(0, -0.8, -0.9))
			parts.append(sword)
	for p in parts:
		p.material_overlay = hit_overlay
	if is_strong() or is_boss():
		Build.light(self, ec, 0.8, 4.0, Vector3(0, 1.8 * float(spec.scale), -0.3))
	if spec.get("float", false):
		Build.particles(visual, {
			"amount": 20, "lifetime": 1.0, "velocity": 0.4, "spread": 40.0, "size": 0.35,
			"color": Color(0.6, 0.3, 1.0, 0.5), "radius": 0.3, "position": Vector3(0, 0.3, 0),
			"direction": Vector3.DOWN,
		})
	# Name plate.
	var title := display_name()
	var col := Color(0.85, 0.85, 0.9)
	if is_boss():
		col = Color(1.0, 0.35, 0.35)
	elif is_strong():
		col = Color(1.0, 0.7, 0.45)
	var size := 40 if is_strong() else 28
	name_label = Build.label(self, title, col, size, Vector3(0, 2.25 * float(spec.scale) + 0.2, 0), 26.0 if is_strong() else 14.0)


# --------------------------------------------------------------------------
# AI
# --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	state_t += delta
	_bob += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 6.0)
		hit_overlay.albedo_color = Color(1, 1, 1, _flash * 0.8)
	if is_phantom:
		phantom_life -= delta
		if phantom_life <= 0.0 and state != State.DYING:
			vanish()
	match state:
		State.RISING:
			var s: float = spec.scale
			visual.position.y = lerpf(-2.0 * s, 0.0, clampf(state_t / 1.0, 0.0, 1.0))
			if state_t >= 1.0:
				visual.position.y = 0.0
				_set_state(State.CHASE)
			return
		State.DYING:
			return
	_pick_target()
	var to_target := Vector3.ZERO
	var dist := 999.0
	if target:
		to_target = target.global_position - global_position
		to_target.y = 0.0
		dist = to_target.length()
	var move := Vector3.ZERO
	match state:
		State.CHASE:
			if target:
				move = to_target.normalized() * speed
				var reach: float = float(spec.range) + _target_radius()
				if dist < reach:
					_set_state(State.WINDUP)
				elif is_boss():
					slam_cd -= delta
					if slam_cd <= 0.0 and dist < 7.0:
						_start_slam()
		State.WINDUP:
			var k := clampf(state_t / float(spec.windup), 0.0, 1.0)
			arm_r.rotation.x = lerpf(0.0, 2.6, k)
			arm_l.rotation.x = lerpf(0.0, 1.2, k)
			eye_mat.albedo_color = (spec.eye as Color) * (3.0 + 6.0 * k)
			if target:
				move = to_target.normalized() * speed * 0.15
			if state_t >= float(spec.windup):
				_strike(dist)
				_set_state(State.RECOVER)
		State.RECOVER:
			arm_r.rotation.x = lerpf(arm_r.rotation.x, -0.6, 1.0 - exp(-delta * 18.0))
			arm_l.rotation.x = lerpf(arm_l.rotation.x, 0.0, 1.0 - exp(-delta * 10.0))
			eye_mat.albedo_color = (spec.eye as Color) * 3.0
			if state_t >= 0.6:
				_set_state(State.CHASE)
		State.SLAM:
			_update_slam(delta)
	# Separation from other enemies so they don't stack up.
	var sep := Vector3.ZERO
	for o in world.enemies():
		if o == self:
			continue
		var d: Vector3 = global_position - o.global_position
		d.y = 0.0
		var l := d.length()
		var min_d: float = radius() + o.radius() + 0.3
		if l < min_d and l > 0.001:
			sep += d / l * (min_d - l) * 4.0
	knock = knock.lerp(Vector3.ZERO, 1.0 - exp(-delta * 7.0))
	velocity.x = move.x + sep.x + knock.x
	velocity.z = move.z + sep.z + knock.z
	if spec.get("float", false):
		velocity.y = (0.35 + sin(_bob * 2.0) * 0.15 - global_position.y) * 4.0
		visual.position.y = 0.0
	elif not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	if target and to_target.length() > 0.1 and state != State.SLAM:
		var yaw := atan2(-to_target.x, -to_target.z)
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-delta * 8.0))
	# Idle sway of the arms while walking.
	if state == State.CHASE:
		arm_l.rotation.x = sin(_bob * 6.0) * 0.4
		arm_r.rotation.x = -sin(_bob * 6.0) * 0.4


func _set_state(s: State) -> void:
	state = s
	state_t = 0.0


func _pick_target() -> void:
	var player = world.player
	target = player if player and not player.dead else null
	var best := INF
	if target:
		best = global_position.distance_to(target.global_position)
	# Ghost minions draw aggro when they are closer.
	for m in get_tree().get_nodes_in_group("minions"):
		var d := global_position.distance_to((m as Node3D).global_position)
		if d < best and d < 8.0:
			best = d
			target = m


func _target_radius() -> float:
	if target and target.has_method("radius"):
		return target.radius()
	return 0.4


func _strike(dist: float) -> void:
	if target == null:
		return
	var reach: float = float(spec.range) + _target_radius() + 0.6
	if dist > reach:
		return
	if is_phantom:
		# The hallucination "hits" and dissolves - it was never there.
		if target.has_method("fake_hurt"):
			target.fake_hurt()
		vanish()
		return
	target.take_damage(dmg, global_position)


func _start_slam() -> void:
	slam_cd = randf_range(7.0, 10.0)
	_set_state(State.SLAM)
	_slam_disc = Build.part(world, Build.cylinder(4.5, 4.5, 0.05, 32), _slam_mat(), Vector3.ZERO)
	_slam_disc.global_position = global_position + Vector3(0, 0.06, 0)
	_slam_disc.scale = Vector3(0.05, 1, 0.05)
	if world.hud:
		world.hud.actionbar("%s holt zum Erdstoß aus!" % display_name(), Color(1, 0.4, 0.3))


func _slam_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.1, 0.1, 0.35)
	return m


func _update_slam(_delta: float) -> void:
	var k := clampf(state_t / 1.2, 0.0, 1.0)
	if _slam_disc:
		_slam_disc.scale = Vector3(k, 1, k)
	arm_r.rotation.x = lerpf(0.0, 3.0, k)
	arm_l.rotation.x = lerpf(0.0, 3.0, k)
	if state_t >= 1.2:
		if _slam_disc:
			_slam_disc.queue_free()
			_slam_disc = null
		Build.burst(world, global_position + Vector3(0, 0.3, 0), Color(1.0, 0.3, 0.2), 60, 9.0, 0.5, 0.9)
		Sfx.play_at("hit", global_position, 6.0, 0.0)
		var player = world.player
		if player and not player.dead and player.global_position.distance_to(global_position) < 4.7:
			player.take_damage(dmg * 1.2, global_position)
		if player:
			player.shake = maxf(player.shake, 0.8)
		_set_state(State.RECOVER)


# --------------------------------------------------------------------------
# Damage & death
# --------------------------------------------------------------------------

func take_hit(amount: float, from_pos: Vector3, knockback: float) -> void:
	if state == State.DYING:
		return
	if is_phantom:
		vanish()
		return
	hp -= amount
	_flash = 1.0
	var away := global_position - from_pos
	away.y = 0.0
	if away.length() > 0.01:
		var resist: float = 1.0 / float(spec.scale)
		knock += away.normalized() * knockback * resist
	Sfx.play_at("hit", global_position, 0.0)
	Build.burst(world, global_position + Vector3(0, 1.2 * float(spec.scale), 0), Color(0.6, 0.85, 1.0), 10, 3.0, 0.18, 0.4)
	Build.float_text(world, global_position + Vector3(randf_range(-0.3, 0.3), 2.1 * float(spec.scale), 0), str(int(round(amount))), Color(1.0, 0.95, 0.7), 34, 0.7, 0.8)
	if state == State.RISING:
		return
	if hp <= 0.0:
		_die()


func _die() -> void:
	_set_state(State.DYING)
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 1
	if _slam_disc:
		_slam_disc.queue_free()
	if name_label:
		name_label.queue_free()
	Sfx.play_at("death", global_position, -2.0)
	Build.burst(world, global_position + Vector3(0, 1.0, 0), spec.eye, 36, 4.5, 0.3, 1.0)
	Build.float_text(world, global_position + Vector3(0, 2.4 * float(spec.scale), 0),
		"„%s“" % victim.get("last_words", "…"), Color(0.85, 0.85, 1.0), 30, 3.2, 0.9)
	killed.emit(self)
	var tw := create_tween()
	tw.tween_property(visual, "rotation:x", deg_to_rad(80), 0.6)
	tw.parallel().tween_property(visual, "position:y", -1.0, 1.4).set_delay(0.4)
	tw.tween_callback(queue_free)


## Hallucinations simply fade away with a laugh.
func vanish() -> void:
	if state == State.DYING:
		return
	_set_state(State.DYING)
	remove_from_group("enemies")
	remove_from_group("phantoms")
	collision_layer = 0
	if name_label:
		name_label.queue_free()
	Sfx.play_at("laugh", global_position, -2.0)
	Build.burst(world, global_position + Vector3(0, 1.0, 0), Color(0.5, 0.1, 0.3, 0.7), 30, 2.0, 0.6, 0.9)
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(0.01, 3.0, 0.01), 0.35)
	tw.tween_callback(queue_free)
