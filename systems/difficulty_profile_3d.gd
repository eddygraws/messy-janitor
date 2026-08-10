class_name DifficultyProfile3D
extends RefCounted

## Erişilebilirlik: kolay / normal / zor — emir süresi + spawn / prop çarpanları.
## Prop sayıları: LevelData3D chapter eğrisi × buradaki prop_count_mult.

enum Tier { EASY, NORMAL, HARD }

## Menü zorluğu → başlangıç kir/kutu sayısı (kolay daha az, zor daha çok)
const PROP_COUNT_EASY := 0.85
const PROP_COUNT_NORMAL := 1.0
const PROP_COUNT_HARD := 1.25

static func tier_name(tier: int) -> String:
	match tier:
		Tier.EASY:
			return "Kolay"
		Tier.HARD:
			return "Zor"
		_:
			return "Normal"


static func task_duration_mult(tier: int) -> float:
	match tier:
		Tier.EASY:
			return 1.35
		Tier.HARD:
			return 0.82
		_:
			return 1.0


static func task_interval_mult(tier: int) -> float:
	match tier:
		Tier.EASY:
			return 1.25 # daha seyrek emir
		Tier.HARD:
			return 0.8
		_:
			return 1.0


static func spawn_rate_mult(tier: int) -> float:
	match tier:
		Tier.EASY:
			return 0.75
		Tier.HARD:
			return 1.3
		_:
			return 1.0


static func prop_count_mult(tier: int) -> float:
	match tier:
		Tier.EASY:
			return PROP_COUNT_EASY
		Tier.HARD:
			return PROP_COUNT_HARD
		_:
			return PROP_COUNT_NORMAL


static func stress_gain_mult(tier: int) -> float:
	match tier:
		Tier.EASY:
			return 0.75
		Tier.HARD:
			return 1.2
		_:
			return 1.0
