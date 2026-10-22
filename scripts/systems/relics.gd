class_name Relics
extends RefCounted
## Run relics: after every cleared wave you pick 1 of 3. They only last for
## the current run, stack up to `max` times and change how the run plays.

const POOL := {
	"klinge": {"name": "Schwere Klinge", "desc": "+20 % Nahkampfschaden.", "max": 3, "color": Color(1.0, 0.55, 0.4)},
	"sohlen": {"name": "Flinke Sohlen", "desc": "+12 % Laufgeschwindigkeit.", "max": 3, "color": Color(0.6, 1.0, 0.7)},
	"zahn": {"name": "Vampirzahn", "desc": "Nahkampftreffer heilen 6 % des Schadens.", "max": 3, "color": Color(0.9, 0.2, 0.3)},
	"panzer": {"name": "Knochenpanzer", "desc": "Du nimmst 15 % weniger Schaden.", "max": 3, "color": Color(0.85, 0.85, 0.75)},
	"splitter": {"name": "Splitterblitz", "desc": "Der Seelenblitz teilt sich in 2 weitere Blitze.", "max": 2, "color": Color(0.5, 0.8, 1.0)},
	"feuer": {"name": "Seelenfeuer", "desc": "Seelenblitz lädt 20 % schneller.", "max": 3, "color": Color(0.4, 0.6, 1.0)},
	"magnet": {"name": "Seelenmagnet", "desc": "Seelen fliegen dir aus viel größerer Entfernung zu.", "max": 2, "color": Color(0.7, 0.9, 1.0)},
	"gier": {"name": "Gierige Hand", "desc": "Schwache Gegner lassen 15 % öfter ihre Seele fallen.", "max": 3, "color": Color(1.0, 0.85, 0.3)},
	"atem": {"name": "Zweiter Atem", "desc": "Schattenschritt lädt 25 % schneller.", "max": 2, "color": Color(0.7, 0.6, 1.0)},
	"zorn": {"name": "Totenzorn", "desc": "Getötete Gegner explodieren und verletzen ihre Nachbarn.", "max": 3, "color": Color(1.0, 0.4, 0.1)},
	"geister": {"name": "Ewige Geister", "desc": "Beschworene Geister bleiben 50 % länger und treffen härter.", "max": 2, "color": Color(0.6, 1.0, 1.0)},
	"ruhe": {"name": "Totenruhe", "desc": "Schnellere Heilung außerhalb des Kampfes.", "max": 3, "color": Color(0.5, 0.9, 0.6)},
}


## Three different relics that are not maxed yet.
static func offer(owned: Dictionary, count := 3) -> Array[String]:
	var ids: Array[String] = []
	for id in POOL:
		if int(owned.get(id, 0)) < int(POOL[id].max):
			ids.append(id)
	ids.shuffle()
	return ids.slice(0, mini(count, ids.size()))


static func title(id: String, stacks: int) -> String:
	var t: String = POOL[id].name
	if stacks > 1:
		t += " " + ["", "I", "II", "III", "IV"][mini(stacks, 4)]
	return t
