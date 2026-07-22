class_name CardPool
extends RefCounted

## Endless mod starter kart havuzu (10 kart).


static func starter_cards() -> Array[CardData]:
	var raw: Array[Dictionary] = [
		{
			"id": "momentum",
			"title": "Momentum",
			"desc": "Combo milestone başına +3 sn global süre.",
			"icon": "⏱",
			"rarity": CardData.Rarity.COMMON,
			"add": {"milestone_time_add": 3.0},
		},
		{
			"id": "second_wind",
			"title": "İkinci Nefes",
			"desc": "Combo milestone stamina ödülü x2.",
			"icon": "💨",
			"rarity": CardData.Rarity.COMMON,
			"mult": {"milestone_stamina_mult": 2.0},
		},
		{
			"id": "golden_hands",
			"title": "Altın Eller",
			"desc": "Combo puanları x1.5 (oda skoru).",
			"icon": "✨",
			"rarity": CardData.Rarity.UNCOMMON,
			"mult": {"score_combo_mult": 1.5},
		},
		{
			"id": "cool_mop",
			"title": "Serin Paspas",
			"desc": "Paspas kirlenme hızı x0.72.",
			"icon": "🧽",
			"rarity": CardData.Rarity.COMMON,
			"mult": {"mop_heat_mult": 0.72},
		},
		{
			"id": "lazy_rinse",
			"title": "Tembel Durulama",
			"desc": "Kovada durulama hızı x1.28.",
			"icon": "🪣",
			"rarity": CardData.Rarity.COMMON,
			"mult": {"mop_rinse_mult": 1.28},
		},
		{
			"id": "drip_time",
			"title": "Damla Süre",
			"desc": "Her temizlik +0.6 sn global süre.",
			"icon": "💧",
			"rarity": CardData.Rarity.COMMON,
			"add": {"clean_time_add": 0.6},
		},
		{
			"id": "gargoyle_calm",
			"title": "Sakin Taş",
			"desc": "Yüksek combo kırılınca ekstra stres x0.5.",
			"icon": "🗿",
			"rarity": CardData.Rarity.UNCOMMON,
			"mult": {"combo_break_stress_mult": 0.5},
		},
		{
			"id": "brush_rush",
			"title": "Fırça Coşkusu",
			"desc": "Fırça mash hızı x1.45.",
			"icon": "🪥",
			"rarity": CardData.Rarity.COMMON,
			"mult": {"mash_mult": 1.45},
		},
		{
			"id": "hot_streak",
			"title": "Ateşli Seri",
			"desc": "Combo x8+ iken temizlik hızı x1.3.",
			"icon": "🔥",
			"rarity": CardData.Rarity.UNCOMMON,
			"flags": {"hot_streak_threshold": 8},
			"mult": {"hot_streak_speed_mult": 1.3},
		},
		{
			"id": "overclock",
			"title": "Overclock",
			"desc": "Tüm ovalama/temizlik hızı x1.12.",
			"icon": "⚡",
			"rarity": CardData.Rarity.RARE,
			"mult": {"clean_speed_mult": 1.12},
		},
	]

	var out: Array[CardData] = []
	for entry in raw:
		out.append(CardData.from_dict(entry))
	return out


static func find_by_id(card_id: String) -> CardData:
	for card in starter_cards():
		if card.id == card_id:
			return card
	return null
