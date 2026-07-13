class_name RoomRating
extends RefCounted

const GRADES: Array[Dictionary] = [
	{"min": 950, "label": "PERFECT!", "color": Color(1.0, 0.88, 0.25)},
	{"min": 800, "label": "AMAZING!", "color": Color(0.45, 1.0, 0.65)},
	{"min": 650, "label": "SWEET!", "color": Color(0.55, 0.92, 1.0)},
	{"min": 500, "label": "NICE!", "color": Color(0.82, 0.82, 1.0)},
	{"min": 300, "label": "OK", "color": Color(0.92, 0.9, 0.72)},
	{"min": 0, "label": "MEH...", "color": Color(0.65, 0.65, 0.65)},
]

const BASE_SCORE := 300
const JUNK_PENALTY := 150
const PANIC_PENALTY := 90
const STRESS_PENALTY := 250
const TIME_PENALTY_PER_SEC := 3.0
const TIME_CAP := 90.0
const FLAWLESS_BONUS := 150
const MAX_SCORE := 1500


# Ayrıntılı puan dökümü döndürür (feedback ekranında gösterilebilir).
static func calculate_score(
	combo_points: int,
	mistake_penalty: int,
	junk_eaten: int,
	panic_events: int,
	stress_ratio: float,
	elapsed_sec: float,
	flawless: bool
) -> Dictionary:
	var junk_pen := junk_eaten * JUNK_PENALTY
	var panic_pen := panic_events * PANIC_PENALTY
	var stress_pen := int(stress_ratio * STRESS_PENALTY)
	var time_pen := int(minf(elapsed_sec, TIME_CAP) * TIME_PENALTY_PER_SEC)
	var flawless_bonus := FLAWLESS_BONUS if flawless else 0

	var total := BASE_SCORE + combo_points + flawless_bonus
	total -= mistake_penalty + junk_pen + panic_pen + stress_pen + time_pen
	total = clampi(total, 0, MAX_SCORE)

	return {
		"total": total,
		"base": BASE_SCORE,
		"combo_points": combo_points,
		"flawless_bonus": flawless_bonus,
		"mistake_penalty": mistake_penalty,
		"junk_penalty": junk_pen,
		"panic_penalty": panic_pen,
		"stress_penalty": stress_pen,
		"time_penalty": time_pen,
	}


static func get_grade_data(score: int) -> Dictionary:
	for grade in GRADES:
		if score >= grade.min:
			return grade
	return GRADES[GRADES.size() - 1]


static func build_subtitle(max_combo: int, mistakes: int, junk_eaten: int) -> String:
	if mistakes == 0 and junk_eaten == 0:
		return "Kusursuz! · En yüksek combo x%d" % max_combo
	var parts: Array[String] = []
	if max_combo > 1:
		parts.append("Combo x%d" % max_combo)
	if mistakes > 0:
		parts.append("%d hata" % mistakes)
	if junk_eaten > 0:
		parts.append("%d abur cubur" % junk_eaten)
	return " · ".join(parts)
