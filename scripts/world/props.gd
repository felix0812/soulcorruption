class_name Props
extends RefCounted
## Physics props: rigid bodies built from the graveyard models (skulls,
## bones, pumpkins, candles, coffins ...) plus helpers to push everything
## around with impulses (sword hits, soul bolts, boss slams, deaths).

const DIR := "res://assets/kaykit/graveyard/"
const LAYER := 8  # Collision layer 4 (value 8) = physics props.

## Approximate collision boxes (metres, at scale 1) for the prop models.
const SIZES := {
	"skull": Vector3(0.9, 0.9, 0.9),
	"skull_candle": Vector3(0.9, 1.1, 0.9),
	"bone_A": Vector3(0.7, 0.25, 0.2),
	"bone_B": Vector3(0.6, 0.17, 0.29),
	"ribcage": Vector3(0.85, 0.85, 0.75),
	"pumpkin_orange_jackolantern": Vector3(1.4, 1.25, 1.35),
	"candle_triple": Vector3(0.45, 0.8, 0.35),
	"candle_melted": Vector3(0.3, 0.63, 0.3),
	"coffin": Vector3(2.0, 1.3, 3.0),
	"coffin_decorated": Vector3(2.0, 0.9, 3.0),
	"lantern_standing": Vector3(0.6, 0.93, 0.6),
	"bench": Vector3(2.0, 0.5, 0.75),
}

static var _scenes: Dictionary = {}


static func model(file: String) -> Node3D:
	if not _scenes.has(file):
		_scenes[file] = load(DIR + file + ".gltf")
	return (_scenes[file] as PackedScene).instantiate()


## Creates a rigid prop. `pos` is the bottom centre of the object.
static func spawn(world: Node3D, file: String, pos: Vector3, scale_f := 1.0, mass := 5.0, yaw := 0.0) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.collision_layer = LAYER
	rb.collision_mask = 1 | 2 | 4 | LAYER
	rb.mass = mass
	rb.add_to_group("props")
	var size: Vector3 = SIZES.get(file, Vector3(0.5, 0.5, 0.5)) * scale_f
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position.y = size.y * 0.5
	rb.add_child(cs)
	var m := model(file)
	m.scale = Vector3.ONE * scale_f
	rb.add_child(m)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.25
	pm.friction = 0.8
	rb.physics_material_override = pm
	rb.linear_damp = 0.3
	rb.angular_damp = 0.6
	rb.position = pos
	rb.rotation.y = yaw
	world.add_child(rb)
	return rb


## Pushes every prop within `radius` of `center` away from it.
static func blast(tree: SceneTree, center: Vector3, radius: float, strength: float) -> void:
	for n in tree.get_nodes_in_group("props"):
		var rb := n as RigidBody3D
		if rb == null:
			continue
		var d := rb.global_position - center
		var dist := d.length()
		if dist > radius:
			continue
		var dir := (d + Vector3(0, 0.6, 0)).normalized()
		var falloff := 1.0 - dist / radius
		rb.apply_central_impulse(dir * strength * falloff * rb.mass)
		rb.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * strength * 0.1 * rb.mass)


## Pushes props in a cone in front of an attacker (melee swings).
static func swing(tree: SceneTree, origin: Vector3, forward: Vector3, reach: float, strength: float) -> void:
	for n in tree.get_nodes_in_group("props"):
		var rb := n as RigidBody3D
		if rb == null:
			continue
		var d := rb.global_position - origin
		d.y = 0.0
		if d.length() > reach or (d.length() > 0.6 and forward.dot(d.normalized()) < 0.3):
			continue
		rb.apply_central_impulse((forward + Vector3(0, 0.5, 0)).normalized() * strength * rb.mass)
		rb.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * strength * 0.15 * rb.mass)


## Lets a CharacterBody3D shove the props it walks into.
static func push_from_slides(body: CharacterBody3D, strength: float) -> void:
	for i in body.get_slide_collision_count():
		var c := body.get_slide_collision(i)
		var rb := c.get_collider() as RigidBody3D
		if rb:
			var n := -c.get_normal()
			n.y = 0.0
			rb.apply_central_impulse(n.normalized() * strength)


## A skeleton falls apart: skull and bones fly off with real physics and
## disappear after a while.
static func bone_burst(world: Node3D, pos: Vector3, from_dir: Vector3, scale_f := 1.0, count := 4) -> void:
	var pieces := ["skull", "bone_A", "bone_B", "ribcage", "bone_A", "bone_B"]
	for i in mini(count, pieces.size()):
		var file: String = pieces[i]
		var s := (0.32 if file == "skull" else 0.45) * scale_f
		var p := pos + Vector3(randf_range(-0.3, 0.3), (1.4 if file == "skull" else randf_range(0.5, 1.1)) * scale_f, randf_range(-0.3, 0.3))
		var rb := spawn(world, file, p, s, 1.0, randf() * TAU)
		rb.remove_from_group("props")  # Debris doesn't block attacks.
		rb.add_to_group("debris")
		rb.collision_mask = 1 | LAYER
		var dir := (from_dir + Vector3(randf_range(-0.6, 0.6), randf_range(0.6, 1.2), randf_range(-0.6, 0.6))).normalized()
		rb.apply_central_impulse(dir * randf_range(3.0, 6.0))
		rb.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.6)
		# Rigid bodies must not be scaled, so shrink the visual child instead.
		var vis := rb.get_child(1) as Node3D
		var tw := rb.create_tween()
		tw.tween_interval(randf_range(5.0, 7.0))
		tw.tween_property(vis, "scale", Vector3.ONE * 0.01, 0.6)
		tw.tween_callback(rb.queue_free)
