class_name SoulItem
extends RefCounted
## One stolen soul. This is the "item" of the game: it lives in the soul
## vessel (inventory), is saved to disk and carries the victim's personality.

const PERSONALITY_COLORS := {
	"zornig": Color(1.0, 0.32, 0.25),
	"verzweifelt": Color(0.4, 0.65, 1.0),
	"höhnisch": Color(0.75, 1.0, 0.35),
	"wahnsinnig": Color(0.85, 0.4, 1.0),
	"trauernd": Color(0.85, 0.9, 1.0),
}

const KIND_LABELS := {
	"ahne": "Ahnenseele",
	"hollow": "Hohler",
	"wraith": "Irrgeist",
	"warden": "Grabwächter",
	"knight": "Gefallener Ritter",
	"mage": "Knochenmagier",
	"bomber": "Knochenbomber",
	"bulwark": "Schildträger",
}

var id := 0
var victim := ""
var kind := "hollow"
var personality := "trauernd"
var last_words := ""
var timestamp := 0
var wave := 0
var count := 1


func stack_key() -> String:
	return "%s|%s|%s" % [victim, kind, personality]


func color() -> Color:
	return PERSONALITY_COLORS.get(personality, Color(0.6, 0.9, 1.0))


func kind_label() -> String:
	return KIND_LABELS.get(kind, kind)


func is_boss() -> bool:
	return kind == "knight"


## Local, human readable time of death, e.g. "22.10.2026 08:53".
func time_text() -> String:
	if timestamp <= 0:
		return "vor aller Zeit"
	var bias_min: int = Time.get_time_zone_from_system().get("bias", 0)
	var d := Time.get_datetime_dict_from_unix_time(timestamp + bias_min * 60)
	return "%02d.%02d.%04d %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]


func single_copy() -> SoulItem:
	var s := SoulItem.new()
	s.id = id
	s.victim = victim
	s.kind = kind
	s.personality = personality
	s.last_words = last_words
	s.timestamp = timestamp
	s.wave = wave
	s.count = 1
	return s


func to_dict() -> Dictionary:
	return {
		"id": id,
		"victim": victim,
		"kind": kind,
		"personality": personality,
		"last_words": last_words,
		"timestamp": timestamp,
		"wave": wave,
		"count": count,
	}


static func from_dict(d: Dictionary) -> SoulItem:
	var s := SoulItem.new()
	s.id = int(d.get("id", 0))
	s.victim = str(d.get("victim", "Namenlos"))
	s.kind = str(d.get("kind", "hollow"))
	s.personality = str(d.get("personality", "trauernd"))
	s.last_words = str(d.get("last_words", "…"))
	s.timestamp = int(d.get("timestamp", 0))
	s.wave = int(d.get("wave", 0))
	s.count = maxi(1, int(d.get("count", 1)))
	return s
