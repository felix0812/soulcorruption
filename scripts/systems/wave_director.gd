class_name WaveDirector
extends Node
## Endless waves. Between waves there is a short break in which the altar
## glows and the soul shop is the natural thing to visit.

signal wave_started(wave: int)
signal wave_cleared(wave: int)

enum Phase { BREAK, COMBAT }

var world  # World node
var wave := 0
var phase := Phase.BREAK
var break_left := 6.0
var _queue: Array[String] = []
var _spawn_cd := 0.0
var _alive: Array[Enemy] = []
var boss: Enemy


func start() -> void:
	wave = 0
	phase = Phase.BREAK
	break_left = 6.0
	world.arena.set_altar_active(true)


func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	match phase:
		Phase.BREAK:
			break_left -= delta
			if break_left <= 0.0:
				_begin_wave()
		Phase.COMBAT:
			for i in range(_alive.size() - 1, -1, -1):
				if not is_instance_valid(_alive[i]) or _alive[i].state == Enemy.State.DYING:
					_alive.remove_at(i)
			_spawn_cd -= delta
			if not _queue.is_empty() and _spawn_cd <= 0.0 and _alive.size() < Cfg.gi("waves.max_alive"):
				_spawn(_queue.pop_front())
				_spawn_cd = randf_range(0.6, 1.4) * maxf(0.4, 1.0 - wave * 0.04)
			if _queue.is_empty() and _alive.is_empty():
				_end_wave()


## Lets the player call the next wave early.
func skip_break() -> void:
	if phase == Phase.BREAK and break_left > 0.5:
		break_left = 0.5


func remaining() -> int:
	return _queue.size() + _alive.size()


func _begin_wave() -> void:
	wave += 1
	phase = Phase.COMBAT
	_queue = composition(wave)
	_spawn_cd = 0.5
	world.arena.set_altar_active(false)
	Sfx.play("wave", -2.0, 0.0)
	wave_started.emit(wave)


## Which enemies a wave consists of.
func composition(w: int) -> Array[String]:
	var list: Array[String] = []
	var count := Cfg.gi("waves.base_enemies") + Cfg.gi("waves.enemies_per_wave") * (w - 1)
	var wardens := 0 if w < 2 else 1 + (w - 2) / 2
	var wraiths := 0 if w < 3 else (w - 1) / 2
	for i in wardens:
		list.append("warden")
	for i in wraiths:
		list.append("wraith")
	while list.size() < count:
		list.append("hollow")
	list.shuffle()
	var every := Cfg.gi("waves.boss_every")
	if every > 0 and w % every == 0:
		list.insert(mini(3, list.size()), "knight")
	return list


func _spawn(kind: String) -> void:
	var idx: int = randi() % world.arena.spawn_points.size()
	# Prefer spawn graves away from the player.
	for i in 4:
		var p: Vector3 = world.arena.spawn_points[idx]
		if p.distance_to(world.player.global_position) > 12.0:
			break
		idx = randi() % world.arena.spawn_points.size()
	var pos: Vector3 = world.arena.spawn_points[idx] + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0))
	var e := Enemy.new()
	e.setup(kind, wave, world)
	e.position = pos
	world.add_child(e)
	e.killed.connect(world.on_enemy_killed)
	_alive.append(e)
	world.arena.flash_spawn(idx)
	if e.is_boss():
		boss = e
		world.hud.announce("%s erhebt sich" % e.display_name(), Color(1, 0.3, 0.3))


func _end_wave() -> void:
	phase = Phase.BREAK
	break_left = Cfg.gf("waves.intermission_sec")
	boss = null
	Souls.record_wave(wave)
	world.arena.set_altar_active(true)
	wave_cleared.emit(wave)
