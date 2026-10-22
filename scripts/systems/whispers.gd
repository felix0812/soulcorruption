class_name Whispers
extends Node
## The souls talk. Every few seconds one held soul whispers to its owner;
## more souls = more frequent and more aggressive whispers.

var world  # World node
var _timer := 10.0


func _process(delta: float) -> void:
	if not Cfg.gb("whispers.enabled") or world == null or world.player == null or world.player.dead:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = interval() * randf_range(0.7, 1.3)
	whisper_now()


func interval() -> float:
	var total := Souls.total()
	var base := Cfg.gf("whispers.base_interval_sec")
	var speedup := clampf(Cfg.gf("whispers.speedup_per_soul"), 0.0, 0.5)
	return maxf(Cfg.gf("whispers.min_interval_sec"), base * pow(1.0 - speedup, total))


## Aggression tier 0..3 derived from the corruption stage.
func tier() -> int:
	var s: int = world.corruption.stage if world.corruption else 0
	return [0, 0, 1, 2, 3][clampi(s, 0, 4)]


func whisper_now() -> void:
	var soul := Souls.random_soul()
	if soul == null:
		return
	var t := tier()
	var line := Lore.whisper(soul, t, Souls.profile_name, Souls.total())
	if t >= 3:
		line = Lore.glitch_text(line, 0.25)
	world.hud.whisper(soul, line, t)
	Sfx.play("whisper", linear_to_db(Cfg.gf("audio.whisper_volume", 0.9)) - 6.0 + t * 2.0, 0.15)
