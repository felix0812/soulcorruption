extends Node
## Lore ("Lore"): names, last words, whispers and fake messages.
## All text the souls say is generated here from small building blocks.

const FIRST_NAMES := [
	"Aldric", "Mira", "Henrik", "Isolde", "Bertram", "Wendelin", "Elsbeth", "Gottfried",
	"Agnes", "Ruprecht", "Kunigunde", "Lothar", "Hedwig", "Ansgar", "Brunhild", "Dietmar",
	"Ottilie", "Severin", "Walburga", "Konrad", "Irmgard", "Friedhelm", "Adelheid", "Eckhart",
	"Gisela", "Hartmut", "Liesel", "Mechthild", "Ulrich", "Veit", "Rosamunde", "Jost",
]

const EPITHETS := [
	"der Schwermütige", "von Aschental", "die Blinde", "der Fährmann", "aus dem Moor",
	"die Letzte", "der Gebrochene", "von Rabenstein", "die Ertrunkene", "der Wortbrüchige",
	"die Glockenläuterin", "der Totengräber", "von Nebelheim", "die Hexe", "der Bußprediger",
	"die Kinderlose", "der Henker", "von Grauwald", "die Lichtlose", "der Verräter",
	"die Wäscherin", "der Pestarzt", "von Kaltenbrunn", "die Verlobte",
]

const BOSS_NAMES := [
	"Morgrath der Ungetrübte", "Ser Valdemar Eisenschwur", "Die Graue Herzogin Ysolde",
	"Kastellan Brandolf", "Ritter Ohne-Gesicht", "Hochmeister Ulfrik Sargtreu",
]

const PERSONALITIES := ["zornig", "verzweifelt", "höhnisch", "wahnsinnig", "trauernd"]

const LAST_WORDS := {
	"zornig": [
		"Ich finde dich. Auch im Tod.",
		"Verflucht seist du und dein Blut!",
		"Das war nicht… das Ende…",
		"Du wirst an mir ersticken.",
		"Ich hätte dich zuerst erwischen sollen.",
	],
	"verzweifelt": [
		"Bitte… sag meiner Tochter nichts.",
		"Ich wollte doch nur nach Hause.",
		"Es ist so kalt. Warum ist es so kalt?",
		"Nicht so. Nicht hier.",
		"Ich habe noch nicht einmal gelebt.",
	],
	"höhnisch": [
		"Viel Spaß mit mir, Seelendieb.",
		"Ha… du weißt nicht, was du da nimmst.",
		"Ich bin nicht die Erste. Und nicht die Letzte.",
		"Glückwunsch. Jetzt gehörst du mir.",
		"Schwach. So unglaublich schwach.",
	],
	"wahnsinnig": [
		"Die Glocken! Hörst du die Glocken?",
		"Sie lachen unter der Erde, weißt du?",
		"Zähl die Sterne. Einer fehlt.",
		"Endlich darf ich in dir wohnen.",
		"Rot ist die Farbe des Mondes. Rot.",
	],
	"trauernd": [
		"Leb wohl, Hedwig. Vergib mir.",
		"Ich habe den Herbst immer geliebt.",
		"Es tut mir leid. Es tut mir so leid.",
		"Endlich… Ruhe.",
		"Hätte ich nur ein letztes Mal das Meer gesehen.",
	],
}

## Personality lines, by aggression tier (0 = mild, 3 = rabid).
const WHISPERS := {
	"zornig": [
		["Ich vergesse dein Gesicht nicht.", "Du hast mir alles genommen."],
		["Jeder Schritt von dir tut mir weh.", "Ich warte. Ich bin geduldig."],
		["Ich reiße dich von innen auf, {player}.", "Du gehörst MIR, nicht umgekehrt."],
		["BRENN. BRENN. BRENN.", "ICH BIN DEINE HÄNDE JETZT."],
	],
	"verzweifelt": [
		["Lass mich gehen… bitte.", "Wo bin ich? Warum ist es so dunkel?"],
		["Du hast mich einfach genommen.", "Ich höre meine Familie nicht mehr."],
		["Warum hört es nicht auf, {player}?", "Wir sind so viele hier drin…"],
		["HILF UNS HILF UNS HILF UNS", "es gibt keinen ausgang. keinen. keinen."],
	],
	"höhnisch": [
		["Netter Schlag. Für ein Kind.", "Du weißt, dass du verlierst, oder?"],
		["Sie lachen alle über dich, {player}.", "Noch eine Seele, und du zerbrichst."],
		["Wir haben schon Stärkere ausgehöhlt.", "Dein Herz klingt so… zerbrechlich."],
		["HAHAHAHAHAHA", "Du bist nur noch ein Gefäß. Ein leeres, dummes Gefäß."],
	],
	"wahnsinnig": [
		["Die Grabsteine flüstern deinen Namen.", "Hast du gezählt? Ich zähle."],
		["Da steht jemand hinter dir.", "Die Bäume haben Augen, {player}."],
		["Wir tanzen in deinen Knochen.", "Rot rot rot ist der Mond."],
		["3 2 1 3 2 1 3 2 1", "SIE KOMMEN AUS DEN WÄNDEN"],
	],
	"trauernd": [
		["Erinnerst du dich an mich?", "Ich hatte einen Garten…"],
		["Es hätte nicht so enden müssen.", "Du trägst jetzt meine Trauer, {player}."],
		["Warum hast du nicht weggesehen?", "Wir werden alle in dir verwelken."],
		["vergiss uns nicht vergiss uns nicht", "Du wirst so werden wie wir."],
	],
}

## Lines everyone says once the corruption gets bad.
const CHORUS := [
	"Mehr. Wir brauchen mehr.",
	"Du hörst uns doch, {player}.",
	"Schlaf nicht ein.",
	"Wir sind {count}. Wir sind viele.",
	"Dein Name schmeckt nach Asche, {player}.",
]

## Fake chat lines for hallucinations: [sender, text].
const FAKE_CHAT := [
	["System", "Ein Spieler hat die Welt betreten: {victim}"],
	["{victim}", "hinter dir"],
	["{victim}", "ich sehe dich, {player}"],
	["System", "Deine Seele wurde verkauft."],
	["System", "Welle {wave} wurde abgebrochen."],
	["Unbekannt", "warum hast du das getan"],
	["{victim}", "ich bin nicht tot. nicht wirklich."],
	["System", "{player} ist gestorben."],
	["Altar", "Komm näher. Nur ein bisschen näher."],
]

const GHOST_FAREWELL := {
	"zornig": "Wir sind noch nicht fertig, {player}.",
	"verzweifelt": "Danke… dass ich atmen durfte.",
	"höhnisch": "Gern geschehen. Du schuldest mir was.",
	"wahnsinnig": "Die Glocken rufen. Ich gehe tanzen.",
	"trauernd": "Endlich darf ich weiterziehen.",
}

const STARTING_SOUL_WORDS := [
	"Wir waren vor dir da. Wir bleiben nach dir.",
	"Trag uns mit Würde, Kind.",
	"Unser Blut ist dein Blut.",
]

const ZALGO := ["̶", "̷", "̴", "̵", "̸", "̕", "̛", "̀", "́", "͘"]


func random_name(kind: String) -> String:
	if kind == "knight":
		return BOSS_NAMES.pick_random()
	return "%s %s" % [FIRST_NAMES.pick_random(), EPITHETS.pick_random()]


## Creates the identity of a new victim (used for every spawned enemy).
func make_victim(kind: String) -> Dictionary:
	var personality: String = PERSONALITIES.pick_random()
	if kind == "knight":
		personality = ["zornig", "höhnisch"].pick_random()
	return {
		"name": random_name(kind),
		"personality": personality,
		"last_words": (LAST_WORDS[personality] as Array).pick_random(),
	}


func make_starting_soul() -> SoulItem:
	var s := SoulItem.new()
	s.kind = "ahne"
	s.victim = "%s %s" % [FIRST_NAMES.pick_random(), ["die Ahnin", "der Ahne", "aus alter Zeit"].pick_random()]
	s.personality = "trauernd"
	s.last_words = STARTING_SOUL_WORDS.pick_random()
	s.timestamp = 0
	return s


## A whisper of `soul`. `tier` 0..3 = how aggressive. `total` = souls held.
func whisper(soul: SoulItem, tier: int, player_name: String, total: int) -> String:
	var line := ""
	if randf() < Cfg.gf("whispers.last_words_echo_chance"):
		line = "„%s“" % soul.last_words
	elif tier >= 2 and randf() < 0.3:
		line = CHORUS.pick_random()
	else:
		var tiers: Array = WHISPERS.get(soul.personality, WHISPERS["trauernd"])
		# Pick from the current tier, sometimes one lower for variety.
		var t := clampi(tier - (1 if randf() < 0.3 else 0), 0, tiers.size() - 1)
		line = (tiers[t] as Array).pick_random()
	return fill(line, {"player": player_name, "count": str(total)})


func fake_chat(victim: String, player_name: String, wave: int) -> Array:
	var pair: Array = FAKE_CHAT.pick_random()
	var vars := {"victim": victim, "player": player_name, "wave": str(wave)}
	return [fill(pair[0], vars), fill(pair[1], vars)]


func ghost_farewell(soul: SoulItem, player_name: String) -> String:
	return fill(GHOST_FAREWELL.get(soul.personality, "…"), {"player": player_name})


func fill(text: String, vars: Dictionary) -> String:
	var out := text
	for k in vars.keys():
		out = out.replace("{%s}" % k, str(vars[k]))
	return out


## Adds combining "glitch" marks to text. amount 0..1.
func glitch_text(text: String, amount: float) -> String:
	if amount <= 0.0:
		return text
	var out := ""
	for ch in text:
		out += ch
		if ch != " " and randf() < amount:
			for i in randi_range(1, 2):
				out += ZALGO.pick_random()
	return out
