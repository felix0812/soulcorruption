class_name UIKit
extends RefCounted
## Shared look & feel for all menus: theme, fonts and small widget helpers.

const ACCENT := Color(0.55, 0.4, 1.0)
const TEXT := Color(0.88, 0.86, 0.95)
const DIM := Color(0.6, 0.57, 0.7)
const SOUL_ICON := preload("res://assets/soul_orb.svg")

const CONTROLS_TEXT := """[b]Bewegung[/b]  W A S D
[b]Kamera[/b]  Maus
[b]Seelenklinge[/b]  Linke Maustaste
[b]Seelenblitz[/b]  Rechte Maustaste
[b]Schattenschritt[/b]  Leertaste / Shift
[b]Altar benutzen[/b]  E
[b]Seelengefäß (Inventar)[/b]  Tab / I
[b]Seelenhandel (Shop)[/b]  B (in Wellenpausen oder am Altar)
[b]Geist beschwören[/b]  G (jüngste Seele)
[b]Nächste Welle rufen[/b]  F
[b]Chat / Befehle[/b]  T oder Enter  (z. B. /soul balance)
[b]Pause[/b]  Esc
[b]Vollbild[/b]  F11"""

static var _theme: Theme
static var _title_font: SystemFont


static func title_font() -> Font:
	if _title_font == null:
		_title_font = SystemFont.new()
		_title_font.font_names = PackedStringArray(["Constantia", "Georgia", "Palatino Linotype", "Times New Roman", "Liberation Serif", "DejaVu Serif", "serif"])
		_title_font.font_weight = 600
	return _title_font


static func _box(bg: Color, border: Color, border_w := 2, radius := 6, margin := 12.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.6
	s.content_margin_bottom = margin * 0.6
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 6
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 19
	var panel := _box(Color(0.045, 0.03, 0.07, 0.94), Color(0.4, 0.28, 0.75, 0.85), 2, 8, 18.0)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("normal", "Button", _box(Color(0.1, 0.07, 0.16), Color(0.35, 0.25, 0.6), 1, 5, 14.0))
	t.set_stylebox("hover", "Button", _box(Color(0.18, 0.11, 0.3), Color(0.6, 0.45, 1.0), 1, 5, 14.0))
	t.set_stylebox("pressed", "Button", _box(Color(0.26, 0.14, 0.42), Color(0.75, 0.6, 1.0), 1, 5, 14.0))
	t.set_stylebox("disabled", "Button", _box(Color(0.07, 0.06, 0.09), Color(0.2, 0.18, 0.25), 1, 5, 14.0))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Color(0.8, 0.7, 1.0, 0.6), 1, 5, 14.0))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.38, 0.45))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("normal", "LineEdit", _box(Color(0.03, 0.02, 0.05, 0.95), Color(0.35, 0.25, 0.6), 1, 4, 10.0))
	t.set_stylebox("focus", "LineEdit", _box(Color(0.03, 0.02, 0.05, 0.95), Color(0.7, 0.55, 1.0), 1, 4, 10.0))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("panel", "ItemList", _box(Color(0.03, 0.02, 0.05, 0.9), Color(0.25, 0.18, 0.45), 1, 4, 8.0))
	t.set_stylebox("hovered", "ItemList", _box(Color(0.2, 0.12, 0.35, 0.8), Color(0, 0, 0, 0), 0, 4, 4.0))
	t.set_stylebox("selected", "ItemList", _box(Color(0.3, 0.16, 0.5, 0.9), Color(0.7, 0.5, 1.0), 1, 4, 4.0))
	t.set_stylebox("selected_focus", "ItemList", _box(Color(0.3, 0.16, 0.5, 0.9), Color(0.8, 0.6, 1.0), 1, 4, 4.0))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", Color(1, 1, 1))
	t.set_constant("v_separation", "ItemList", 6)
	t.set_stylebox("background", "ProgressBar", _box(Color(0.05, 0.03, 0.07, 0.85), Color(0.25, 0.2, 0.35), 1, 3, 0.0))
	t.set_stylebox("fill", "ProgressBar", _box(Color(0.7, 0.12, 0.2), Color(0, 0, 0, 0), 0, 3, 0.0))
	t.set_stylebox("panel", "TooltipPanel", _box(Color(0.05, 0.03, 0.08, 0.97), Color(0.55, 0.4, 1.0), 1, 4, 10.0))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 17)
	_theme = t
	return t


static func label(text: String, size := 19, color := TEXT, title := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if title:
		l.add_theme_font_override("font", title_font())
		l.add_theme_color_override("font_shadow_color", Color(0.35, 0.1, 0.6, 0.8))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 3)
		l.add_theme_constant_override("shadow_outline_size", 8)
	return l


static func rich(text := "", size := 18) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.text = text
	return r


static func button(text: String, callback: Callable, min_width := 260.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 44)
	b.pressed.connect(func():
		Sfx.play("pickup", -14.0, 0.0)
		callback.call())
	return b


static func bar(fill: Color, size: Vector2) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = size
	var fs := StyleBoxFlat.new()
	fs.bg_color = fill
	fs.set_corner_radius_all(3)
	p.add_theme_stylebox_override("fill", fs)
	return p


static func centered_panel(parent: Control, size: Vector2) -> PanelContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	center.add_child(panel)
	return panel


static func dim_background(parent: Control, alpha := 0.55) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.02, alpha)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	return bg


## Sets anchors (0..1) and pixel offsets in one go.
static func place(c: Control, anchors: Vector4, offsets: Vector4) -> void:
	c.anchor_left = anchors.x
	c.anchor_top = anchors.y
	c.anchor_right = anchors.z
	c.anchor_bottom = anchors.w
	c.offset_left = offsets.x
	c.offset_top = offsets.y
	c.offset_right = offsets.z
	c.offset_bottom = offsets.w


static func fmt_time(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]
