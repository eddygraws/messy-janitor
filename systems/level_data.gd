class_name LevelData
extends RefCounted

# Adventure: 12 seviye.
# L1-4 temel → L5 slime girişi → L6 Cadı (flagship) → L7+ aletler / final.
#
# Ekipman: L1-3 paspas, L4-5 +süpürge, L6-7 +fırça aşamalı,
# L8 +sprey, L9-12 +cımbız.

const BG_WITCH := Color(0.42, 0.28, 0.52)
const BG_APPRENTICE := Color(0.18, 0.2, 0.26)
const BG_APPETITE := Color(0.24, 0.16, 0.2)
const BG_MOLD := Color(0.16, 0.24, 0.18)
const BG_BROOM := Color(0.28, 0.2, 0.14)
const BG_SLIME := Color(0.14, 0.24, 0.22)
const BG_BRUSH := Color(0.22, 0.18, 0.14)
const BG_SPRAY := Color(0.14, 0.2, 0.28)
const BG_TWEEZERS := Color(0.2, 0.2, 0.28)
const BG_DARK := Color(0.07, 0.07, 0.1)
const BG_CHAOS := Color(0.26, 0.12, 0.12)
const BG_RITUAL := Color(0.2, 0.1, 0.22)
const BG_FINALE := Color(0.3, 0.08, 0.1)


static func level_count() -> int:
	return 12


static func unlocked_equipment(level_index: int) -> int:
	var lvl := level_index + 1
	if lvl >= 9:
		return 5
	elif lvl == 8:
		return 4
	elif lvl >= 6:
		return 3
	elif lvl >= 4:
		return 2
	return 1


static func get_level(level_index: int) -> Dictionary:
	var levels := _all_levels()
	if level_index >= 0 and level_index < levels.size():
		return levels[level_index]
	return levels[0]


static func _commission(npc: String, icon: String, title: String, desc: String, rule: int, param: float) -> Dictionary:
	return {"npc": npc, "icon": icon, "title": title, "desc": desc, "rule": rule, "param": param}


static func _all_levels() -> Array[Dictionary]:
	return [
		# ---------- L1: Çıraklık ----------
		{
			"name": "1 · Çıraklık", "subtitle": "Temel temizlik", "bg": BG_APPRENTICE,
			"unlocked_equipment": 1,
			"rooms": [
				{"label": "1-1", "bg": BG_APPRENTICE, "tutorial": "Kirlere TIKLA ve temizle! Combo x10 = TEMİZLİK BOMBASI.",
					"dirt": [{"type": "stain", "count": 3}]},
				{"label": "1-2", "bg": BG_APPRENTICE, "tutorial": "İnatçı leke: basılı tutup SAĞA-SOLA ovala.",
					"dirt": [{"type": "scrub", "count": 3}]},
				{"label": "1-3", "bg": BG_APPRENTICE,
					"dirt": [{"type": "stain", "count": 2}, {"type": "scrub", "count": 2}]},
				{"label": "1-4", "bg": BG_APPRENTICE,
					"dirt": [{"type": "scrub", "count": 4}]},
				{"label": "1-5", "bg": BG_APPRENTICE,
					"dirt": [{"type": "stain", "count": 3}, {"type": "scrub", "count": 3}]},
			],
		},
		# ---------- L2: İştah ----------
		{
			"name": "2 · İştah", "subtitle": "Abur cubur + kırılgan", "bg": BG_APPETITE,
			"unlocked_equipment": 1,
			"rooms": [
				{"label": "2-1", "bg": BG_APPETITE, "tutorial": "Abur cubura tıklama — stres artar!",
					"dirt": [{"type": "scrub", "count": 3}]},
				{"label": "2-2", "bg": BG_APPETITE, "tutorial": "Kırılgan: YAVAŞ ovala.",
					"dirt": [{"type": "fragile", "count": 1}, {"type": "scrub", "count": 3}]},
				{"label": "2-3", "bg": BG_APPETITE,
					"dirt": [{"type": "scrub", "count": 4}, {"type": "fragile", "count": 1}]},
				{"label": "2-4", "bg": BG_APPETITE,
					"dirt": [{"type": "fragile", "count": 2}, {"type": "stain", "count": 3}]},
				{"label": "2-5", "bg": BG_APPETITE,
					"dirt": [{"type": "scrub", "count": 4}, {"type": "fragile", "count": 2}]},
				{"label": "2-6", "bg": BG_APPETITE,
					"dirt": [{"type": "scrub", "count": 5}, {"type": "fragile", "count": 2}],
					"commission": _commission("Gargoyle Grimble", "⏱", "Hızlı Tur",
						"55 saniye — combo kırılırsa batarız!",
						CommissionData.Rule.TIME_LIMIT, 55.0)},
			],
		},
		# ---------- L3: Küf ----------
		{
			"name": "3 · Küf Baskını", "subtitle": "Yayılmadan yetiş", "bg": BG_MOLD,
			"unlocked_equipment": 1,
			"rooms": [
				{"label": "3-1", "bg": BG_MOLD, "tutorial": "KÜF yayılır — önce onu temizle!",
					"dirt": [{"type": "mold", "count": 1}, {"type": "scrub", "count": 3}]},
				{"label": "3-2", "bg": BG_MOLD,
					"dirt": [{"type": "mold", "count": 2}, {"type": "scrub", "count": 2}]},
				{"label": "3-3", "bg": BG_MOLD,
					"dirt": [{"type": "mold", "count": 2}, {"type": "scrub", "count": 3}]},
				{"label": "3-4", "bg": BG_MOLD,
					"dirt": [{"type": "mold", "count": 3}, {"type": "scrub", "count": 2}],
					"commission": _commission("Gargoyle Grimble", "🤢", "Midem Bulanıyor",
						"40 saniye!",
						CommissionData.Rule.TIME_LIMIT, 40.0)},
				{"label": "3-5", "bg": BG_MOLD,
					"dirt": [{"type": "mold", "count": 2}, {"type": "fragile", "count": 1}, {"type": "scrub", "count": 3}]},
				{"label": "3-6", "bg": BG_MOLD,
					"dirt": [{"type": "mold", "count": 3}, {"type": "scrub", "count": 3}]},
			],
		},
		# ---------- L4: Süpürge ----------
		{
			"name": "4 · Süpürge Zamanı", "subtitle": "Yeni alet: Süpürge", "bg": BG_BROOM,
			"unlocked_equipment": 2,
			"rooms": [
				{"label": "4-1", "bg": BG_BROOM, "tutorial": "SÜPÜRGE (2): kırıntıları ÇÖP KOVASINA sürükle.",
					"dirt": [{"type": "broom", "count": 2}, {"type": "scrub", "count": 2}]},
				{"label": "4-2", "bg": BG_BROOM,
					"dirt": [{"type": "broom", "count": 3}]},
				{"label": "4-3", "bg": BG_BROOM,
					"dirt": [{"type": "broom", "count": 3}, {"type": "scrub", "count": 2}]},
				{"label": "4-4", "bg": BG_BROOM,
					"dirt": [{"type": "broom", "count": 3}, {"type": "mold", "count": 1}]},
				{"label": "4-5", "bg": BG_BROOM,
					"dirt": [{"type": "broom", "count": 3}, {"type": "scrub", "count": 2}],
					"commission": _commission("Hayalet Ev Sahibi", "👻", "Kutsal Leke",
						"İşaretli lekeye SAKIN dokunma!",
						CommissionData.Rule.FORBIDDEN, 0.0)},
				{"label": "4-6", "bg": BG_BROOM,
					"dirt": [{"type": "broom", "count": 4}, {"type": "scrub", "count": 2}]},
			],
		},
		# ---------- L5: Slime girişi (boss yok) ----------
		{
			"name": "5 · Salyangoz İzi", "subtitle": "Paspasla gidere it", "bg": BG_SLIME,
			"unlocked_equipment": 2,
			"rooms": [
				{"label": "5-1", "bg": BG_SLIME, "tutorial": "SLIME'ı paspasla GİDERE sürükle! Combo x15 = MIKNATIS.",
					"dirt": [{"type": "slime", "count": 2}, {"type": "scrub", "count": 2}]},
				{"label": "5-2", "bg": BG_SLIME,
					"dirt": [{"type": "slime", "count": 3}]},
				{"label": "5-3", "bg": BG_SLIME,
					"dirt": [{"type": "slime", "count": 2}, {"type": "broom", "count": 2}]},
				{"label": "5-4", "bg": BG_SLIME,
					"dirt": [{"type": "slime", "count": 3}, {"type": "scrub", "count": 2}]},
				{"label": "5-5", "bg": BG_SLIME,
					"dirt": [{"type": "slime", "count": 3}, {"type": "broom", "count": 2}],
					"commission": _commission("Gargoyle Grimble", "⏰", "Kaygan Zemin",
						"50 saniye — kaygan iş!",
						CommissionData.Rule.TIME_LIMIT, 50.0)},
				{"label": "5-6", "bg": BG_SLIME,
					"dirt": [{"type": "slime", "count": 4}, {"type": "broom", "count": 2}]},
			],
		},
		# ---------- L6: Cadı (flagship) ----------
		{
			"name": "6 · Cadı'nın İksirhanesi", "subtitle": "İksir · miniboss · sarhoşluk", "bg": BG_WITCH,
			"unlocked_equipment": 3,
			"rooms": [
				{"label": "6-1", "bg": BG_WITCH,
					"tutorial": "İksir lekesi zor çıkar ve imleci sarhoş eder. Combo x20 = ANTİDOT!",
					"dirt": [{"type": "slime", "count": 2}, {"type": "potion", "count": 1}]},
				{"label": "6-2", "bg": BG_WITCH,
					"dirt": [{"type": "slime", "count": 2}, {"type": "potion", "count": 2}]},
				{"label": "6-3", "bg": BG_WITCH,
					"tutorial": "MİNİBOSS: dolaşır, iz bırakır, küçülür. İzleri temizle; zayıflayınca gidere sürükle!",
					"dirt": [{"type": "slime_boss", "count": 1}, {"type": "potion", "count": 1}]},
				{"label": "6-4", "bg": BG_WITCH,
					"dirt": [{"type": "slime", "count": 3}, {"type": "potion", "count": 2}, {"type": "scrub", "count": 1}]},
				{"label": "6-5", "bg": BG_WITCH,
					"dirt": [{"type": "slime_boss", "count": 1}, {"type": "slime", "count": 2}, {"type": "potion", "count": 2}]},
				{"label": "6-6", "bg": BG_WITCH,
					"dirt": [{"type": "slime", "count": 3}, {"type": "potion", "count": 2}],
					"commission": _commission("Cadı Morgana", "🧪", "İksir Taşması",
						"65 saniyede balçık ve iksiri temizle.",
						CommissionData.Rule.TIME_LIMIT, 65.0)},
				{"label": "6-7", "bg": BG_WITCH,
					"dirt": [{"type": "slime_boss", "count": 1}, {"type": "potion", "count": 3}]},
				{"label": "6-8", "bg": BG_WITCH,
					"dirt": [{"type": "slime", "count": 3}, {"type": "potion", "count": 3}, {"type": "brush", "count": 1}]},
				{"label": "6-9", "bg": BG_WITCH,
					"dirt": [{"type": "slime_boss", "count": 1}, {"type": "slime", "count": 2}, {"type": "potion", "count": 2}]},
				{"label": "6-10", "bg": BG_WITCH,
					"dirt": [{"type": "slime_boss", "count": 2}, {"type": "slime", "count": 2}, {"type": "potion", "count": 3}],
					"commission": _commission("Cadı Morgana", "🧙", "Büyük Kaynama",
						"İki lord! İzleri sil, küçült, sonra gidere at.",
						CommissionData.Rule.TIME_LIMIT, 90.0)},
			],
		},
		# ---------- L7: Fırça ----------
		{
			"name": "7 · Fırça Gücü", "subtitle": "Yeni alet: Fırça", "bg": BG_BRUSH,
			"unlocked_equipment": 3,
			"rooms": [
				{"label": "7-1", "bg": BG_BRUSH, "tutorial": "FIRÇA (3): sert kire HIZLI tıkla.",
					"dirt": [{"type": "brush", "count": 3}, {"type": "scrub", "count": 2}]},
				{"label": "7-2", "bg": BG_BRUSH,
					"dirt": [{"type": "brush", "count": 4}]},
				{"label": "7-3", "bg": BG_BRUSH,
					"dirt": [{"type": "brush", "count": 3}, {"type": "broom", "count": 2}]},
				{"label": "7-4", "bg": BG_BRUSH,
					"dirt": [{"type": "brush", "count": 3}, {"type": "mold", "count": 2}]},
				{"label": "7-5", "bg": BG_BRUSH,
					"dirt": [{"type": "brush", "count": 3}, {"type": "slime", "count": 2}]},
				{"label": "7-6", "bg": BG_BRUSH,
					"dirt": [{"type": "brush", "count": 3}, {"type": "scrub", "count": 2}],
					"commission": _commission("Cadı Morgana", "🧪", "Karışan İksirler",
						"Yanlış alet acıtır.",
						CommissionData.Rule.HIGH_RISK, 2.2)},
				{"label": "7-7", "bg": BG_BRUSH,
					"dirt": [{"type": "brush", "count": 4}, {"type": "mold", "count": 2}, {"type": "broom", "count": 2}]},
			],
		},
		# ---------- L8: Sprey ----------
		{
			"name": "8 · Sprey & Bez", "subtitle": "Yeni alet: Sprey", "bg": BG_SPRAY,
			"unlocked_equipment": 4,
			"rooms": [
				{"label": "8-1", "bg": BG_SPRAY, "tutorial": "SPREY (4): önce sık, sonra ovala.",
					"dirt": [{"type": "spray", "count": 3}, {"type": "scrub", "count": 2}]},
				{"label": "8-2", "bg": BG_SPRAY,
					"dirt": [{"type": "spray", "count": 4}]},
				{"label": "8-3", "bg": BG_SPRAY,
					"dirt": [{"type": "spray", "count": 3}, {"type": "brush", "count": 2}]},
				{"label": "8-4", "bg": BG_SPRAY,
					"dirt": [{"type": "spray", "count": 3}, {"type": "slime", "count": 2}, {"type": "broom", "count": 2}]},
				{"label": "8-5", "bg": BG_SPRAY,
					"dirt": [{"type": "spray", "count": 3}, {"type": "mold", "count": 2}]},
				{"label": "8-6", "bg": BG_SPRAY,
					"dirt": [{"type": "spray", "count": 3}, {"type": "brush", "count": 2}],
					"commission": _commission("Gargoyle Grimble", "⏱", "Sabırsız Patron",
						"50 saniye!",
						CommissionData.Rule.TIME_LIMIT, 50.0)},
				{"label": "8-7", "bg": BG_SPRAY,
					"dirt": [{"type": "spray", "count": 4}, {"type": "slime", "count": 2}, {"type": "broom", "count": 2}]},
			],
		},
		# ---------- L9: Cımbız ----------
		{
			"name": "9 · Hassas İş", "subtitle": "Yeni alet: Cımbız", "bg": BG_TWEEZERS,
			"unlocked_equipment": 5,
			"rooms": [
				{"label": "9-1", "bg": BG_TWEEZERS, "tutorial": "CIMBIZ (5): TEK hassas tıkla.",
					"dirt": [{"type": "tweezers", "count": 3}, {"type": "scrub", "count": 2}]},
				{"label": "9-2", "bg": BG_TWEEZERS,
					"dirt": [{"type": "tweezers", "count": 4}, {"type": "brush", "count": 2}]},
				{"label": "9-3", "bg": BG_TWEEZERS,
					"dirt": [{"type": "tweezers", "count": 3}, {"type": "spray", "count": 2}]},
				{"label": "9-4", "bg": BG_TWEEZERS,
					"dirt": [{"type": "tweezers", "count": 3}, {"type": "broom", "count": 2}],
					"commission": _commission("Hayalet Ev Sahibi", "🕯", "Dokunulmaz",
						"İşaretli iz kutsal!",
						CommissionData.Rule.FORBIDDEN, 0.0)},
				{"label": "9-5", "bg": BG_TWEEZERS,
					"dirt": [{"type": "tweezers", "count": 4}, {"type": "brush", "count": 2}],
					"commission": _commission("Cadı Morgana", "☠", "Titrek Eller",
						"Yanlış hamle can yakar.",
						CommissionData.Rule.HIGH_RISK, 2.4)},
				{"label": "9-6", "bg": BG_TWEEZERS,
					"dirt": [{"type": "tweezers", "count": 4}, {"type": "spray", "count": 2}, {"type": "slime", "count": 2}]},
				{"label": "9-7", "bg": BG_TWEEZERS,
					"dirt": [{"type": "tweezers", "count": 4}, {"type": "mold", "count": 2}, {"type": "brush", "count": 2}]},
			],
		},
		# ---------- L10: Karanlık ----------
		{
			"name": "10 · Perili Karanlık", "subtitle": "İmleçle aydınlat", "bg": BG_DARK,
			"unlocked_equipment": 5,
			"rooms": [
				{"label": "10-1", "bg": BG_DARK, "tutorial": "Kir sadece ışıkta görünür.",
					"dirt": [{"type": "hidden", "count": 3}, {"type": "scrub", "count": 2}],
					"commission": _commission("Vampir Kont", "🌑", "Ay Işığı",
						"Perdeler kapalı.",
						CommissionData.Rule.LOW_VISIBILITY, 145.0)},
				{"label": "10-2", "bg": BG_DARK,
					"dirt": [{"type": "hidden", "count": 3}, {"type": "brush", "count": 2}],
					"commission": _commission("Vampir Kont", "🦇", "Gölge Oyunu",
						"Fırça + karanlık.",
						CommissionData.Rule.LOW_VISIBILITY, 140.0)},
				{"label": "10-3", "bg": BG_DARK,
					"dirt": [{"type": "hidden", "count": 4}, {"type": "spray", "count": 2}],
					"commission": _commission("Vampir Kont", "🌑", "Zifiri",
						"Daha karanlık.",
						CommissionData.Rule.LOW_VISIBILITY, 130.0)},
				{"label": "10-4", "bg": BG_DARK,
					"dirt": [{"type": "hidden", "count": 3}, {"type": "tweezers", "count": 2}],
					"commission": _commission("Vampir Kont", "🕯", "Kör Nokta",
						"Cımbız ve karanlık.",
						CommissionData.Rule.LOW_VISIBILITY, 135.0)},
				{"label": "10-5", "bg": BG_DARK,
					"dirt": [{"type": "hidden", "count": 3}, {"type": "mold", "count": 2}, {"type": "brush", "count": 1}],
					"commission": _commission("Vampir Kont", "🌑", "Perili Geçit",
						"Küf karanlıkta.",
						CommissionData.Rule.LOW_VISIBILITY, 140.0)},
				{"label": "10-6", "bg": BG_DARK,
					"dirt": [{"type": "hidden", "count": 4}, {"type": "slime_boss", "count": 1}],
					"commission": _commission("Vampir Kont", "🦇", "Balçık Gölgesi",
						"Miniboss karanlıkta — izleri temizle, küçült, yakala.",
						CommissionData.Rule.LOW_VISIBILITY, 150.0)},
				{"label": "10-7", "bg": BG_DARK,
					"dirt": [{"type": "hidden", "count": 4}, {"type": "tweezers", "count": 2}, {"type": "mold", "count": 1}],
					"commission": _commission("Vampir Kont", "☠", "Perili Final",
						"Son oda.",
						CommissionData.Rule.LOW_VISIBILITY, 145.0)},
			],
		},
		# ---------- L11: Ritüel ----------
		{
			"name": "11 · Cadı Ritüeli", "subtitle": "İksir + balçık + risk", "bg": BG_RITUAL,
			"unlocked_equipment": 5,
			"rooms": [
				{"label": "11-1", "bg": BG_RITUAL,
					"dirt": [{"type": "potion", "count": 3}, {"type": "slime", "count": 3}, {"type": "brush", "count": 2}]},
				{"label": "11-2", "bg": BG_RITUAL,
					"dirt": [{"type": "slime_boss", "count": 1}, {"type": "potion", "count": 3}, {"type": "spray", "count": 2}]},
				{"label": "11-3", "bg": BG_RITUAL,
					"dirt": [{"type": "potion", "count": 3}, {"type": "tweezers", "count": 3}, {"type": "slime", "count": 2}],
					"commission": _commission("Cadı Morgana", "🧪", "Zehirli Buhar",
						"Yanlış alet = acı.",
						CommissionData.Rule.HIGH_RISK, 2.5)},
				{"label": "11-4", "bg": BG_RITUAL,
					"dirt": [{"type": "slime_boss", "count": 1}, {"type": "mold", "count": 2}, {"type": "potion", "count": 2}]},
				{"label": "11-5", "bg": BG_RITUAL,
					"dirt": [{"type": "potion", "count": 3}, {"type": "hidden", "count": 2}, {"type": "brush", "count": 2}],
					"commission": _commission("Cadı Morgana", "🌑", "Loş Kazan",
						"İksir karanlıkta.",
						CommissionData.Rule.LOW_VISIBILITY, 140.0)},
				{"label": "11-6", "bg": BG_RITUAL,
					"dirt": [{"type": "slime_boss", "count": 2}, {"type": "potion", "count": 3}],
					"commission": _commission("Cadı Morgana", "⏰", "Ritüel Saati",
						"70 sn — iki lord, izleri sil!",
						CommissionData.Rule.TIME_LIMIT, 70.0)},
				{"label": "11-7", "bg": BG_RITUAL,
					"dirt": [{"type": "potion", "count": 4}, {"type": "slime", "count": 3}, {"type": "tweezers", "count": 2}]},
			],
		},
		# ---------- L12: Final ----------
		{
			"name": "12 · Büyük Kaos", "subtitle": "Her şey bir arada", "bg": BG_FINALE,
			"unlocked_equipment": 5,
			"rooms": [
				{"label": "12-1", "bg": BG_FINALE,
					"dirt": [{"type": "scrub", "count": 3}, {"type": "brush", "count": 2}, {"type": "spray", "count": 2}]},
				{"label": "12-2", "bg": BG_FINALE,
					"dirt": [{"type": "broom", "count": 3}, {"type": "slime", "count": 3}, {"type": "potion", "count": 2}]},
				{"label": "12-3", "bg": BG_FINALE,
					"dirt": [{"type": "mold", "count": 3}, {"type": "spray", "count": 2}, {"type": "scrub", "count": 2}],
					"commission": _commission("Gargoyle Grimble", "⏱", "Kaos Sayacı",
						"45 saniye!",
						CommissionData.Rule.TIME_LIMIT, 45.0)},
				{"label": "12-4", "bg": BG_FINALE,
					"dirt": [{"type": "hidden", "count": 3}, {"type": "tweezers", "count": 2}, {"type": "brush", "count": 2}],
					"commission": _commission("Vampir Kont", "🌑", "Karanlık Dönemeç",
						"Işıklar gitti.",
						CommissionData.Rule.LOW_VISIBILITY, 140.0)},
				{"label": "12-5", "bg": BG_FINALE,
					"dirt": [{"type": "slime_boss", "count": 1}, {"type": "potion", "count": 3}, {"type": "spray", "count": 2}]},
				{"label": "12-6", "bg": BG_FINALE,
					"dirt": [{"type": "brush", "count": 3}, {"type": "mold", "count": 2}, {"type": "tweezers", "count": 2}],
					"commission": _commission("Hayalet Ev Sahibi", "👻", "Son Yasak",
						"İşaretliye dokunma!",
						CommissionData.Rule.FORBIDDEN, 0.0)},
				{"label": "12-7", "bg": BG_FINALE,
					"dirt": [{"type": "slime_boss", "count": 2}, {"type": "potion", "count": 3}, {"type": "hidden", "count": 2}],
					"commission": _commission("Cadı Morgana", "☠", "Çifte Lord",
						"İki miniboss — küçült, yakala.",
						CommissionData.Rule.HIGH_RISK, 2.7)},
				{"label": "12-8", "bg": BG_FINALE,
					"dirt": [{"type": "brush", "count": 3}, {"type": "spray", "count": 2}, {"type": "tweezers", "count": 2}, {"type": "slime_boss", "count": 1}, {"type": "mold", "count": 2}],
					"commission": _commission("Cadı Morgana", "🔥", "BÜYÜK FİNAL",
						"Son oda. Combo tut, powerup kullan!",
						CommissionData.Rule.TIME_LIMIT, 80.0)},
			],
		},
	]
