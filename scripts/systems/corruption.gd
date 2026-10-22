class_name Corruption
extends Node
## Turns the number of held souls into a corruption stage (0..4) and applies
## its buffs, debuffs and visuals. Also handles the "soulless" state (0 souls).

signal stage_changed(new_stage: int, old_stage: int)

const STAGE_NAMES := ["Rein", "Befleckt", "Verdorben", "Zerrissen", "Verschlungen"]
const STAGE_COLORS := [Color(0.6, 0.9, 1.0), Color(0.75, 0.7, 1.0), Color(0.9, 0.45, 0.9), Color(1.0, 0.3, 0.45), Color(1.0, 0.1, 0.2)]

var world  # World node
var stage := 0
## Smoothed 0..1 value used by all visual effects.
var visual := 0.0
var glitch := 0.0
var _t := 0.0


func _ready() -> void:
	Souls.souls_changed.connect(_on_souls_changed)
	stage = stage_for(Souls.total())
	visual = _target_visual()


static func stage_for(total: int) -> int:
	var s := 0
	for t in Cfg.ga("corruption.thresholds"):
		if total >= int(t):
			s += 1
	return clampi(s, 0, 4)


func _on_souls_changed(total: int) -> void:
	var new_stage := stage_for(total)
	if new_stage != stage:
		var old := stage
		stage = new_stage
		stage_changed.emit(stage, old)
	if world and world.player:
		world.player.recompute_stats()


func soulless() -> bool:
	return Souls.total() == 0 and Cfg.gs("zero_souls.mode") == "debuff"


func damage_mult() -> float:
	var m := Cfg.stage_value("corruption.damage_mult", stage)
	if soulless():
		m *= Cfg.gf("zero_souls.debuff_damage_mult")
	return m


func speed_mult() -> float:
	var m := Cfg.stage_value("corruption.speed_mult", stage)
	if soulless():
		m *= Cfg.gf("zero_souls.debuff_speed_mult")
	return m


func stage_name(s := -1) -> String:
	return STAGE_NAMES[clampi(stage if s < 0 else s, 0, 4)]


func stage_color(s := -1) -> Color:
	return STAGE_COLORS[clampi(stage if s < 0 else s, 0, 4)]


## 0..1 progress from the current threshold to the next one.
func progress() -> float:
	var th := Cfg.ga("corruption.thresholds")
	var total := Souls.total()
	var lo := 0 if stage == 0 else int(th[stage - 1])
	if stage >= th.size():
		return 1.0
	var hi := int(th[stage])
	return clampf(float(total - lo) / float(maxi(1, hi - lo)), 0.0, 1.0)


func next_threshold() -> int:
	var th := Cfg.ga("corruption.thresholds")
	return int(th[stage]) if stage < th.size() else -1


func _target_visual() -> float:
	return clampf((stage + progress() * 0.8) / 4.0, 0.0, 1.0) * Cfg.gf("corruption.visual_intensity", 1.0)


func _process(delta: float) -> void:
	_t += delta
	visual = lerpf(visual, _target_visual(), 1.0 - exp(-delta * 1.5))
	glitch = maxf(0.0, glitch - delta * 1.8)
	# Random micro-glitches at the highest stage.
	if stage >= 4 and randf() < delta * 0.25:
		glitch = maxf(glitch, 0.35)
	if world:
		if world.arena:
			world.arena.set_corruption_tint(visual)
		if world.hud:
			world.hud.set_overlay(visual, glitch, 1.0 if soulless() else 0.0)
	Sfx.set_drone(world != null and world.player != null, 1.0 - 0.25 * visual, -16.0 + 8.0 * visual)


func spike_glitch(amount: float) -> void:
	glitch = maxf(glitch, amount)
