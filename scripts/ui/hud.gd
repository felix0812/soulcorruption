class_name Hud
extends CanvasLayer
## In-game interface: corruption overlay, health, souls, corruption stage,
## wave info, chat with whispers, the action bar and all in-game windows
## (soul vessel, shop, console, pause, death and end screens).

signal quit_to_menu
signal quit_game

const OVERLAY_SHADER := preload("res://shaders/corruption_overlay.gdshader")
const CHAT_FADE_SEC := 14.0
const CHAT_MAX := 60

var world  # World node
var root: Control
var overlay_mat: ShaderMaterial
var hp_bar: ProgressBar
var hp_label: Label
var souls_label: Label
var stage_label: Label
var stage_bar: ProgressBar
var wave_label: Label
var boss_box: VBoxContainer
var boss_label: Label
var boss_bar: ProgressBar
var status_label: RichTextLabel
var hint_label: Label
var actionbar_label: Label
var announce_label: Label
var chat: RichTextLabel
var crosshair: Label
var death_panel: Control
var death_label: RichTextLabel
var end_panel: Control

var inventory: InventoryUI
var shop: ShopUI
var console: ConsoleUI
var pause_menu: PauseUI
var open_panel: Control = null
var relic_picker: RelicPicker

var _chat_lines: Array = []  # [text, time]
var _clock := 0.0
var _damage := 0.0
var _flash := 0.0
var _announce_tw: Tween
var _action_tw: Tween


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.theme()
	add_child(root)
	_build_overlay()
	_build_stats()
	_build_center()
	_build_chat()
	inventory = InventoryUI.new()
	inventory.hud = self
	shop = ShopUI.new()
	shop.hud = self
	console = ConsoleUI.new()
	console.hud = self
	pause_menu = PauseUI.new()
	pause_menu.hud = self
	relic_picker = RelicPicker.new()
	relic_picker.hud = self
	for p in [inventory, shop, console, pause_menu, relic_picker]:
		p.visible = false
		root.add_child(p)


func attach(p_world) -> void:
	world = p_world
	Souls.souls_changed.connect(func(_t): _refresh_souls())
	world.player.hp_changed.connect(_on_hp_changed)
	_refresh_souls()
	_on_hp_changed(world.player.hp, world.player.max_hp)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --------------------------------------------------------------------------
# Construction
# --------------------------------------------------------------------------

func _build_overlay() -> void:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_mat = ShaderMaterial.new()
	overlay_mat.shader = OVERLAY_SHADER
	rect.material = overlay_mat
	root.add_child(rect)


func _build_stats() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(28, 24)
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	hp_bar = UIKit.bar(Color(0.72, 0.1, 0.18), Vector2(340, 22))
	box.add_child(hp_bar)
	hp_label = UIKit.label("100 / 100", 16, Color(1, 0.85, 0.85))
	hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_bar.add_child(hp_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var icon := TextureRect.new()
	icon.texture = UIKit.SOUL_ICON
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	souls_label = UIKit.label("Seelen: 0", 26, Color(0.75, 0.95, 1.0), true)
	col.add_child(souls_label)
	stage_label = UIKit.label("Korruption: Rein", 17, Color(0.7, 0.9, 1.0))
	col.add_child(stage_label)
	stage_bar = UIKit.bar(Color(0.6, 0.3, 0.9), Vector2(340, 8))
	box.add_child(stage_bar)
	status_label = UIKit.rich("", 16)
	status_label.custom_minimum_size = Vector2(380, 0)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(status_label)

	# Top centre: wave + boss.
	var top := VBoxContainer.new()
	UIKit.place(top, Vector4(0.5, 0, 0.5, 0), Vector4(-300, 16, 300, 110))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	wave_label = UIKit.label("", 22, Color(0.9, 0.85, 1.0), true)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(wave_label)
	boss_box = VBoxContainer.new()
	boss_box.visible = false
	top.add_child(boss_box)
	boss_label = UIKit.label("", 20, Color(1.0, 0.45, 0.45), true)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_label)
	boss_bar = UIKit.bar(Color(0.8, 0.08, 0.12), Vector2(600, 16))
	boss_box.add_child(boss_bar)


func _build_center() -> void:
	crosshair = UIKit.label("+", 24, Color(0.85, 0.9, 1.0, 0.75))
	UIKit.place(crosshair, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-20, -20, 20, 20))
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)

	announce_label = UIKit.label("", 54, Color.WHITE, true)
	UIKit.place(announce_label, Vector4(0.5, 0, 0.5, 0), Vector4(-700, 160, 700, 240))
	announce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announce_label.modulate.a = 0.0
	announce_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(announce_label)

	actionbar_label = UIKit.label("", 24, Color.WHITE, true)
	UIKit.place(actionbar_label, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-460, 70, 460, 150))
	actionbar_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	actionbar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	actionbar_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	actionbar_label.modulate.a = 0.0
	actionbar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(actionbar_label)

	hint_label = UIKit.label("", 20, Color(0.75, 0.95, 1.0))
	UIKit.place(hint_label, Vector4(0.5, 1, 0.5, 1), Vector4(-400, -100, 400, -64))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint_label)


func _build_chat() -> void:
	chat = UIKit.rich("", 17)
	chat.fit_content = false
	chat.scroll_active = false
	chat.scroll_following = true
	UIKit.place(chat, Vector4(0, 1, 0, 1), Vector4(24, -290, 600, -70))
	chat.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	chat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	chat.add_theme_constant_override("shadow_offset_x", 1)
	chat.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(chat)


# --------------------------------------------------------------------------
# Update
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	_damage = maxf(0.0, _damage - delta * 2.2)
	_flash = maxf(0.0, _flash - delta * 2.5)
	overlay_mat.set_shader_parameter("damage", _damage)
	overlay_mat.set_shader_parameter("flash", _flash)
	if world == null or world.player == null:
		return
	_update_wave()
	_update_status()
	_update_hint()
	if int(_clock * 2.0) != int((_clock - delta) * 2.0):
		_render_chat()


func set_overlay(intensity: float, glitch: float, soulless: float) -> void:
	overlay_mat.set_shader_parameter("intensity", intensity)
	overlay_mat.set_shader_parameter("glitch", glitch)
	overlay_mat.set_shader_parameter("soulless", soulless)


func flash_damage(amount: float) -> void:
	_damage = maxf(_damage, amount)


func flash_white(amount: float) -> void:
	_flash = maxf(_flash, amount)


func _on_hp_changed(hp: float, max_hp: float) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_label.text = "%d / %d" % [ceili(hp), ceili(max_hp)]


func _refresh_souls() -> void:
	if world == null or world.corruption == null:
		return
	var c = world.corruption
	souls_label.text = "Seelen: %d" % Souls.total()
	var nxt: int = c.next_threshold()
	stage_label.text = "Korruption: %s%s" % [c.stage_name(), (" (nächste Stufe ab %d)" % nxt) if nxt > 0 else " (maximal)"]
	stage_label.add_theme_color_override("font_color", c.stage_color())
	stage_bar.value = c.progress() * 100.0
	(stage_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = c.stage_color()
	if c.soulless():
		souls_label.text = "SEELENLOS"
		souls_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	else:
		souls_label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))


func _update_wave() -> void:
	var w = world.waves
	if w == null:
		return
	if w.phase == WaveDirector.Phase.BREAK:
		wave_label.text = "Welle %d naht in %d s  ·  [F] sofort rufen" % [w.wave + 1, ceili(w.break_left)]
	else:
		wave_label.text = "Welle %d  ·  %d Feinde übrig" % [w.wave, w.remaining()]
	var b = w.boss
	if b != null and is_instance_valid(b) and b.state != Enemy.State.DYING:
		boss_box.visible = true
		boss_label.text = b.display_name()
		boss_bar.max_value = b.max_hp
		boss_bar.value = maxf(0.0, b.hp)
	else:
		boss_box.visible = false


func _update_status() -> void:
	var p = world.player
	var lines: PackedStringArray = []
	var cd := func(v: float) -> String: return "[color=#7fd]bereit[/color]" if v <= 0.0 else "[color=#aaa]%.1f s[/color]" % v
	lines.append("[color=#ccc]Seelenblitz[/color] %s   [color=#ccc]Schritt[/color] %s" % [cd.call(p.bolt_cd), cd.call(p.dash_cd)])
	var minions := get_tree().get_nodes_in_group("minions").size()
	if minions > 0:
		lines.append("[color=#9cf]Geister: %d / %d[/color]" % [minions, Cfg.gi("minions.max_active")])
	var ward: float = world.hallucinations.ward_left() if world.hallucinations else 0.0
	if ward > 0.0:
		lines.append("[color=#bdf]Weihwasser: %d s[/color]" % ceili(ward))
	var c = world.corruption
	var dm: float = c.damage_mult()
	if absf(dm - 1.0) > 0.01:
		lines.append("[color=#%s]Schaden ×%.2f · Tempo ×%.2f · Lebensraub %d%%[/color]" % [
			c.stage_color().to_html(false), dm, c.speed_mult(), int(Cfg.stage_value("corruption.lifesteal", c.stage, 0.0) * 100.0)])
	if not world.relics.is_empty():
		var names: Array[String] = []
		for id in world.relics:
			names.append(Relics.title(id, world.relics[id]))
		lines.append("[color=#ffd98a]Relikte: %s[/color]" % ", ".join(names))
	if world.waves and world.waves.event != "":
		var ev: Dictionary = WaveDirector.EVENTS[world.waves.event]
		lines.append("[color=#%s]%s[/color]" % [(ev.color as Color).to_html(false), ev.name])
	status_label.text = "\n".join(lines)


func _update_hint() -> void:
	if world.player.dead:
		hint_label.text = ""
	elif world.near_altar():
		hint_label.text = "Sichere Zone · [E] Seelenaltar: Handel mit dem Jenseits"
	else:
		hint_label.text = ""


# --------------------------------------------------------------------------
# Messages
# --------------------------------------------------------------------------

func chat_line(bbcode: String) -> void:
	_chat_lines.append([bbcode, _clock])
	if _chat_lines.size() > CHAT_MAX:
		_chat_lines.pop_front()
	_render_chat()


func _render_chat() -> void:
	var full := open_panel == console
	var out: PackedStringArray = []
	for entry in _chat_lines:
		if full or _clock - float(entry[1]) < CHAT_FADE_SEC:
			out.append(entry[0])
	if not full and out.size() > 7:
		out = out.slice(out.size() - 7)
	chat.text = "\n".join(out)


func actionbar(text: String, color := Color.WHITE, duration := 3.5) -> void:
	actionbar_label.text = text
	actionbar_label.add_theme_color_override("font_color", color)
	if _action_tw:
		_action_tw.kill()
	actionbar_label.modulate.a = 1.0
	_action_tw = create_tween()
	_action_tw.tween_interval(duration)
	_action_tw.tween_property(actionbar_label, "modulate:a", 0.0, 0.8)


func announce(text: String, color := Color.WHITE) -> void:
	announce_label.text = text
	announce_label.add_theme_color_override("font_color", color)
	if _announce_tw:
		_announce_tw.kill()
	announce_label.modulate.a = 0.0
	announce_label.scale = Vector2.ONE
	_announce_tw = create_tween()
	_announce_tw.tween_property(announce_label, "modulate:a", 1.0, 0.3)
	_announce_tw.tween_interval(1.8)
	_announce_tw.tween_property(announce_label, "modulate:a", 0.0, 0.9)


## A soul whispers: shown in chat and/or the action bar.
func whisper(soul: SoulItem, line: String, tier: int) -> void:
	var col := soul.color().lerp(Color(1.0, 0.15, 0.25), tier / 4.0)
	if Cfg.gb("whispers.show_in_chat"):
		chat_line("[color=#%s][i]%s flüstert:[/i][/color] %s" % [col.to_html(false), soul.victim, line])
	if Cfg.gb("whispers.show_in_actionbar"):
		actionbar("%s: %s" % [soul.victim, line], col, 3.0 + tier * 0.5)


func on_soul_collected(soul: SoulItem) -> void:
	chat_line("[color=#%s]✦ Du hast die Seele von %s gestohlen.[/color] [i]„%s“[/i]" % [soul.color().to_html(false), soul.victim, soul.last_words])
	actionbar("+1 Seele: %s" % soul.victim, soul.color(), 2.0)


func show_death(lost_names: Array, respawn: float) -> void:
	_close_panel()
	if death_panel == null:
		death_panel = Control.new()
		death_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		death_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(death_panel)
		var bg := UIKit.dim_background(death_panel, 0.45)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		death_panel.add_child(center)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		center.add_child(v)
		var t := UIKit.label("DU BIST GEFALLEN", 72, Color(0.85, 0.1, 0.15), true)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		death_label = UIKit.rich("", 22)
		death_label.custom_minimum_size = Vector2(900, 0)
		death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(death_label)
	var lost_txt := "Keine Seele ging verloren." if lost_names.is_empty() else "Verlorene Seelen: [color=#9cf]%s[/color]" % ", ".join(lost_names)
	if not lost_names.is_empty():
		lost_txt += "\n[color=#aaa]%s[/color]" % ("Sie liegen dort, wo du gefallen bist. Hol sie dir zurück." if Cfg.gb("souls.drop_on_death") else "Sie sind für immer fort.")
	death_label.text = "%s\n\n[color=#888]Wiedergeburt am Altar in %d Sekunden…[/color]" % [lost_txt, int(respawn)]
	death_panel.visible = true


func hide_death() -> void:
	if death_panel:
		death_panel.visible = false


## Final screen when the run ends (soulless death or ban).
func show_end(summary: Dictionary) -> void:
	_close_panel()
	hide_death()
	end_panel = Control.new()
	end_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(end_panel)
	UIKit.dim_background(end_panel, 0.75)
	var panel := UIKit.centered_panel(end_panel, Vector2(760, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var banned: bool = summary.get("reason", "") == "ban"
	var title := UIKit.label("VERBANNT" if banned else "SEELENLOS", 64, Color(0.9, 0.15, 0.2), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var txt := ""
	if banned:
		txt = "Deine letzte Seele ist zerfallen. Das Jenseits verweigert dir den Zutritt.\nDu kannst in [b]%s[/b] zurückkehren." % UIKit.fmt_time(int(summary.get("ban_seconds", 0)))
	else:
		txt = "Ohne Seele bist du ein zweites Mal gestorben. Dein Lauf endet hier.\nDie Ahnen schenken dir neue Seelen für den nächsten Versuch."
	txt += "\n\n[color=#bbb]Erreichte Welle:[/color] %d    [color=#bbb]Getötet:[/color] %d    [color=#bbb]Seelen gestohlen:[/color] %d" % [
		int(summary.get("wave", 0)), int(summary.get("kills", 0)), int(summary.get("stolen", 0))]
	var body := UIKit.rich(txt, 20)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(body)
	var btn := UIKit.button("Zum Hauptmenü", func(): quit_to_menu.emit())
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(btn)
	btn.grab_focus()
	# Freeze the world behind the summary.
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --------------------------------------------------------------------------
# Window handling & input
# --------------------------------------------------------------------------

func is_panel_open() -> bool:
	return open_panel != null


func open(panel: Control) -> void:
	if world == null or world.player == null or world.player.dead or end_panel != null:
		return
	if open_panel and open_panel != panel:
		open_panel.visible = false
	open_panel = panel
	panel.visible = true
	if panel.has_method("refresh"):
		panel.refresh()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_render_chat()


func _close_panel() -> void:
	if open_panel:
		open_panel.visible = false
		if open_panel.has_method("on_closed"):
			open_panel.on_closed()
	open_panel = null
	get_tree().paused = false
	if end_panel == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_render_chat()


func close() -> void:
	_close_panel()


func toggle(panel: Control) -> void:
	if open_panel == panel:
		_close_panel()
	else:
		open(panel)


func try_open_shop() -> void:
	var w = world.waves
	if world.near_altar() or (w and w.phase == WaveDirector.Phase.BREAK):
		open(shop)
	else:
		actionbar("Der Altar ist fern. Handel nur am Altar oder in Wellenpausen.", Color(0.8, 0.7, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if world == null or world.player == null or end_panel != null:
		return
	if open_panel == console:
		return  # The console's LineEdit handles its own keys.
	if open_panel == relic_picker:
		return  # A relic has to be chosen.
	if event.is_action_pressed("pause"):
		if open_panel:
			_close_panel()
		else:
			open(pause_menu)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory"):
		toggle(inventory)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("shop"):
		if open_panel == shop:
			_close_panel()
		elif open_panel == null:
			try_open_shop()
		get_viewport().set_input_as_handled()
		return
	if open_panel:
		return
	if event.is_action_pressed("console"):
		open(console)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and world.near_altar():
		open(shop)
	elif event.is_action_pressed("summon"):
		var s := Souls.newest()
		var err: String = world.summon_ghost(s) if s else "Du hast keine Seele, die dir dienen könnte."
		if err != "":
			actionbar(err, Color(1, 0.6, 0.6))
	elif event.is_action_pressed("next_wave"):
		world.waves.skip_break()
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
