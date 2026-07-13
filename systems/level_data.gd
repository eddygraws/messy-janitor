class_name LevelData
extends RefCounted

# Adventure Mode: 10 seviye, her biri 3-5 oda. Mekanikler kademeli tanıtılır.
# Her oda RoomFactory.build_room() ile kurulur; opsiyonel "tutorial" (mekanik
# öğreten kısa banner) ve "commission" (twist kural + görev kartı) içerir.
#
# Ekipman kilidi seviye bazlı: L1-3 paspas, L4-5 +süpürge, L6 +fırça,
# L7 +sprey, L8-10 +cımbız.

const BG_APPRENTICE := Color(0.16, 0.18, 0.24)
const BG_APPETITE := Color(0.22, 0.16, 0.2)
const BG_MOLD := Color(0.16, 0.22, 0.18)
const BG_BROOM := Color(0.26, 0.2, 0.14)
const BG_SLIME := Color(0.14, 0.22, 0.2)
const BG_BRUSH := Color(0.2, 0.18, 0.14)
const BG_SPRAY := Color(0.14, 0.2, 0.26)
const BG_TWEEZERS := Color(0.2, 0.2, 0.26)
const BG_DARK := Color(0.08, 0.08, 0.12)
const BG_CHAOS := Color(0.24, 0.12, 0.12)


static func level_count() -> int:
	return 10


static func unlocked_equipment(level_index: int) -> int:
	var lvl := level_index + 1
	if lvl >= 8:
		return 5
	elif lvl == 7:
		return 4
	elif lvl == 6:
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
		# ---------- L1: Çıraklık (paspas temeli) ----------
		{
			"name": "1 · Çıraklık", "subtitle": "Paspas temeli", "bg": BG_APPRENTICE,
			"unlocked_equipment": 1,
			"rooms": [
				{"label": "1-1", "bg": BG_APPRENTICE, "tutorial": "Kirlere TIKLA ve temizle!",
					"dirt": [{"type": "stain", "count": 3}]},
				{"label": "1-2", "bg": BG_APPRENTICE, "tutorial": "İnatçı leke: basılı tutup SAĞA-SOLA ovala!",
					"dirt": [{"type": "scrub", "count": 3}]},
				{"label": "1-3", "bg": BG_APPRENTICE,
					"dirt": [{"type": "stain", "count": 2}, {"type": "scrub", "count": 2}]},
			],
		},
		# ---------- L2: İştah (junk food + kırılgan) ----------
		{
			"name": "2 · İştah", "subtitle": "Dikkat dağıtan lezzetler", "bg": BG_APPETITE,
			"unlocked_equipment": 1,
			"rooms": [
				{"label": "2-1", "bg": BG_APPETITE, "tutorial": "Abur cubur cezbeder — tıklarsan STRES artar!",
					"dirt": [{"type": "scrub", "count": 3}]},
				{"label": "2-2", "bg": BG_APPETITE, "tutorial": "Kırılgan eşya! YAVAŞ ovala, sert ovalama kırar.",
					"dirt": [{"type": "fragile", "count": 1}, {"type": "scrub", "count": 2}]},
				{"label": "2-3", "bg": BG_APPETITE,
					"dirt": [{"type": "scrub", "count": 3}, {"type": "fragile", "count": 1}]},
			],
		},
		# ---------- L3: Küf Baskını (yayılan küf + süre) ----------
		{
			"name": "3 · Küf Baskını", "subtitle": "Yayılmadan yetiş", "bg": BG_MOLD,
			"unlocked_equipment": 1,
			"rooms": [
				{"label": "3-1", "bg": BG_MOLD, "tutorial": "KÜF yayılır! Zaman geçmeden temizle.",
					"dirt": [{"type": "mold", "count": 1}, {"type": "scrub", "count": 2}]},
				{"label": "3-2", "bg": BG_MOLD,
					"dirt": [{"type": "mold", "count": 2}, {"type": "scrub", "count": 1}]},
				{"label": "3-3", "bg": BG_MOLD,
					"dirt": [{"type": "scrub", "count": 3}],
					"commission": _commission("Gargoyle Grimble", "🤢", "Midem Bulanıyor",
						"Bu koku dayanılmaz! 40 saniyede temizle yoksa üstüne kusarım.",
						CommissionData.Rule.TIME_LIMIT, 40.0)},
				{"label": "3-4", "bg": BG_MOLD,
					"dirt": [{"type": "mold", "count": 2}, {"type": "scrub", "count": 2}]},
			],
		},
		# ---------- L4: Süpürge (broom → çöp kovası) ----------
		{
			"name": "4 · Süpürge Zamanı", "subtitle": "Yeni alet: Süpürge", "bg": BG_BROOM,
			"unlocked_equipment": 2,
			"rooms": [
				{"label": "4-1", "bg": BG_BROOM, "tutorial": "Yeni alet: SÜPÜRGE (2). Kırıntıları ÇÖP KOVASINA sürükle!",
					"dirt": [{"type": "broom", "count": 2}, {"type": "scrub", "count": 1}]},
				{"label": "4-2", "bg": BG_BROOM,
					"dirt": [{"type": "broom", "count": 3}]},
				{"label": "4-3", "bg": BG_BROOM,
					"dirt": [{"type": "broom", "count": 2}, {"type": "scrub", "count": 2}]},
				{"label": "4-4", "bg": BG_BROOM,
					"dirt": [{"type": "broom", "count": 3}, {"type": "scrub", "count": 1}],
					"commission": _commission("Hayalet Ev Sahibi", "👻", "Kutsal Leke",
						"Her yeri temizle AMA işaretli lekeye SAKIN dokunma!",
						CommissionData.Rule.FORBIDDEN, 0.0)},
			],
		},
		# ---------- L5: Salyangoz İzi (slime → gider) ----------
		{
			"name": "5 · Salyangoz İzi", "subtitle": "Paspasla gidere it", "bg": BG_SLIME,
			"unlocked_equipment": 2,
			"rooms": [
				{"label": "5-1", "bg": BG_SLIME, "tutorial": "SLIME'ı paspasla GİDERE sürükle!",
					"dirt": [{"type": "slime", "count": 2}, {"type": "scrub", "count": 1}]},
				{"label": "5-2", "bg": BG_SLIME,
					"dirt": [{"type": "slime", "count": 2}, {"type": "broom", "count": 2}]},
				{"label": "5-3", "bg": BG_SLIME,
					"dirt": [{"type": "slime", "count": 3}, {"type": "scrub", "count": 1}]},
				{"label": "5-4", "bg": BG_SLIME,
					"dirt": [{"type": "slime", "count": 2}, {"type": "broom", "count": 2}, {"type": "scrub", "count": 1}],
					"commission": _commission("Cadı Morgana", "⏰", "Acele Var",
						"İksir seansım başlıyor! 50 saniyede burayı topla.",
						CommissionData.Rule.TIME_LIMIT, 50.0)},
			],
		},
		# ---------- L6: Fırça Gücü (brush) ----------
		{
			"name": "6 · Fırça Gücü", "subtitle": "Yeni alet: Fırça", "bg": BG_BRUSH,
			"unlocked_equipment": 3,
			"rooms": [
				{"label": "6-1", "bg": BG_BRUSH, "tutorial": "Yeni alet: FIRÇA (3). Sert kire HIZLI HIZLI tıkla!",
					"dirt": [{"type": "brush", "count": 2}, {"type": "scrub", "count": 1}]},
				{"label": "6-2", "bg": BG_BRUSH,
					"dirt": [{"type": "brush", "count": 3}]},
				{"label": "6-3", "bg": BG_BRUSH,
					"dirt": [{"type": "brush", "count": 2}, {"type": "broom", "count": 2}]},
				{"label": "6-4", "bg": BG_BRUSH,
					"dirt": [{"type": "brush", "count": 2}, {"type": "mold", "count": 1}, {"type": "scrub", "count": 1}]},
				{"label": "6-5", "bg": BG_BRUSH,
					"dirt": [{"type": "brush", "count": 3}, {"type": "slime", "count": 1}],
					"commission": _commission("Cadı Morgana", "🧪", "Karışan İksirler",
						"Malzemeler karıştı! Yanlış aletle dokunma, acıtır.",
						CommissionData.Rule.HIGH_RISK, 2.2)},
			],
		},
		# ---------- L7: Sprey & Bez (spray) ----------
		{
			"name": "7 · Sprey & Bez", "subtitle": "Yeni alet: Sprey", "bg": BG_SPRAY,
			"unlocked_equipment": 4,
			"rooms": [
				{"label": "7-1", "bg": BG_SPRAY, "tutorial": "Yeni alet: SPREY (4). Önce SIK, sonra ovala!",
					"dirt": [{"type": "spray", "count": 2}, {"type": "scrub", "count": 1}]},
				{"label": "7-2", "bg": BG_SPRAY,
					"dirt": [{"type": "spray", "count": 3}]},
				{"label": "7-3", "bg": BG_SPRAY,
					"dirt": [{"type": "spray", "count": 2}, {"type": "brush", "count": 2}]},
				{"label": "7-4", "bg": BG_SPRAY,
					"dirt": [{"type": "spray", "count": 2}, {"type": "broom", "count": 2}, {"type": "scrub", "count": 1}]},
				{"label": "7-5", "bg": BG_SPRAY,
					"dirt": [{"type": "spray", "count": 3}, {"type": "mold", "count": 1}],
					"commission": _commission("Gargoyle Grimble", "⏱", "Sabırsız Patron",
						"55 saniye! Cam gibi parlasın istiyorum.",
						CommissionData.Rule.TIME_LIMIT, 55.0)},
			],
		},
		# ---------- L8: Hassas İş (tweezers) ----------
		{
			"name": "8 · Hassas İş", "subtitle": "Yeni alet: Cımbız", "bg": BG_TWEEZERS,
			"unlocked_equipment": 5,
			"rooms": [
				{"label": "8-1", "bg": BG_TWEEZERS, "tutorial": "Yeni alet: CIMBIZ (5). Ufak parçaya TEK hassas tıkla!",
					"dirt": [{"type": "tweezers", "count": 3}, {"type": "scrub", "count": 1}]},
				{"label": "8-2", "bg": BG_TWEEZERS,
					"dirt": [{"type": "tweezers", "count": 3}, {"type": "brush", "count": 1}]},
				{"label": "8-3", "bg": BG_TWEEZERS,
					"dirt": [{"type": "tweezers", "count": 2}, {"type": "spray", "count": 2}]},
				{"label": "8-4", "bg": BG_TWEEZERS,
					"dirt": [{"type": "tweezers", "count": 3}, {"type": "broom", "count": 1}, {"type": "scrub", "count": 1}],
					"commission": _commission("Hayalet Ev Sahibi", "🕯", "Dokunulmaz",
						"İşaretli izi kutsal sayıyorum. Gerisini temizle, ona el sürme!",
						CommissionData.Rule.FORBIDDEN, 0.0)},
				{"label": "8-5", "bg": BG_TWEEZERS,
					"dirt": [{"type": "tweezers", "count": 3}, {"type": "brush", "count": 2}],
					"commission": _commission("Cadı Morgana", "☠", "Titrek Eller",
						"Kırık camlar her yerde; yanlış hamle canını yakar.",
						CommissionData.Rule.HIGH_RISK, 2.3)},
			],
		},
		# ---------- L9: Perili Karanlık (hidden / low-vis) ----------
		{
			"name": "9 · Perili Karanlık", "subtitle": "İmleçle aydınlat", "bg": BG_DARK,
			"unlocked_equipment": 5,
			"rooms": [
				{"label": "9-1", "bg": BG_DARK, "tutorial": "KARANLIK! İmleci gezdir, kir sadece ışıkta görünür.",
					"dirt": [{"type": "hidden", "count": 3}, {"type": "scrub", "count": 1}],
					"commission": _commission("Vampir Kont", "🌑", "Ay Işığı",
						"Perdeler kapalı. Kirleri imlecinle avla bakalım.",
						CommissionData.Rule.LOW_VISIBILITY, 150.0)},
				{"label": "9-2", "bg": BG_DARK,
					"dirt": [{"type": "hidden", "count": 2}, {"type": "brush", "count": 2}],
					"commission": _commission("Vampir Kont", "🦇", "Gölge Oyunu",
						"Karanlıkta fırça işi. Elini iyi tut.",
						CommissionData.Rule.LOW_VISIBILITY, 145.0)},
				{"label": "9-3", "bg": BG_DARK,
					"dirt": [{"type": "hidden", "count": 3}, {"type": "spray", "count": 1}],
					"commission": _commission("Vampir Kont", "🌑", "Zifiri",
						"Daha da karanlık. Sabırlı ol.",
						CommissionData.Rule.LOW_VISIBILITY, 135.0)},
				{"label": "9-4", "bg": BG_DARK,
					"dirt": [{"type": "hidden", "count": 2}, {"type": "tweezers", "count": 2}, {"type": "scrub", "count": 1}],
					"commission": _commission("Vampir Kont", "🕯", "Kör Nokta",
						"Cımbız ve karanlık... eğlenceli, değil mi?",
						CommissionData.Rule.LOW_VISIBILITY, 140.0)},
				{"label": "9-5", "bg": BG_DARK,
					"dirt": [{"type": "hidden", "count": 3}, {"type": "mold", "count": 1}, {"type": "brush", "count": 1}],
					"commission": _commission("Vampir Kont", "🌑", "Perili Final",
						"Karanlıkta küf bile var. Hadi bakalım.",
						CommissionData.Rule.LOW_VISIBILITY, 150.0)},
			],
		},
		# ---------- L10: Final: Kaos (hepsi bir arada) ----------
		{
			"name": "10 · Final: Kaos", "subtitle": "Her şey bir arada", "bg": BG_CHAOS,
			"unlocked_equipment": 5,
			"rooms": [
				{"label": "10-1", "bg": BG_CHAOS,
					"dirt": [{"type": "scrub", "count": 2}, {"type": "brush", "count": 1}, {"type": "spray", "count": 1}]},
				{"label": "10-2", "bg": BG_CHAOS,
					"dirt": [{"type": "broom", "count": 2}, {"type": "slime", "count": 2}, {"type": "tweezers", "count": 1}]},
				{"label": "10-3", "bg": BG_CHAOS,
					"dirt": [{"type": "mold", "count": 2}, {"type": "spray", "count": 2}, {"type": "scrub", "count": 1}],
					"commission": _commission("Gargoyle Grimble", "⏱", "Kaos Sayacı",
						"45 saniye! Kimse bu kadarını başaramadı.",
						CommissionData.Rule.TIME_LIMIT, 45.0)},
				{"label": "10-4", "bg": BG_CHAOS,
					"dirt": [{"type": "hidden", "count": 2}, {"type": "tweezers", "count": 2}, {"type": "brush", "count": 1}],
					"commission": _commission("Vampir Kont", "🌑", "Karanlık Dönemeç",
						"Sona az kaldı ama ışıklar yine gitti.",
						CommissionData.Rule.LOW_VISIBILITY, 145.0)},
				{"label": "10-5", "bg": BG_CHAOS,
					"dirt": [{"type": "brush", "count": 2}, {"type": "spray", "count": 2}, {"type": "tweezers", "count": 2}, {"type": "mold", "count": 1}],
					"commission": _commission("Cadı Morgana", "☠", "BÜYÜK FİNAL",
						"Cam tarlası, iksir ve küf! Tek yanlış hamle... Bol şans!",
						CommissionData.Rule.HIGH_RISK, 2.5)},
			],
		},
	]
