class_name MainMenu
extends Control
## Title screen over the slowly orbiting graveyard: profile selection,
## start, settings, controls, leaderboard and quit.

signal start_requested
signal quit_requested

var main_box: VBoxContainer
var settings: SettingsPanel
var controls: VBoxContainer
var leaderboard: VBoxContainer
var board_text: RichTextLabel
var name_edit: LineEdit
var profile_text: RichTextLabel
var start_btn: Button
var _panel_host: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.02, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var left := VBoxContainer.new()
	UIKit.place(left, Vector4(0, 0, 0, 1), Vector4(90, 70, 690, -40))
	left.add_theme_constant_override("separation", 14)
	add_child(left)
	var title := UIKit.label("SoulCorruption", 84, Color(0.78, 0.93, 1.0), true)
	left.add_child(title)
	left.add_child(UIKit.label("Jede Seele hat eine Stimme. Und sie hört nie auf zu reden.", 20, Color(0.75, 0.68, 0.9)))

	_panel_host = PanelContainer.new()
	_panel_host.custom_minimum_size = Vector2(600, 0)
	left.add_child(_panel_host)
	var stack := VBoxContainer.new()
	_panel_host.add_child(stack)

	main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 10)
	stack.add_child(main_box)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	main_box.add_child(name_row)
	name_row.add_child(UIKit.label("Profil:", 19))
	name_edit = LineEdit.new()
	name_edit.text = Souls.profile_name
	name_edit.max_length = 20
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_submitted.connect(func(_t): _load_profile())
	name_row.add_child(name_edit)
	name_row.add_child(UIKit.button("Laden", _load_profile, 110))
	profile_text = UIKit.rich("", 18)
	main_box.add_child(profile_text)
	start_btn = UIKit.button("Spiel starten", func(): start_requested.emit(), 560)
	main_box.add_child(start_btn)
	main_box.add_child(UIKit.button("Einstellungen", func(): _show(settings), 560))
	main_box.add_child(UIKit.button("Steuerung & Regeln", func(): _show(controls), 560))
	main_box.add_child(UIKit.button("Bestenliste", func(): _show_board(), 560))
	main_box.add_child(UIKit.button("Beenden", func(): quit_requested.emit(), 560))

	settings = SettingsPanel.new()
	settings.back.connect(func(): _show(main_box))
	stack.add_child(settings)

	controls = VBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	controls.add_child(UIKit.label("Steuerung & Regeln", 30, Color(0.8, 0.7, 1.0), true))
	controls.add_child(UIKit.rich(UIKit.CONTROLS_TEXT + "\n\n" + _rules_text(), 17))
	controls.add_child(UIKit.button("Zurück", func(): _show(main_box), 160))
	stack.add_child(controls)

	leaderboard = VBoxContainer.new()
	leaderboard.add_theme_constant_override("separation", 10)
	leaderboard.add_child(UIKit.label("Bestenliste", 30, Color(0.8, 0.7, 1.0), true))
	board_text = UIKit.rich("", 18)
	leaderboard.add_child(board_text)
	leaderboard.add_child(UIKit.button("Zurück", func(): _show(main_box), 160))
	stack.add_child(leaderboard)

	var footer := UIKit.label("", 14, Color(0.5, 0.47, 0.58))
	UIKit.place(footer, Vector4(0, 1, 1, 1), Vector4(24, -34, -24, -10))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.text = "v%s  ·  Spieldaten: %s%s" % [ProjectSettings.get_setting("application/config/version", "1.0"), Cfg.data_dir, "" if Cfg.portable else "  (nicht portabel: Ordner der .exe ist schreibgeschützt)"]
	add_child(footer)
	if GameLog.crashed_last_time:
		var warn := UIKit.label("Das Spiel wurde zuletzt nicht normal beendet. Falls es abstürzt: „Start_Kompatibilitaetsmodus.bat“ benutzen\nund die Datei aus SoulCorruption_Daten\\logs schicken.", 15, Color(1.0, 0.7, 0.45))
		UIKit.place(warn, Vector4(0, 1, 1, 1), Vector4(24, -80, -24, -40))
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(warn)

	_show(main_box)
	_refresh_profile()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_btn.grab_focus.call_deferred()


func _process(_delta: float) -> void:
	# Live ban countdown.
	if Souls.is_banned() or start_btn.disabled:
		_refresh_profile()


func _rules_text() -> String:
	return """[b]Seelen[/b]: Du beginnst mit %d Seelen. Starke Gegner (Grabwächter, Ritter) lassen immer ihre Seele fallen, schwache nur selten. Jede Seele trägt Namen, Persönlichkeit und letzte Worte ihres Opfers.
[b]Tod[/b]: Jeder Tod kostet %d Seele(n). Ohne Seelen bist du [i]seelenlos[/i] (oder wirst verbannt, siehe config.json).
[b]Korruption[/b]: Ab %s Seelen steigt deine Korruption. Du wirst stärker, aber zerbrechlicher. Die Seelen flüstern lauter, und irgendwann lügt dir die Welt ins Gesicht.""" % [
		Cfg.gi("souls.start_count"), Cfg.gi("souls.lost_on_death"), ", ".join(Cfg.ga("corruption.thresholds").map(func(x): return str(int(x))))]


func _load_profile() -> void:
	Souls.load_profile(name_edit.text)
	name_edit.text = Souls.profile_name
	_refresh_profile()


func _refresh_profile() -> void:
	var st := Souls.stats
	var stage := Corruption.stage_for(Souls.total())
	var txt := "[color=#9cf]%d Seelen[/color]  ·  Korruption: [color=#%s]%s[/color]  ·  beste Welle %d  ·  %d Kills" % [
		Souls.total(), Corruption.STAGE_COLORS[stage].to_html(false), Corruption.STAGE_NAMES[stage],
		int(st.get("best_wave", 0)), int(st.get("kills", 0))]
	if Souls.is_banned():
		txt += "\n[color=#f55]Verbannt! Rückkehr möglich in %s[/color]" % UIKit.fmt_time(Souls.ban_seconds_left())
		start_btn.disabled = true
	else:
		start_btn.disabled = false
	profile_text.text = txt


func _show_board() -> void:
	var profiles := Souls.list_profiles()
	profiles.sort_custom(func(a, b): return a.souls > b.souls or (a.souls == b.souls and a.best_wave > b.best_wave))
	var lines: PackedStringArray = []
	for i in mini(10, profiles.size()):
		var p: Dictionary = profiles[i]
		lines.append("%d.  [b]%s[/b]  ·  %d Seelen  ·  beste Welle %d  ·  %d gestohlen" % [i + 1, p.name, p.souls, p.best_wave, p.stolen])
	board_text.text = "\n".join(lines) if not lines.is_empty() else "Noch keine Einträge."
	_show(leaderboard)


func _show(which: Control) -> void:
	for c in [main_box, settings, controls, leaderboard]:
		c.visible = c == which
