class_name Enemy
extends CharacterBody3D
## Every enemy is a (former) person: it has a name, a personality and last
## words. Strong ones always leave their soul behind. With `is_phantom` the
## enemy is a hallucination: it looks real but deals no damage and dissolves.
##
## Visuals are animated KayKit skeletons that claw their way out of the
## graves, walk, strike, flinch and collapse into a pile of physical bones.

signal killed(enemy: Enemy)

enum State { RISING, CHASE, WINDUP, RECOVER, SLAM, DYING }

const KINDS := {
	"hollow": {"hp": 45.0, "speed": 2.6, "damage": 9.0, "strong": false, "scale": 0.8, "range": 1.6,
		"model": "Skeleton_Minion.glb", "eye": Color(0.4, 0.9, 1.0), "windup": 0.55,
		"walk": "Walking_D_Skeletons", "walk_speed": 1.6, "attacks": ["Unarmed_Melee_Attack_Punch_A", "1H_Melee_Attack_Chop"]},
	"wraith": {"hp": 30.0, "speed": 5.0, "damage": 7.0, "strong": false, "scale": 0.8, "range": 1.6,
		"model": "Skeleton_Rogue.glb", "eye": Color(0.85, 0.35, 1.0), "windup": 0.4,
		"walk": "Running_C", "walk_speed": 1.0, "attacks": ["1H_Melee_Attack_Stab", "1H_Melee_Attack_Slice_Diagonal"],
		"weapon": "Skeleton_Blade.gltf"},
	"warden": {"hp": 150.0, "speed": 2.6, "damage": 18.0, "strong": true, "scale": 1.05, "range": 2.0,
		"model": "Skeleton_Warrior.glb", "eye": Color(1.0, 0.35, 0.1), "windup": 0.65,
		"walk": "Walking_B", "walk_speed": 1.1, "attacks": ["1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Horizontal"],
		"weapon": "Skeleton_Axe.gltf", "offhand": "Skeleton_Shield_Large_A.gltf"},
	"knight": {"hp": 700.0, "speed": 3.0, "damage": 28.0, "strong": true, "scale": 1.7, "range": 2.8,
		"model": "Skeleton_Warrior.glb", "eye": Color(1.0, 0.1, 0.2), "windup": 0.8,
		"walk": "Walking_A", "walk_speed": 1.0, "attacks": ["1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Chop"],
		"weapon": "Skeleton_Blade.gltf", "offhand": "Skeleton_Shield_Large_A.gltf", "boss": true},
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
var body: CharacterModel
var name_label: Label3D
var hit_overlay: StandardMaterial3D
var eye_light: OmniLight3D
var _flash := 0.0
var _rise_time := 1.2
var _last_hit_dir := Vector3.FORWARD
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
	add_to_group("enemies")
	if is_phantom:
		add_to_group("phantoms")
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | Props.LAYER
	var s: float = spec.scale
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45 * s
	shape.height = 2.0 * s
	cs.shape = shape
	cs.position.y = 1.0 * s
	add_child(cs)
	_build_visual()
	state = State.RISING
	state_t = 0.0
	if body.has("Spawn_Ground_Skeletons"):
		var a := body.anim.get_animation("Spawn_Ground_Skeletons")
		_rise_time = a.length / 1.3
		body.once("Spawn_Ground_Skeletons", 1.3, 0.0)
	body.loop(spec.walk, spec.walk_speed)
	Build.burst(world, global_position + Vector3(0, 0.2, 0), Color(0.35, 0.28, 0.22, 0.9), 26, 2.5, 0.45, 0.9)


func is_strong() -> bool:
	return spec.strong


func is_boss() -> bool:
	return spec.get("boss", false)


func radius() -> float:
	return 0.45 * float(spec.scale)


func display_name() -> String:
	return str(victim.get("name", "?"))


# --------------------------------------------------------------------------
# Visual
# --------------------------------------------------------------------------

func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	body = CharacterModel.new()
	visual.add_child(body)
	body.setup(spec.model, float(spec.scale))
	if spec.has("weapon"):
		body.attach(spec.weapon, "handslot.r")
	if spec.has("offhand"):
		body.attach(spec.offhand, "handslot.l")
	hit_overlay = StandardMaterial3D.new()
	hit_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hit_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hit_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hit_overlay.albedo_color = Color(1, 1, 1, 0)
	body.set_overlay(hit_overlay)
	var ec: Color = spec.eye
	var s: float = spec.scale
	eye_light = Build.light(self, ec, 0.9 if is_strong() else 0.5, 3.5 * s, Vector3(0, 1.8 * s, -0.4 * s))
	if kind == "wraith":
		# Spectral trail behind the fast ones.
		Build.particles(visual, {
			"amount": 20, "lifetime": 0.8, "velocity": 0.3, "spread": 60.0, "size": 0.45,
			"color": Color(0.6, 0.3, 1.0, 0.35), "radius": 0.35, "position": Vector3(0, 0.9, 0.2),
		})
	if is_boss():
		Build.particles(visual, {
			"amount": 30, "lifetime": 1.4, "velocity": 0.8, "spread": 30.0, "size": 0.5,
			"box": Vector3(0.6, 0.2, 0.6), "color": Color(1.0, 0.15, 0.1, 0.5),
			"color_end": Color(0.2, 0.0, 0.0, 0.0), "gravity": Vector3(0, 1.2, 0),
		})
	# Name plate.
	var col := Color(0.85, 0.85, 0.9)
	if is_boss():
		col = Color(1.0, 0.35, 0.35)
	elif is_strong():
		col = Color(1.0, 0.7, 0.45)
	var size := 40 if is_strong() else 28
	name_label = Build.label(self, display_name(), col, size, Vector3(0, 2.15 * s + 0.25, 0), 26.0 if is_strong() else 14.0)


# --------------------------------------------------------------------------
# AI
# --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	state_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 6.0)
		hit_overlay.albedo_color = Color(1, 1, 1, _flash * 0.7)
	if is_phantom:
		phantom_life -= delta
		if phantom_life <= 0.0 and state != State.DYING:
			vanish()
	match state:
		State.RISING:
			_gravity_only(delta)
			if state_t >= _rise_time:
				_set_state(State.CHASE)
			return
		State.DYING:
			_gravity_only(delta)
			return
	_pick_target()
	var to_target := Vector3.ZERO
	var dist := 999.0
	if target:
		to_target = target.global_position - global_position
		to_target.y = 0.0
		dist = to_target.length()
		if Arena.in_safe_zone(target.global_position):
			# The prey hides at the altar: prowl along the edge, never strike.
			to_target = _edge_point(target.global_position) - global_position
			to_target.y = 0.0
			dist = 999.0
	var move := Vector3.ZERO
	match state:
		State.CHASE:
			if target:
				move = to_target.normalized() * speed
				body.loop(spec.walk, spec.walk_speed)
				var reach: float = float(spec.range) + _target_radius()
				if dist < reach:
					_start_windup()
				elif is_boss():
					slam_cd -= delta
					if slam_cd <= 0.0 and dist < 7.0:
						_start_slam()
			else:
				body.loop("Idle")
		State.WINDUP:
			var k := clampf(state_t / float(spec.windup), 0.0, 1.0)
			eye_light.light_energy = 0.6 + 2.5 * k
			if target:
				move = to_target.normalized() * speed * 0.1
			if state_t >= float(spec.windup):
				_strike(dist)
				_set_state(State.RECOVER)
		State.RECOVER:
			eye_light.light_energy = 0.9 if is_strong() else 0.5
			if state_t >= 0.55:
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
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	_keep_out_of_safe_zone()
	Props.push_from_slides(self, 1.5 * float(spec.scale))
	if target and to_target.length() > 0.1 and state != State.SLAM:
		var yaw := atan2(-to_target.x, -to_target.z)
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-delta * 8.0))


## Closest point just outside the safe zone towards `p`.
func _edge_point(p: Vector3) -> Vector3:
	var d := p - Arena.ALTAR_POS
	d.y = 0.0
	if d.length() < 0.01:
		d = global_position - Arena.ALTAR_POS
		d.y = 0.0
	return Arena.ALTAR_POS + d.normalized() * (Arena.safe_radius() + radius() + 0.3)


## The altar's ward is a wall for the dead.
func _keep_out_of_safe_zone() -> void:
	var d := global_position - Arena.ALTAR_POS
	d.y = 0.0
	var min_r := Arena.safe_radius() + radius()
	if d.length() < min_r:
		if d.length() < 0.01:
			d = Vector3.FORWARD
		var p := Arena.ALTAR_POS + d.normalized() * min_r
		global_position = Vector3(p.x, global_position.y, p.z)
		knock = Vector3.ZERO


func _gravity_only(delta: float) -> void:
	velocity.x = knock.x
	velocity.z = knock.z
	knock = knock.lerp(Vector3.ZERO, 1.0 - exp(-delta * 7.0))
	velocity.y = velocity.y - 22.0 * delta if not is_on_floor() else -0.5
	move_and_slide()
	if state != State.DYING:
		_keep_out_of_safe_zone()


func _set_state(s: State) -> void:
	state = s
	state_t = 0.0


func _start_windup() -> void:
	_set_state(State.WINDUP)
	# Time the attack animation so its hit frame lands at the end of the windup.
	var attack: String = (spec.attacks as Array).pick_random()
	var anim_speed := 1.0
	if body.has(attack):
		anim_speed = clampf(body.anim.get_animation(attack).length * 0.45 / float(spec.windup), 0.6, 2.5)
	body.once(attack, anim_speed)


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
	body.once("1H_Melee_Attack_Jump_Chop", 0.9)
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
	if state_t >= 1.2:
		if _slam_disc:
			_slam_disc.queue_free()
			_slam_disc = null
		Build.burst(world, global_position + Vector3(0, 0.3, 0), Color(1.0, 0.3, 0.2), 60, 9.0, 0.5, 0.9)
		Sfx.play_at("hit", global_position, 6.0, 0.0)
		Props.blast(get_tree(), global_position, 7.0, 9.0)
		var player = world.player
		if player and not player.dead and player.global_position.distance_to(global_position) < 4.7 and not Arena.in_safe_zone(player.global_position):
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
		_last_hit_dir = away.normalized()
		var resist: float = 1.0 / float(spec.scale)
		knock += _last_hit_dir * knockback * resist
	Sfx.play_at("hit", global_position, 0.0)
	Build.burst(world, global_position + Vector3(0, 1.2 * float(spec.scale), 0), Color(0.9, 0.9, 0.8), 10, 3.0, 0.18, 0.4)
	Build.float_text(world, global_position + Vector3(randf_range(-0.3, 0.3), 2.1 * float(spec.scale), 0), str(int(round(amount))), Color(1.0, 0.95, 0.7), 34, 0.7, 0.8)
	if state == State.RISING:
		if hp <= 0.0:
			_die()
		return
	if hp <= 0.0:
		_die()
	elif state == State.CHASE and not is_boss():
		body.once("Hit_A" if randf() < 0.5 else "Hit_B", 1.6)


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
	# The skeleton collapses and its skull and bones fly off with physics.
	body.final("Death_C_Skeletons" if body.has("Death_C_Skeletons") else "Death_A")
	Props.bone_burst(world, global_position, _last_hit_dir, float(spec.scale), 6 if is_strong() else 4)
	Props.blast(get_tree(), global_position, 3.0, 3.0)
	var tw := create_tween()
	tw.tween_property(eye_light, "light_energy", 0.0, 0.8)
	tw.tween_interval(2.5)
	tw.tween_property(visual, "position:y", -1.6 * float(spec.scale), 1.5)
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
	body.once("Taunt", 2.0)
	Build.burst(world, global_position + Vector3(0, 1.0, 0), Color(0.5, 0.1, 0.3, 0.7), 30, 2.0, 0.6, 0.9)
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(visual, "scale", Vector3(0.01, 3.0, 0.01), 0.35)
	tw.tween_callback(queue_free)
