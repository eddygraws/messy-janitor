class_name DailyChallenge3D
extends RefCounted

## Günlük meydan okuma — seed ile sabit seviye + kendini geç.

const SAVE_PATH := "user://messy3d_scores.cfg"


static func day_key() -> int:
	var d := Time.get_datetime_dict_from_system()
	return int(d.year) * 10000 + int(d.month) * 100 + int(d.day)


## Bugünün challenge seviyesi (0..level_count-1), unlocked üst sınırına sıkıştırılmaz — menü kontrol eder.
static func todays_level_index(level_count: int = 10) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("messy_daily_level_%d" % day_key())
	return rng.randi_range(0, maxi(0, level_count - 1))


static func challenge_title(level_index: int) -> String:
	var info: Dictionary = LevelData3D.get_level(level_index)
	return "Günlük · %s" % String(info.get("name", "Seviye %d" % (level_index + 1)))


static func load_best(level_index: int) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0
	return int(cfg.get_value("best", "level_%d" % level_index, 0))


static func load_last(level_index: int) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0
	return int(cfg.get_value("last", "level_%d" % level_index, 0))


static func load_daily_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0
	var key := "day_%d" % day_key()
	return int(cfg.get_value("daily_best", key, 0))


static func load_daily_last() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0
	var key := "day_%d" % day_key()
	return int(cfg.get_value("daily_last", key, 0))


## Kaydeder; dönen dict: {best, last, beat_best, beat_last, is_new_best}
static func save_result(level_index: int, score: int, daily: bool = false) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var prev_best := int(cfg.get_value("best", "level_%d" % level_index, 0))
	var last := int(cfg.get_value("last", "level_%d" % level_index, 0))
	var beat_last := score > last and last > 0
	var beat_best := score > prev_best
	var is_new_best := (beat_best or prev_best == 0) and score > 0
	var best := maxi(prev_best, score)
	cfg.set_value("best", "level_%d" % level_index, best)
	cfg.set_value("last", "level_%d" % level_index, score)
	var daily_best := 0
	var daily_last := 0
	var prev_daily_best := 0
	var beat_daily_best := false
	var beat_daily_last := false
	if daily:
		var key := "day_%d" % day_key()
		prev_daily_best = int(cfg.get_value("daily_best", key, 0))
		daily_last = int(cfg.get_value("daily_last", key, 0))
		beat_daily_last = score > daily_last and daily_last > 0
		beat_daily_best = score > prev_daily_best
		daily_best = maxi(prev_daily_best, score)
		cfg.set_value("daily_best", key, daily_best)
		cfg.set_value("daily_last", key, score)
	cfg.save(SAVE_PATH)
	SteamService.push_saves()
	return {
		"best": best,
		"prev_best": prev_best,
		"last": last,
		"beat_best": beat_best,
		"beat_last": beat_last,
		"is_new_best": is_new_best,
		"daily_best": daily_best,
		"prev_daily_best": prev_daily_best,
		"daily_last": daily_last,
		"beat_daily_best": beat_daily_best,
		"beat_daily_last": beat_daily_last,
	}


static func load_world_best(world_slot: int) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0
	return int(cfg.get_value("world_best", "world_%d" % world_slot, 0))


## Dünya toplam skoru kaydı — {world_best, prev_best, is_new_best}
static func save_world_result(world_slot: int, total_score: int) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var prev_best := int(cfg.get_value("world_best", "world_%d" % world_slot, 0))
	var is_new_best := total_score > prev_best or (prev_best == 0 and total_score > 0)
	var best := maxi(prev_best, total_score)
	cfg.set_value("world_best", "world_%d" % world_slot, best)
	cfg.set_value("world_last", "world_%d" % world_slot, total_score)
	cfg.save(SAVE_PATH)
	SteamService.push_saves()
	return {
		"world_best": best,
		"prev_best": prev_best,
		"is_new_best": is_new_best,
	}


## Menü kayıtları — seçili dünya seviyelerinin best/last özeti
static func world_records_summary(world_slot: int) -> String:
	var indices := LevelData3D.level_indices_for_world(world_slot)
	if indices.is_empty():
		return "Kayıt yok"
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var lines: PackedStringArray = []
	var world_best := int(cfg.get_value("world_best", "world_%d" % world_slot, 0))
	if world_best > 0:
		lines.append("Dünya rekoru: %d" % world_best)
	var shown := 0
	for li in indices:
		var best := int(cfg.get_value("best", "level_%d" % li, 0))
		if best <= 0:
			continue
		var info := LevelData3D.get_level(li)
		var short_name := String(info.get("name", "Lv%d" % (li + 1)))
		# Kısa etiket: son parça
		var parts := short_name.split(" · ")
		var label := parts[parts.size() - 1] if parts.size() > 0 else short_name
		lines.append("%s  %d" % [label, best])
		shown += 1
		if shown >= 5:
			break
	if lines.is_empty():
		return "Henüz rekor yok — oyna!"
	return "\n".join(lines)
