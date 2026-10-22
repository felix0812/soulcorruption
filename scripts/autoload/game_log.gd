class_name GameLog
extends Logger
## Mirrors every engine/script message into a log file in the portable data
## folder (SoulCorruption_Daten/logs/), so crashes can be reported even when
## %APPDATA% is locked down. Keeps the newest few logs.

const KEEP := 5

## True when the previous session never shut down cleanly (likely a crash).
static var crashed_last_time := false

var _file: FileAccess
var _mutex := Mutex.new()
var _flag_path := ""


static func install(data_dir: String) -> GameLog:
	var dir := data_dir.path_join("logs")
	DirAccess.make_dir_recursive_absolute(dir)
	_prune(dir)
	var flag := dir.path_join("laeuft.flag")
	crashed_last_time = FileAccess.file_exists(flag)
	var f := FileAccess.open(flag, FileAccess.WRITE)
	if f:
		f.store_string("Wird beim normalen Beenden gelöscht.")
		f.close()
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var logger := GameLog.new()
	logger._file = FileAccess.open(dir.path_join("spiel_%s.log" % stamp), FileAccess.WRITE)
	if logger._file == null:
		return null
	logger._flag_path = flag
	OS.add_logger(logger)
	if crashed_last_time:
		logger.write("Hinweis: der letzte Start wurde nicht sauber beendet (Absturz?).")
	return logger


## Called on a clean shutdown.
func close() -> void:
	write("Spiel sauber beendet.")
	if _flag_path != "":
		DirAccess.remove_absolute(_flag_path)


static func _prune(dir: String) -> void:
	var files: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("spiel_") and f.ends_with(".log"):
			files.append(f)
	files.sort()
	while files.size() >= KEEP:
		DirAccess.remove_absolute(dir.path_join(files.pop_front()))


func write(line: String) -> void:
	_mutex.lock()
	if _file:
		_file.store_line("[%s] %s" % [Time.get_time_string_from_system(), line])
		_file.flush()  # Make sure the last lines survive a hard crash.
	_mutex.unlock()


func _log_message(message: String, error: bool) -> void:
	write(("FEHLER " if error else "") + message.strip_edges(false, true))


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	var kind: String = ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"][clampi(error_type, 0, 3)]
	var text := "%s: %s" % [kind, rationale if rationale != "" else code]
	text += "\n    bei %s (%s:%d)" % [function, file, line]
	for bt in script_backtraces:
		text += "\n" + bt.format(4)
	write(text)
