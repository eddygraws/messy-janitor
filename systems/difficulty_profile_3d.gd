class_name DifficultyProfile3D
extends RefCounted

## Erişilebilirlik: kolay / normal / zor — emir süresi + spawn hızı çarpanları.

enum Tier { EASY, NORMAL, HARD }

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


static func stress_gain_mult(tier: int) -> float:
	match tier:
		Tier.EASY:
			return 0.75
		Tier.HARD:
			return 1.2
		_:
			return 1.0
