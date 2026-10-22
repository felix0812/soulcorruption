extends Node
## Automated self-test that plays through every system once.
## Run:  godot --path . -- --autotest [--shots=<dir>]
## Exits with code 0 when everything works, 1 otherwise. Used by CI.

var main  # main.gd
var shots_dir := ""
var failures: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
			DirAccess.make_dir_recursive_absolute(shots_dir)
	if "--bench" in OS.get_cmdline_user_args():
		_bench.call_deferred()
	elif "--soak" in OS.get_cmdline_user_args():
		_soak.call_deferred()
	else:
		_run.call_deferred()


## Plays several waves naturally (breaks, spawns, boss, safe zone, physics)
## to catch crashes that only show up over time: `-- --autotest --soak`.
func _soak() -> void:
	main = get_parent()
	Cfg.set_value("waves.intermission_sec", 4.0)
	Cfg.set_value("waves.boss_every", 3)
	main.start_game()
	await wait(1.0)
	var w: World = main.world
	var t := 0.0
	while t < 150.0 and w.waves.wave < 6:
		w.player.invulnerable = 99.0
		if w.waves.phase == WaveDirector.Phase.BREAK:
			w.player.global_position = Vector3(0, 0.2, 3)  # Wait in the safe zone.
		else:
			var es: Array = w.enemies()
			if not es.is_empty():
				var e = es[randi() % es.size()]
				if e.state != Enemy.State.RISING:
					w.player.global_position = e.global_position + Vector3(0, 0.2, 2.0)
					e.take_hit(40.0, w.player.global_position, 3.0)
		await wait(0.5)
		t += 0.5
	print("soak reached wave %d after %.0fs, nodes=%d" % [w.waves.wave, t, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	get_tree().quit(0 if w.waves.wave >= 4 else 1)


## Performance probe: `-- --autotest --bench` prints frame and render stats
## with a crowd of enemies on screen.
func _bench() -> void:
	main = get_parent()
	main.start_game()
	await wait(1.0)
	var w: World = main.world
	w.player.cam_yaw = PI
	var kinds := ["hollow", "wraith", "warden", "hollow", "wraith"]
	for i in 16:
		var e := Enemy.new()
		e.setup(kinds[i % kinds.size()], 3, w)
		e.position = Vector3(randf_range(-14, 14), 0, randf_range(9, 20))
		w.add_child(e)
	await wait(3.0)
	for i in 6:
		for e in w.enemies():
			if i % 2 == 0 and randf() < 0.3:
				e.take_hit(99999.0, w.player.global_position, 1.0)
		var t0 := Time.get_ticks_usec()
		var frames := Engine.get_frames_drawn()
		await wait(1.0)
		var fps := (Engine.get_frames_drawn() - frames) / ((Time.get_ticks_usec() - t0) / 1e6)
		print("bench fps=%.1f draws=%d objects=%d prims=%d proc=%.2fms phys=%.2fms bodies=%d nodes=%d" % [
			fps,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	var counts := {}
	for mi in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var owner_name := "?"
		var n: Node = mi
		while n and n.get_parent() != w and n != get_tree().root:
			n = n.get_parent()
		if n:
			owner_name = n.get_class() + ":" + (n.get_script().get_global_name() if n.get_script() else "")
		var key := owner_name + " " + mi.get_class()
		counts[key] = counts.get(key, 0) + 1
	print("bench geometry: ", counts)
	get_tree().quit(0)


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures.append(msg)
		printerr("  FAIL ", msg)


func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout


func shot(file: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join(file + ".png"))
	print("  shot ", file)


func _fresh_profile() -> void:
	Souls.load_profile("Autotest")
	Souls.souls.clear()
	Souls.upgrades = {}
	Souls.stats = Souls._empty_stats()
	Souls.banned_until = 0
	Souls.grant_starting_souls()
	Souls.save_now()


func _fake_soul(n: int) -> void:
	for i in n:
		var s := SoulItem.new()
		s.victim = Lore.random_name("warden")
		s.kind = "warden"
		var v := Lore.make_victim("warden")
		s.personality = v.personality
		s.last_words = v.last_words
		s.timestamp = int(Time.get_unix_time_from_system())
		s.wave = 1
		Souls.add_soul(s)


func _run() -> void:
	print("== SoulCorruption autotest ==")
	print("data dir: ", Cfg.data_dir)
	var original_config: Dictionary = Cfg.data.duplicate(true)
	Cfg.set_value("zero_souls.mode", "debuff")
	_fresh_profile()
	var start := Cfg.gi("souls.start_count")
	check(Souls.total() == start, "profile starts with %d souls" % start)

	main.show_menu()
	await wait(1.5)
	check(main.menu != null, "main menu shown")
	await shot("01_menu")

	main.start_game()
	await wait(1.0)
	var w: World = main.world
	check(w.player != null and not w.player.dead, "player spawned")
	w.waves.skip_break()
	await wait(2.0)
	check(w.waves.wave == 1, "wave 1 started")
	await wait(1.5)
	w.player.cam_yaw = PI  # Look toward the spawn graves.
	await shot("02_wave1")

	# Clear the wave; weak enemies drop souls during the test.
	Cfg.set_value("souls.weak_enemy_soul_chance", 1.0)
	for i in 40:
		for e in w.enemies():
			if e.state != Enemy.State.RISING:
				e.take_hit(99999.0, w.player.global_position, 1.0)
		await wait(0.4)
		if w.waves.phase == WaveDirector.Phase.BREAK:
			break
	check(w.waves.phase == WaveDirector.Phase.BREAK, "wave 1 cleared")
	check(get_tree().get_nodes_in_group("props").size() > 30, "physics props placed (%d)" % get_tree().get_nodes_in_group("props").size())
	check(get_tree().get_nodes_in_group("debris").size() > 0, "skeletons burst into physical bones")
	var prop := get_tree().get_nodes_in_group("props")[0] as RigidBody3D
	var prop_pos := prop.global_position
	Props.blast(get_tree(), prop_pos + Vector3(0.5, 0, 0), 3.0, 8.0)
	await wait(0.4)
	check(prop.global_position.distance_to(prop_pos) > 0.2, "blast moves physics props")
	var orbs := get_tree().get_nodes_in_group("orbs")
	check(orbs.size() > 0, "soul orbs dropped (%d)" % orbs.size())
	if orbs.size() > 0:
		w.player.global_position = (orbs[0] as Node3D).global_position - Vector3(0, 1.0, 2.5)
		w.player.cam_yaw = 0.0
		await wait(0.2)
		await shot("03_soul_orb")
	for o in get_tree().get_nodes_in_group("orbs"):
		if not is_instance_valid(o):
			continue
		w.player.global_position = (o as Node3D).global_position - Vector3(0, 1.0, 0)
		await wait(0.25)
	await wait(0.5)
	check(Souls.total() > start, "souls stolen on pickup (now %d)" % Souls.total())
	check(w.run_stolen > 0, "run statistics count stolen souls")

	# Inventory.
	w.player.global_position = Vector3(0, 0.2, 7)
	main.hud.open(main.hud.inventory)
	await wait(0.3)
	check(get_tree().paused, "inventory pauses the game")
	check(main.hud.inventory.list.item_count > 0, "inventory lists souls")
	await shot("04_inventory")
	main.hud.close()
	check(not get_tree().paused, "closing inventory resumes")

	# Shop.
	_fake_soul(10)
	var before := Souls.total()
	main.hud.open(main.hud.shop)
	await wait(0.3)
	await shot("05_shop")
	check(ShopUI.purchase(w, "blade") == "", "buy blade upgrade")
	check(Souls.upgrade("blade") == 1, "upgrade stored")
	check(Souls.total() == before - Cfg.gi("shop.blade_cost"), "souls spent as currency")
	check(ShopUI.purchase(w, "holywater") == "", "buy holy water")
	check(w.hallucinations.ward_left() > 0.0, "holy water wards hallucinations")
	w.hallucinations.warded_until = 0.0
	main.hud.close()

	# Console commands.
	var con: ConsoleUI = main.hud.console
	for cmd in ["/soul balance", "/soul top", "/soul list", "/soul info 1", "/hilfe"]:
		check(con.run_command(cmd), "command " + cmd)
	before = Souls.total()
	check(con.run_command("/soul withdraw 2"), "command /soul withdraw 2")
	check(Souls.total() == before - 2, "withdraw removed 2 souls")
	check(not con.run_command("/quatsch"), "unknown command rejected")

	# Ghost minion.
	check(w.summon_ghost(Souls.newest()) == "", "summon ghost")
	await wait(0.5)
	check(get_tree().get_nodes_in_group("minions").size() == 1, "ghost minion exists")

	# Corruption stages.
	_fake_soul(46 - Souls.total())
	await wait(2.5)
	check(w.corruption.stage == 4, "46 souls = corruption stage 4 (got %d)" % w.corruption.stage)
	check(w.corruption.damage_mult() > 1.5, "corruption buffs damage")
	check(w.player.max_hp < Cfg.gf("player.max_hp") * 1.6, "corruption reduces max hp")
	w.whispers.whisper_now()
	await wait(0.5)
	await shot("06_corruption")

	# Hallucinations.
	check(w.hallucinations.active(), "hallucinations active at stage 4")
	w.hallucinations.trigger("fake_mob")
	check(get_tree().get_nodes_in_group("phantoms").size() > 0, "phantom enemy spawned")
	for k in ["fake_chat", "teleport", "fake_orb", "flicker"]:
		w.hallucinations.trigger(k)
		await wait(0.2)
	await wait(1.2)
	await shot("07_hallucination")
	for p in get_tree().get_nodes_in_group("phantoms"):
		p.take_hit(10.0, w.player.global_position, 1.0)
	await wait(0.6)
	check(get_tree().get_nodes_in_group("phantoms").size() == 0, "phantoms dissolve when hit")

	# Boss.
	w.waves.skip_break()
	await wait(1.5)
	var knight := Enemy.new()
	knight.setup("knight", 5, w)
	knight.position = Vector3(0, 0, -8)
	w.add_child(knight)
	knight.killed.connect(w.on_enemy_killed)
	w.waves.boss = knight
	w.player.global_position = Vector3(0, 0.2, 2)
	w.player.cam_yaw = 0.0
	await wait(2.0)
	await shot("08_boss")
	knight.take_hit(99999.0, w.player.global_position, 1.0)
	await wait(0.5)
	check(get_tree().get_nodes_in_group("orbs").size() >= Cfg.gi("souls.boss_soul_count"), "boss drops %d souls" % Cfg.gi("souls.boss_soul_count"))

	# Safe zone at the altar.
	w.player.global_position = Vector3(0, 0.2, 3)
	await wait(0.2)
	check(w.near_altar(), "altar area counts as shop/safe zone")
	var hp_before: float = w.player.hp
	w.player.invulnerable = 0.0
	w.player.take_damage(50.0, Vector3(0, 0, 8))
	check(is_equal_approx(w.player.hp, hp_before), "no damage inside the safe zone")
	var intruder := Enemy.new()
	intruder.setup("hollow", 1, w)
	intruder.position = Vector3(0, 0, 4)
	w.add_child(intruder)
	await wait(2.5)
	var ir := Vector2(intruder.global_position.x, intruder.global_position.z).length()
	check(ir >= Arena.safe_radius(), "enemies cannot enter the safe zone (r=%.1f)" % ir)
	intruder.take_hit(99999.0, w.player.global_position, 1.0)

	# Death: lose souls, respawn.
	w.player.global_position = Vector3(10, 0.2, 10)
	await wait(0.1)
	before = Souls.total()
	w.player.invulnerable = 0.0
	w.player.take_damage(99999.0, Vector3.ZERO)
	check(w.player.dead, "player can die")
	check(Souls.total() == before - Cfg.gi("souls.lost_on_death"), "death costs souls")
	await wait(0.5)
	await shot("09_death")
	await wait(Cfg.gf("player.respawn_sec") + 0.5)
	check(not w.player.dead, "player respawned")

	# Persistence.
	Souls.save_now()
	var saved_total := Souls.total()
	Souls.load_profile("Autotest")
	check(Souls.total() == saved_total, "profile saved and loaded (%d souls)" % saved_total)
	check(Souls.upgrade("blade") == 1, "upgrades persisted")

	# Zero souls -> soulless -> run ends on next death.
	Souls.take_souls(Souls.total())
	await wait(0.3)
	check(w.corruption.soulless(), "0 souls = soulless state")
	check(w.corruption.speed_mult() < 1.0, "soulless debuff applies")
	var ended := [false]
	w.run_ended.connect(func(_s): ended[0] = true)
	for o in get_tree().get_nodes_in_group("orbs"):
		o.queue_free()  # No stray souls to pick up.
	w.player.global_position = Vector3(-12, 0.2, 9)  # Outside the safe zone.
	await wait(0.1)
	w.player.invulnerable = 0.0
	w.player.take_damage(99999.0, Vector3.ZERO)
	await wait(0.5)
	check(ended[0], "dying while soulless ends the run")
	await shot("10_end")
	check(Souls.total() == start, "fresh starting souls after soulless run")

	# Ban mode.
	Cfg.set_value("zero_souls.mode", "ban")
	main.end_to_menu()
	await wait(0.5)
	main.start_game()
	await wait(1.0)
	w = main.world
	Souls.take_souls(Souls.total())
	w.player.global_position = Vector3(10, 0.2, 10)  # Outside the safe zone.
	await wait(0.1)
	w.player.invulnerable = 0.0
	w.player.take_damage(99999.0, Vector3.ZERO)
	await wait(0.5)
	check(Souls.is_banned(), "ban mode bans at 0 souls")
	Souls.banned_until = 0
	Souls.ensure_minimum_souls()
	Cfg.data = original_config  # Restore the real config values.
	Cfg.save_config()
	main.end_to_menu()
	await wait(0.5)

	print("== autotest finished: %d failure(s) ==" % failures.size())
	for f in failures:
		printerr("   - ", f)
	get_tree().quit(0 if failures.is_empty() else 1)
