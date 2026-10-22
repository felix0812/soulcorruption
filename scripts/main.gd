extends Node
## Entry point: sets up input and graphics, switches between the main menu
## and a running game, and hosts the automated self-test (--autotest).

var world: World
var hud: Hud
var menu: MainMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("GPU: %s (%s), API %s, Renderer %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_api_version(), RenderingServer.get_current_rendering_method()])
	if RendererGuard.check(get_tree()):
		return
	add_to_group("settings_listeners")
	_setup_input()
	apply_settings()
	get_tree().root.theme = UIKit.theme()
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		var t = load("res://scripts/autotest.gd").new()
		t.main = self
		add_child(t)
		return
	show_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		Cfg.set_value("graphics.fullscreen", not Cfg.gb("graphics.fullscreen"))
		Cfg.save_config()
		apply_settings()


## Applies window, audio and render settings from the config.
func apply_settings() -> void:
	if DisplayServer.get_name() != "headless":
		var fs := Cfg.gb("graphics.fullscreen")
		var mode := DisplayServer.window_get_mode()
		if fs and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not fs and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if Cfg.gb("graphics.vsync") else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = Cfg.gi("graphics.max_fps")
	get_viewport().scaling_3d_scale = clampf(Cfg.gf("graphics.render_scale", 1.0), 0.5, 1.0)
	Sfx.apply_volume()


# --------------------------------------------------------------------------
# Flow
# --------------------------------------------------------------------------

func _replace_world(menu_mode: bool) -> void:
	if world:
		world.queue_free()
	world = World.new()
	world.menu_mode = menu_mode
	add_child(world)


func show_menu() -> void:
	get_tree().paused = false
	if hud:
		hud.queue_free()
		hud = null
	_replace_world(true)
	Sfx.set_drone(true, 0.9, -18.0)
	menu = MainMenu.new()
	menu.start_requested.connect(start_game)
	menu.quit_requested.connect(quit_game)
	add_child(menu)


func start_game() -> void:
	if Souls.is_banned():
		return
	Souls.ensure_minimum_souls()
	if menu:
		menu.queue_free()
		menu = null
	_replace_world(false)
	hud = Hud.new()
	add_child(hud)
	hud.quit_to_menu.connect(end_to_menu)
	hud.quit_game.connect(quit_game)
	world.run_ended.connect(_on_run_ended)
	world.start_run(hud)


func _on_run_ended(summary: Dictionary) -> void:
	hud.show_end(summary)


func end_to_menu() -> void:
	if world and not world.menu_mode:
		world.quit_run()
	show_menu()


func quit_game() -> void:
	if world and not world.menu_mode:
		world.quit_run()
	Souls.save_now()
	get_tree().quit()


# --------------------------------------------------------------------------
# Input map (physical keys, so it works on QWERTZ/AZERTY alike)
# --------------------------------------------------------------------------

func _setup_input() -> void:
	_action("move_forward", [KEY_W, KEY_UP])
	_action("move_back", [KEY_S, KEY_DOWN])
	_action("move_left", [KEY_A, KEY_LEFT])
	_action("move_right", [KEY_D, KEY_RIGHT])
	_action("dash", [KEY_SPACE, KEY_SHIFT])
	_action("interact", [KEY_E])
	_action("inventory", [KEY_TAB, KEY_I])
	_action("shop", [KEY_B])
	_action("summon", [KEY_G])
	_action("next_wave", [KEY_F])
	_action("console", [KEY_T, KEY_ENTER])
	_action("pause", [KEY_ESCAPE])
	_action("fullscreen", [KEY_F11])
	_action("attack", [], [MOUSE_BUTTON_LEFT])
	_action("bolt", [KEY_Q], [MOUSE_BUTTON_RIGHT])


func _action(action: String, keys: Array, mouse_buttons: Array = []) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in mouse_buttons:
		var m := InputEventMouseButton.new()
		m.button_index = b
		InputMap.action_add_event(action, m)
