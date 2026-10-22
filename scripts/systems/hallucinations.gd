class_name Hallucinations
extends Node
## Strong corruption makes the player see things: fake enemies, fake chat
## messages, short teleports, fake soul orbs and screen flicker.

var world  # World node
var warded_until := 0.0
var _timer := 12.0
var _clock := 0.0


func active() -> bool:
	if world == null or world.corruption == null or world.player == null or world.player.dead:
		return false
	if _clock < warded_until:
		return false
	return world.corruption.stage >= Cfg.gi("corruption.hallucinations_from_stage")


func ward(seconds: float) -> void:
	warded_until = _clock + seconds


func ward_left() -> float:
	return maxf(0.0, warded_until - _clock)


func _process(delta: float) -> void:
	_clock += delta
	if not active():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	var extra: int = world.corruption.stage - Cfg.gi("corruption.hallucinations_from_stage")
	_timer = Cfg.gf("corruption.hallucination_interval_sec") / (1.0 + 0.6 * extra) * randf_range(0.6, 1.4)
	trigger_random()


func trigger_random() -> void:
	var options := {
		"fake_mob": Cfg.gf("corruption.fake_mob_weight"),
		"fake_chat": Cfg.gf("corruption.fake_chat_weight"),
		"teleport": Cfg.gf("corruption.teleport_weight"),
		"fake_orb": Cfg.gf("corruption.fake_orb_weight"),
		"flicker": Cfg.gf("corruption.flicker_weight"),
	}
	var sum := 0.0
	for v in options.values():
		sum += maxf(0.0, v)
	if sum <= 0.0:
		return
	var r := randf() * sum
	for k in options.keys():
		r -= maxf(0.0, options[k])
		if r <= 0.0:
			trigger(k)
			return


func trigger(kind: String) -> void:
	match kind:
		"fake_mob":
			_fake_mob()
		"fake_chat":
			_fake_chat()
		"teleport":
			_teleport()
		"fake_orb":
			_fake_orb()
		"flicker":
			world.corruption.spike_glitch(0.9)
			Sfx.play("whisper", -4.0, 0.4)


func _behind_player(dist: float) -> Vector3:
	var p = world.player
	var back: Vector3 = -p.forward()
	var side := back.cross(Vector3.UP) * randf_range(-0.6, 0.6)
	var pos: Vector3 = p.global_position + (back + side).normalized() * dist
	var flat := Vector2(pos.x, pos.z)
	if flat.length() > Arena.RADIUS - 3.0:
		flat = flat.normalized() * (Arena.RADIUS - 3.0)
	return Vector3(flat.x, 0, flat.y)


func _fake_mob() -> void:
	var kinds := ["hollow", "wraith", "warden"]
	var e := Enemy.new()
	e.setup(kinds.pick_random(), world.waves.wave if world.waves else 1, world, true)
	# Phantoms wear the names of souls you carry.
	var soul := Souls.random_soul()
	if soul:
		e.victim["name"] = soul.victim
	world.add_child(e)
	e.global_position = _behind_player(randf_range(4.0, 7.0))
	Sfx.play("whisper", -2.0, 0.3)


func _fake_chat() -> void:
	var soul := Souls.random_soul()
	var victim := soul.victim if soul else "Niemand"
	var msg := Lore.fake_chat(victim, Souls.profile_name, world.waves.wave if world.waves else 1)
	world.hud.chat_line("[color=#c9c2d8]%s:[/color] %s" % [msg[0], msg[1]])


func _teleport() -> void:
	if world.player.glitch_teleport(Cfg.gf("corruption.teleport_distance")):
		world.corruption.spike_glitch(1.0)
		world.hud.flash_white(0.5)
		Sfx.play("teleport", -3.0)


func _fake_orb() -> void:
	var orb := SoulOrb.new()
	orb.item = Lore.make_starting_soul()
	orb.item.victim = Lore.random_name("hollow")
	orb.item.personality = Lore.PERSONALITIES.pick_random()
	orb.fake = true
	orb.world = world
	orb.lifetime = 20.0
	var p = world.player
	var a := randf() * TAU
	# World root sits at the origin, so local == global here (set before _ready).
	orb.position = p.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(5.0, 8.0) + Vector3(0, 1.0, 0)
	world.add_child(orb)
