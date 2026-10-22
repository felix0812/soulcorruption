class_name ShopUI
extends Control
## The soul altar shop: souls are the currency. Spending souls also lowers
## your corruption, which makes every purchase a small dilemma.

var hud  # Hud
var balance: Label
var rows: VBoxContainer


## id, title, description; cost and effect are resolved below.
const OFFERS := [
	["heal", "Blutphiole", "Heilt 60 % deiner Lebenspunkte."],
	["blade", "Geschärfte Seelenklinge", "+15 % Schaden (dauerhaft)."],
	["vessel", "Gefäß des Lebens", "+15 maximale Lebenspunkte (dauerhaft)."],
	["shadowstep", "Schattenschritt", "Schattenschritt lädt 12 % schneller (dauerhaft)."],
	["bolt", "Seelenblitz", "+25 % Blitzschaden, 8 % schneller (dauerhaft)."],
	["ghostpact", "Geisterpakt", "Ein fremder Geist kämpft für dich, ohne eigene Seele."],
	["holywater", "Weihwasser", "Eine Zeit lang keine Halluzinationen."],
]
const UPGRADES := ["blade", "vessel", "shadowstep", "bolt"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIKit.dim_background(self, 0.5)
	var panel := UIKit.centered_panel(self, Vector2(980, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(UIKit.label("Seelenaltar", 34, Color(0.8, 0.7, 1.0), true))
	var sub := UIKit.label("Handel mit dem Jenseits. Jede bezahlte Seele verlässt dein Gefäß und senkt deine Korruption.", 17, UIKit.DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	balance = UIKit.label("", 22, Color(0.75, 0.95, 1.0))
	v.add_child(balance)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	v.add_child(rows)
	var footer := HBoxContainer.new()
	v.add_child(footer)
	var hint := UIKit.label("Bezahlt wird mit deinen ältesten Seelen.   [B] / [Esc] schließen", 16, UIKit.DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)
	footer.add_child(UIKit.button("Schließen", func(): hud.close(), 160))


static func cost(id: String) -> int:
	var base := Cfg.gi("shop.%s_cost" % id, 5)
	if id in UPGRADES:
		base += Cfg.gi("shop.upgrade_cost_growth") * Souls.upgrade(id)
	return base


static func maxed(id: String) -> bool:
	return id in UPGRADES and Souls.upgrade(id) >= Cfg.gi("shop.max_upgrade_level")


func refresh() -> void:
	balance.text = "Deine Seelen: %d" % Souls.total()
	for c in rows.get_children():
		c.queue_free()
	for offer in OFFERS:
		var id: String = offer[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		rows.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		var title: String = offer[1]
		if id in UPGRADES:
			title += "  (Stufe %d/%d)" % [Souls.upgrade(id), Cfg.gi("shop.max_upgrade_level")]
		text.add_child(UIKit.label(title, 21, Color(0.92, 0.88, 1.0)))
		var desc: String = offer[2]
		if id == "holywater":
			desc = "%d Sekunden keine Halluzinationen." % int(Cfg.gf("shop.holywater_duration_sec"))
		text.add_child(UIKit.label(desc, 16, UIKit.DIM))
		var c := cost(id)
		var price := UIKit.label("%d Seelen" % c, 20, Color(0.7, 0.95, 1.0))
		price.custom_minimum_size = Vector2(110, 0)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(price)
		var btn := UIKit.button("Kaufen", func(): buy(id), 120)
		btn.disabled = maxed(id) or Souls.total() < c
		if maxed(id):
			btn.text = "Maximal"
		row.add_child(btn)


## Executes a purchase; returns an error text or "".
func buy(id: String) -> String:
	var err := purchase(hud.world, id)
	if err != "":
		hud.actionbar(err, Color(1, 0.6, 0.6))
	else:
		Sfx.play("buy", -3.0)
	refresh()
	return err


static func purchase(world, id: String) -> String:
	if maxed(id):
		return "Diese Verbesserung ist bereits auf der höchsten Stufe."
	var c := cost(id)
	if Souls.total() < c:
		return "Nicht genug Seelen (%d benötigt)." % c
	if id == "ghostpact" and world.get_tree().get_nodes_in_group("minions").size() >= Cfg.gi("minions.max_active"):
		return "Es dienen dir bereits genug Geister."
	Souls.spend(c)
	match id:
		"heal":
			world.player.heal(world.player.max_hp * 0.6)
		"ghostpact":
			world.summon_pact_ghost()
		"holywater":
			world.hallucinations.ward(Cfg.gf("shop.holywater_duration_sec"))
		_:
			Souls.add_upgrade(id)
			world.player.recompute_stats()
	return ""
