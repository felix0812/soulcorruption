extends Node
## Soul bank ("Souls"): the persistent soul data of the current player profile.
##
## Each profile is one JSON file in `<data dir>/profile/<name>.json` and holds
## the soul vessel (all SoulItems), bought upgrades, statistics and a possible
## ban. Changes are saved automatically a moment later and on quit.

signal souls_changed(total: int)
signal soul_added(item: SoulItem)
signal soul_rejected(item: SoulItem)
signal upgrades_changed

const PROFILE_DIR := "profile"
const AUTOSAVE_DELAY := 2.0

var profile_name := ""
var souls: Array[SoulItem] = []
var upgrades: Dictionary = {}
var stats: Dictionary = {}
var banned_until := 0
var _next_id := 1
var _dirty := false
var _save_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_profile(Cfg.gs("player.name", "Wanderer"))


func _process(delta: float) -> void:
	if _dirty:
		_save_timer -= delta
		if _save_timer <= 0.0:
			save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _dirty:
			save_now()


# --------------------------------------------------------------------------
# Profiles
# --------------------------------------------------------------------------

static func sanitize_name(n: String) -> String:
	var clean := ""
	for ch in n.strip_edges():
		if ch.is_valid_identifier() or ch in "0123456789 -_äöüÄÖÜß":
			clean += ch
	clean = clean.strip_edges().left(20)
	return clean if clean != "" else "Wanderer"


func profile_dir() -> String:
	return Cfg.data_dir.path_join(PROFILE_DIR)


func profile_path(n: String) -> String:
	return profile_dir().path_join(n.to_lower().replace(" ", "_") + ".json")


func load_profile(n: String) -> void:
	if _dirty and profile_name != "":
		save_now()
	profile_name = sanitize_name(n)
	souls.clear()
	upgrades = {}
	stats = _empty_stats()
	banned_until = 0
	_next_id = 1
	var path := profile_path(profile_name)
	if FileAccess.file_exists(path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary:
			for sd in d.get("souls", []):
				if sd is Dictionary:
					souls.append(SoulItem.from_dict(sd))
			upgrades = d.get("upgrades", {})
			var st: Dictionary = d.get("stats", {})
			for k in st.keys():
				stats[k] = st[k]
			banned_until = int(d.get("banned_until", 0))
			_next_id = int(d.get("next_id", 1))
	else:
		grant_starting_souls()
	for s in souls:
		_next_id = maxi(_next_id, s.id + 1)
	Cfg.set_value("player.name", profile_name)
	Cfg.save_config()
	save_now()
	souls_changed.emit(total())
	upgrades_changed.emit()


func _empty_stats() -> Dictionary:
	return {"kills": 0, "deaths": 0, "souls_stolen": 0, "best_wave": 0, "runs": 0, "created": int(Time.get_unix_time_from_system())}


func grant_starting_souls() -> void:
	for i in Cfg.gi("souls.start_count"):
		add_soul(Lore.make_starting_soul(), false)


func save_now() -> void:
	_dirty = false
	if profile_name == "":
		return
	DirAccess.make_dir_recursive_absolute(profile_dir())
	var arr: Array = []
	for s in souls:
		arr.append(s.to_dict())
	Cfg.write_json_atomic(profile_path(profile_name), {
		"name": profile_name,
		"souls": arr,
		"upgrades": upgrades,
		"stats": stats,
		"banned_until": banned_until,
		"next_id": _next_id,
		"saved_at": int(Time.get_unix_time_from_system()),
	})


func mark_dirty() -> void:
	_dirty = true
	_save_timer = AUTOSAVE_DELAY


## All profiles on disk, used by "/soul top" and the menu.
func list_profiles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(profile_dir())
	if dir == null:
		return out
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(profile_dir().path_join(f)))
		if not (d is Dictionary):
			continue
		var n := 0
		for sd in d.get("souls", []):
			n += int(sd.get("count", 1))
		var st: Dictionary = d.get("stats", {})
		out.append({
			"name": str(d.get("name", f.get_basename())),
			"souls": n,
			"best_wave": int(st.get("best_wave", 0)),
			"stolen": int(st.get("souls_stolen", 0)),
			"kills": int(st.get("kills", 0)),
		})
	return out


# --------------------------------------------------------------------------
# Souls
# --------------------------------------------------------------------------

func total() -> int:
	var n := 0
	for s in souls:
		n += s.count
	return n


## Adds a soul (stacking if enabled). Returns false if the vessel is full.
func add_soul(item: SoulItem, count_as_stolen := true) -> bool:
	if total() + item.count > Cfg.gi("souls.max_held"):
		soul_rejected.emit(item)
		return false
	if item.id == 0:
		item.id = _next_id
		_next_id += 1
	var added := false
	if Cfg.gb("souls.stackable"):
		for s in souls:
			if s.stack_key() == item.stack_key():
				s.count += item.count
				added = true
				break
	if not added:
		souls.append(item)
	if count_as_stolen:
		stats["souls_stolen"] = int(stats.get("souls_stolen", 0)) + item.count
	mark_dirty()
	soul_added.emit(item)
	souls_changed.emit(total())
	return true


## Removes `n` single souls and returns them as separate items.
## order: "oldest", "newest" or "random".
func take_souls(n: int, order := "oldest") -> Array[SoulItem]:
	var taken: Array[SoulItem] = []
	while taken.size() < n and not souls.is_empty():
		var idx := 0
		match order:
			"newest":
				idx = souls.size() - 1
			"random":
				idx = randi() % souls.size()
		taken.append(remove_one(souls[idx], false))
	if not taken.is_empty():
		mark_dirty()
		souls_changed.emit(total())
	return taken


## Removes a single soul from a stack (or the whole entry if count is 1).
func remove_one(item: SoulItem, notify := true) -> SoulItem:
	var single := item.single_copy()
	item.count -= 1
	if item.count <= 0:
		souls.erase(item)
	if notify:
		mark_dirty()
		souls_changed.emit(total())
	return single


func spend(n: int) -> bool:
	if total() < n:
		return false
	take_souls(n, "oldest")
	return true


func newest() -> SoulItem:
	return null if souls.is_empty() else souls[souls.size() - 1]


func random_soul() -> SoulItem:
	if souls.is_empty():
		return null
	# Weighted by stack size so big stacks talk more.
	var r := randi() % total()
	for s in souls:
		r -= s.count
		if r < 0:
			return s
	return souls[0]


# --------------------------------------------------------------------------
# Upgrades, stats, ban
# --------------------------------------------------------------------------

func upgrade(id: String) -> int:
	return int(upgrades.get(id, 0))


func add_upgrade(id: String, amount := 1) -> void:
	upgrades[id] = upgrade(id) + amount
	mark_dirty()
	upgrades_changed.emit()


func add_stat(key: String, amount := 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount
	mark_dirty()


func record_wave(w: int) -> void:
	if w > int(stats.get("best_wave", 0)):
		stats["best_wave"] = w
		mark_dirty()


func now() -> int:
	return int(Time.get_unix_time_from_system())


func is_banned() -> bool:
	return banned_until > now()


func ban_seconds_left() -> int:
	return maxi(0, banned_until - now())


func ban(minutes: float) -> void:
	banned_until = now() + int(minutes * 60.0)
	save_now()


## After a ban or a soulless death the profile gets fresh starting souls.
func ensure_minimum_souls() -> void:
	if total() == 0:
		grant_starting_souls()
		save_now()
