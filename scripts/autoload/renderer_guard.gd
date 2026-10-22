class_name RendererGuard
extends RefCounted
## Picks the renderer that the PC can handle. Weak or old GPUs (Intel
## integrated graphics, old Vulkan drivers) and PCs where the last start
## crashed get the OpenGL compatibility renderer; everything else keeps the
## Vulkan renderer (Forward+). The choice is written to override.cfg next to
## the exe, which Godot reads at startup, and the game restarts once.

const OVERRIDE := "override.cfg"


static func is_weak_gpu() -> bool:
	var vendor := RenderingServer.get_video_adapter_vendor().to_lower()
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	if vendor.contains("intel") and not gpu.contains("arc"):
		return true
	var api := RenderingServer.get_video_adapter_api_version().split(".")
	return api.size() >= 2 and api[0] == "1" and api[1].to_int() < 3


## Returns true when the game is restarting with another renderer.
static func check(tree: SceneTree) -> bool:
	if OS.has_feature("editor") or DisplayServer.get_name() == "headless":
		return false
	var args := OS.get_cmdline_args()
	if "--autotest" in OS.get_cmdline_user_args() or "--rendering-method" in args or "--rendering-driver" in args:
		return false  # Started explicitly (e.g. by the compatibility .bat).
	var current := RenderingServer.get_current_rendering_method()
	var is_compat := current == "gl_compatibility"
	var want_compat := is_compat
	match Cfg.gs("graphics.renderer", "auto"):
		"opengl":
			want_compat = true
		"vulkan":
			want_compat = false
		_:
			if not is_compat and (is_weak_gpu() or GameLog.crashed_last_time):
				if not Cfg.gb("graphics.auto_compat"):
					print("Renderer: schwache GPU oder Absturz erkannt, wechsle zu OpenGL und senke die Grafikstufe.")
					Cfg.set_value("graphics.auto_compat", true)
					Cfg.set_value("graphics.shadows", false)
					Cfg.set_value("graphics.render_scale", 0.75)
					Cfg.set_value("graphics.particles", 0.6)
					Cfg.save_config()
			want_compat = Cfg.gb("graphics.auto_compat") or is_compat
	if want_compat == is_compat:
		return false
	if "--renderer-switched" in OS.get_cmdline_user_args():
		return false  # Never loop.
	var path := OS.get_executable_path().get_base_dir().path_join(OVERRIDE)
	if want_compat:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			printerr("Renderer: override.cfg kann nicht geschrieben werden: ", path)
			return false
		f.store_string("; Von SoulCorruption geschrieben: Kompatibilitäts-Renderer (OpenGL).\n; Löschen, um wieder Vulkan zu benutzen.\n[rendering]\nrenderer/rendering_method=\"gl_compatibility\"\n")
		f.close()
	else:
		DirAccess.remove_absolute(path)
	print("Renderer: Neustart mit ", "OpenGL" if want_compat else "Vulkan")
	var restart_args := args.duplicate()
	if not "--" in restart_args:
		restart_args.append("--")
	restart_args.append("--renderer-switched")
	OS.set_restart_on_exit(true, restart_args)
	tree.quit()
	return true
