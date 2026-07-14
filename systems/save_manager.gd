class_name SaveManager
extends Node

# Kalıcı meta-ilerleme: iki mod için rekorlar + ömür-boyu istatistikler.
# Kozmetik/ekonomi yok; sadece rekor takibi ve "YENİ REKOR" geri bildirimi.

const SAVE_PATH := "user://gargoyle_save.json"

var data := {
	"endless_best_rooms": 0,
	"endless_best_score": 0,
	"adventure_best_score": 0,
	"adventure_cleared": false,
	"total_rooms_cleaned": 0,
	"best_combo": 0,
	"runs_played": 0,
	"highest_level_unlocked": 1,   # 1..10 (1 = sadece 1. seviye açık)
	"level_best": {},              # {"0": skor, "1": skor, ...}
	"intro_seen": false,
}


func _ready() -> void:
	_load()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		for key in data.keys():
			if (parsed as Dictionary).has(key):
				data[key] = (parsed as Dictionary)[key]


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


# Bir koşu bitince çağrılır. Kırılan rekorların metin listesini döndürür.
func record_run(run_mode: int, rooms_cleared: int, score: int, max_combo: int, completed: bool) -> Array[String]:
	var records: Array[String] = []
	data["runs_played"] = int(data["runs_played"]) + 1
	data["total_rooms_cleaned"] = int(data["total_rooms_cleaned"]) + rooms_cleared

	if max_combo > int(data["best_combo"]):
		data["best_combo"] = max_combo

	if run_mode == 1:  # Endless
		if rooms_cleared > int(data["endless_best_rooms"]):
			data["endless_best_rooms"] = rooms_cleared
			records.append("🏆 Sonsuz rekoru: %d tur!" % rooms_cleared)
		if score > int(data["endless_best_score"]):
			data["endless_best_score"] = score
			records.append("🏆 Sonsuz puan rekoru: %d!" % score)
	else:  # Adventure
		if score > int(data["adventure_best_score"]):
			data["adventure_best_score"] = score
			records.append("🏆 Macera puan rekoru: %d!" % score)
		if completed and not bool(data["adventure_cleared"]):
			data["adventure_cleared"] = true
			records.append("🏆 Macera ilk kez tamamlandı!")

	_save()
	return records


# Bir Adventure seviyesi tamamlanınca çağrılır. Kırılan rekorları döndürür,
# sonraki seviyeyi açar.
func record_level_complete(level_index: int, score: int, max_combo: int) -> Array[String]:
	var records: Array[String] = []
	var key := str(level_index)
	var prev := int((data["level_best"] as Dictionary).get(key, 0))
	if score > prev:
		(data["level_best"] as Dictionary)[key] = score
		if prev > 0:
			records.append("🏆 Seviye rekoru: %d puan!" % score)

	if max_combo > int(data["best_combo"]):
		data["best_combo"] = max_combo

	if score > int(data["adventure_best_score"]):
		data["adventure_best_score"] = score

	# Sonraki seviyeyi aç (1 tabanlı sayı).
	var next_level := level_index + 2
	var max_level := LevelData.level_count()
	if next_level > int(data["highest_level_unlocked"]) and next_level <= max_level:
		data["highest_level_unlocked"] = next_level
		records.append("🔓 Seviye %d açıldı!" % next_level)

	if level_index >= max_level - 1:
		data["adventure_cleared"] = true

	_save()
	return records


func get_highest_unlocked() -> int:
	return int(data["highest_level_unlocked"])


func get_level_best(level_index: int) -> int:
	return int((data["level_best"] as Dictionary).get(str(level_index), 0))


func get_endless_best_rooms() -> int:
	return int(data["endless_best_rooms"])


func get_endless_best_score() -> int:
	return int(data["endless_best_score"])


func get_adventure_best_score() -> int:
	return int(data["adventure_best_score"])


func is_adventure_cleared() -> bool:
	return bool(data["adventure_cleared"])


func get_total_rooms_cleaned() -> int:
	return int(data["total_rooms_cleaned"])


func get_best_combo() -> int:
	return int(data["best_combo"])


func has_any_record() -> bool:
	return int(data["runs_played"]) > 0


func has_seen_intro() -> bool:
	return bool(data.get("intro_seen", false))


func mark_intro_seen() -> void:
	data["intro_seen"] = true
	_save()
