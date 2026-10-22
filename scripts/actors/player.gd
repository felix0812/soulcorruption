class_name Player
extends CharacterBody3D
## The soul thief. Third-person controller with melee slash, soul bolt and
## dash. Its stats are modified by upgrades and the corruption stage.

signal died
signal hp_changed(hp: float, max_hp: float)

const GRAVITY := 22.0
const ATTACK_COOLDOWN := 0.42
const ATTACK_RANGE := 2.9
const DASH_TIME := 0.18
const DASH_SPEED := 19.0

var world  # World node (left untyped on purpose: dynamic access to its systems)
var max_hp := 100.0
var hp := 100.0
var dead := false
var controls_enabled := true
var invulnerable := 0.0

var attack_cd := 0.0
var bolt_cd := 0.0
var dash_cd := 0.0
var dash_time := 0.0
var dash_dir := Vector3.ZERO
var swing_t := -1.0
var swing_side := 1.0
var _hit_done := false
var last_hurt_time := -100.0
var shake := 0.0

var cam_yaw := 0.0
var cam_pitch := -0.32
var rig: Node3D
var spring: SpringArm3D
var camera: Camera3D
var visual: Node3D
var blade_pivot: Node3D
var cloak: MeshInstance3D
var aura: GPUParticles3D
var soul_light: OmniLight3D
var rim: ShaderMaterial
var _time := 0.0


func _ready() -> void:
	add_to_group("player")
	add_to_group("settings_listeners")
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.8
	cs.shape = shape
	cs.position.y = 0.9
	add_child(cs)
	_build_visual()
	_build_camera()
	recompute_stats()
	hp = max_hp


func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	rim = Build.rim_mat()
	var cloth := Build.mat(Color(0.07, 0.06, 0.09), 0.9)
	var skin := Build.mat(Color(0.55, 0.5, 0.55), 0.7)
	var metal := Build.mat(Color(0.45, 0.45, 0.5), 0.3, Color.BLACK, 0.0, 0.8)
	cloak = Build.part(visual, Build.cylinder(0.22, 0.5, 1.35, 10), cloth, Vector3(0, 0.75, 0))
	cloak.material_overlay = rim
	var torso := Build.part(visual, Build.capsule(0.27, 0.9), cloth, Vector3(0, 1.2, 0))
	torso.material_overlay = rim
	var head := Build.part(visual, Build.sphere(0.2), skin, Vector3(0, 1.72, 0))
	head.material_overlay = rim
	var hood := Build.part(visual, Build.cylinder(0.05, 0.28, 0.5, 10), cloth, Vector3(0, 1.8, 0.03))
	hood.material_overlay = rim
	# Glowing eyes peek out of the hood.
	var eye := Build.glow_mat(Color(0.5, 0.9, 1.0), 4.0)
	Build.part(visual, Build.sphere(0.035, 6), eye, Vector3(-0.07, 1.74, -0.18))
	Build.part(visual, Build.sphere(0.035, 6), eye, Vector3(0.07, 1.74, -0.18))
	# Soul blade on a pivot at the right shoulder.
	blade_pivot = Node3D.new()
	blade_pivot.position = Vector3(0.35, 1.25, 0)
	visual.add_child(blade_pivot)
	Build.part(blade_pivot, Build.box(Vector3(0.08, 0.08, 0.3)), metal, Vector3(0, 0, -0.1))
	var blade := Build.part(blade_pivot, Build.box(Vector3(0.05, 0.14, 1.25)), Build.soul_mat(Color(0.7, 1.0, 1.0), Color(0.4, 0.3, 1.0), 2.2), Vector3(0, 0, -0.85))
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blade_pivot.rotation = Vector3(-0.3, 0.9, 0)
	soul_light = Build.light(self, Color(0.5, 0.8, 1.0), 0.6, 5.0, Vector3(0, 1.5, 0))
	aura = Build.particles(self, {
		"amount": 40, "lifetime": 1.4, "velocity": 0.8, "spread": 25.0, "size": 0.22,
		"box": Vector3(0.4, 0.8, 0.4), "position": Vector3(0, 0.9, 0),
		"color": Color(0.9, 0.1, 0.3, 0.8), "color_end": Color(0.2, 0.0, 0.1, 0.0),
	})
	aura.amount_ratio = 0.0


func _build_camera() -> void:
	rig = Node3D.new()
	rig.top_level = true
	add_child(rig)
	spring = SpringArm3D.new()
	spring.spring_length = 5.2
	spring.collision_mask = 1
	spring.margin = 0.3
	spring.position = Vector3(0.55, 0, 0)
	rig.add_child(spring)
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	spring.shape = probe
	spring.add_excluded_object(get_rid())
	camera = Camera3D.new()
	camera.fov = Cfg.gf("graphics.fov", 75.0)
	camera.far = 400.0
	spring.add_child(camera)
	camera.current = true


func apply_settings() -> void:
	camera.fov = Cfg.gf("graphics.fov", 75.0)


func recompute_stats() -> void:
	var stage := _stage()
	var new_max := (Cfg.gf("player.max_hp") + 15.0 * Souls.upgrade("vessel")) * Cfg.stage_value("corruption.max_hp_mult", stage)
	var ratio := hp / max_hp if max_hp > 0.0 else 1.0
	max_hp = maxf(10.0, new_max)
	hp = clampf(ratio * max_hp, 0.0, max_hp) if not dead else 0.0
	hp_changed.emit(hp, max_hp)


func _stage() -> int:
	return world.corruption.stage if world and world.corruption else 0


func damage() -> float:
	var d := Cfg.gf("player.damage") * (1.0 + 0.15 * Souls.upgrade("blade"))
	if world and world.corruption:
		d *= world.corruption.damage_mult()
	return d


func move_speed() -> float:
	var s := Cfg.gf("player.move_speed")
	if world and world.corruption:
		s *= world.corruption.speed_mult()
	return s


# --------------------------------------------------------------------------
# Input & update
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if dead or not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := Cfg.gf("controls.mouse_sensitivity", 0.25) * 0.01
		var inv := -1.0 if Cfg.gb("controls.invert_y") else 1.0
		cam_yaw -= event.relative.x * sens
		cam_pitch = clampf(cam_pitch - event.relative.y * sens * inv, -1.25, 0.55)


func _physics_process(delta: float) -> void:
	_time += delta
	attack_cd = maxf(0.0, attack_cd - delta)
	bolt_cd = maxf(0.0, bolt_cd - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	invulnerable = maxf(0.0, invulnerable - delta)

	var input := Vector2.ZERO
	if controls_enabled and not dead:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_just_pressed("attack"):
			_start_attack()
		if Input.is_action_just_pressed("bolt"):
			_fire_bolt()
		if Input.is_action_just_pressed("dash"):
			_dash(input)

	var yaw_basis := Basis(Vector3.UP, cam_yaw)
	var dir := yaw_basis * Vector3(input.x, 0, input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()

	if dash_time > 0.0:
		dash_time -= delta
		velocity.x = dash_dir.x * DASH_SPEED
		velocity.z = dash_dir.z * DASH_SPEED
	else:
		var target := dir * move_speed()
		var accel := 14.0 if is_on_floor() else 5.0
		velocity.x = move_toward(velocity.x, target.x, accel * delta * move_speed())
		velocity.z = move_toward(velocity.z, target.z, accel * delta * move_speed())
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = maxf(velocity.y, -1.0)
	move_and_slide()

	# Body faces the camera direction (makes aiming the bolt easy).
	if not dead:
		visual.rotation.y = lerp_angle(visual.rotation.y, cam_yaw, 1.0 - exp(-delta * 14.0))
		var moving := Vector2(velocity.x, velocity.z).length() > 0.5
		cloak.scale = Vector3(1.0, 1.0 + (sin(_time * 12.0) * 0.03 if moving else 0.0), 1.0)
	_update_swing(delta)
	_update_regen(delta)


func _process(delta: float) -> void:
	# Camera follows smoothly; shake on hits.
	rig.global_position = rig.global_position.lerp(global_position + Vector3(0, 1.65, 0), 1.0 - exp(-delta * 18.0))
	rig.rotation = Vector3(0, cam_yaw, 0)
	spring.rotation = Vector3(cam_pitch, 0, 0)
	shake = maxf(0.0, shake - delta * 2.5)
	camera.h_offset = randf_range(-1.0, 1.0) * shake * 0.25
	camera.v_offset = randf_range(-1.0, 1.0) * shake * 0.25
	# Corruption look: rim glow, red aura, colder light.
	var c: float = world.corruption.visual if world and world.corruption else 0.0
	rim.set_shader_parameter("strength", clampf((c - 0.2) * 1.6, 0.0, 1.6))
	aura.amount_ratio = clampf((c - 0.3) * 1.5, 0.0, 1.0)
	soul_light.light_color = Color(0.5, 0.8, 1.0).lerp(Color(1.0, 0.15, 0.3), c)


func _update_regen(delta: float) -> void:
	if dead:
		return
	if world and world.corruption and world.corruption.soulless():
		var drain := Cfg.gf("zero_souls.debuff_hp_drain_per_sec")
		if hp > max_hp * 0.25:
			hp = maxf(max_hp * 0.25, hp - drain * delta)
			hp_changed.emit(hp, max_hp)
		return
	if _time - last_hurt_time > 4.0 and hp < max_hp:
		hp = minf(max_hp, hp + Cfg.gf("player.regen_per_sec") * delta)
		hp_changed.emit(hp, max_hp)


# --------------------------------------------------------------------------
# Combat
# --------------------------------------------------------------------------

func forward() -> Vector3:
	return Basis(Vector3.UP, cam_yaw) * Vector3.FORWARD


func _start_attack() -> void:
	if attack_cd > 0.0:
		return
	attack_cd = ATTACK_COOLDOWN
	swing_t = 0.0
	swing_side = -swing_side
	_hit_done = false
	Sfx.play("slash", -4.0)


func _update_swing(delta: float) -> void:
	if swing_t < 0.0:
		blade_pivot.rotation = blade_pivot.rotation.lerp(Vector3(-0.3, 0.9, 0), 1.0 - exp(-delta * 10.0))
		return
	swing_t += delta
	var k := clampf(swing_t / 0.2, 0.0, 1.0)
	var ease_k := 1.0 - pow(1.0 - k, 3.0)
	blade_pivot.rotation = Vector3(-0.2, lerpf(1.5, -1.5, ease_k) * swing_side, 0.4 * swing_side)
	if not _hit_done and swing_t >= 0.08:
		_hit_done = true
		_resolve_melee()
	if swing_t > 0.32:
		swing_t = -1.0


func _resolve_melee() -> void:
	var fwd := forward()
	var hit_any := false
	for e in world.enemies():
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var reach: float = ATTACK_RANGE + e.radius()
		if to.length() > reach:
			continue
		if to.length() > 0.8 and fwd.dot(to.normalized()) < 0.25:
			continue
		e.take_hit(damage(), global_position, 6.0)
		hit_any = true
		_lifesteal(damage())
	if hit_any:
		shake = maxf(shake, 0.35)


func _lifesteal(amount: float) -> void:
	if world == null or world.corruption == null:
		return
	var ls: float = Cfg.stage_value("corruption.lifesteal", world.corruption.stage, 0.0)
	if ls > 0.0 and not dead:
		hp = minf(max_hp, hp + amount * ls)
		hp_changed.emit(hp, max_hp)


func on_bolt_hit(amount: float) -> void:
	_lifesteal(amount)


func _fire_bolt() -> void:
	if bolt_cd > 0.0:
		return
	bolt_cd = Cfg.gf("player.bolt_cooldown_sec") * pow(0.92, Souls.upgrade("bolt"))
	var origin := global_position + Vector3(0, 1.4, 0) + forward() * 0.6
	# Aim at whatever is under the crosshair.
	var vp := get_viewport()
	var center := vp.get_visible_rect().size * 0.5
	var ray_from := camera.project_ray_origin(center)
	var ray_dir := camera.project_ray_normal(center)
	var q := PhysicsRayQueryParameters3D.create(ray_from, ray_from + ray_dir * 80.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var target: Vector3 = hit.position if hit else ray_from + ray_dir * 80.0
	var dir := (target - origin).normalized()
	var bolt := SoulBolt.new()
	bolt.direction = dir
	bolt.damage = damage() * 0.85 * (1.0 + 0.25 * Souls.upgrade("bolt"))
	bolt.shooter = self
	world.add_child(bolt)
	bolt.global_position = origin
	Sfx.play("bolt", -6.0)


func _dash(input: Vector2) -> void:
	if dash_cd > 0.0:
		return
	dash_cd = Cfg.gf("player.dash_cooldown_sec") * pow(0.88, Souls.upgrade("shadowstep"))
	var dir := Basis(Vector3.UP, cam_yaw) * Vector3(input.x, 0, input.y)
	if dir.length() < 0.1:
		dir = forward()
	dash_dir = dir.normalized()
	dash_time = DASH_TIME
	invulnerable = maxf(invulnerable, 0.28)
	Sfx.play("dash", -6.0)
	Build.burst(world, global_position + Vector3(0, 1, 0), Color(0.5, 0.4, 1.0, 0.8), 18, 2.0, 0.4, 0.5)


func take_damage(amount: float, from_pos: Vector3) -> void:
	if dead or invulnerable > 0.0:
		return
	hp -= amount
	last_hurt_time = _time
	invulnerable = 0.35
	shake = maxf(shake, 0.6)
	var push := global_position - from_pos
	push.y = 0.0
	if push.length() > 0.01:
		velocity += push.normalized() * 5.0
	Sfx.play("hurt", -3.0)
	if world and world.hud:
		world.hud.flash_damage(clampf(amount / 30.0, 0.3, 1.0))
	hp_changed.emit(maxf(hp, 0.0), max_hp)
	if hp <= 0.0:
		_die()


## Fake damage for hallucinations: looks and sounds real, costs nothing.
func fake_hurt() -> void:
	shake = maxf(shake, 0.5)
	Sfx.play("hurt", -5.0)
	if world and world.hud:
		world.hud.flash_damage(0.6)


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)


func _die() -> void:
	dead = true
	hp = 0.0
	velocity = Vector3.ZERO
	Sfx.play("death", -2.0)
	var tw := create_tween()
	tw.tween_property(visual, "rotation:x", -PI / 2.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(visual, "position:y", 0.3, 0.6)
	died.emit()


func respawn(pos: Vector3) -> void:
	dead = false
	global_position = pos
	velocity = Vector3.ZERO
	visual.rotation = Vector3(0, cam_yaw, 0)
	visual.position = Vector3.ZERO
	recompute_stats()
	hp = max_hp
	invulnerable = 2.5
	hp_changed.emit(hp, max_hp)
	Build.burst(world, pos + Vector3(0, 1, 0), Color(0.6, 0.9, 1.0), 40, 5.0, 0.35, 1.0)


func radius() -> float:
	return 0.42


## Small hallucination teleport; only moves if the path is free.
func glitch_teleport(distance: float) -> bool:
	var space := get_world_3d().direct_space_state
	for i in 8:
		var a := randf() * TAU
		var offset := Vector3(cos(a), 0, sin(a)) * randf_range(distance * 0.5, distance)
		var dest := global_position + offset
		if Vector2(dest.x, dest.z).length() > Arena.RADIUS - 2.0:
			continue
		var from := global_position + Vector3(0, 1.0, 0)
		var q := PhysicsRayQueryParameters3D.create(from, dest + Vector3(0, 1.0, 0), 1)
		if space.intersect_ray(q).is_empty():
			global_position = dest
			velocity = Vector3.ZERO
			return true
	return false
