class_name ScrapCatalog
extends RefCounted

## Kayıp eşyalar — temizlik yan ürünü + gizli koşul (easter egg).

enum DropKind { CLEAN, SECRET }

## drop: "clean" | "secret"
## props: clean drop için prop_id listesi (boş = çoğu kir)
## chance: clean drop şansı (0–1)
## secret: secret id (ScrapDirector3D)
static func all() -> Array[Dictionary]:
	return [
		{
			"id": "remzi_badge",
			"name": "Remzi'nin Rozeti",
			"icon": "🪪",
			"hint": "Tozun içinde kaybolmuş.",
			"drop": "clean",
			"props": ["dust", "crumb", "mold", "hidden"],
			"chance": 0.07,
		},
		{
			"id": "cousin_key",
			"name": "Kuzen'in Anahtarı",
			"icon": "🔑",
			"hint": "Bir kolinin dibindeymiş.",
			"drop": "clean",
			"props": ["box"],
			"chance": 0.09,
		},
		{
			"id": "witch_cork",
			"name": "Cadı Mantarlı Tıpa",
			"icon": "🧿",
			"hint": "İksir / balçık artığı.",
			"drop": "clean",
			"props": ["potion", "slime", "boss_slime"],
			"chance": 0.08,
		},
		{
			"id": "vampire_fang",
			"name": "Kont'un Dişliği",
			"icon": "🦇",
			"hint": "Karanlıkta saklanan kirden.",
			"drop": "clean",
			"props": ["hidden", "tiny"],
			"chance": 0.1,
		},
		{
			"id": "tv_remote",
			"name": "Kayıp Kumanda",
			"icon": "📺",
			"hint": "Tamir / kırık ekran yan ürünü.",
			"drop": "clean",
			"props": ["tv", "tv_repair"],
			"chance": 0.12,
		},
		{
			"id": "crust_shard",
			"name": "Kabuk Parçası",
			"icon": "🪨",
			"hint": "Sert tortunun içinde.",
			"drop": "clean",
			"props": ["crust"],
			"chance": 0.08,
		},
		# --- Gizli koşullar (tip 2) ---
		{
			"id": "dance_dust",
			"name": "Dans Tozu",
			"icon": "🕺",
			"hint": "Temizlik + dans…?",
			"drop": "secret",
			"secret": "dance_dispose",
		},
		{
			"id": "art_critique",
			"name": "Eleştiri Kartı",
			"icon": "🎨",
			"hint": "Tabloya yanlış aletle yaklaş.",
			"drop": "secret",
			"secret": "tweezers_painting",
		},
		{
			"id": "bag_tag",
			"name": "Dolu Torba Etiketi",
			"icon": "🏷️",
			"hint": "Torba tıka basa doluyken çöpe boşalt.",
			"drop": "secret",
			"secret": "empty_full_bag",
		},
		{
			"id": "junk_groove",
			"name": "Afiyet Rozeti",
			"icon": "🍔",
			"hint": "Dans ederken abur cubur ye.",
			"drop": "secret",
			"secret": "dance_junk",
		},
		{
			"id": "spray_bluff",
			"name": "Yanlış Sprey Notu",
			"icon": "🧴",
			"hint": "Küfe sprey sıkmayı dene.",
			"drop": "secret",
			"secret": "spray_mold",
		},
		{
			"id": "rush_rinse",
			"name": "Acele Kova Damlası",
			"icon": "💧",
			"hint": "Speed rush sırasında kovada durula.",
			"drop": "secret",
			"secret": "rush_rinse",
		},
	]


static func by_id(scrap_id: String) -> Dictionary:
	for s in all():
		if String(s.get("id", "")) == scrap_id:
			return s
	return {}


static func clean_candidates_for(prop_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in all():
		if String(s.get("drop", "")) != "clean":
			continue
		var props: Array = s.get("props", []) as Array
		if props.is_empty() or prop_id in props:
			out.append(s)
	return out


static func secret_scrap(secret_id: String) -> Dictionary:
	for s in all():
		if String(s.get("drop", "")) == "secret" and String(s.get("secret", "")) == secret_id:
			return s
	return {}


static func count() -> int:
	return all().size()
