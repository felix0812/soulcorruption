class_name ConsoleUI
extends Control
## Chat input with /soul commands (balance, top, withdraw, shop, list, ...).
## Plain text is "spoken into the void" - and sometimes a soul answers.

var hud  # Hud
var input: LineEdit
var _history: PackedStringArray = []
var _hist_idx := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	input = LineEdit.new()
	UIKit.place(input, Vector4(0, 1, 0, 1), Vector4(24, -72, 664, -30))
	input.placeholder_text = "Nachricht oder Befehl, z. B. /soul balance   (/hilfe)"
	input.text_submitted.connect(_on_submit)
	input.gui_input.connect(_on_input_key)
	add_child(input)


func refresh() -> void:
	input.text = ""
	_hist_idx = -1
	input.grab_focus.call_deferred()


func on_closed() -> void:
	input.release_focus()


func _on_input_key(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_ESCAPE:
			hud.close()
			accept_event()
		KEY_UP:
			if not _history.is_empty():
				_hist_idx = clampi(_hist_idx + 1, 0, _history.size() - 1)
				input.text = _history[_history.size() - 1 - _hist_idx]
				input.caret_column = input.text.length()
			accept_event()
		KEY_DOWN:
			_hist_idx = maxi(-1, _hist_idx - 1)
			input.text = "" if _hist_idx < 0 else _history[_history.size() - 1 - _hist_idx]
			accept_event()


func _on_submit(text: String) -> void:
	text = text.strip_edges()
	hud.close()
	if text == "":
		return
	_history.append(text)
	if text.begins_with("/"):
		run_command(text)
	else:
		hud.chat_line("[color=#ddd]<%s>[/color] %s" % [Souls.profile_name, text.replace("[", "(")])
		# Someone inside you may answer.
		var soul := Souls.random_soul()
		if soul and randf() < 0.6:
			var answer := Lore.whisper(soul, hud.world.whispers.tier(), Souls.profile_name, Souls.total())
			var tier: int = hud.world.whispers.tier()
			var h = hud
			get_tree().create_timer(randf_range(0.8, 2.0), false).timeout.connect(func():
				if is_instance_valid(h):
					h.whisper(soul, answer, tier)
			)


func _say(text: String) -> void:
	hud.chat_line("[color=#b8a8ff]%s[/color]" % text)


## Parses and runs a command. Returns false if unknown.
func run_command(text: String) -> bool:
	var parts := text.substr(1).split(" ", false)
	if parts.is_empty():
		return false
	var cmd := parts[0].to_lower()
	var args := parts.slice(1)
	match cmd:
		"soul", "souls", "seele", "s":
			return _soul_command(args)
		"hilfe", "help", "?":
			_help()
			return true
		"config":
			if not args.is_empty() and args[0] == "reload":
				Cfg.load_config()
				hud.world.player.recompute_stats()
				_say("Config neu geladen aus %s" % Cfg.config_path())
				return true
	_say("Unbekannter Befehl. Tippe /hilfe")
	return false


func _soul_command(args: PackedStringArray) -> bool:
	var sub := args[0].to_lower() if not args.is_empty() else "balance"
	var world = hud.world
	match sub:
		"balance", "bal", "stand":
			var c = world.corruption
			_say("Du trägst %d Seelen (max. %d). Korruption: %s. Gestohlen insgesamt: %d." % [
				Souls.total(), Cfg.gi("souls.max_held"), c.stage_name(), int(Souls.stats.get("souls_stolen", 0))])
		"top", "bestenliste":
			var profiles := Souls.list_profiles()
			profiles.sort_custom(func(a, b): return a.souls > b.souls or (a.souls == b.souls and a.best_wave > b.best_wave))
			_say("— Die verdorbensten Seelendiebe —")
			for i in mini(10, profiles.size()):
				var p: Dictionary = profiles[i]
				_say("%d. %s  ·  %d Seelen  ·  beste Welle %d  ·  %d gestohlen" % [i + 1, p.name, p.souls, p.best_wave, p.stolen])
		"withdraw", "abheben", "drop":
			var n := 1
			if args.size() > 1:
				n = maxi(1, args[1].to_int())
			var done: int = world.withdraw(n)
			if done == 0:
				_say("Du hast keine Seelen, die du freigeben könntest.")
			else:
				_say("%d Seele(n) aus deinem Gefäß gelöst. Sie schweben vor dir." % done)
		"shop", "handel":
			hud.call_deferred("open", hud.shop)
		"list", "liste":
			if Souls.souls.is_empty():
				_say("Dein Gefäß ist leer.")
			for i in Souls.souls.size():
				var s: SoulItem = Souls.souls[i]
				_say("%d. %s%s  [%s, %s]" % [i + 1, s.victim, (" ×%d" % s.count) if s.count > 1 else "", s.kind_label(), s.personality])
		"info":
			var s := _soul_by_index(args)
			if s:
				_say("%s · %s · %s · gestorben %s\n„%s“" % [s.victim, s.kind_label(), s.personality, s.time_text(), s.last_words])
		"summon", "beschwören", "beschwoeren":
			var s := _soul_by_index(args) if args.size() > 1 else Souls.newest()
			if s == null:
				_say("Keine Seele zum Beschwören.")
			else:
				var err: String = world.summon_ghost(s)
				_say(err if err != "" else "Der Geist von %s erhebt sich." % s.victim)
		"release", "freilassen":
			var s := _soul_by_index(args)
			if s:
				world.release_soul(s)
		_:
			_say("Befehle: /soul balance | top | withdraw <n> | shop | list | info <nr> | summon [nr] | release <nr>")
			return false
	return true


func _soul_by_index(args: PackedStringArray) -> SoulItem:
	if args.size() < 2 or not args[1].is_valid_int():
		_say("Bitte eine Nummer aus /soul list angeben.")
		return null
	var i := args[1].to_int() - 1
	if i < 0 or i >= Souls.souls.size():
		_say("Keine Seele mit Nummer %s." % args[1])
		return null
	return Souls.souls[i]


func _help() -> void:
	_say("/soul balance – Seelen & Korruption anzeigen")
	_say("/soul top – Bestenliste aller Profile")
	_say("/soul withdraw <n> – n Seelen als Orbs ablegen")
	_say("/soul shop – Seelenhandel öffnen")
	_say("/soul list · /soul info <nr> – Seelen ansehen")
	_say("/soul summon [nr] – Geist beschwören · /soul release <nr> – Seele freilassen")
	_say("/config reload – config.json neu laden")
