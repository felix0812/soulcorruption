class_name SoulBolt
extends Node3D
## Ranged attack of the player: a small homing-free spirit projectile.

const SPEED := 26.0
const LIFETIME := 1.6

var direction := Vector3.FORWARD
var damage := 10.0
var shooter  # Player
var _life := 0.0


func _ready() -> void:
	var core := Build.part(self, Build.sphere(0.16, 10), Build.soul_mat(Color(0.9, 1.0, 1.0), Color(0.4, 0.4, 1.0), 3.0))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Build.light(self, Color(0.5, 0.7, 1.0), 1.4, 4.0)
	Build.particles(self, {
		"amount": 24, "lifetime": 0.35, "velocity": 0.3, "spread": 180.0, "size": 0.25,
		"color": Color(0.6, 0.8, 1.0, 0.9), "color_end": Color(0.4, 0.2, 1.0, 0.0), "radius": 0.08,
	})


func _physics_process(delta: float) -> void:
	_life += delta
	if _life > LIFETIME:
		_explode()
		return
	var from := global_position
	var to := from + direction * SPEED * delta
	# World collision.
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | Props.LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position = hit.position
		_explode()
		return
	# Enemy collision (simple distance test against the travelled segment).
	var world = shooter.world if shooter else null
	if world:
		for e in world.enemies():
			var c: Vector3 = e.global_position + Vector3(0, e.radius() * 1.6, 0)
			var closest := Geometry3D.get_closest_point_to_segment(c, from, to)
			if closest.distance_to(c) < e.radius() + 0.35:
				e.take_hit(damage, from, 3.0)
				shooter.on_bolt_hit(damage)
				global_position = closest
				_explode()
				return
	global_position = to


func _explode() -> void:
	var parent := get_parent() as Node3D
	if parent:
		Build.burst(parent, global_position, Color(0.6, 0.85, 1.0), 16, 3.0, 0.25, 0.5)
		Props.blast(get_tree(), global_position, 2.5, 5.0)
	queue_free()
