extends Node
## Global configuration ("Cfg").
##
## Every tunable value of the game lives here. On start the file
## `<data dir>/config.json` is read, missing keys are filled with defaults and
## the merged result is written back, so the player always sees every option.
##
## The data dir is a folder next to the .exe (portable mode). If that folder
## is not writable (e.g. the game sits in "Program Files"), we fall back to the
## per-user directory so the game still works.

signal changed

const FILE_NAME := "config.json"
const DATA_FOLDER := "SoulCorruption_Daten"

var data: Dictionary = {}
var data_dir: String = ""
var portable := true
var game_log: GameLog


func _init() -> void:
	data_dir = _resolve_data_dir()
	if not OS.has_feature("editor"):
		game_log = GameLog.install(data_dir)
		if game_log:
			game_log.write("SoulCorruption %s · %s · %s · Renderer %s" % [
				ProjectSettings.get_setting("application/config/version"), OS.get_name(), OS.get_processor_name(),
				ProjectSettings.get_setting("rendering/renderer/rendering_method")])
	load_config()


func _exit_tree() -> void:
	if game_log:
		game_log.close()


# --------------------------------------------------------------------------
# Defaults
# --------------------------------------------------------------------------

static func defaults() -> Dictionary:
	return {
		"_hilfe": "Alle Werte können frei angepasst werden. Fehlende Einträge werden beim Start ergänzt. Löschen setzt auf Standard zurück.",
		"souls": {
			"start_count": 3,
			"stackable": true,
			"max_held": 99,
			"lost_on_death": 1,
			"drop_on_death": true,
			"dropped_orb_lifetime_sec": 120.0,
			"orb_lifetime_sec": 45.0,
			"weak_enemy_soul_chance": 0.12,
			"strong_enemy_soul_chance": 1.0,
			"boss_soul_count": 3,
		},
		"zero_souls": {
			"_modus_info": "debuff = Seelenlos-Zustand (nächster Tod beendet den Lauf), ban = Verbannung für ban_minutes",
			"mode": "debuff",
			"ban_minutes": 5.0,
			"debuff_speed_mult": 0.65,
			"debuff_damage_mult": 0.5,
			"debuff_hp_drain_per_sec": 1.0,
		},
		"whispers": {
			"enabled": true,
			"show_in_chat": true,
			"show_in_actionbar": true,
			"base_interval_sec": 28.0,
			"min_interval_sec": 4.0,
			"speedup_per_soul": 0.05,
			"last_words_echo_chance": 0.25,
		},
		"corruption": {
			"_stufen_info": "thresholds = Seelen-Anzahl ab der Stufe 1..4 beginnt; die Listen haben je einen Wert für Stufe 0..4",
			"thresholds": [5, 12, 25, 45],
			"damage_mult": [1.0, 1.15, 1.3, 1.5, 1.85],
			"speed_mult": [1.0, 1.04, 1.08, 1.12, 1.18],
			"max_hp_mult": [1.0, 0.95, 0.85, 0.72, 0.58],
			"lifesteal": [0.0, 0.0, 0.03, 0.06, 0.1],
			"visual_intensity": 1.0,
			"hallucinations_from_stage": 3,
			"hallucination_interval_sec": 16.0,
			"fake_mob_weight": 3.0,
			"fake_chat_weight": 3.0,
			"teleport_weight": 1.5,
			"fake_orb_weight": 1.5,
			"flicker_weight": 2.0,
			"teleport_distance": 4.0,
		},
		"minions": {
			"enabled": true,
			"duration_sec": 40.0,
			"max_active": 2,
			"damage": 9.0,
			"hp": 60.0,
		},
		"shop": {
			"safe_zone_radius": 6.5,
			"heal_cost": 2,
			"blade_cost": 5,
			"vessel_cost": 5,
			"shadowstep_cost": 4,
			"bolt_cost": 6,
			"ghostpact_cost": 3,
			"holywater_cost": 3,
			"holywater_duration_sec": 90.0,
			"upgrade_cost_growth": 3,
			"max_upgrade_level": 8,
		},
		"waves": {
			"intermission_sec": 15.0,
			"base_enemies": 4,
			"enemies_per_wave": 2,
			"max_alive": 18,
			"hp_scale_per_wave": 0.12,
			"damage_scale_per_wave": 0.06,
			"boss_every": 5,
		},
		"player": {
			"name": "Wanderer",
			"max_hp": 100.0,
			"damage": 22.0,
			"move_speed": 6.5,
			"dash_cooldown_sec": 1.1,
			"bolt_cooldown_sec": 1.2,
			"regen_per_sec": 2.0,
			"respawn_sec": 3.0,
		},
		"controls": {
			"mouse_sensitivity": 0.25,
			"invert_y": false,
		},
		"graphics": {
			"fullscreen": false,
			"vsync": true,
			"fov": 75.0,
			"brightness": 1.0,
			"render_scale": 1.0,
			"renderer": "auto",
			"auto_compat": false,
			"glow": true,
			"fog": true,
			"volumetric_fog": false,
			"shadows": true,
			"particles": 1.0,
			"max_fps": 0,
		},
		"audio": {
			"master_volume": 0.8,
			"whisper_volume": 0.9,
		},
	}


# --------------------------------------------------------------------------
# Loading / saving
# --------------------------------------------------------------------------

func _resolve_data_dir() -> String:
	if OS.has_feature("editor"):
		# While developing, keep data inside the project (ignored by git).
		return ProjectSettings.globalize_path("res://data")
	var exe_dir := OS.get_executable_path().get_base_dir()
	var candidate := exe_dir.path_join(DATA_FOLDER)
	if _is_writable(candidate):
		portable = true
		return candidate
	portable = false
	return ProjectSettings.globalize_path("user://")


func _is_writable(dir: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	var probe := dir.path_join(".schreibtest")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string("ok")
	f.close()
	DirAccess.remove_absolute(probe)
	return true


func config_path() -> String:
	return data_dir.path_join(FILE_NAME)


func load_config() -> void:
	DirAccess.make_dir_recursive_absolute(data_dir)
	data = defaults()
	var path := config_path()
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			_merge(data, parsed)
		else:
			push_warning("config.json ist fehlerhaft und wird mit Standardwerten ersetzt.")
			var backup := path + ".kaputt"
			DirAccess.copy_absolute(path, backup)
	save_config()
	changed.emit()


func save_config() -> void:
	write_json_atomic(config_path(), data)


## Recursively copies values from `src` onto `dst`, but only for keys that
## exist in the defaults and with a compatible type, so typos can't break the game.
func _merge(dst: Dictionary, src: Dictionary) -> void:
	for key in src.keys():
		if not dst.has(key):
			continue
		var dv = dst[key]
		var sv = src[key]
		if dv is Dictionary and sv is Dictionary:
			_merge(dv, sv)
		elif (dv is float or dv is int) and (sv is float or sv is int):
			dst[key] = int(sv) if dv is int else float(sv)
		elif typeof(dv) == typeof(sv):
			dst[key] = sv


## Writes JSON via a temp file + rename so a crash can never leave half a file.
static func write_json_atomic(path: String, value) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Kann nicht schreiben: %s" % path)
		return false
	f.store_string(JSON.stringify(value, "  ", false))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


# --------------------------------------------------------------------------
# Typed getters ("souls.start_count" style paths)
# --------------------------------------------------------------------------

func get_value(path: String, fallback = null):
	var node = data
	for part in path.split("."):
		if node is Dictionary and node.has(part):
			node = node[part]
		else:
			return fallback
	return node


func set_value(path: String, value) -> void:
	var parts := path.split(".")
	var node: Dictionary = data
	for i in parts.size() - 1:
		if not node.has(parts[i]) or not (node[parts[i]] is Dictionary):
			node[parts[i]] = {}
		node = node[parts[i]]
	node[parts[parts.size() - 1]] = value
	changed.emit()


func gf(path: String, fallback := 0.0) -> float:
	return float(get_value(path, fallback))


func gi(path: String, fallback := 0) -> int:
	return int(get_value(path, fallback))


func gb(path: String, fallback := false) -> bool:
	return bool(get_value(path, fallback))


func gs(path: String, fallback := "") -> String:
	return str(get_value(path, fallback))


func ga(path: String) -> Array:
	var v = get_value(path, [])
	return v if v is Array else []


## Returns the value of a per-corruption-stage list, clamped to its length.
func stage_value(path: String, stage: int, fallback := 1.0) -> float:
	var arr := ga(path)
	if arr.is_empty():
		return fallback
	return float(arr[clampi(stage, 0, arr.size() - 1)])
