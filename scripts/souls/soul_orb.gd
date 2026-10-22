class_name SoulOrb
extends Node3D
## A soul lying in the world: the physical form of a SoulItem.
## Glowing orb with a swirling shader, light, wisps and the victim's name.
## Drifts toward the player when close and is absorbed on contact.
## `fake` orbs are hallucinations that dissolve when touched.

const PICKUP_DIST := 1.1
const MAGNET_DIST := 4.0

var item: SoulItem
var world  # World node
var lifetime := 45.0
var fake := false
## Seconds before the orb can be picked up (used for withdrawn souls).
var pickup_delay := 0.0
var _t := 0.0
var _core: MeshInstance3D
var _shell: MeshInstance3D
var _light: OmniLight3D
var _label: Label3D
var _base_y := 0.0
var _collected := false


func _ready() -> void:
	add_to_group("orbs")
	var col := item.color() if item else Color(0.6, 0.9, 1.0)
	_shell = Build.part(self, Build.sphere(0.34, 24), Build.soul_mat(col.lerp(Color.WHITE, 0.5), col, 2.4, 0.85))
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core = Build.part(self, Build.sphere(0.12, 12), Build.glow_mat(col.lerp(Color.WHITE, 0.6), 4.0))
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light = Build.light(self, col, 1.6, 4.5)
	Build.particles(self, {
		"amount": 18, "lifetime": 1.6, "velocity": 0.5, "spread": 180.0, "size": 0.16,
		"color": Color(col.r, col.g, col.b, 0.8), "radius": 0.35, "gravity": Vector3(0, 0.6, 0),
	})
	if item:
		var title := item.victim
		if item.count > 1:
			title += " ×%d" % item.count
		_label = Build.label(self, title, col.lerp(Color.WHITE, 0.4), 30, Vector3(0, 0.75, 0), 12.0)
	_base_y = position.y
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if _collected:
		return
	_t += delta
	lifetime -= delta
	_core.scale = Vector3.ONE * (1.0 + 0.25 * sin(_t * 5.0))
	_shell.rotation.y += delta * 1.2
	position.y = _base_y + 0.15 * sin(_t * 2.2)
	if lifetime < 5.0:
		# Flicker before it fades into nothing.
		visible = fmod(_t, 0.25) > 0.08
		if lifetime <= 0.0:
			_fade_away()
			return
	pickup_delay -= delta
	var player = world.player if world else null
	if player == null or player.dead or pickup_delay > 0.0:
		return
	var target: Vector3 = player.global_position + Vector3(0, 1.0, 0)
	var d := global_position.distance_to(target)
	if d < MAGNET_DIST:
		var pull := (target - global_position).normalized() * (MAGNET_DIST - d + 1.0) * 2.5 * delta
		global_position += pull
		_base_y = position.y - 0.15 * sin(_t * 2.2)
	if d < PICKUP_DIST:
		_collect()


func _collect() -> void:
	if fake:
		_collected = true
		Sfx.play("laugh", -6.0)
		if world.hud:
			world.hud.chat_line("[color=#a070ff]Da war nichts. Da war nie etwas.[/color]")
		_fade_away()
		return
	if Souls.add_soul(item):
		_collected = true
		Sfx.play("pickup", -2.0)
		Build.burst(world, global_position, item.color(), 30, 3.0, 0.3, 0.8)
		world.on_soul_collected(item)
		queue_free()
	else:
		# Vessel is full; the soul keeps hovering and mocks you.
		if world.hud and fmod(_t, 2.0) < 0.05:
			world.hud.actionbar("Dein Seelengefäß ist voll (%d)." % Cfg.gi("souls.max_held"), Color(1, 0.5, 0.5))


func _fade_away() -> void:
	_collected = true
	remove_from_group("orbs")
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.4)
	tw.tween_callback(queue_free)
