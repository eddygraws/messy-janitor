class_name BadgeRating3D
extends RefCounted

## Seviye rozeti — süre fail yok; bitirme hızına göre 🥉🥈🥇

enum Rank { NONE = 0, BRONZE = 1, SILVER = 2, GOLD = 3 }

const GOLD_MULT := 0.65 ## par × bu → altın tavan
const SILVER_MULT := 1.0 ## par × bu → gümüş tavan (üstü bronz)


static func rank_from_elapsed(elapsed: float, par_seconds: float) -> int:
	if elapsed < 0.0:
		elapsed = 0.0
	if par_seconds <= 0.5:
		# Par yoksa sadece bitirme = gümüş; çok hızlıysa altın
		if elapsed <= 35.0:
			return Rank.GOLD
		if elapsed <= 55.0:
			return Rank.SILVER
		return Rank.BRONZE
	if elapsed <= par_seconds * GOLD_MULT:
		return Rank.GOLD
	if elapsed <= par_seconds * SILVER_MULT:
		return Rank.SILVER
	return Rank.BRONZE


static func label(rank: int) -> String:
	match rank as Rank:
		Rank.GOLD:
			return "ALTIN"
		Rank.SILVER:
			return "GÜMÜŞ"
		Rank.BRONZE:
			return "BRONZ"
		_:
			return ""


static func icon(rank: int) -> String:
	match rank as Rank:
		Rank.GOLD:
			return "🥇"
		Rank.SILVER:
			return "🥈"
		Rank.BRONZE:
			return "🥉"
		_:
			return ""


static func color(rank: int) -> Color:
	match rank as Rank:
		Rank.GOLD:
			return Color(1.0, 0.82, 0.28)
		Rank.SILVER:
			return Color(0.78, 0.84, 0.92)
		Rank.BRONZE:
			return Color(0.82, 0.55, 0.32)
		_:
			return Color(0.55, 0.55, 0.58)


static func short(rank: int) -> String:
	var lab := label(rank)
	if lab.is_empty():
		return "—"
	return lab


static func gold_threshold(par_seconds: float) -> float:
	if par_seconds <= 0.5:
		return 35.0
	return par_seconds * GOLD_MULT


static func silver_threshold(par_seconds: float) -> float:
	if par_seconds <= 0.5:
		return 55.0
	return par_seconds * SILVER_MULT


static func best(a: int, b: int) -> int:
	return maxi(a, b)
