class_name Arena
extends Node3D
## The cursed graveyard: lighting, sky, fog, ground, the soul altar with its
## safe zone, the spawn graves, static scenery (KayKit Halloween models) and
## loose physics props that can be kicked around.

const RADIUS := 36.0
const ALTAR_POS := Vector3(0, 0, 0)
const WARM := Color(1.0, 0.62, 0.3)
const SAFE_COLOR := Color(0.35, 0.9, 1.0)

var env: Environment
var moon: DirectionalLight3D
var spawn_points: Array[Vector3] = []
var altar_light: OmniLight3D
var altar_ring: MeshInstance3D
var altar_crystal: MeshInstance3D
var safe_ring: MeshInstance3D
var spawn_glows: Array[OmniLight3D] = []
var _base_fog := Color(0.2, 0.16, 0.28)
var _base_ambient := Color(0.5, 0.48, 0.65)
var _event_fog := 0.0
var _event_tint := Color(0, 0, 0, 0)
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _flames: Array[OmniLight3D] = []
## Static scenery is collected per model and drawn as one MultiMesh each
## (a few dozen draw calls instead of well over a thousand).
var _batches: Dictionary = {}
var _rock_xforms: Array[Transform3D] = []
const NO_SHADOW := ["path_A", "path_B", "floor_dirt_grave", "candle_triple", "shrine_candles", "fence_pillar", "fence_pillar_broken"]


## Radius of the safe zone around the altar (the shop area). Nothing can
## hurt the player in here and enemies cannot enter.
static func safe_radius() -> float:
	return Cfg.gf("shop.safe_zone_radius", 6.5)


static func in_safe_zone(p: Vector3) -> bool:
	return Vector2(p.x - ALTAR_POS.x, p.z - ALTAR_POS.z).length() < safe_radius()


func _ready() -> void:
	add_to_group("settings_listeners")
	_rng.seed = 1337  # Same layout every time.
	_build_environment()
	_build_ground()
	_build_boundary()
	_build_altar()
	_build_spawns()
	_build_scenery()
	_build_physics_props()
	_build_mist()
	_flush_batches()


func _process(delta: float) -> void:
	_t += delta
	if altar_crystal:
		altar_crystal.rotation.y += delta * 0.8
		altar_crystal.position.y = 3.1 + sin(_t * 1.5) * 0.15
	if altar_ring:
		altar_ring.rotation.y -= delta * 0.3
	if safe_ring:
		safe_ring.rotation.y += delta * 0.1
	# Candle/lantern flicker.
	for i in _flames.size():
		var l := _flames[i]
		l.light_energy = float(l.get_meta("base", 1.0)) * (0.88 + 0.12 * sin(_t * 9.0 + i * 1.7) * sin(_t * 5.3 + i))


# --------------------------------------------------------------------------
# Light & atmosphere
# --------------------------------------------------------------------------

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.08, 0.06, 0.18)
	sky_mat.sky_horizon_color = Color(0.4, 0.28, 0.48)
	sky_mat.ground_horizon_color = Color(0.22, 0.17, 0.26)
	sky_mat.ground_bottom_color = Color(0.05, 0.04, 0.06)
	sky_mat.sun_angle_max = 8.0
	sky_mat.sun_curve = 0.05
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _base_ambient
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_intensity = 0.8
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_light_color = _base_fog
	env.fog_density = 0.011
	env.fog_sky_affect = 0.5
	env.volumetric_fog_density = 0.015
	env.volumetric_fog_albedo = Color(0.6, 0.55, 0.7)
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.75, 0.78, 1.0)
	moon.light_energy = 1.25
	moon.rotation_degrees = Vector3(-42, 35, 0)
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = 40.0
	add_child(moon)
	apply_settings()

	# A big pale moon far away (pure decoration).
	var moon_disc := Build.part(self, Build.sphere(14.0, 24), Build.glow_mat(Color(0.8, 0.85, 1.0), 1.6), Vector3(-160, 120, -230))
	moon_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Called by the settings menu (and once at start).
func apply_settings() -> void:
	env.glow_enabled = Cfg.gb("graphics.glow", true)
	env.fog_enabled = Cfg.gb("graphics.fog", true)
	env.volumetric_fog_enabled = Cfg.gb("graphics.volumetric_fog", false)
	env.tonemap_exposure = 1.1 * clampf(Cfg.gf("graphics.brightness", 1.0), 0.3, 3.0)
	moon.shadow_enabled = Cfg.gb("graphics.shadows", true)


## Tints the fog with the corruption (called every frame by the corruption system).
func set_corruption_tint(amount: float) -> void:
	if env == null:
		return
	var a := clampf(amount, 0.0, 1.0)
	env.fog_light_color = _base_fog.lerp(Color(0.35, 0.05, 0.12), a).lerp(Color(_event_tint, 1.0), _event_tint.a)
	env.fog_density = 0.011 + 0.016 * a + _event_fog
	env.adjustment_saturation = 1.0 - 0.3 * a
	env.ambient_light_color = _base_ambient.lerp(Color(0.6, 0.35, 0.45), a)


func _flame_light(parent: Node3D, pos: Vector3, energy := 1.6, range_m := 9.0, color := WARM) -> OmniLight3D:
	var l := Build.light(parent, color, energy, range_m, pos)
	l.set_meta("base", energy)
	_flames.append(l)
	return l


# --------------------------------------------------------------------------
# Ground & helpers
# --------------------------------------------------------------------------

func _build_ground() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.02
	noise.fractal_octaves = 5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.17, 0.18, 0.15))
	ramp.set_color(1, Color(0.36, 0.33, 0.28))
	ramp.add_point(0.5, Color(0.24, 0.28, 0.19))
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.color_ramp = ramp
	var gmat := StandardMaterial3D.new()
	gmat.albedo_texture = tex
	gmat.roughness = 0.95
	gmat.uv1_scale = Vector3(14, 14, 14)
	var plane := PlaneMesh.new()
	plane.size = Vector2(240, 240)
	Build.part(self, plane, gmat)

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(cs)
	add_child(floor_body)

	# Stone path rings: the inner one marks the edge of the safe zone.
	for ring in [safe_radius() + 0.7, 14.0]:
		var count := int(TAU * ring / 1.4)
		for i in count:
			var a := TAU * i / count
			var p: Vector3 = Vector3(cos(a), 0.01, sin(a)) * ring
			_model("path_A" if i % 2 == 0 else "path_B", p, -a + _rng.randf_range(-0.3, 0.3), 0.7)


## Queues a static scenery model; returns its transform.
func _model(file: String, pos: Vector3, yaw := 0.0, scale_f := 1.0, tilt_z := 0.0) -> Transform3D:
	var t := Transform3D(Basis.from_euler(Vector3(0, yaw, tilt_z)).scaled(Vector3.ONE * scale_f), pos)
	if not _batches.has(file):
		_batches[file] = []
	(_batches[file] as Array).append(t)
	return t


func _flush_batches() -> void:
	for file in _batches:
		var xforms: Array = _batches[file]
		var inst := Props.model(file)
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var local := Transform3D()
			var n: Node = mi
			while n != inst:
				local = (n as Node3D).transform * local
				n = n.get_parent()
			var mat: Material = mi.material_override
			if mat == null and mi.get_surface_override_material_count() > 0:
				mat = mi.get_surface_override_material(0)
			_add_multimesh(mi.mesh, mat, xforms, local, not NO_SHADOW.has(file))
		inst.free()
	_batches.clear()
	var rock_mesh := Build.cylinder(0.3, 1.0, 1.0, 6)
	_add_multimesh(rock_mesh, Build.mat(Color(0.22, 0.21, 0.24), 1.0), _rock_xforms, Transform3D(), true)
	_rock_xforms.clear()


func _add_multimesh(mesh: Mesh, mat: Material, xforms: Array, local: Transform3D, shadows: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, (xforms[i] as Transform3D) * local)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if mat:
		mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _static_box(pos: Vector3, size: Vector3, rot_y := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	body.rotation.y = rot_y
	add_child(body)
	return body


func _static_cylinder(pos: Vector3, radius: float, height: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	add_child(body)
	return body


func _clear_spot(p: Vector3, min_r := 7.0) -> bool:
	var flat := Vector2(p.x, p.z).length()
	if flat <= min_r or flat >= RADIUS - 3.0:
		return false
	# Keep the outer path and the spawn graves free.
	if absf(flat - 14.0) < 1.6:
		return false
	for s in spawn_points:
		if p.distance_to(s) < 3.5:
			return false
	return true


func _random_spot(min_r: float, tries := 60) -> Vector3:
	for i in tries:
		var p := Vector3(_rng.randf_range(-RADIUS, RADIUS), 0, _rng.randf_range(-RADIUS, RADIUS))
		if _clear_spot(p, min_r):
			return p
	return Vector3(min_r + 2.5, 0, 0)


# --------------------------------------------------------------------------
# Boundary, altar, scenery
# --------------------------------------------------------------------------

func _build_boundary() -> void:
	# Iron fence ring (KayKit fence pieces), rocks behind it, invisible wall.
	var r := RADIUS + 0.6
	var segments := int(TAU * r / 4.0)
	for i in segments:
		var a := TAU * (i + 0.5) / segments
		var p := Vector3(cos(a), 0, sin(a)) * r
		var yaw := -a + PI / 2.0
		var piece := "fence"
		if i % 7 == 3:
			piece = "fence_broken"
		elif i % 11 == 0:
			piece = "fence_gate"
		_model(piece, p, yaw, TAU * r / segments / 4.0)
		var pa := TAU * i / segments
		_model("fence_pillar" if i % 5 != 2 else "fence_pillar_broken", Vector3(cos(pa), 0, sin(pa)) * r, -pa)
		_static_box(p + Vector3(0, 3, 0), Vector3(TAU * r / segments + 0.4, 6, 0.6), yaw)
		var h := _rng.randf_range(3.0, 8.0)
		var rr := r + 3.5 + _rng.randf_range(0.0, 2.5)
		var w := _rng.randf_range(1.6, 2.6)
		var rb := Basis.from_euler(Vector3(deg_to_rad(_rng.randf_range(-10, 10)), _rng.randf() * TAU, deg_to_rad(_rng.randf_range(-10, 10))))
		_rock_xforms.append(Transform3D(rb * Basis.from_scale(Vector3(w, h, w)), Vector3(cos(a), 0, sin(a)) * rr + Vector3(0, h * 0.5 - 0.3, 0)))
	# A grand gate arch in the north, outside the fence.
	_model("arch_gate", Vector3(0, 0, -(r + 1.0)), 0.0, 1.3)


func _build_altar() -> void:
	# Central shrine with candles, four candle pillars and the soul crystal.
	var stone := Build.mat(Color(0.34, 0.32, 0.38), 0.8)
	Build.part(self, Build.cylinder(2.6, 2.9, 0.3, 16), stone, ALTAR_POS + Vector3(0, 0.15, 0))
	_model("shrine_candles", ALTAR_POS + Vector3(0, 0.3, 0), 0.0, 1.2)
	_static_cylinder(ALTAR_POS + Vector3(0, 1.0, 0), 1.3, 2.0)
	_flame_light(self, ALTAR_POS + Vector3(0, 1.6, 1.4), 1.2, 6.0)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		var p := ALTAR_POS + Vector3(cos(a), 0, sin(a)) * 4.2
		_model("pillar", p, a, 0.65)
		_model("candle_triple", p + Vector3(0, 2.86, 0), a, 0.9)
		_static_cylinder(p + Vector3(0, 1.4, 0), 0.4, 2.9)
		if i % 2 == 0:
			_flame_light(self, p + Vector3(0, 3.6, 0), 1.6, 10.0)
	altar_ring = Build.part(self, Build.torus(2.25, 2.4), Build.glow_mat(Color(0.4, 0.3, 1.0), 2.2), ALTAR_POS + Vector3(0, 0.32, 0))
	altar_crystal = Build.part(self, Build.cylinder(0.0, 0.35, 0.9, 4), Build.soul_mat(Color(0.8, 1.0, 1.0), Color(0.5, 0.3, 1.0), 2.5), ALTAR_POS + Vector3(0, 3.1, 0))
	var bottom := Build.part(altar_crystal, Build.cylinder(0.35, 0.0, 0.6, 4), altar_crystal.material_override, Vector3(0, -0.75, 0))
	bottom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	altar_light = Build.light(self, Color(0.6, 0.5, 1.0), 2.4, 14.0, ALTAR_POS + Vector3(0, 3.4, 0))
	# Glowing border of the safe zone + rising wisps along it.
	var sr := safe_radius()
	safe_ring = Build.part(self, Build.torus(sr - 0.06, sr + 0.06), Build.glow_mat(SAFE_COLOR, 2.0), ALTAR_POS + Vector3(0, 0.05, 0))
	safe_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	safe_ring.scale = Vector3(1, 0.2, 1)
	for i in 6:
		var a := TAU * i / 6.0
		Build.particles(self, {
			"position": ALTAR_POS + Vector3(cos(a), 0.1, sin(a)) * sr, "amount": 8, "lifetime": 2.0, "velocity": 0.6,
			"spread": 8.0, "size": 0.18, "color": Color(SAFE_COLOR, 0.8), "color_end": Color(0.3, 0.5, 1.0, 0.0), "radius": 1.6,
			"direction": Vector3.UP,
		})


## Wave events change the mood of the graveyard.
func set_event(id: String) -> void:
	var moon_col := Color(0.75, 0.78, 1.0)
	_event_fog = 0.0
	_event_tint = Color(0, 0, 0, 0)
	match id:
		"blutmond":
			moon_col = Color(1.0, 0.35, 0.3)
			_event_tint = Color(0.45, 0.05, 0.05, 0.6)
		"seelensturm":
			moon_col = Color(0.55, 0.9, 1.0)
			_event_tint = Color(0.1, 0.35, 0.5, 0.5)
		"nebelnacht":
			_event_fog = 0.035
			_event_tint = Color(0.5, 0.5, 0.55, 0.6)
		"knochenregen":
			moon_col = Color(1.0, 0.75, 0.5)
			_event_tint = Color(0.35, 0.2, 0.1, 0.4)
	create_tween().tween_property(moon, "light_color", moon_col, 1.5)


## Altar glows brighter during the break between waves (shop is "open").
func set_altar_active(active: bool) -> void:
	if altar_light:
		var tw := create_tween()
		tw.tween_property(altar_light, "light_energy", 3.6 if active else 1.8, 0.8)


func _build_scenery() -> void:
	# Graves of all kinds in loose rows, each facing the altar.
	var graves := [
		["gravestone", Vector3(1.4, 1.6, 0.4)], ["gravestone", Vector3(1.4, 1.6, 0.4)],
		["gravemarker_A", Vector3(0.8, 1.2, 0.3)], ["gravemarker_B", Vector3(0.8, 1.2, 0.4)],
		["grave_A", Vector3(2.0, 2.1, 1.0)], ["grave_B", Vector3(2.0, 2.2, 1.0)],
		["grave_A_destroyed", Vector3(2.0, 1.4, 1.1)],
	]
	var placed := 0
	var tries := 0
	while placed < 55 and tries < 900:
		tries += 1
		var p := Vector3(_rng.randf_range(-RADIUS, RADIUS), 0, _rng.randf_range(-RADIUS, RADIUS))
		if not _clear_spot(p, 9.0):
			continue
		var g: Array = graves[_rng.randi() % graves.size()]
		var s := _rng.randf_range(0.8, 1.0)
		var yaw := atan2(p.x, p.z) + _rng.randf_range(-0.25, 0.25)
		_model(g[0], p, yaw, s, deg_to_rad(_rng.randf_range(-5, 5)))
		var size: Vector3 = g[1] * s
		_static_box(p + Vector3(0, size.y * 0.5, 0), size, yaw)
		placed += 1
	# Dead trees.
	var trees := ["tree_dead_large", "tree_dead_medium", "tree_dead_small", "tree_dead_large_decorated"]
	for i in 14:
		var p := _random_spot(11.0)
		var s := _rng.randf_range(1.3, 1.9)
		_model(trees[i % trees.size()], p, _rng.randf() * TAU, s)
		_static_cylinder(p + Vector3(0, 2.0, 0), 0.3 * s, 4.0)
	# Crypts with a warm light at the door.
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		var dir := Vector3(cos(a), 0, sin(a))
		var p := dir * 27.0
		var yaw := atan2(p.x, p.z) + PI
		_model("crypt", p, yaw, 0.85)
		_static_box(p + Vector3(0, 3.0, 0), Vector3(5.1, 6.0, 6.8), yaw)
		_flame_light(self, p - dir * 4.0 + Vector3(0, 2.2, 0), 1.4, 8.0)
	# Lantern posts along the outer path.
	for i in 8:
		var a := TAU * i / 8.0
		var p := Vector3(cos(a), 0, sin(a)) * 15.3
		var post := _model("post_lantern", p, -a, 0.9)
		_static_cylinder(p + Vector3(0, 1.5, 0), 0.25, 3.0)
		if i % 2 == 0:
			_flame_light(self, post * Vector3(0, 2.0, 1.2), 2.4, 14.0)
	# Standing lanterns, skull posts and benches between the graves.
	for i in 8:
		var p := _random_spot(9.0)
		_model("lantern_standing", p, _rng.randf() * TAU)
		if i % 4 == 0:
			_flame_light(self, p + Vector3(0, 0.6, 0), 1.2, 7.0)
	for i in 5:
		var p := _random_spot(9.0)
		_model("post_skull", p, _rng.randf() * TAU, 0.9)
		_static_cylinder(p + Vector3(0, 1.5, 0), 0.25, 3.0)


func _build_spawns() -> void:
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		var dir := Vector3(cos(a), 0, sin(a))
		var p := dir * (RADIUS - 5.0)
		spawn_points.append(p)
		_model("floor_dirt_grave", p + Vector3(0, 0.02, 0), -a, 0.7)
		_model("gravemarker_A", p + dir * 2.0, -a + PI / 2.0)
		var glow := Build.light(self, Color(1.0, 0.15, 0.2), 0.0, 6.0, p + Vector3(0, 0.6, 0))
		glow.visible = false
		spawn_glows.append(glow)


## Briefly lights up a spawn grave in red.
func flash_spawn(index: int) -> void:
	if index < 0 or index >= spawn_glows.size():
		return
	var l := spawn_glows[index]
	l.visible = true
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 3.0, 0.25)
	tw.tween_property(l, "light_energy", 0.0, 1.2)
	tw.tween_callback(func(): l.visible = false)


# --------------------------------------------------------------------------
# Loose physics props
# --------------------------------------------------------------------------

func _build_physics_props() -> void:
	# [model, scale, mass, count]
	var list := [
		["skull", 0.5, 2.0, 10], ["skull_candle", 0.6, 3.0, 5], ["pumpkin_orange_jackolantern", 0.55, 4.0, 7],
		["candle_triple", 0.9, 1.5, 6], ["candle_melted", 1.0, 1.0, 6], ["coffin", 0.75, 35.0, 4],
		["coffin_decorated", 0.75, 30.0, 2], ["bone_A", 0.7, 0.6, 8], ["bone_B", 0.7, 0.6, 6],
		["ribcage", 0.7, 2.0, 4], ["bench", 1.0, 20.0, 3],
	]
	for entry in list:
		for i in int(entry[3]):
			var p := _random_spot(safe_radius() + 2.0)
			var rb := Props.spawn(self, entry[0], p + Vector3(0, 0.05, 0), entry[1], entry[2], _rng.randf() * TAU)
			rb.sleeping = true  # Cheap until something touches them.


func _build_mist() -> void:
	Build.particles(self, {
		"amount": 70, "lifetime": 9.0, "velocity": 0.25, "spread": 180.0, "size": 5.0,
		"box": Vector3(RADIUS, 0.4, RADIUS), "position": Vector3(0, 0.6, 0),
		"color": Color(0.6, 0.55, 0.7, 0.05), "color_end": Color(0.45, 0.4, 0.55, 0.0), "additive": false,
	}).visibility_aabb = AABB(Vector3(-50, -5, -50), Vector3(100, 10, 100))
	# Soul motes.
	Build.particles(self, {
		"amount": 50, "lifetime": 6.0, "velocity": 0.4, "spread": 180.0, "size": 0.12,
		"box": Vector3(RADIUS, 2.0, RADIUS), "position": Vector3(0, 2.0, 0),
		"color": Color(0.5, 0.9, 1.0, 0.9), "color_end": Color(0.6, 0.3, 1.0, 0.0),
	}).visibility_aabb = AABB(Vector3(-50, -5, -50), Vector3(100, 10, 100))
