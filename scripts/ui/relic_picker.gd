class_name RelicPicker
extends Control
## Shown after a cleared wave: choose one of three relics for this run.

var hud  # Hud
var cards: HBoxContainer
var _offer: Array[String] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIKit.dim_background(self, 0.55)
	var panel := UIKit.centered_panel(self, Vector2(1060, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(UIKit.label("Ein Relikt aus dem Grab", 34, Color(1.0, 0.85, 0.5), true))
	var sub := UIKit.label("Wähle eines. Es begleitet dich bis zum Ende dieses Laufs.", 17, UIKit.DIM)
	v.add_child(sub)
	cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	v.add_child(cards)


func refresh() -> void:
	for c in cards.get_children():
		c.queue_free()
	_offer = Relics.offer(hud.world.relics)
	for i in _offer.size():
		var id := _offer[i]
		var r: Dictionary = Relics.POOL[id]
		var have := int(hud.world.relics.get(id, 0))
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(330, 200)
		card.add_theme_constant_override("separation", 8)
		cards.add_child(card)
		card.add_child(UIKit.label(Relics.title(id, have + 1), 23, r.color, true))
		var d := UIKit.label(r.desc, 17)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(320, 70)
		card.add_child(d)
		card.add_child(UIKit.label("Stufe %d/%d" % [have + 1, int(r.max)], 15, UIKit.DIM))
		card.add_child(UIKit.button("[%d] Nehmen" % (i + 1), func(): choose(id), 220))


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	var k := event as InputEventKey
	if k and k.pressed and k.keycode >= KEY_1 and k.keycode <= KEY_3:
		var i := int(k.keycode - KEY_1)
		if i < _offer.size():
			choose(_offer[i])
			get_viewport().set_input_as_handled()


func choose(id: String) -> void:
	hud.world.add_relic(id)
	hud.close()
