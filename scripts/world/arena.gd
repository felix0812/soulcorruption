class_name Arena
extends Node3D
## The cursed graveyard: lighting, sky, fog, ground, props, the soul altar
## and the spawn graves. Built entirely from code.

const RADIUS := 36.0
const ALTAR_POS := Vector3(0, 0, 0)

var env: Environment
var moon: DirectionalLight3D
var spawn_points: Array[Vector3] = []
var altar_light: OmniLight3D
var altar_ring: MeshInstance3D
var altar_crystal: MeshInstance3D
var spawn_glows: Array[OmniLight3D] = []
var _base_fog := Color(0.09, 0.05, 0.13)
var _rng := RandomNumberGenerator.new()
var _t := 0.0


func _ready() -> void:
	add_to_group("settings_listeners")
	_rng.seed = 1337  # Same layout every time.
	_build_environment()
	_build_ground()
	_build_boundary()
	_build_altar()
	_build_props()
	_build_spawns()
	_build_mist()


func _process(delta: float) -> void:
	_t += delta
	if altar_crystal:
		altar_crystal.rotation.y += delta * 0.8
		altar_crystal.position.y = 2.6 + sin(_t * 1.5) * 0.15
	if altar_ring:
		altar_ring.rotation.y -= delta * 0.3


# --------------------------------------------------------------------------

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.03, 0.01, 0.06)
	sky_mat.sky_horizon_color = Color(0.16, 0.07, 0.2)
	sky_mat.ground_horizon_color = Color(0.08, 0.04, 0.1)
	sky_mat.ground_bottom_color = Color(0.01, 0.0, 0.02)
	sky_mat.sun_angle_max = 8.0
	sky_mat.sun_curve = 0.05
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.22, 0.38)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.glow_enabled = Cfg.gb("graphics.glow", true)
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = Cfg.gb("graphics.fog", true)
	env.fog_light_color = _base_fog
	env.fog_density = 0.028
	env.fog_sky_affect = 0.6
	env.volumetric_fog_enabled = Cfg.gb("graphics.volumetric_fog", false)
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.5, 0.45, 0.6)
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.6, 0.95)
	moon.light_energy = 0.8
	moon.rotation_degrees = Vector3(-38, 35, 0)
	moon.shadow_enabled = Cfg.gb("graphics.shadows", true)
	moon.directional_shadow_max_distance = 55.0
	add_child(moon)

	# A big pale moon far away (pure decoration).
	var moon_disc := Build.part(self, Build.sphere(14.0, 24), Build.glow_mat(Color(0.75, 0.8, 1.0), 1.4), Vector3(-160, 120, -230))
	moon_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Called by the settings menu.
func apply_settings() -> void:
	env.glow_enabled = Cfg.gb("graphics.glow", true)
	env.fog_enabled = Cfg.gb("graphics.fog", true)
	env.volumetric_fog_enabled = Cfg.gb("graphics.volumetric_fog", false)
	moon.shadow_enabled = Cfg.gb("graphics.shadows", true)
	altar_light.shadow_enabled = moon.shadow_enabled


## Tints the fog with the corruption (called every frame by the corruption system).
func set_corruption_tint(amount: float) -> void:
	if env == null:
		return
	env.fog_light_color = _base_fog.lerp(Color(0.22, 0.02, 0.07), clampf(amount, 0.0, 1.0))
	env.fog_density = 0.028 + 0.02 * amount
	env.adjustment_saturation = 0.9 - 0.35 * amount


func _build_ground() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.02
	noise.fractal_octaves = 5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.05, 0.05, 0.06))
	ramp.set_color(1, Color(0.17, 0.16, 0.14))
	ramp.add_point(0.5, Color(0.09, 0.1, 0.08))
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

	# Stone path rings around the altar.
	var stone := Build.mat(Color(0.2, 0.19, 0.22), 0.9)
	for ring in [5.5, 12.0]:
		var count := int(ring * 4.0)
		for i in count:
			var a := TAU * i / count
			var p: Vector3 = Vector3(cos(a), 0.02, sin(a)) * ring
			var slab := Build.part(self, Build.box(Vector3(1.1, 0.06, 0.8)), stone, p, Vector3(0, -rad_to_deg(a) + _rng.randf_range(-8, 8), 0))
			slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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


func _build_boundary() -> void:
	# Jagged rock wall + iron fence ring; invisible wall keeps everyone inside.
	var rock := Build.mat(Color(0.11, 0.1, 0.12), 1.0)
	var iron := Build.mat(Color(0.08, 0.07, 0.08), 0.5, Color.BLACK, 0.0, 0.7)
	var segments := 48
	for i in segments:
		var a := TAU * i / segments
		var dir := Vector3(cos(a), 0, sin(a))
		var h := _rng.randf_range(3.0, 8.0)
		var r := RADIUS + 3.0 + _rng.randf_range(0.0, 2.5)
		Build.part(self, Build.cylinder(_rng.randf_range(0.3, 1.0), _rng.randf_range(1.6, 2.6), h, 6), rock,
			dir * r + Vector3(0, h * 0.5 - 0.3, 0), Vector3(_rng.randf_range(-10, 10), _rng.randf_range(0, 360), _rng.randf_range(-10, 10)))
		# Fence posts.
		var fp := dir * (RADIUS + 0.6)
		Build.part(self, Build.box(Vector3(0.08, 2.2, 0.08)), iron, fp + Vector3(0, 1.1, 0))
		Build.part(self, Build.cylinder(0.0, 0.07, 0.25, 4), iron, fp + Vector3(0, 2.3, 0))
		# Invisible wall segment.
		var seg_len := TAU * (RADIUS + 0.6) / segments + 0.3
		_static_box(fp + Vector3(0, 3, 0), Vector3(seg_len, 6, 0.6), -a + PI / 2.0)
	# Fence rails.
	for y in [0.6, 1.8]:
		var rail := Build.part(self, Build.torus(RADIUS + 0.57, RADIUS + 0.63), iron, Vector3(0, y, 0))
		rail.scale = Vector3(1, 0.4, 1)


func _build_altar() -> void:
	var stone := Build.mat(Color(0.16, 0.14, 0.18), 0.8)
	var dark := Build.mat(Color(0.07, 0.05, 0.09), 0.7)
	Build.part(self, Build.cylinder(2.6, 2.9, 0.4, 8), stone, ALTAR_POS + Vector3(0, 0.2, 0))
	Build.part(self, Build.cylinder(1.8, 2.1, 0.4, 8), dark, ALTAR_POS + Vector3(0, 0.6, 0))
	Build.part(self, Build.box(Vector3(1.4, 1.0, 0.9)), stone, ALTAR_POS + Vector3(0, 1.3, 0))
	Build.part(self, Build.box(Vector3(1.7, 0.15, 1.1)), dark, ALTAR_POS + Vector3(0, 1.85, 0))
	_static_cylinder(ALTAR_POS + Vector3(0, 1.0, 0), 1.6, 2.0)
	# Four pillars with braziers.
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		var p := ALTAR_POS + Vector3(cos(a), 0, sin(a)) * 4.2
		Build.part(self, Build.cylinder(0.28, 0.35, 2.4, 8), stone, p + Vector3(0, 1.2, 0))
		Build.part(self, Build.cylinder(0.45, 0.25, 0.3, 8), dark, p + Vector3(0, 2.5, 0))
		_static_cylinder(p + Vector3(0, 1.2, 0), 0.36, 2.4)
		Build.particles(self, {
			"position": p + Vector3(0, 2.7, 0), "amount": 14, "lifetime": 0.9, "velocity": 1.4,
			"spread": 12.0, "size": 0.35, "color": Color(0.5, 0.8, 1.0), "color_end": Color(0.4, 0.1, 0.9, 0.0), "radius": 0.15,
		})
		if i % 2 == 0:
			Build.light(self, Color(0.45, 0.65, 1.0), 1.2, 9.0, p + Vector3(0, 3.0, 0))
	altar_ring = Build.part(self, Build.torus(2.25, 2.4), Build.glow_mat(Color(0.4, 0.3, 1.0), 2.2), ALTAR_POS + Vector3(0, 0.82, 0))
	altar_crystal = Build.part(self, Build.cylinder(0.0, 0.35, 0.9, 4), Build.soul_mat(Color(0.8, 1.0, 1.0), Color(0.5, 0.3, 1.0), 2.5), ALTAR_POS + Vector3(0, 2.6, 0))
	var bottom := Build.part(altar_crystal, Build.cylinder(0.35, 0.0, 0.6, 4), altar_crystal.material_override, Vector3(0, -0.75, 0))
	bottom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	altar_light = Build.light(self, Color(0.55, 0.45, 1.0), 2.2, 12.0, ALTAR_POS + Vector3(0, 3.0, 0), Cfg.gb("graphics.shadows", true))


## Altar glows brighter during the break between waves (shop is "open").
func set_altar_active(active: bool) -> void:
	if altar_light:
		var tw := create_tween()
		tw.tween_property(altar_light, "light_energy", 3.2 if active else 1.4, 0.8)


func _clear_spot(p: Vector3, min_r := 7.0) -> bool:
	var flat := Vector2(p.x, p.z).length()
	return flat > min_r and flat < RADIUS - 2.5


func _build_props() -> void:
	var stone := Build.mat(Color(0.22, 0.21, 0.24), 0.95)
	var moss := Build.mat(Color(0.12, 0.15, 0.1), 1.0)
	var wood := Build.mat(Color(0.09, 0.07, 0.06), 1.0)
	# Gravestones.
	var placed := 0
	var tries := 0
	while placed < 70 and tries < 600:
		tries += 1
		var p := Vector3(_rng.randf_range(-RADIUS, RADIUS), 0, _rng.randf_range(-RADIUS, RADIUS))
		if not _clear_spot(p, 7.5):
			continue
		var yaw := _rng.randf_range(-0.4, 0.4) + (PI if _rng.randf() < 0.5 else 0.0)
		var tilt := Vector3(_rng.randf_range(-12, 12), rad_to_deg(yaw), _rng.randf_range(-8, 8))
		var kind := _rng.randi() % 3
		var root := Node3D.new()
		root.position = p
		root.rotation_degrees = tilt
		add_child(root)
		match kind:
			0:  # Classic rounded stone.
				Build.part(root, Build.box(Vector3(0.8, 1.0, 0.18)), stone, Vector3(0, 0.5, 0))
				Build.part(root, Build.cylinder(0.4, 0.4, 0.18, 12), stone, Vector3(0, 1.0, 0), Vector3(90, 0, 0))
			1:  # Cross.
				Build.part(root, Build.box(Vector3(0.18, 1.5, 0.18)), stone, Vector3(0, 0.75, 0))
				Build.part(root, Build.box(Vector3(0.8, 0.18, 0.18)), stone, Vector3(0, 1.1, 0))
			2:  # Flat slab with mossy base.
				Build.part(root, Build.box(Vector3(1.0, 0.7, 0.25)), stone, Vector3(0, 0.35, 0))
				Build.part(root, Build.box(Vector3(1.1, 0.12, 2.0)), moss, Vector3(0, 0.06, 0.9))
		_static_box(p + Vector3(0, 0.6, 0), Vector3(0.9, 1.2, 0.35), yaw)
		placed += 1
	# Dead trees.
	for i in 14:
		var p := Vector3.ZERO
		for t in 30:
			p = Vector3(_rng.randf_range(-RADIUS, RADIUS), 0, _rng.randf_range(-RADIUS, RADIUS))
			if _clear_spot(p, 10.0):
				break
		var h := _rng.randf_range(4.0, 7.0)
		var tree := Node3D.new()
		tree.position = p
		tree.rotation.y = _rng.randf() * TAU
		add_child(tree)
		Build.part(tree, Build.cylinder(0.12, 0.35, h, 7), wood, Vector3(0, h * 0.5, 0), Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6)))
		for b in _rng.randi_range(3, 5):
			var by := _rng.randf_range(h * 0.45, h * 0.9)
			var bl := _rng.randf_range(1.2, 2.4)
			var ang := _rng.randf() * 360.0
			var branch := Node3D.new()
			branch.position = Vector3(0, by, 0)
			branch.rotation_degrees = Vector3(0, ang, _rng.randf_range(35, 70))
			tree.add_child(branch)
			Build.part(branch, Build.cylinder(0.03, 0.1, bl, 5), wood, Vector3(0, bl * 0.5, 0))
		_static_cylinder(p + Vector3(0, h * 0.5, 0), 0.35, h)
	# Ruined crypt walls.
	for i in 5:
		var a := TAU * i / 5.0 + 0.4
		var p := Vector3(cos(a), 0, sin(a)) * 24.0
		var yaw := -a + PI / 2.0
		var length := _rng.randf_range(4.0, 6.5)
		var h := _rng.randf_range(1.6, 3.2)
		var wall := Build.part(self, Build.box(Vector3(length, h, 0.6)), stone, p + Vector3(0, h * 0.5, 0))
		wall.rotation.y = yaw
		_static_box(p + Vector3(0, h * 0.5, 0), Vector3(length, h, 0.6), yaw)
		# Broken top blocks.
		for k in 3:
			var bp := p + Vector3(cos(yaw), 0, -sin(yaw)) * _rng.randf_range(-length * 0.4, length * 0.4)
			var blk := Build.part(self, Build.box(Vector3(0.7, 0.5, 0.7)), stone, bp + Vector3(0, h + 0.2, 0))
			blk.rotation_degrees = Vector3(_rng.randf_range(-15, 15), _rng.randf() * 90.0, _rng.randf_range(-15, 15))
	# Candles at some graves (cheap emissive, no lights).
	var candle := Build.glow_mat(Color(1.0, 0.65, 0.3), 3.0)
	var wax := Build.mat(Color(0.8, 0.78, 0.7))
	for i in 24:
		var p := Vector3(_rng.randf_range(-RADIUS, RADIUS), 0, _rng.randf_range(-RADIUS, RADIUS))
		if not _clear_spot(p, 6.0):
			continue
		Build.part(self, Build.cylinder(0.05, 0.05, 0.25, 6), wax, p + Vector3(0, 0.125, 0))
		Build.part(self, Build.sphere(0.04, 6), candle, p + Vector3(0, 0.29, 0))


func _build_spawns() -> void:
	var hole := Build.mat(Color(0.02, 0.01, 0.02), 1.0)
	var dirt := Build.mat(Color(0.12, 0.08, 0.06), 1.0)
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		var p := Vector3(cos(a), 0, sin(a)) * (RADIUS - 4.0)
		spawn_points.append(p)
		Build.part(self, Build.cylinder(1.2, 1.2, 0.04, 16), hole, p + Vector3(0, 0.03, 0))
		Build.part(self, Build.box(Vector3(2.4, 0.4, 0.8)), dirt, p + Vector3(0, 0.2, 1.3), Vector3(0, rad_to_deg(-a), 8))
		var glow := Build.light(self, Color(1.0, 0.15, 0.2), 0.0, 6.0, p + Vector3(0, 0.6, 0))
		spawn_glows.append(glow)


## Briefly lights up a spawn grave in red.
func flash_spawn(index: int) -> void:
	if index < 0 or index >= spawn_glows.size():
		return
	var l := spawn_glows[index]
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 3.0, 0.25)
	tw.tween_property(l, "light_energy", 0.0, 1.2)


func _build_mist() -> void:
	Build.particles(self, {
		"amount": 90, "lifetime": 9.0, "velocity": 0.25, "spread": 180.0, "size": 5.0,
		"box": Vector3(RADIUS, 0.4, RADIUS), "position": Vector3(0, 0.6, 0),
		"color": Color(0.35, 0.3, 0.45, 0.07), "color_end": Color(0.25, 0.2, 0.35, 0.0), "additive": false,
	}).visibility_aabb = AABB(Vector3(-50, -5, -50), Vector3(100, 10, 100))
	# Fireflies / soul motes.
	Build.particles(self, {
		"amount": 50, "lifetime": 6.0, "velocity": 0.4, "spread": 180.0, "size": 0.12,
		"box": Vector3(RADIUS, 2.0, RADIUS), "position": Vector3(0, 2.0, 0),
		"color": Color(0.5, 0.9, 1.0, 0.9), "color_end": Color(0.6, 0.3, 1.0, 0.0),
	}).visibility_aabb = AABB(Vector3(-50, -5, -50), Vector3(100, 10, 100))
