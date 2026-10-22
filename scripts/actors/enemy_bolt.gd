class_name EnemyBolt
extends Node3D
## Cursed projectile of the skeleton mages. Slow enough to dodge.

const SPEED := 13.0
const LIFETIME := 3.5

var direction := Vector3.FORWARD
var damage := 10.0
var world  # World node
var _life := 0.0


func _ready() -> void:
	var core := Build.part(self, Build.sphere(0.22, 10), Build.glow_mat(Color(1.0, 0.25, 0.5), 4.0))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Build.light(self, Color(1.0, 0.3, 0.5), 1.2, 4.0)
	Build.particles(self, {
		"amount": 20, "lifetime": 0.4, "velocity": 0.3, "spread": 180.0, "size": 0.3,
		"color": Color(1.0, 0.3, 0.5, 0.9), "color_end": Color(0.4, 0.0, 0.2, 0.0), "radius": 0.1,
	})


func _physics_process(delta: float) -> void:
	_life += delta
	if _life > LIFETIME:
		_explode()
		return
	var from := global_position
	var to := from + direction * SPEED * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | Props.LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position = hit.position
		_explode()
		return
	var targets: Array = get_tree().get_nodes_in_group("minions")
	if world and world.player and not world.player.dead:
		targets.append(world.player)
	for t in targets:
		var c: Vector3 = (t as Node3D).global_position + Vector3(0, 1.0, 0)
		if Geometry3D.get_closest_point_to_segment(c, from, to).distance_to(c) < 0.65:
			t.take_damage(damage, from)
			global_position = to
			_explode()
			return
	global_position = to


func _explode() -> void:
	var parent := get_parent() as Node3D
	if parent:
		Build.burst(parent, global_position, Color(1.0, 0.3, 0.5), 18, 3.0, 0.25, 0.5)
		Props.blast(get_tree(), global_position, 2.0, 3.0)
	queue_free()
