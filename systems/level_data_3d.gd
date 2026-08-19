class_name LevelData3D
extends RefCounted

## 3D kampanya: 2 tutorial + 10 bölüm × 5 kademe.
## Her bölüm: Intro → Filler → Filler+ → Challenge → Climax (kademeli unlock).

const CHAPTERS_PER_CAMPAIGN := 10
const TIERS_PER_CHAPTER := 5
const INTRO_LEVELS := 2
const TIER_LABELS: Array[String] = ["Giriş", "Alıştırma", "Pratik", "Zorluk", "Doruk"]

## Kampanya prop yoğunluğu — buradan / chapter dict override ile ayarlanır.
## final ≈ base × tier_mult × chapter_prop_mult × DifficultyProfile3D.prop_count_mult
const CHAPTER_PROP_GROWTH := 0.10 ## her bölüm +10% (ch1=1.0 … ch10≈1.9)
const CHAPTER_PROP_MULT_MAX := 2.0
const SETPIECE_COUNT_CAP_MULT := 1.2 ## tv / painting / boss — oda şişmesin
const SETPIECE_TYPES: Array[String] = ["tv", "tv_repair", "painting", "boss_slime"]

## Oda par süresi (RoomTimer) — fail yok; gold/silver eşiği için referans.
const LEVEL_TIME_MULT := 1.55
const LEVEL_TIME_FLOOR := 42.0 ## challenge/climax için minimum par sn


static func level_count() -> int:
	return _all().size()


static func get_level(index: int) -> Dictionary:
	var levels: Array[Dictionary] = _all()
	if index < 0 or index >= levels.size():
		return levels[0]
	return levels[index]


## Bölüm → prop count çarpanı. Chapter dict: "prop_mult" (mutlak) veya "prop_growth".
static func chapter_prop_mult(chapter_num: int, ch: Dictionary = {}) -> float:
	if ch.has("prop_mult"):
		return clampf(float(ch.get("prop_mult", 1.0)), 0.5, CHAPTER_PROP_MULT_MAX)
	var growth := float(ch.get("prop_growth", CHAPTER_PROP_GROWTH))
	var m := 1.0 + float(maxi(0, chapter_num - 1)) * growth
	return clampf(m, 0.5, CHAPTER_PROP_MULT_MAX)


## Kutu stack yüksekliği — chapter ilerledikçe 1–2 → 2–4.
## Override: chapter dict "box_stack_min" / "box_stack_max".
static func box_stack_range_for(chapter_num: int, ch: Dictionary = {}) -> Vector2i:
	if ch.has("box_stack_min") or ch.has("box_stack_max"):
		var mn := int(ch.get("box_stack_min", 1))
		var mx := int(ch.get("box_stack_max", 3))
		return Vector2i(maxi(1, mn), maxi(maxi(1, mn), mx))
	var m := chapter_prop_mult(chapter_num, ch)
	var mn2 := 1 if m < 1.55 else 2
	var mx2 := clampi(2 + int(round((m - 1.0) / 0.30)), 2, 4)
	return Vector2i(mn2, maxi(mn2, mx2))


## Menü zorluğu gibi runtime çarpan — props + (tutorial değilse) sections.
static func apply_runtime_prop_scale(spec: Dictionary, difficulty_mult: float) -> Dictionary:
	if absf(difficulty_mult - 1.0) < 0.001:
		return spec
	var out: Dictionary = spec.duplicate(true)
	if out.has("props"):
		out["props"] = _scale_props(out.get("props", []) as Array, difficulty_mult)
	if bool(out.get("tutorial_level", false)):
		return out
	if out.has("sections"):
		var secs: Array = []
		for sec_v in out.get("sections", []) as Array:
			var sec: Dictionary = (sec_v as Dictionary).duplicate(true)
			if sec.has("props"):
				sec["props"] = _scale_props(sec.get("props", []) as Array, difficulty_mult)
			secs.append(sec)
		out["sections"] = secs
	return out


static func is_tutorial_level(index: int) -> bool:
	var info := get_level(index)
	return bool(info.get("tutorial_level", false))


static func unlocked_tools_for(index: int) -> int:
	var info := get_level(index)
	return clampi(int(info.get("unlocked_tools", 1)), 1, 4)


static func dash_charges_for(index: int) -> int:
	var info := get_level(index)
	return 2 if bool(info.get("double_dash", false)) else 1


static func chapter_index_for(level_index: int) -> int:
	var info := get_level(level_index)
	if bool(info.get("tutorial_level", false)) and int(info.get("chapter", 0)) <= 0:
		return -1
	var ch := int(info.get("chapter", 0))
	if ch <= 0:
		# Global intro tutorial'lar chapter alanı yok
		if bool(info.get("tutorial_level", false)):
			return -1
		return -1
	return ch - 1


static func tier_in_chapter(level_index: int) -> int:
	var info := get_level(level_index)
	if bool(info.get("tutorial_level", false)) and int(info.get("chapter", 0)) <= 0:
		return 0
	return int(info.get("tier", 0))


## Dünya haritası: -1 = Eğitim (intro), 0..N-1 = bölümler.
static func world_count() -> int:
	return 1 + CHAPTERS_PER_CAMPAIGN  # eğitim + 10 bölüm


static func world_title(world_slot: int) -> String:
	if world_slot <= 0:
		return "Eğitim"
	var ch := _chapter_defs()
	var idx := world_slot - 1
	if idx < 0 or idx >= ch.size():
		return "Bölüm %d" % world_slot
	var d: Dictionary = ch[idx]
	return "%d · %s" % [world_slot, String(d.get("title", "Bölüm"))]


static func world_icon(world_slot: int) -> String:
	if world_slot <= 0:
		return "📘"
	var ch := _chapter_defs()
	var idx := world_slot - 1
	if idx < 0 or idx >= ch.size():
		return "🗺️"
	return String((ch[idx] as Dictionary).get("icon", "🗺️"))


## world_slot: 0 = eğitim (intro), 1..10 = bölüm → seviye index listesi
static func level_indices_for_world(world_slot: int) -> Array[int]:
	var out: Array[int] = []
	var levels := _all()
	if world_slot <= 0:
		for i in mini(INTRO_LEVELS, levels.size()):
			out.append(i)
		return out
	var chapter_num := world_slot
	for i in levels.size():
		var info: Dictionary = levels[i]
		if int(info.get("chapter", 0)) == chapter_num:
			out.append(i)
	return out


static func world_slot_for_level(level_index: int) -> int:
	var info := get_level(level_index)
	var ch := int(info.get("chapter", 0))
	if ch > 0:
		return ch
	return 0


## Bu seviye dünyanın / bölümün son seviyesi mi? (stat ekranı burada)
static func is_world_finale(level_index: int) -> bool:
	var slot := world_slot_for_level(level_index)
	var indices := level_indices_for_world(slot)
	if indices.is_empty():
		return false
	return indices[indices.size() - 1] == level_index


static func is_level_unlocked(level_index: int, highest_unlocked: int) -> bool:
	return (level_index + 1) <= highest_unlocked


static func is_level_cleared(level_index: int, highest_unlocked: int) -> bool:
	return highest_unlocked > (level_index + 1)


static func _commission(npc: String, icon: String, title: String, desc: String, rule: int, param: float) -> Dictionary:
	return {
		"npc": npc,
		"icon": icon,
		"title": title,
		"desc": desc,
		"rule": rule,
		"param": param,
	}


static func _scale_props(base: Array, mult: float) -> Array:
	var out: Array = []
	for entry_v in base:
		var e: Dictionary = (entry_v as Dictionary).duplicate(true)
		var typ := String(e.get("type", "box"))
		var use_m := mult
		if typ in SETPIECE_TYPES:
			use_m = minf(mult, SETPIECE_COUNT_CAP_MULT)
		var c := int(e.get("count", 1))
		e["count"] = maxi(1, int(round(float(c) * use_m)))
		out.append(e)
	return out


static func _merge_props(a: Array, b: Array) -> Array:
	var out: Array = []
	for x in a:
		out.append((x as Dictionary).duplicate(true))
	for x in b:
		out.append((x as Dictionary).duplicate(true))
	return out


## chapter dict → 5 seviye
static func _expand_chapter(ch: Dictionary, chapter_num: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var focus: Array = ch.get("focus_props", []) as Array
	var filler: Array = ch.get("filler_props", []) as Array
	var climax: Array = ch.get("climax_props", focus) as Array
	var tools := int(ch.get("unlocked_tools", 1))
	var base_time := float(ch.get("base_time", 48.0))
	var npc := String(ch.get("npc", "Remzi"))
	var icon := String(ch.get("icon", "🧹"))
	var chapter_title := String(ch.get("title", "Bölüm"))
	var id_base := String(ch.get("id", "ch"))
	var ch_prop_m := chapter_prop_mult(chapter_num, ch)
	var stack_range := box_stack_range_for(chapter_num, ch)

	for tier in TIERS_PER_CHAPTER:
		# Global display number: intro'lar + bölüm kademeleri
		var display_n := INTRO_LEVELS + (chapter_num - 1) * TIERS_PER_CHAPTER + tier + 1

		var props: Array
		var time_lim: float
		var subtitle: String
		var intro: String
		var hint: String
		var allow_junk := bool(ch.get("allow_junk", true)) and tier >= int(ch.get("junk_from_tier", 1))
		var disable_hazards := tier < int(ch.get("hazards_from_tier", 2))
		var disable_micro := tier < int(ch.get("micro_from_tier", 1))
		var disable_pressure := tier < int(ch.get("pressure_from_tier", 2))
		var is_boss := bool(ch.get("is_boss_room", false)) and tier == 4
		var rule := CommissionData.Rule.NONE
		var rule_param := 0.0
		var commission_title := "%s · %s" % [chapter_title, TIER_LABELS[tier]]
		var commission_desc := String(ch.get("intro", "Odayı temizle."))

		match tier:
			0:
				props = _scale_props(focus, 0.45 * ch_prop_m)
				time_lim = base_time + 18.0
				subtitle = "Yeni: %s" % String(ch.get("new_mechanic", "öğren"))
				intro = "Bu bölümün temeli: %s. Sakin başla." % String(ch.get("new_mechanic", "mekanik"))
				hint = String(ch.get("hint_intro", ch.get("tutorial", "")))
				commission_desc = intro
				disable_hazards = true
				disable_micro = true
				disable_pressure = true
				allow_junk = false
			1:
				props = _scale_props(focus, 0.7 * ch_prop_m)
				time_lim = base_time + 10.0
				subtitle = "Alıştırma · %s" % TIER_LABELS[tier]
				intro = "Aynı mekaniği biraz daha yoğun tekrarla."
				hint = String(ch.get("hint_filler", ch.get("tutorial", "")))
				commission_desc = intro
			2:
				props = _merge_props(
					_scale_props(focus, 0.75 * ch_prop_m),
					_scale_props(filler, 0.85 * ch_prop_m)
				)
				time_lim = base_time + 4.0
				subtitle = "Karışık pratik"
				intro = "Önceki kirler de karışıyor — tempo tut."
				hint = String(ch.get("hint_mixed", "Öncelik tut · alet değiştir"))
				commission_desc = intro
			3:
				props = _merge_props(
					_scale_props(focus, 1.0 * ch_prop_m),
					_scale_props(filler, 1.0 * ch_prop_m)
				)
				time_lim = maxf(LEVEL_TIME_FLOOR, base_time - 2.0)
				subtitle = "Zorluk artıyor"
				intro = String(ch.get("challenge_intro", "Daha sıkı süre · daha çok kir."))
				hint = String(ch.get("hint_challenge", ch.get("tutorial", "")))
				rule = int(ch.get("challenge_rule", CommissionData.Rule.TIME_LIMIT)) as CommissionData.Rule
				rule_param = float(ch.get("challenge_param", time_lim))
				if rule == CommissionData.Rule.TIME_LIMIT:
					rule_param = time_lim
				commission_desc = String(ch.get("challenge_desc", intro))
			4:
				props = _scale_props(climax, 1.0 * ch_prop_m)
				time_lim = maxf(LEVEL_TIME_FLOOR + 4.0, base_time)
				subtitle = String(ch.get("climax_subtitle", "Bölüm doruğu"))
				intro = String(ch.get("climax_intro", ch.get("intro", "Doruk turu.")))
				hint = String(ch.get("hint_climax", ch.get("tutorial", "")))
				rule = int(ch.get("climax_rule", ch.get("challenge_rule", CommissionData.Rule.TIME_LIMIT))) as CommissionData.Rule
				rule_param = float(ch.get("climax_param", time_lim))
				if rule == CommissionData.Rule.TIME_LIMIT:
					rule_param = time_lim
				commission_desc = String(ch.get("climax_desc", intro))
				# Bölüm eşiğini aşmadan hazard/micro zorla açma
				disable_hazards = tier < int(ch.get("hazards_from_tier", 2)) or bool(ch.get("disable_hazards", false))
				disable_micro = tier < int(ch.get("micro_from_tier", 1))
				disable_pressure = tier < int(ch.get("pressure_from_tier", 2))
				allow_junk = bool(ch.get("allow_junk", true)) and tier >= int(ch.get("junk_from_tier", 1))

		# Global gametime çarpanı
		if time_lim > 0.0:
			time_lim = maxf(LEVEL_TIME_FLOOR * 0.85, time_lim * LEVEL_TIME_MULT)
		if rule == CommissionData.Rule.TIME_LIMIT:
			rule_param = time_lim

		# Karanlık bölüm: tüm kademelerde fener konisi maskesi
		if id_base == "dark":
			rule = CommissionData.Rule.LOW_VISIBILITY
			rule_param = float(ch.get("challenge_param", 0.0))

		var lvl := {
			"id": "%s_t%d" % [id_base, tier],
			"name": "%d · %s · %s" % [display_n, chapter_title, TIER_LABELS[tier]],
			"subtitle": subtitle,
			"npc": npc,
			"icon": icon,
			"intro": intro,
			"floor": ch.get("floor", Color(0.2, 0.2, 0.22)),
			"wall": ch.get("wall", Color(0.28, 0.28, 0.3)),
			"wall_style": String(ch.get("wall_style", "plaster")),
			"accent": ch.get("accent", Color(0.8, 0.7, 0.4)),
			"stations": ch.get("stations", ["trash", "bucket"]),
			"tutorial": hint,
			"unlocked_tools": tools,
			"allow_mop": bool(ch.get("allow_mop", true)),
			"allow_junk": allow_junk,
			"disable_junk": not allow_junk,
			"time_limit": time_lim,
			"disable_hazards": disable_hazards or bool(ch.get("disable_hazards", false)),
			"disable_micro": disable_micro,
			"disable_pressure": disable_pressure,
			"disable_curses": tier < 3 and chapter_num < 3,
			"double_dash": bool(ch.get("double_dash", false)) and tier >= int(ch.get("dash_from_tier", 2)),
			"ufo_abduction": bool(ch.get("ufo_abduction", false)),
			"theme_id": id_base,
			"chapter": chapter_num,
			"tier": tier,
			"chapter_prop_mult": ch_prop_m,
			"box_stack_min": stack_range.x,
			"box_stack_max": stack_range.y,
			"commission": _commission(npc, icon, commission_title, commission_desc, rule as int, rule_param),
			"props": props,
		}
		if is_boss:
			lvl["is_boss_room"] = true
			lvl["boss_mode"] = String(ch.get("boss_mode", ""))
			lvl["boss_title"] = String(ch.get("boss_title", "SET-PIECE"))
		# İlk karşılaşma: bölümlemeli mekanik tutorial
		var intro_sections: Array = ch.get("intro_sections", []) as Array
		if tier == 0 and not intro_sections.is_empty():
			lvl["tutorial_level"] = true
			lvl["sections"] = intro_sections.duplicate(true)
			lvl["props"] = []
			lvl["name"] = "%d · %s · Tutorial" % [display_n, chapter_title]
			lvl["subtitle"] = "Yeni alet öğren"
			lvl["disable_hazards"] = true
			lvl["disable_micro"] = true
			lvl["disable_pressure"] = true
			lvl["disable_curses"] = true
			lvl["disable_junk"] = true
			lvl["allow_junk"] = false
			lvl["time_limit"] = 0.0
			lvl["tutorial"] = String(ch.get("tutorial", hint))
			if id_base == "broom":
				lvl["start_tool"] = "broom"
			lvl["commission"] = _commission(
				npc,
				icon,
				"%s · Tutorial" % chapter_title,
				String(ch.get("intro_sections_desc", intro)),
				CommissionData.Rule.NONE,
				0.0
			)
		out.append(lvl)
	return out


static func _all() -> Array[Dictionary]:
	var levels: Array[Dictionary] = []
	levels.append(_tutorial())
	levels.append(_junk_tutorial())
	var chapters: Array[Dictionary] = _chapter_defs()
	for i in chapters.size():
		levels.append_array(_expand_chapter(chapters[i], i + 1))
	return levels


static func _chapter_defs() -> Array[Dictionary]:
	## İsteğe bağlı override anahtarları (herhangi bir chapter dict'te):
	##   prop_growth: float     — CHAPTER_PROP_GROWTH yerine (örn. 0.12)
	##   prop_mult: float       — mutlak çarpan (prop_growth yok sayılır)
	##   box_stack_min/max: int — kutu yığını yüksekliği
	return [
		{
			"id": "liquids",
			"title": "Paspas",
			"npc": "Kuzen Marv",
			"icon": "🧹",
			"new_mechanic": "paspas ile sıvı ovalama",
			"floor": Color(0.32, 0.34, 0.38),
			"wall": Color(0.48, 0.5, 0.54),
			"wall_style": "garage",
			"accent": Color(0.45, 0.85, 1.0),
			"stations": ["trash", "bucket"],
			"unlocked_tools": 1,
			"allow_mop": true,
			"base_time": 55.0,
			"junk_from_tier": 99,
			"hazards_from_tier": 99,
			"micro_from_tier": 99,
			"pressure_from_tier": 99,
			"disable_hazards": true,
			"tutorial": "1=Paspas · Space basılı tut + yürü = ovala · Space tık = hızlı (kaygan iz)",
			"hint_intro": "Sadece sıvı lekeler — paspası basılı tutup üzerinde yürü",
			"hint_filler": "Daha çok leke · paspas kirlenirse kovada Space basılı tut",
			"hint_mixed": "Sıvı + ilk kutular — önce paspasla sil, sonra koliyi çöpe",
			"hint_challenge": "Tempo tut — sürükleyerek temizle (mash kaygan bırakır)",
			"hint_climax": "Sıvı deniz + kutular · kova hazır tut",
			"focus_props": [
				{"type": "wet", "count": 2},
				{"type": "slime", "count": 1},
			],
			"filler_props": [
				{"type": "wet", "count": 1},
				{"type": "slime", "count": 1},
				{"type": "box", "count": 2},
			],
			"climax_props": [
				{"type": "wet", "count": 2},
				{"type": "slime", "count": 2},
				{"type": "box", "count": 3},
			],
			"challenge_rule": CommissionData.Rule.TIME_LIMIT,
			"challenge_intro": "Süre sıkı — sürükleyerek sil, mash'ten kaçın (kaygan).",
			"climax_subtitle": "Islak sahne",
			"climax_intro": "Paspas + kova + birkaç koli — Viscera günü!",
		},
		{
			"id": "mold",
			"title": "Küf",
			"npc": "Gargoyle Grimble",
			"icon": "🤢",
			"new_mechanic": "paspas + küf",
			"floor": Color(0.16, 0.24, 0.18),
			"wall": Color(0.22, 0.32, 0.24),
			"wall_style": "mold",
			"accent": Color(0.45, 0.95, 0.40),
			"stations": ["trash", "bucket"],
			"unlocked_tools": 1,
			"allow_mop": true,
			"base_time": 50.0,
			"junk_from_tier": 2,
			"hazards_from_tier": 3,
			"micro_from_tier": 2,
			"pressure_from_tier": 3,
			"tutorial": "1=Paspas · küfe vur / ovala",
			"hint_intro": "Sadece birkaç küf — paspasla temizle",
			"hint_filler": "Küf + koli · paspas kirlenir → kova",
			"hint_mixed": "Tablo düzelt (YAMUK) · küf · koli",
			"focus_props": [
				{"type": "mold", "count": 4},
				{"type": "box", "count": 2},
			],
			"filler_props": [
				{"type": "painting", "count": 1},
				{"type": "box", "count": 1},
			],
			"climax_props": [
				{"type": "mold", "count": 5},
				{"type": "box", "count": 3},
				{"type": "tv", "count": 1},
				{"type": "painting", "count": 2},
			],
			"challenge_rule": CommissionData.Rule.TIME_LIMIT,
			"climax_subtitle": "Küf baskını",
			"climax_intro": "Küf her yerde — tabloları da düzelt, süreye karşı bitir!",
		},
		{
			"id": "broom",
			"title": "Süpürge",
			"npc": "Hayalet Ev Sahibi",
			"icon": "👻",
			"new_mechanic": "süpürge emme (sektör)",
			"floor": Color(0.28, 0.2, 0.14),
			"wall": Color(0.36, 0.28, 0.2),
			"wall_style": "peach",
			"accent": Color(0.95, 0.72, 0.35),
			"stations": ["trash", "bucket"],
			"unlocked_tools": 2,
			"base_time": 48.0,
			"junk_from_tier": 2,
			"hazards_from_tier": 2,
			"micro_from_tier": 1,
			"pressure_from_tier": 2,
			"tutorial": "2=Süpürge · seçince otomatik emer · mavi sektördeki tozu çek",
			"hint_intro": "Süpürge: mavi alan içindeki tozlar uçar! Torba 3/3 → çöp",
			"hint_filler": "Sektördeki her şeyi em · alet değiştir (1/2)",
			"hint_mixed": "TV tamir + süpürge sektörü",
			"intro_sections_desc": "Üç kısa ders: em → torba doldur/boşalt → karışık toz.",
			"intro_sections": [
				{
					"id": "vac_suck",
					"title": "Bölüm 1 · Em",
					"banner": "SÜPÜRGEYLE EM",
					"subtitle": "2 = Süpürge · otomatik emme",
					"hint": "2 tuşu = süpürge · toza yaklaş → mavi sektör emer",
					"card_desc": "Süpürgeyi (2) seç. Basılı tutmana gerek yok — mavi alan içindeki toz/kırıntı/küf otomatik çekilir.",
					"banner_color": Color(0.45, 0.85, 1.0),
					"enable_micro": false,
					"enable_pressure": false,
					"props": [
						{"type": "dust", "count": 2},
						{"type": "crumb", "count": 1},
					],
				},
				{
					"id": "vac_bag",
					"title": "Bölüm 2 · Torba",
					"banner": "TORBA DOLUNCA ÇÖP",
					"subtitle": "3 emme = dolu · çöpte Space = boşalt",
					"hint": "Torba 3/3 dolunca emme durur · ÇÖP yanında Space",
					"card_desc": "Torba en fazla 3 emer. Dördüncü toz için önce çöpün yanında Space ile boşalt!",
					"banner_color": Color(1.0, 0.55, 0.35),
					"enable_micro": false,
					"enable_pressure": false,
					"props": [
						{"type": "dust", "count": 2},
						{"type": "crumb", "count": 2},
					],
				},
				{
					"id": "vac_mix",
					"title": "Bölüm 3 · Karışık",
					"banner": "TOZ + KÜF + KOLI",
					"subtitle": "Em · torba boşalt · koliyi çöpe taşı",
					"hint": "Küf/toz = süpürge em · koli = tut → çöp",
					"card_desc": "Toz ve küfü em. Torba dolarsa çöpe boşalt. Koliyi elle çöpe taşı.",
					"banner_color": Color(0.95, 0.78, 0.45),
					"enable_micro": false,
					"enable_pressure": false,
					"props": [
						{"type": "dust", "count": 2},
						{"type": "mold", "count": 1},
						{"type": "box", "count": 1},
					],
				},
			],
			"focus_props": [
				{"type": "crumb", "count": 4},
				{"type": "dust", "count": 3},
			],
			"filler_props": [
				{"type": "dust", "count": 2},
				{"type": "mold", "count": 2},
				{"type": "box", "count": 1},
			],
			"climax_props": [
				{"type": "crumb", "count": 5},
				{"type": "dust", "count": 4},
				{"type": "mold", "count": 2},
				{"type": "box", "count": 2},
				{"type": "tv_repair", "count": 1},
			],
			"challenge_rule": CommissionData.Rule.FORBIDDEN,
			"challenge_desc": "✕ işaretli koliye dokunma — gerisini temizle.",
			"climax_rule": CommissionData.Rule.FORBIDDEN,
			"climax_subtitle": "Kutsal koli",
			"climax_intro": "Tozları em, TV'yi tamir et — yasak koliye el sürme!",
		},
		{
			"id": "slime",
			"title": "Balçık",
			"npc": "Gargoyle Grimble",
			"icon": "🐌",
			"new_mechanic": "paspas ovalama (slime)",
			"floor": Color(0.14, 0.24, 0.22),
			"wall": Color(0.18, 0.3, 0.28),
			"wall_style": "cool",
			"accent": Color(0.35, 1.0, 0.72),
			"stations": ["trash", "bucket"],
			"unlocked_tools": 2,
			"base_time": 46.0,
			"junk_from_tier": 1,
			"hazards_from_tier": 2,
			"micro_from_tier": 1,
			"pressure_from_tier": 2,
			"tutorial": "Lekeye Space spam = ovala",
			"hint_intro": "Yeşil balçık — Space ile ovala, bitene kadar",
			"focus_props": [
				{"type": "slime", "count": 2},
				{"type": "box", "count": 1},
			],
			"filler_props": [
				{"type": "crumb", "count": 2},
				{"type": "mold", "count": 1},
			],
			"climax_props": [
				{"type": "slime", "count": 2},
				{"type": "crumb", "count": 3},
				{"type": "box", "count": 2},
			],
			"challenge_rule": CommissionData.Rule.TIME_LIMIT,
			"climax_subtitle": "Kaygan zemin",
			"climax_intro": "Balçık her yerde — süreye karşı ovala!",
		},
		{
			"id": "brush",
			"title": "Fırça & İksir",
			"npc": "Cadı Morgana",
			"icon": "🧪",
			"new_mechanic": "fırça + kabuk + iksir",
			"floor": Color(0.42, 0.28, 0.52),
			"wall": Color(0.32, 0.18, 0.4),
			"wall_style": "ritual",
			"accent": Color(0.85, 0.4, 1.0),
			"stations": ["trash", "bucket"],
			"unlocked_tools": 3,
			"base_time": 44.0,
			"junk_from_tier": 1,
			"hazards_from_tier": 2,
			"micro_from_tier": 1,
			"pressure_from_tier": 2,
			"is_boss_room": true,
			"boss_mode": "mega_scrub",
			"boss_title": "SET-PIECE · İKSİR PATLAMASI",
			"tutorial": "3=Fırça · kabuk · iksire basma",
			"hint_intro": "Yeni: Fırça — kabuklara vur",
			"focus_props": [
				{"type": "crust", "count": 2},
				{"type": "slime", "count": 1},
			],
			"filler_props": [
				{"type": "potion", "count": 1},
				{"type": "box", "count": 1},
			],
			"climax_props": [
				{"type": "potion", "count": 3},
				{"type": "crust", "count": 3},
				{"type": "slime", "count": 2},
				{"type": "boss_slime", "count": 1},
				{"type": "wet", "count": 2},
			],
			"challenge_rule": CommissionData.Rule.HIGH_RISK,
			"challenge_param": 1.4,
			"challenge_desc": "İksire basma — hata cezası sert.",
			"climax_rule": CommissionData.Rule.HIGH_RISK,
			"climax_param": 1.4,
			"climax_subtitle": "İksir patlaması",
			"climax_intro": "Boss turu — iksir, kabuk, büyük balçık. Fırça hazır!",
		},
		{
			"id": "spray",
			"title": "Sprey",
			"npc": "Gargoyle Grimble",
			"icon": "💧",
			"new_mechanic": "sprey → ıslatma (opsiyonel) + paspas",
			"floor": Color(0.14, 0.2, 0.28),
			"wall": Color(0.2, 0.28, 0.38),
			"wall_style": "cool",
			"accent": Color(0.4, 0.85, 1.0),
			"stations": ["trash", "bucket", "drain"],
			"unlocked_tools": 4,
			"double_dash": true,
			"dash_from_tier": 2,
			"base_time": 42.0,
			"junk_from_tier": 1,
			"hazards_from_tier": 1,
			"micro_from_tier": 1,
			"pressure_from_tier": 2,
			"tutorial": "4=Sprey (opsiyonel) · ıslak lekeler 1=Paspas · Shift×2",
			"hint_intro": "Yeni: Sprey. Islak lekeleri paspasla sil — sprey opsiyonel.",
			"focus_props": [
				{"type": "wet", "count": 2},
				{"type": "box", "count": 1},
			],
			"filler_props": [
				{"type": "mold", "count": 2},
				{"type": "painting", "count": 1},
			],
			"climax_props": [
				{"type": "wet", "count": 2},
				{"type": "mold", "count": 3},
				{"type": "crumb", "count": 3},
				{"type": "box", "count": 2},
				{"type": "painting", "count": 2},
			],
			"challenge_rule": CommissionData.Rule.TIME_LIMIT,
			"climax_subtitle": "Sabırsız patron",
			"climax_intro": "Sprey + paspas + tablolar — çift dash kullan!",
		},
		{
			"id": "alien",
			"title": "Uzaylı",
			"npc": "Ajan Zorp",
			"icon": "👽",
			"new_mechanic": "UFO ışını — yakalanma = kayıp",
			"floor": Color(0.12, 0.18, 0.14),
			"wall": Color(0.18, 0.28, 0.2),
			"wall_style": "cool",
			"accent": Color(0.45, 1.0, 0.55),
			"stations": ["trash", "bucket", "drain"],
			"unlocked_tools": 4,
			"double_dash": true,
			"dash_from_tier": 0,
			"base_time": 40.0,
			"junk_from_tier": 1,
			"hazards_from_tier": 2,
			"micro_from_tier": 1,
			"pressure_from_tier": 1,
			"ufo_abduction": true,
			"tutorial": "UFO iner · ışından kaç (Shift) · aletler 1–4",
			"hint_intro": "Ufolar iniyor — yeşil ışında kalma, yoksa kaçırılırsın!",
			"hint_filler": "Işından dash ile çık · süpür / fırçala / sprey",
			"hint_mixed": "Temizlik + UFO kaçınma",
			"hint_challenge": "Çok UFO — ışınları izle",
			"hint_climax": "Kaçırma yok · tüm kiri bitir!",
			"focus_props": [
				{"type": "wet", "count": 2},
				{"type": "crumb", "count": 3},
				{"type": "box", "count": 1},
			],
			"filler_props": [
				{"type": "mold", "count": 2},
				{"type": "crust", "count": 2},
				{"type": "slime", "count": 1},
			],
			"climax_props": [
				{"type": "wet", "count": 2},
				{"type": "crumb", "count": 4},
				{"type": "mold", "count": 2},
				{"type": "crust", "count": 2},
				{"type": "slime", "count": 2},
				{"type": "box", "count": 2},
				{"type": "tv_repair", "count": 1},
			],
			"challenge_rule": CommissionData.Rule.TIME_LIMIT,
			"climax_rule": CommissionData.Rule.TIME_LIMIT,
			"climax_subtitle": "Kaçırma gecesi",
			"climax_intro": "Ufolar iniyor — ışından kaç, kirleri bitir!",
		},
		{
			"id": "dark",
			"title": "Karanlık",
			"npc": "Vampir Kont",
			"icon": "🦇",
			"new_mechanic": "gizli kir + fener maskesi",
			"floor": Color(0.07, 0.07, 0.1),
			"wall": Color(0.12, 0.12, 0.16),
			"wall_style": "cool",
			"accent": Color(0.45, 0.85, 1.0),
			"stations": ["trash", "bucket", "drain"],
			"unlocked_tools": 4,
			"double_dash": true,
			"dash_from_tier": 0,
			"base_time": 40.0,
			"junk_from_tier": 2,
			"hazards_from_tier": 2,
			"micro_from_tier": 1,
			"pressure_from_tier": 2,
			"tutorial": "Fener konisiyle tara — sadece mavi alanda kir görünür",
			"hint_intro": "Karanlık — dönerek tara, koni içindeki gizli kirleri bul",
			"hint_filler": "Feneri çevir · koni dışı görünmez",
			"hint_mixed": "Koniyi tara · alet değiştir",
			"hint_challenge": "Dar görüş — her köşeyi fenerle tara",
			"hint_climax": "Fener konisiyle tara — her gizli kiri bul!",
			"focus_props": [
				{"type": "hidden", "count": 4},
				{"type": "tiny", "count": 2},
			],
			"filler_props": [
				{"type": "mold", "count": 2},
				{"type": "box", "count": 1},
			],
			"climax_props": [
				{"type": "hidden", "count": 6},
				{"type": "tiny", "count": 4},
				{"type": "mold", "count": 2},
				{"type": "boss_slime", "count": 1},
			],
			"challenge_rule": CommissionData.Rule.LOW_VISIBILITY,
			"challenge_param": 0.0,
			"climax_rule": CommissionData.Rule.LOW_VISIBILITY,
			"climax_param": 0.0,
			"climax_subtitle": "Ay ışığı",
			"climax_intro": "Fener konisiyle tara — her gizli kiri bul!",
		},
		{
			"id": "ritual",
			"title": "Ritüel",
			"npc": "Cadı Morgana",
			"icon": "🧙",
			"new_mechanic": "yüksek risk karma",
			"floor": Color(0.2, 0.1, 0.22),
			"wall": Color(0.28, 0.12, 0.3),
			"wall_style": "ritual",
			"accent": Color(0.95, 0.4, 0.85),
			"stations": ["trash", "bucket", "drain"],
			"unlocked_tools": 4,
			"double_dash": true,
			"dash_from_tier": 0,
			"base_time": 38.0,
			"junk_from_tier": 1,
			"hazards_from_tier": 1,
			"micro_from_tier": 1,
			"pressure_from_tier": 1,
			"is_boss_room": true,
			"boss_mode": "ritual_rush",
			"boss_title": "SET-PIECE · CADI RİTÜELİ",
			"tutorial": "İksire basma · aletler 1–4",
			"hint_intro": "İksir + balçık — riskli ama puanlı",
			"focus_props": [
				{"type": "potion", "count": 1},
				{"type": "slime", "count": 1},
				{"type": "crust", "count": 1},
			],
			"filler_props": [
				{"type": "hidden", "count": 1},
				{"type": "painting", "count": 1},
			],
			"climax_props": [
				{"type": "potion", "count": 2},
				{"type": "slime", "count": 2},
				{"type": "crust", "count": 2},
				{"type": "hidden", "count": 2},
				{"type": "boss_slime", "count": 1},
				{"type": "painting", "count": 1},
			],
			"challenge_rule": CommissionData.Rule.HIGH_RISK,
			"challenge_param": 2.0,
			"climax_rule": CommissionData.Rule.HIGH_RISK,
			"climax_param": 2.0,
			"climax_subtitle": "Cadı ritüeli",
			"climax_intro": "Boss — stres cezası sert; tempo tut!",
		},
		{
			"id": "finale",
			"title": "Final",
			"npc": "Remzi",
			"icon": "🔥",
			"new_mechanic": "her şey bir arada",
			"floor": Color(0.3, 0.08, 0.1),
			"wall": Color(0.38, 0.12, 0.14),
			"wall_style": "garage",
			"accent": Color(1.0, 0.35, 0.4),
			"stations": ["trash", "bucket", "drain"],
			"unlocked_tools": 4,
			"double_dash": true,
			"dash_from_tier": 0,
			"base_time": 42.0,
			"junk_from_tier": 0,
			"hazards_from_tier": 0,
			"micro_from_tier": 0,
			"pressure_from_tier": 0,
			"is_boss_room": true,
			"boss_mode": "box_rain",
			"boss_title": "BOSS · KUTU YAĞMURU",
			"tutorial": "Aletler 1–4 · burger · kutu yağmuru",
			"hint_intro": "Isınma — karışık ama henüz final değil",
			"focus_props": [
				{"type": "box", "count": 3},
				{"type": "mold", "count": 2},
				{"type": "slime", "count": 1},
				{"type": "crumb", "count": 2},
			],
			"filler_props": [
				{"type": "wet", "count": 1},
				{"type": "tiny", "count": 2},
				{"type": "painting", "count": 1},
			],
			"climax_props": [
				{"type": "box", "count": 10},
				{"type": "tv", "count": 2},
				{"type": "mold", "count": 3},
				{"type": "crumb", "count": 3},
				{"type": "slime", "count": 2},
				{"type": "potion", "count": 2},
				{"type": "crust", "count": 2},
				{"type": "wet", "count": 1},
				{"type": "tiny", "count": 3},
				{"type": "hidden", "count": 2},
				{"type": "boss_slime", "count": 1},
				{"type": "painting", "count": 1},
				{"type": "tv_repair", "count": 1},
			],
			"challenge_rule": CommissionData.Rule.TIME_LIMIT,
			"climax_rule": CommissionData.Rule.TIME_LIMIT,
			"climax_subtitle": "Büyük kaos",
			"climax_intro": "Son gece — her kir tipi + kutu yağmuru!",
		},
	]


static func _junk_tutorial() -> Dictionary:
	return {
		"id": "junk_powerup",
		"name": "2 · Tutorial · Abur Cubur",
		"subtitle": "Ye · şiş · power-up",
		"npc": "Kuzen Marv",
		"icon": "🍔",
		"intro": "Gökten hamburger düşer! Space ile ye — 3. lokmada rastgele güç: HIZ veya tüm sahneyi süpür.",
		"floor": Color(0.34, 0.32, 0.28),
		"wall": Color(0.48, 0.42, 0.36),
		"wall_style": "garage",
		"accent": Color(1.0, 0.7, 0.3),
		"stations": ["trash", "bucket"],
		"allow_mop": true,
		"unlocked_tools": 1,
		"allow_junk": true,
		"disable_junk": false,
		"junk_starter_burst": 3,
		"junk_interval_min": 5.5,
		"junk_interval_max": 8.5,
		"junk_max_concurrent": 2,
		"tutorial_level": true,
		"disable_hazards": true,
		"disable_micro": true,
		"disable_pressure": true,
		"disable_curses": true,
		"time_limit": 70.0,
		"chapter": 0,
		"tier": 0,
		"tutorial": "Space = abur cubur ye · 3 yemek = ⚡Hız veya 🌪️Süpür",
		"commission": _commission("Kuzen Marv", "🍔", "Abur Cubur Dersi",
			"3 abur cubur ye — rastgele power-up gelir. Sonra kalan kirleri bitir!",
			CommissionData.Rule.NONE, 0.0),
		"props": [
			{"type": "box", "count": 3},
			{"type": "wet", "count": 2},
			{"type": "tv", "count": 1},
		],
	}


static func _tutorial() -> Dictionary:
	return {
		"id": "garage",
		"name": "1 · Tutorial · Garaj",
		"subtitle": "5 bölüm · öğren + tempo",
		"npc": "Kuzen Marv",
		"icon": "🧹",
		"intro": "Hoş geldin! Beş kısa bölüm: taşı, vur, yığ, karıştır, sonra tempo. Paspas ve tehlike yok.",
		"floor": Color(0.34, 0.36, 0.38),
		"wall": Color(0.52, 0.51, 0.50),
		"wall_style": "garage",
		"accent": Color(0.72, 0.58, 0.32),
		"stations": ["trash"],
		"allow_mop": false,
		"unlocked_tools": 1,
		"allow_junk": false,
		"tutorial_level": true,
		"disable_hazards": true,
		"disable_micro": true,
		"disable_pressure": true,
		"disable_curses": true,
		"disable_junk": true,
		"chapter": 0,
		"tier": 0,
		"tutorial": "WASD hareket · Space tut/at/vur · Shift dash",
		"commission": _commission("Kuzen Marv", "🧹", "İlk Gün · Tutorial",
			"Beş bölüm: taşı → vur → yığ → karışık → tempo. Her kartı okuyup tıkla / Space ile geç.",
			CommissionData.Rule.NONE, 0.0),
		"props": [],
		"sections": [
			{
				"id": "carry",
				"title": "Bölüm 1 · Taşı",
				"banner": "KOLİ → ÇÖP",
				"subtitle": "Space tut → çöpe git → Space at",
				"hint": "1) Koliye yaklaş  2) Space = tut  3) Çöpün yanında Space = at",
				"card_desc": "İki koli var. Space ile tut, yeşil ÇÖP'e götür, yanında tekrar Space ile at.",
				"banner_color": Color(0.55, 0.92, 0.65),
				"enable_micro": false,
				"enable_pressure": false,
				"props": [{"type": "box", "count": 2}],
			},
			{
				"id": "smash",
				"title": "Bölüm 2 · Vur",
				"banner": "TV'Yİ KIR",
				"subtitle": "Yaklaş · Space = vur (3 kez)",
				"hint": "TV'ye yaklaş · Space üç kez · Shift = dash",
				"card_desc": "TV taşınmaz. Yaklaş ve Space ile vur — 3 vuruşta kırılır.",
				"banner_color": Color(1.0, 0.75, 0.35),
				"enable_micro": false,
				"enable_pressure": false,
				"props": [{"type": "tv", "count": 1}],
			},
			{
				"id": "stack",
				"title": "Bölüm 3 · Yığ",
				"banner": "KOLİLERİ ÜST ÜSTE KOY",
				"subtitle": "Koli tut → başka koliye Space = yığın → çöpe at",
				"hint": "Elde koli varken başka koliye Space = stack · sonra çöpe Space",
				"card_desc": "Bir koliyi tut. Başka koliye Space — üst üste yığılır. Yığını çöpe at.",
				"banner_color": Color(0.95, 0.78, 0.45),
				"enable_micro": false,
				"enable_pressure": false,
				"props": [{"type": "box", "count": 3}],
			},
			{
				"id": "mix",
				"title": "Bölüm 4 · Karışık",
				"banner": "TAŞI + VUR",
				"subtitle": "Koli çöp · TV kır · Shift dash",
				"hint": "Koli→çöp · TV→Space vur · Shift dash",
				"card_desc": "Kolileri çöpe, TV'yi kır. Shift dash ile hızlan.",
				"banner_color": Color(0.55, 0.78, 1.0),
				"enable_micro": false,
				"enable_pressure": false,
				"props": [
					{"type": "box", "count": 2},
					{"type": "box", "count": 1, "fallen": true},
					{"type": "tv", "count": 1},
				],
			},
			{
				"id": "tempo",
				"title": "Bölüm 5 · Tempo",
				"banner": "EMİRLER GELİYOR!",
				"subtitle": "Üst şeritteki emri süre içinde yap",
				"hint": "Üst şerit = emir · ★ hedef · combo süre ekler",
				"card_desc": "Son tur: süre başlar! ★ hedefe koş — combo ile süre uzar.",
				"banner_color": Color(1.0, 0.45, 0.55),
				"enable_micro": true,
				"enable_pressure": false,
				"time_limit": 45.0,
				"props": [
					{"type": "box", "count": 4},
					{"type": "tv", "count": 1},
					{"type": "box", "count": 1, "fallen": true},
				],
			},
		],
	}
