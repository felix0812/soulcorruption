class_name GhostMinion
extends Node3D
## The ghost of a stolen soul, summoned as a temporary companion.
## Floats beside the player, hunts nearby enemies and departs with a
## farewell line when its time is up (the soul is consumed).

var soul: SoulItem
var world  # World node
var hp := 60.0
var max_hp := 60.0
var dmg := 9.0
var life := 40.0
var _attack_cd := 0.0
var _t := 0.0
var _target = null
var _orbit := 0.0
var _leaving := false
var _body: Node3D
var _model: CharacterModel
var _mat: ShaderMaterial


func _ready() -> void:
	add_to_group("minions")
	max_hp = Cfg.gf("minions.hp")
	hp = max_hp
	life = Cfg.gf("minions.duration_sec")
	var stage: int = world.corruption.stage if world and world.corruption else 0
	dmg = Cfg.gf("minions.damage") * (1.0 + 0.1 * stage)
	_orbit = randf() * TAU
	var col := soul.color()
	_mat = Build.soul_mat(col.lerp(Color.WHITE, 0.4), col, 1.6, 0.7)
	_body = Node3D.new()
	add_child(_body)
	# The ghost wears the body of the victim, rendered as translucent soul-stuff.
	var models := {"hollow": "Skeleton_Minion.glb", "wraith": "Skeleton_Rogue.glb", "warden": "Skeleton_Warrior.glb", "knight": "Skeleton_Warrior.glb", "ahne": "Skeleton_Mage.glb"}
	_model = CharacterModel.new()
	_body.add_child(_model)
	_model.setup(models.get(soul.kind, "Skeleton_Mage.glb"), 0.8)
	if soul.kind == "ahne":
		_model.attach("Skeleton_Staff.gltf", "handslot.r")
	else:
		_model.attach("Skeleton_Blade.gltf", "handslot.r")
	_model.set_override(_mat)
	_model.loop("Running_A")
	Build.light(self, col, 1.0, 4.0, Vector3(0, 1.2, 0))
	Build.particles(_body, {
		"amount": 22, "lifetime": 1.2, "velocity": 0.5, "spread": 30.0, "size": 0.3,
		"color": Color(col.r, col.g, col.b, 0.5), "radius": 0.3, "direction": Vector3.DOWN,
		"position": Vector3(0, 0.3, 0),
	})
	Build.label(self, "Geist: %s" % soul.victim, col.lerp(Color.WHITE, 0.5), 26, Vector3(0, 2.2, 0), 14.0)
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK)
	Sfx.play("summon", -3.0)


func radius() -> float:
	return 0.4


func _physics_process(delta: float) -> void:
	if _leaving:
		return
	_t += delta
	life -= delta
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_mat.set_shader_parameter("alpha_scale", 0.55 + 0.15 * sin(_t * 3.0) if life > 4.0 else 0.4 * fmod(_t * 4.0, 1.0))
	if life <= 0.0 or hp <= 0.0:
		depart(hp <= 0.0)
		return
	var player = world.player
	if player == null:
		return
	# Find the nearest enemy near the player.
	if _target == null or not is_instance_valid(_target) or not _target.is_in_group("enemies"):
		_target = null
		var best := 12.0
		for e in world.enemies():
			var d: float = e.global_position.distance_to(player.global_position)
			if d < best:
				best = d
				_target = e
	var goal: Vector3
	if _target:
		goal = _target.global_position
		var dist := Vector2(goal.x - global_position.x, goal.z - global_position.z).length()
		if dist < 1.4 + _target.radius() and _attack_cd <= 0.0:
			_attack_cd = 0.8
			_target.take_hit(dmg, global_position, 2.5)
			_model.once("1H_Melee_Attack_Slice_Diagonal", 1.8)
	else:
		_orbit += delta * 0.8
		goal = player.global_position + Vector3(cos(_orbit), 0, sin(_orbit)) * 2.2
	goal.y = 0.15 + sin(_t * 2.0) * 0.1
	var to := goal - global_position
	var speed := 9.0 if _target else 6.0
	_model.loop("Running_A" if to.length() > 0.4 else "Idle")
	if to.length() > 0.05:
		global_position += to.normalized() * minf(to.length(), speed * delta)
		var flat := Vector2(to.x, to.z)
		if flat.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-delta * 8.0))


func take_damage(amount: float, _from: Vector3) -> void:
	hp -= amount
	Build.burst(world, global_position + Vector3(0, 1, 0), soul.color(), 8, 2.0, 0.2, 0.4)


func depart(destroyed := false) -> void:
	if _leaving:
		return
	_leaving = true
	remove_from_group("minions")
	if world and world.hud:
		var line := Lore.ghost_farewell(soul, Souls.profile_name)
		if destroyed:
			line = "Schon wieder… sterben…"
		world.hud.chat_line("[color=#%s][Geist] %s:[/color] %s" % [soul.color().to_html(false), soul.victim, line])
	Build.burst(world, global_position + Vector3(0, 1.2, 0), soul.color(), 40, 3.0, 0.4, 1.2)
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y + 3.0, 1.2)
	tw.parallel().tween_property(self, "scale", Vector3.ONE * 0.01, 1.2)
	tw.tween_callback(queue_free)
