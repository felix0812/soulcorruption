class_name Build
extends RefCounted
## Small helpers to assemble procedural 3D content (meshes, materials,
## particles, lights). All art in the game is made with these.

const SOUL_SHADER := preload("res://shaders/soul_orb.gdshader")
const RIM_SHADER := preload("res://shaders/corrupt_rim.gdshader")

static var _mat_cache: Dictionary = {}
static var _glow_tex: GradientTexture2D


static func mat(color: Color, roughness := 0.85, emission := Color.BLACK, emission_energy := 0.0, metallic := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s|%s" % [color, roughness, emission, emission_energy, metallic]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	_mat_cache[key] = m
	return m


static func glow_mat(color: Color, energy := 3.0) -> StandardMaterial3D:
	var key := "glow|%s|%s" % [color, energy]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy)
	_mat_cache[key] = m
	return m


static func soul_mat(core: Color, rim: Color, energy := 2.5, alpha := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SOUL_SHADER
	m.set_shader_parameter("core_color", core)
	m.set_shader_parameter("rim_color", rim)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("alpha_scale", alpha)
	return m


static func rim_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = RIM_SHADER
	return m


static func part(parent: Node3D, mesh: Mesh, material: Material, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func sphere(radius: float, segments := 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = segments
	s.rings = maxi(4, segments / 2)
	return s


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	c.radial_segments = 16
	c.rings = 6
	return c


static func cylinder(top: float, bottom: float, height: float, segments := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return c


static func torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 32
	t.ring_segments = 8
	return t


## Soft round sprite used by all particles.
static func glow_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 64
		_glow_tex.height = 64
	return _glow_tex


static func particle_draw_mat(additive := true) -> StandardMaterial3D:
	var key := "particle|%s" % additive
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = glow_texture()
	m.disable_receive_shadows = true
	m.no_depth_test = false
	_mat_cache[key] = m
	return m


## Generic GPU particle emitter.
## opts: amount, lifetime, size, color, color_end, velocity, spread, gravity,
## radius, box, one_shot, explosiveness, additive, local, direction, damping
static func particles(parent: Node3D, opts: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var mult := clampf(Cfg.gf("graphics.particles", 1.0), 0.0, 2.0)
	p.amount = maxi(1, int(opts.get("amount", 16) * maxf(mult, 0.05)))
	p.lifetime = opts.get("lifetime", 1.0)
	p.one_shot = opts.get("one_shot", false)
	p.explosiveness = opts.get("explosiveness", 0.0)
	p.local_coords = opts.get("local", false)
	p.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	p.visible = mult > 0.0
	var pm := ParticleProcessMaterial.new()
	if opts.has("box"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = opts["box"]
	else:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = opts.get("radius", 0.2)
	pm.direction = opts.get("direction", Vector3.UP)
	pm.spread = opts.get("spread", 30.0)
	var v: float = opts.get("velocity", 1.0)
	pm.initial_velocity_min = v * 0.6
	pm.initial_velocity_max = v
	pm.gravity = opts.get("gravity", Vector3.ZERO)
	pm.damping_min = opts.get("damping", 0.0)
	pm.damping_max = opts.get("damping", 0.0)
	var s: float = opts.get("size", 0.2)
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.2))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var c0: Color = opts.get("color", Color(0.6, 0.9, 1.0))
	var c1: Color = opts.get("color_end", Color(c0.r, c0.g, c0.b, 0.0))
	var grad := Gradient.new()
	grad.set_color(0, c0)
	grad.set_color(1, c1)
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(s, s)
	quad.material = particle_draw_mat(opts.get("additive", true))
	p.draw_pass_1 = quad
	parent.add_child(p)
	if opts.has("position"):
		p.position = opts["position"]
	p.emitting = true
	return p


## One-shot burst that frees itself.
static func burst(world: Node3D, pos: Vector3, color: Color, amount := 24, velocity := 4.0, size := 0.25, lifetime := 0.8) -> void:
	var p := particles(world, {
		"amount": amount, "lifetime": lifetime, "one_shot": true, "explosiveness": 0.95,
		"velocity": velocity, "spread": 180.0, "size": size, "color": color,
		"gravity": Vector3(0, -2.0, 0), "damping": 2.0, "radius": 0.3,
	})
	p.global_position = pos
	p.finished.connect(p.queue_free)


static func light(parent: Node3D, color: Color, energy: float, range_m: float, pos := Vector3.ZERO, shadows := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadows
	l.position = pos
	parent.add_child(l)
	return l


static func label(parent: Node3D, text: String, color: Color, font_size := 36, pos := Vector3.ZERO, view_range := 18.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.008
	l.modulate = color
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	l.visibility_range_end = view_range
	l.visibility_range_end_margin = 2.0
	l.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(l)
	return l


## Floating text that rises and fades (damage numbers, last words).
static func float_text(world: Node3D, pos: Vector3, text: String, color: Color, font_size := 40, duration := 1.0, rise := 1.2) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	l.width = 600.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", pos + Vector3(0, rise, 0), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tw.chain().tween_callback(l.queue_free)
