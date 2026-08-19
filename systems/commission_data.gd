class_name CommissionData
extends RefCounted

# Adventure Mode komisyonları (oda başına absürt istek + twist kural).
# Her komisyon: NPC + istek metni + bir "twist kural".

enum Rule { NONE, FORBIDDEN, TIME_LIMIT, LOW_VISIBILITY, HIGH_RISK }

const RULE_LABELS := {
	Rule.NONE: "",
	Rule.FORBIDDEN: "⛔ Yasak bölgeye dokunma!",
	Rule.TIME_LIMIT: "🥇 Hızlı bitir — altın rozet!",
	Rule.LOW_VISIBILITY: "🌑 Karanlık: fener konisiyle tara",
	Rule.HIGH_RISK: "☠ Yüksek risk: yanlış alet acıtır",
}

const COMMISSIONS: Array[Dictionary] = [
	{
		"npc": "Gargoyle Grimble", "icon": "🗿",
		"title": "İlk İş",
		"desc": "Yeni geldin ha? Şu tozlu odayı bir güzel paspasla da görelim.",
		"rule": Rule.NONE, "param": 0.0,
	},
	{
		"npc": "Hayalet Ev Sahibi", "icon": "👻",
		"title": "Kutsal Leke",
		"desc": "Her yeri temizle AMA işaretli lekeye SAKIN dokunma; o benim hatıram!",
		"rule": Rule.FORBIDDEN, "param": 0.0,
	},
	{
		"npc": "Gargoyle Grimble", "icon": "🤢",
		"title": "Midem Bulanıyor",
		"desc": "Bu küf iğrenç! Altın rozet için hızlı temizle — süre dolunca kayıp yok, ama rozet düşer.",
		"rule": Rule.TIME_LIMIT, "param": 40.0,
	},
	{
		"npc": "Cadı Morgana", "icon": "🧹",
		"title": "Süpürge Zamanı",
		"desc": "Kırıntıları süpürgeyle (2) toplayıp çöp kovasına at. Basit, değil mi?",
		"rule": Rule.NONE, "param": 0.0,
	},
	{
		"npc": "Vampir Kont", "icon": "🦇",
		"title": "Ay Işığı",
		"desc": "Bu gece sadece gölgeler görünür. Kirleri ancak imlecine yaklaşınca görürsün.",
		"rule": Rule.LOW_VISIBILITY, "param": 150.0,
	},
	{
		"npc": "Gargoyle Grimble", "icon": "⏰",
		"title": "Sabırsız Patron",
		"desc": "Acelem var! Altın için acele et — yavaş bitirirsen bronz/gümüş kalır, ama yine geçer.",
		"rule": Rule.TIME_LIMIT, "param": 45.0,
	},
	{
		"npc": "Cadı Morgana", "icon": "🧪",
		"title": "Karışan İksirler",
		"desc": "Malzemelerim birbirine karıştı. Yanlış aletle dokunursan patlama riski var!",
		"rule": Rule.HIGH_RISK, "param": 2.2,
	},
	{
		"npc": "Hayalet Ev Sahibi", "icon": "🕯",
		"title": "Dokunulmaz",
		"desc": "Şu işaretli izi kutsal sayıyorum. Gerisini temizle, ona el sürme!",
		"rule": Rule.FORBIDDEN, "param": 0.0,
	},
	{
		"npc": "Vampir Kont", "icon": "🌑",
		"title": "Perili Karanlık",
		"desc": "Perdeler kapalı kalacak. Karanlıkta kirleri imlecinle avla bakalım.",
		"rule": Rule.LOW_VISIBILITY, "param": 140.0,
	},
	{
		"npc": "Cadı Morgana", "icon": "☠",
		"title": "Final: Cam Tarlası",
		"desc": "Cam kırıkları ve iksir lekeleri her yerde. Tek yanlış hareket canını yakar. Bol şans!",
		"rule": Rule.HIGH_RISK, "param": 2.4,
	},
]


static func get_commission(index: int) -> Dictionary:
	if index >= 0 and index < COMMISSIONS.size():
		return COMMISSIONS[index]
	return {
		"npc": "Gargoyle Grimble", "icon": "🗿",
		"title": "Bir İş Daha",
		"desc": "Şu odayı da temizleyiver.",
		"rule": Rule.NONE, "param": 0.0,
	}


static func rule_label(rule: int) -> String:
	return RULE_LABELS.get(rule, "")
