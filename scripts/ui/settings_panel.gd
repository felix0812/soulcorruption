class_name SettingsPanel
extends VBoxContainer
## Settings shared by the main menu and the pause menu. Every change is
## written to config.json immediately and applied live.

signal back


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	add_child(UIKit.label("Einstellungen", 32, Color(0.8, 0.7, 1.0), true))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	add_child(grid)
	_slider(grid, "Maus-Empfindlichkeit", "controls.mouse_sensitivity", 0.05, 1.0, 0.01)
	_slider(grid, "Gesamtlautstärke", "audio.master_volume", 0.0, 1.0, 0.01)
	_slider(grid, "Flüster-Lautstärke", "audio.whisper_volume", 0.0, 1.0, 0.01)
	_slider(grid, "Sichtfeld (FOV)", "graphics.fov", 55.0, 100.0, 1.0)
	_slider(grid, "Helligkeit", "graphics.brightness", 0.5, 2.0, 0.05)
	_slider(grid, "3D-Auflösung (Leistung)", "graphics.render_scale", 0.5, 1.0, 0.05)
	_slider(grid, "Partikelmenge", "graphics.particles", 0.0, 2.0, 0.1)
	_check(grid, "Vollbild", "graphics.fullscreen")
	_check(grid, "Maus Y invertieren", "controls.invert_y")
	_check(grid, "VSync", "graphics.vsync")
	_check(grid, "Leuchten (Glow)", "graphics.glow")
	_check(grid, "Nebel", "graphics.fog")
	_check(grid, "Schatten", "graphics.shadows")
	_check(grid, "Volumetrischer Nebel (teuer)", "graphics.volumetric_fog")
	var info := UIKit.label("Alle weiteren Werte (Seelen, Korruption, Shop, Wellen …) stehen in config.json.", 15, UIKit.DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	row.add_child(UIKit.button("Spieldaten-Ordner öffnen", func(): OS.shell_open(Cfg.data_dir), 280))
	row.add_child(UIKit.button("Zurück", func(): back.emit(), 160))


func _slider(grid: GridContainer, title: String, path: String, lo: float, hi: float, step: float) -> void:
	grid.add_child(UIKit.label(title, 18))
	var h := HBoxContainer.new()
	grid.add_child(h)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = Cfg.gf(path)
	s.custom_minimum_size = Vector2(260, 28)
	var val := UIKit.label("", 16, UIKit.DIM)
	val.custom_minimum_size = Vector2(60, 0)
	val.text = _fmt(s.value, step)
	s.value_changed.connect(func(v: float):
		val.text = _fmt(v, step)
		Cfg.set_value(path, v)
		_apply())
	h.add_child(s)
	h.add_child(val)


func _check(grid: GridContainer, title: String, path: String) -> void:
	grid.add_child(UIKit.label(title, 18))
	var c := CheckBox.new()
	c.button_pressed = Cfg.gb(path)
	c.toggled.connect(func(on: bool):
		Cfg.set_value(path, on)
		_apply())
	grid.add_child(c)


func _fmt(v: float, step: float) -> String:
	return str(int(v)) if step >= 1.0 else "%.2f" % v


func _apply() -> void:
	Cfg.save_config()
	get_tree().call_group("settings_listeners", "apply_settings")
