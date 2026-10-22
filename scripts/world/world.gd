class_name World
extends Node3D
## One play session (a "run"). Owns the arena, the player and all systems,
## and implements the core soul rules: stealing on kill, losing on death,
## the zero-souls state and the shop actions.

signal run_ended(summary: Dictionary)

var arena: Arena
var player: Player
var hud  # Hud (CanvasLayer)
var corruption: Corruption
var whispers: Whispers
var hallucinations: Hallucinations
var waves: WaveDirector
var menu_mode := true
var run_kills := 0
var run_stolen := 0
var _menu_cam: Camera3D
var _menu_t := 0.0


func _ready() -> void:
	arena = Arena.new()
	add_child(arena)
	corruption = Corruption.new()
	corruption.world = self
	add_child(corruption)
	if menu_mode:
		_menu_cam = Camera3D.new()
		_menu_cam.fov = 60.0
		add_child(_menu_cam)
		_menu_cam.current = true


func _process(delta: float) -> void:
	if _menu_cam:
		_menu_t += delta * 0.05
		_menu_cam.position = Vector3(cos(_menu_t) * 22.0, 7.0, sin(_menu_t) * 22.0)
		_menu_cam.look_at(Vector3(0, 2.0, 0))


## Everything the game systems iterate over: enemies (incl. phantoms) alive.
func enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies")


func start_run(p_hud) -> void:
	menu_mode = false
	hud = p_hud
	if _menu_cam:
		_menu_cam.queue_free()
		_menu_cam = null
	player = Player.new()
	player.world = self
	player.position = Vector3(0, 0.2, 7.0)
	add_child(player)
	player.died.connect(_on_player_died)
	whispers = Whispers.new()
	whispers.world = self
	add_child(whispers)
	hallucinations = Hallucinations.new()
	hallucinations.world = self
	add_child(hallucinations)
	waves = WaveDirector.new()
	waves.world = self
	add_child(waves)
	waves.wave_started.connect(func(w): hud.announce("Welle %d" % w, Color(0.85, 0.75, 1.0)))
	waves.wave_cleared.connect(_on_wave_cleared)
	corruption.stage_changed.connect(_on_stage_changed)
	Souls.add_stat("runs")
	hud.attach(self)
	waves.start()
	hud.chat_line("[color=#9a8cff]Du betrittst den verfluchten Friedhof. %d Seelen begleiten dich.[/color]" % Souls.total())


# --------------------------------------------------------------------------
# Soul rules
# --------------------------------------------------------------------------

func on_enemy_killed(e: Enemy) -> void:
	run_kills += 1
	Souls.add_stat("kills")
	var chance := Cfg.gf("souls.strong_enemy_soul_chance") if e.is_strong() else Cfg.gf("souls.weak_enemy_soul_chance")
	var count := Cfg.gi("souls.boss_soul_count") if e.is_boss() else 1
	hud.chat_line("[color=#8a8a9a]☠ %s:[/color] [i]„%s“[/i]" % [e.display_name(), e.victim.get("last_words", "…")])
	if randf() > chance:
		return
	for i in count:
		var soul := SoulItem.new()
		soul.victim = e.display_name()
		soul.kind = e.kind
		soul.personality = e.victim.get("personality", "trauernd")
		soul.last_words = e.victim.get("last_words", "…")
		soul.timestamp = int(Time.get_unix_time_from_system())
		soul.wave = waves.wave if waves else 0
		var offset := Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8)) if count > 1 else Vector3.ZERO
		spawn_orb(soul, e.global_position + Vector3(0, 1.2, 0) + offset, Cfg.gf("souls.orb_lifetime_sec"))


func spawn_orb(soul: SoulItem, pos: Vector3, lifetime: float) -> SoulOrb:
	var orb := SoulOrb.new()
	orb.item = soul
	orb.world = self
	orb.lifetime = lifetime
	orb.position = pos  # World is at the origin: local == global.
	add_child(orb)
	return orb


func on_soul_collected(soul: SoulItem) -> void:
	run_stolen += 1
	hud.on_soul_collected(soul)


func _on_player_died() -> void:
	Souls.add_stat("deaths")
	var was_soulless := Souls.total() == 0
	var lost := Souls.take_souls(Cfg.gi("souls.lost_on_death"), "newest")
	var death_pos := player.global_position
	if Cfg.gb("souls.drop_on_death"):
		for s in lost:
			var p := death_pos + Vector3(randf_range(-1.2, 1.2), 1.0, randf_range(-1.2, 1.2))
			spawn_orb(s, p, Cfg.gf("souls.dropped_orb_lifetime_sec"))
	var names := []
	for s in lost:
		names.append(s.victim)
	if Souls.total() == 0:
		if Cfg.gs("zero_souls.mode") == "ban":
			Souls.ban(Cfg.gf("zero_souls.ban_minutes"))
			_end_run("ban")
			return
		if was_soulless:
			_end_run("soulless")
			return
	hud.show_death(names, Cfg.gf("player.respawn_sec"))
	get_tree().create_timer(Cfg.gf("player.respawn_sec"), false).timeout.connect(_respawn)


func _respawn() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.respawn(Arena.ALTAR_POS + Vector3(0, 0.2, 4.5))
	hud.hide_death()
	if corruption.soulless():
		hud.announce("Seelenlos", Color(0.7, 0.7, 0.7))
		hud.chat_line("[color=#aaaaaa]Du hast keine Seele mehr. Du bist schwach, und der nächste Tod ist endgültig.[/color]")


func _on_wave_cleared(w: int) -> void:
	hud.announce("Welle %d überstanden" % w, Color(0.6, 1.0, 0.8))
	hud.chat_line("[color=#7fd]Der Altar ruft. [E] am Altar oder [B] öffnet den Seelenhandel. [F] ruft die nächste Welle.[/color]")


func _on_stage_changed(new_stage: int, old_stage: int) -> void:
	var col := corruption.stage_color(new_stage)
	if new_stage > old_stage:
		hud.announce("Korruption: %s" % corruption.stage_name(new_stage), col)
		corruption.spike_glitch(0.8)
		Sfx.play("whisper", 0.0, 0.0)
		if new_stage == Cfg.gi("corruption.hallucinations_from_stage"):
			hud.chat_line("[color=#ff5a7a]Die Welt beginnt zu lügen. Traue nicht allem, was du siehst.[/color]")
	else:
		hud.announce("Korruption sinkt: %s" % corruption.stage_name(new_stage), col)


func _end_run(reason: String) -> void:
	var summary := {
		"reason": reason,
		"wave": waves.wave if waves else 0,
		"kills": run_kills,
		"stolen": run_stolen,
		"ban_seconds": Souls.ban_seconds_left(),
	}
	Souls.record_wave(summary.wave)
	if reason == "soulless":
		Souls.ensure_minimum_souls()
	Souls.save_now()
	player.controls_enabled = false
	run_ended.emit(summary)


## Ends the run from the pause menu (no penalty).
func quit_run() -> void:
	if waves:
		Souls.record_wave(waves.wave - (1 if waves.phase == WaveDirector.Phase.COMBAT else 0))
	Souls.save_now()


# --------------------------------------------------------------------------
# Actions used by the shop, inventory and /soul commands
# --------------------------------------------------------------------------

func summon_ghost(soul: SoulItem) -> String:
	if not Cfg.gb("minions.enabled"):
		return "Geisterbeschwörung ist in der Config deaktiviert."
	if soul == null or not Souls.souls.has(soul):
		return "Diese Seele besitzt du nicht."
	if get_tree().get_nodes_in_group("minions").size() >= Cfg.gi("minions.max_active"):
		return "Es können nur %d Geister gleichzeitig dienen." % Cfg.gi("minions.max_active")
	var single := Souls.remove_one(soul)
	_spawn_ghost(single)
	return ""


func _spawn_ghost(soul: SoulItem) -> void:
	var g := GhostMinion.new()
	g.soul = soul
	g.world = self
	g.position = player.global_position + player.forward() * -1.5 + Vector3(0, 0.3, 0)
	add_child(g)
	hud.chat_line("[color=#%s][Geist] %s erhebt sich, um dir zu dienen.[/color]" % [soul.color().to_html(false), soul.victim])


## A ghost from the shop's "Geisterpakt": random soul personality, no soul used.
func summon_pact_ghost() -> String:
	if get_tree().get_nodes_in_group("minions").size() >= Cfg.gi("minions.max_active"):
		return "Es können nur %d Geister gleichzeitig dienen." % Cfg.gi("minions.max_active")
	var s := SoulItem.new()
	s.victim = Lore.random_name("hollow")
	s.personality = Lore.PERSONALITIES.pick_random()
	s.kind = "wraith"
	_spawn_ghost(s)
	return ""


## Lets a soul go: it leaves the vessel for good (lowers corruption).
func release_soul(soul: SoulItem) -> String:
	if soul == null or not Souls.souls.has(soul):
		return "Diese Seele besitzt du nicht."
	var single := Souls.remove_one(soul)
	hud.chat_line("[color=#%s]%s:[/color] [i]%s[/i]" % [single.color().to_html(false), single.victim, Lore.ghost_farewell(single, Souls.profile_name)])
	Build.burst(self, player.global_position + Vector3(0, 1.5, 0), single.color(), 40, 2.0, 0.4, 1.5)
	return ""


## Drops souls into the world as orbs (e.g. /soul withdraw).
func withdraw(n: int) -> int:
	var taken := Souls.take_souls(n, "newest")
	for i in taken.size():
		var a := TAU * i / maxf(1.0, taken.size())
		var p := player.global_position + player.forward() * 2.5 + Vector3(cos(a), 0, sin(a)) * 0.9 + Vector3(0, 1.0, 0)
		var orb := spawn_orb(taken[i], p, Cfg.gf("souls.dropped_orb_lifetime_sec"))
		orb.pickup_delay = 4.0  # Grace period so it isn't sucked straight back in.
	return taken.size()


func near_altar() -> bool:
	return player != null and player.global_position.distance_to(Arena.ALTAR_POS) < 5.0
