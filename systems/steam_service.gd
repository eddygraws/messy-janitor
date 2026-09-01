extends Node

## GodotSteam köprüsü. GDExtension yoksa veya App ID 0 ise no-op.
## Overlay: Shift-Tab (export + Steam client). Cloud: Remote Storage + Auto-Cloud yolu.
## Başarı API adları Steamworks paneliyle aynı olmalı — docs/steam/STEAMWORKS.md

const Product := preload("res://systems/product_identity.gd")

const ACH_TUTORIAL := "TUTORIAL_DONE"
const ACH_CHAPTERS_3 := "CHAPTERS_3"
const ACH_GOLD := "FIRST_GOLD"
const ACH_DAILY := "DAILY_CLEAR"

const CLOUD_FILES: PackedStringArray = [
	"messy3d_progress_v2.cfg",
	"messy3d_settings.cfg",
	"messy3d_scores.cfg",
	"messy3d_curses.cfg",
]

var _ready_ok: bool = false
var _steam: Object = null


func _init() -> void:
	var app_id := _app_id()
	if app_id <= 0:
		return
	OS.set_environment("SteamAppId", str(app_id))
	OS.set_environment("SteamGameId", str(app_id))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var app_id := _app_id()
	if app_id <= 0:
		return
	if not Engine.has_singleton("Steam"):
		push_warning("SteamService: GodotSteam GDExtension yok (addons/godotsteam). Steam kapalı.")
		return
	_steam = Engine.get_singleton("Steam")
	if _steam == null:
		return
	var init_ok := _init_steam(app_id)
	if not init_ok:
		_steam = null
		return
	_ready_ok = true
	_pull_cloud()
	print("[SteamService] init OK, app %d" % app_id)


func _process(_delta: float) -> void:
	if not _ready_ok or _steam == null:
		return
	if _steam.has_method("run_callbacks"):
		_steam.call("run_callbacks")


func _exit_tree() -> void:
	if _steam != null and _steam.has_method("steamShutdown"):
		_steam.call("steamShutdown")
	_ready_ok = false
	_steam = null


func is_ready() -> bool:
	return _ready_ok


func overlay_available() -> bool:
	if not _ready_ok or _steam == null:
		return false
	if _steam.has_method("isOverlayEnabled"):
		return bool(_steam.call("isOverlayEnabled"))
	return true


func notify_progress(highest_unlocked: int, badges: Dictionary, daily_cleared: bool = false) -> void:
	if highest_unlocked > LevelData3D.INTRO_LEVELS:
		unlock(ACH_TUTORIAL)
	var cleared_idx := highest_unlocked - 2
	if cleared_idx >= 0:
		var slot := LevelData3D.world_slot_for_level(cleared_idx)
		if slot >= 3:
			unlock(ACH_CHAPTERS_3)
	for v in badges.values():
		if int(v) >= BadgeRating3D.Rank.GOLD:
			unlock(ACH_GOLD)
			break
	if daily_cleared:
		unlock(ACH_DAILY)


func unlock(api_name: String) -> void:
	if not _ready_ok or _steam == null or api_name.is_empty():
		return
	if _steam.has_method("setAchievement"):
		_steam.call("setAchievement", api_name)
	if _steam.has_method("storeStats"):
		_steam.call("storeStats")


func push_saves() -> void:
	if not _ready_ok or _steam == null:
		return
	if _steam.has_method("beginFileWriteBatch"):
		_steam.call("beginFileWriteBatch")
	for name in CLOUD_FILES:
		_push_one(name)
	if _steam.has_method("endFileWriteBatch"):
		_steam.call("endFileWriteBatch")


func _app_id() -> int:
	var env := OS.get_environment("MESSY_STEAM_APP_ID")
	if env.is_valid_int():
		var n := int(env)
		if n > 0:
			return n
	return Product.STEAM_APP_ID


func _init_steam(app_id: int) -> bool:
	var result: Variant = null
	if _steam.has_method("steamInitEx"):
		result = _steam.call("steamInitEx", app_id)
	elif _steam.has_method("steamInit"):
		result = _steam.call("steamInit")
	else:
		return false
	if result is Dictionary:
		return int((result as Dictionary).get("status", -1)) == 0
	if result is bool:
		return result
	if result is int:
		return int(result) == 0
	return false


func _pull_cloud() -> void:
	if _steam == null or not _steam.has_method("fileExists"):
		return
	for name in CLOUD_FILES:
		if not bool(_steam.call("fileExists", name)):
			continue
		var local_path := "user://%s" % name
		var remote_ts := 0
		if _steam.has_method("getFileTimestamp"):
			remote_ts = int(_steam.call("getFileTimestamp", name))
		var local_ts := 0
		if FileAccess.file_exists(local_path):
			local_ts = int(FileAccess.get_modified_time(local_path))
		if local_ts >= remote_ts and local_ts > 0:
			continue
		var size := 0
		if _steam.has_method("getFileSize"):
			size = int(_steam.call("getFileSize", name))
		if size <= 0 or not _steam.has_method("fileRead"):
			continue
		var read_v: Variant = _steam.call("fileRead", name, size)
		var buf := PackedByteArray()
		if read_v is Dictionary:
			buf = (read_v as Dictionary).get("buf", PackedByteArray()) as PackedByteArray
		elif read_v is PackedByteArray:
			buf = read_v
		if buf.is_empty():
			continue
		var f := FileAccess.open(local_path, FileAccess.WRITE)
		if f != null:
			f.store_buffer(buf)


func _push_one(name: String) -> void:
	var local_path := "user://%s" % name
	if not FileAccess.file_exists(local_path):
		return
	if not _steam.has_method("fileWrite"):
		return
	var f := FileAccess.open(local_path, FileAccess.READ)
	if f == null:
		return
	var buf := f.get_buffer(int(f.get_length()))
	if buf.is_empty():
		return
	_steam.call("fileWrite", name, buf)
