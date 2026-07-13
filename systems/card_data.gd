class_name CardData
extends RefCounted

enum Rarity { COMMON, UNCOMMON, RARE }

var id: String = ""
var title: String = ""
var description: String = ""
var icon: String = "🃏"
var rarity: int = Rarity.COMMON
## Çarpanlar birbiriyle çarpılır (varsayılan 1.0 yok sayılır).
var mult_mods: Dictionary = {}
## Toplanır (varsayılan 0).
var add_mods: Dictionary = {}
## Özel bayraklar / eşikler (hot_streak_threshold vb.).
var flags: Dictionary = {}


static func from_dict(data: Dictionary) -> CardData:
	var card := CardData.new()
	card.id = String(data.get("id", ""))
	card.title = String(data.get("title", ""))
	card.description = String(data.get("desc", ""))
	card.icon = String(data.get("icon", "🃏"))
	card.rarity = int(data.get("rarity", Rarity.COMMON))
	card.mult_mods = (data.get("mult", {}) as Dictionary).duplicate()
	card.add_mods = (data.get("add", {}) as Dictionary).duplicate()
	card.flags = (data.get("flags", {}) as Dictionary).duplicate()
	return card


func get_rarity_label() -> String:
	match rarity:
		Rarity.UNCOMMON:
			return "NADİR"
		Rarity.RARE:
			return "EPİK"
		_:
			return "NORMAL"


func get_rarity_color() -> Color:
	match rarity:
		Rarity.UNCOMMON:
			return Color(0.55, 0.85, 1.0)
		Rarity.RARE:
			return Color(1.0, 0.75, 0.35)
		_:
			return Color(0.75, 0.78, 0.85)
