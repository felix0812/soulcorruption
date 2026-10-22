class_name InventoryUI
extends Control
## The soul vessel: lists every held soul item. Hovering or selecting a soul
## shows its personality, time of death and last words.

var hud  # Hud
var list: ItemList
var header: Label
var detail_title: Label
var detail_body: RichTextLabel
var btn_summon: Button
var btn_release: Button
var btn_drop: Button
var _selected: SoulItem
var _items: Array[SoulItem] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIKit.dim_background(self, 0.5)
	var panel := UIKit.centered_panel(self, Vector2(1100, 640))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	header = UIKit.label("Seelengefäß", 30, Color(0.8, 0.95, 1.0), true)
	v.add_child(header)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(470, 480)
	list.fixed_icon_size = Vector2i(34, 34)
	list.icon_mode = ItemList.ICON_MODE_LEFT
	list.add_theme_font_size_override("font_size", 19)
	list.item_selected.connect(_on_selected)
	list.gui_input.connect(_on_list_input)
	h.add_child(list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	h.add_child(right)
	detail_title = UIKit.label("", 28, Color.WHITE, true)
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(detail_title)
	detail_body = UIKit.rich("", 19)
	detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail_body)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	right.add_child(buttons)
	btn_summon = UIKit.button("Geist beschwören", _summon, 180)
	btn_summon.tooltip_text = "Verbraucht diese Seele. Ihr Geist kämpft eine Zeit lang an deiner Seite."
	btn_release = UIKit.button("Freilassen", _release, 140)
	btn_release.tooltip_text = "Die Seele verlässt dich für immer. Senkt die Korruption."
	btn_drop = UIKit.button("Fallen lassen", _drop, 150)
	btn_drop.tooltip_text = "Legt die Seele als Orb in die Welt. Du kannst sie wieder aufheben."
	for b in [btn_summon, btn_release, btn_drop]:
		buttons.add_child(b)
	var footer := HBoxContainer.new()
	v.add_child(footer)
	var hint := UIKit.label("Fahre über eine Seele, um ihre Geschichte zu hören.   [Tab] / [Esc] schließen", 16, UIKit.DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)
	footer.add_child(UIKit.button("Schließen", func(): hud.close(), 160))


func refresh() -> void:
	var c = hud.world.corruption
	header.text = "Seelengefäß  ·  %d / %d Seelen  ·  Korruption: %s" % [Souls.total(), Cfg.gi("souls.max_held"), c.stage_name()]
	list.clear()
	_items.clear()
	# Newest first: the freshest souls are the loudest.
	for i in range(Souls.souls.size() - 1, -1, -1):
		var s: SoulItem = Souls.souls[i]
		_items.append(s)
		var text := s.victim
		if s.count > 1:
			text += "  ×%d" % s.count
		var idx := list.add_item(text, UIKit.SOUL_ICON)
		list.set_item_custom_fg_color(idx, s.color().lerp(Color.WHITE, 0.35))
		list.set_item_icon_modulate(idx, s.color().lerp(Color.WHITE, 0.3))
		list.set_item_tooltip(idx, "%s · %s\n„%s“" % [s.kind_label(), s.personality.capitalize(), s.last_words])
	if _selected == null or not Souls.souls.has(_selected):
		_selected = _items[0] if not _items.is_empty() else null
	if _selected:
		list.select(_items.find(_selected))
	_show(_selected)


func _on_selected(idx: int) -> void:
	_selected = _items[idx]
	_show(_selected)


func _on_list_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var idx := list.get_item_at_position(event.position, true)
		_show(_items[idx] if idx >= 0 else _selected)


func _show(s: SoulItem) -> void:
	var has := s != null
	for b in [btn_summon, btn_release, btn_drop]:
		b.disabled = not has
	if not has:
		detail_title.text = "Leere"
		detail_body.text = "[color=#999]Dein Gefäß ist leer. Ohne Seele bist du schwach.\nTöte starke Gegner, um ihre Seelen zu stehlen.[/color]"
		return
	detail_title.text = s.victim
	detail_title.add_theme_color_override("font_color", s.color().lerp(Color.WHITE, 0.3))
	var col := s.color().to_html(false)
	var lines: PackedStringArray = []
	lines.append("[color=#aaa]Herkunft:[/color] %s%s" % [s.kind_label(), "  (Boss)" if s.is_boss() else ""])
	lines.append("[color=#aaa]Persönlichkeit:[/color] [color=#%s]%s[/color]" % [col, s.personality.capitalize()])
	lines.append("[color=#aaa]Gestorben:[/color] %s%s" % [s.time_text(), ("  ·  Welle %d" % s.wave) if s.wave > 0 else ""])
	if s.count > 1:
		lines.append("[color=#aaa]Anzahl:[/color] %d gleiche Seelen" % s.count)
	lines.append("")
	lines.append("[color=#aaa]Letzte Worte:[/color]")
	lines.append("[i][color=#%s]„%s“[/color][/i]" % [col, s.last_words])
	lines.append("")
	lines.append("[color=#777]Sie flüstert:[/color] [i]%s[/i]" % Lore.whisper(s, 0, Souls.profile_name, Souls.total()))
	detail_body.text = "\n".join(lines)


func _summon() -> void:
	if _selected == null:
		return
	var err: String = hud.world.summon_ghost(_selected)
	if err != "":
		hud.actionbar(err, Color(1, 0.6, 0.6))
		return
	hud.close()


func _release() -> void:
	if _selected == null:
		return
	hud.world.release_soul(_selected)
	refresh()


func _drop() -> void:
	if _selected == null:
		return
	# Drop exactly this soul (one of the stack).
	var single := Souls.remove_one(_selected)
	var p = hud.world.player
	var orb: SoulOrb = hud.world.spawn_orb(single, p.global_position + p.forward() * 2.5 + Vector3(0, 1.0, 0), Cfg.gf("souls.dropped_orb_lifetime_sec"))
	orb.pickup_delay = 4.0
	refresh()
