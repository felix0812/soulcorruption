class_name PauseUI
extends Control
## Pause menu with settings, controls overview and run exit.

var hud  # Hud
var main_box: VBoxContainer
var settings: SettingsPanel
var controls: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIKit.dim_background(self, 0.6)
	var panel := UIKit.centered_panel(self, Vector2(620, 0))
	var stack := VBoxContainer.new()
	panel.add_child(stack)

	main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 12)
	stack.add_child(main_box)
	var t := UIKit.label("Pause", 44, Color(0.8, 0.7, 1.0), true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_box.add_child(t)
	for b in [
		UIKit.button("Fortsetzen", func(): hud.close()),
		UIKit.button("Einstellungen", func(): _show(settings)),
		UIKit.button("Steuerung", func(): _show(controls)),
		UIKit.button("Lauf beenden (zum Hauptmenü)", func(): hud.quit_to_menu.emit()),
		UIKit.button("Spiel beenden", func(): hud.quit_game.emit()),
	]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.custom_minimum_size.x = 420
		main_box.add_child(b)
	var note := UIKit.label("Seelen und Verbesserungen werden automatisch gespeichert.", 15, UIKit.DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_box.add_child(note)

	settings = SettingsPanel.new()
	settings.back.connect(func(): _show(main_box))
	stack.add_child(settings)

	controls = VBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	controls.add_child(UIKit.label("Steuerung", 32, Color(0.8, 0.7, 1.0), true))
	controls.add_child(UIKit.rich(UIKit.CONTROLS_TEXT, 18))
	controls.add_child(UIKit.button("Zurück", func(): _show(main_box), 160))
	stack.add_child(controls)
	_show(main_box)


func refresh() -> void:
	_show(main_box)


func _show(which: Control) -> void:
	for c in [main_box, settings, controls]:
		c.visible = c == which
