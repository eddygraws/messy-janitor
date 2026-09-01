extends Node

## Kalıcı dil / grafik / ses. Autoload: GameSettings

signal locale_changed(locale: String)
signal changed

const Product := preload("res://systems/product_identity.gd")

const SAVE_PATH := "user://messy3d_settings.cfg"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"

const LOCALES: PackedStringArray = ["tr", "en"]

var locale: String = "tr"
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var fullscreen: bool = false
var vsync: bool = true
var pixel_size: int = 3
var outlines: bool = true

const _T := {
	"tr": {
		"tag": "3D · Temizlik kaosuna hoş geldin",
		"play": "▶  Oyna",
		"settings": "⚙  Ayarlar",
		"quit": "Çıkış",
		"credits": "Jenerik",
		"hint": "Enter · Oyna     Esc · Ayarlar",
		"lang": "Dil",
		"settings_title": "Ayarlar",
		"graphics": "Grafik",
		"audio": "Ses",
		"fullscreen": "Tam ekran",
		"vsync": "VSync",
		"pixel": "Piksel boyutu",
		"pixel_off": "Kapalı",
		"pixel_2": "2 · keskin",
		"pixel_3": "3 · dengeli",
		"pixel_4": "4 · chunky",
		"outlines": "Kenar çizgisi",
		"master": "Ana ses",
		"music": "Müzik",
		"sfx": "Efektler",
		"back": "◀  Geri",
		"on": "Açık",
		"off": "Kapalı",
		"paused": "Duraklatıldı",
		"resume": "Devam",
		"main_menu": "Ana menü",
		"pause_hint": "Esc · devam",
		"fail_title": "Başarısız",
		"fail_retry": "Tekrar",
		"fail_no_lives": "Can yok",
		"fail_sub_lives": "Kalan can: %d  ·  Tekrar dene veya menüye dön",
		"fail_sub_empty": "Can bitti. 100 coin ile can al veya menüye dön.",
		"fail_buy": "100 coin → can",
		"fail_menu": "Menü",
	},
	"en": {
		"tag": "3D · Welcome to cleaning chaos",
		"play": "▶  Play",
		"settings": "⚙  Settings",
		"quit": "Quit",
		"credits": "Credits",
		"hint": "Enter · Play     Esc · Settings",
		"lang": "Language",
		"settings_title": "Settings",
		"graphics": "Graphics",
		"audio": "Audio",
		"fullscreen": "Fullscreen",
		"vsync": "VSync",
		"pixel": "Pixel size",
		"pixel_off": "Off",
		"pixel_2": "2 · sharp",
		"pixel_3": "3 · balanced",
		"pixel_4": "4 · chunky",
		"outlines": "Outlines",
		"master": "Master",
		"music": "Music",
		"sfx": "Sound FX",
		"back": "◀  Back",
		"on": "On",
		"off": "Off",
		"paused": "Paused",
		"resume": "Resume",
		"main_menu": "Main menu",
		"pause_hint": "Esc · resume",
		"fail_title": "Failed",
		"fail_retry": "Retry",
		"fail_no_lives": "No lives",
		"fail_sub_lives": "Lives left: %d  ·  Retry or return to the menu",
		"fail_sub_empty": "Out of lives. Buy one for 100 coins or return to the menu.",
		"fail_buy": "100 coins → life",
		"fail_menu": "Menu",
	},
}


func _ready() -> void:
	_ensure_buses()
	_load()
	apply_all()


func t(key: String) -> String:
	var pack: Dictionary = _T.get(locale, _T["tr"])
	if pack.has(key):
		return String(pack[key])
	var fallback: Dictionary = _T["tr"]
	return String(fallback.get(key, key))


func set_locale(code: String) -> void:
	if code != "en":
		code = "tr"
	if locale == code:
		return
	locale = code
	TranslationServer.set_locale(locale)
	save()
	locale_changed.emit(locale)
	changed.emit()


func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume(0, master_volume)
	save()
	changed.emit()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume(AudioServer.get_bus_index(BUS_MUSIC), music_volume)
	save()
	changed.emit()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume(AudioServer.get_bus_index(BUS_SFX), sfx_volume)
	save()
	changed.emit()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_window()
	save()
	changed.emit()


func set_vsync(on: bool) -> void:
	vsync = on
	_apply_window()
	save()
	changed.emit()


func set_pixel_size(size: int) -> void:
	pixel_size = clampi(size, 1, 4)
	_apply_pixel()
	save()
	changed.emit()


func set_outlines(on: bool) -> void:
	outlines = on
	_apply_pixel()
	save()
	changed.emit()


func apply_all() -> void:
	TranslationServer.set_locale(locale)
	DisplayServer.window_set_title(Product.APP_NAME)
	_apply_bus_volume(0, master_volume)
	_apply_bus_volume(AudioServer.get_bus_index(BUS_MUSIC), music_volume)
	_apply_bus_volume(AudioServer.get_bus_index(BUS_SFX), sfx_volume)
	_apply_window()
	_apply_pixel()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("locale", "code", locale)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("graphics", "fullscreen", fullscreen)
	cfg.set_value("graphics", "vsync", vsync)
	cfg.set_value("graphics", "pixel_size", pixel_size)
	cfg.set_value("graphics", "outlines", outlines)
	cfg.save(SAVE_PATH)
	if Engine.get_main_loop() != null:
		SteamService.push_saves()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		var os_lang := OS.get_locale_language()
		locale = "en" if os_lang.begins_with("en") else "tr"
		return
	locale = "en" if String(cfg.get_value("locale", "code", "tr")) == "en" else "tr"
	master_volume = clampf(float(cfg.get_value("audio", "master", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("graphics", "fullscreen", false))
	vsync = bool(cfg.get_value("graphics", "vsync", true))
	pixel_size = clampi(int(cfg.get_value("graphics", "pixel_size", 3)), 1, 4)
	outlines = bool(cfg.get_value("graphics", "outlines", true))


func _ensure_buses() -> void:
	_ensure_bus(String(BUS_MUSIC))
	_ensure_bus(String(BUS_SFX))


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _apply_bus_volume(idx: int, linear: float) -> void:
	if idx < 0:
		return
	var muted := linear <= 0.001
	AudioServer.set_bus_mute(idx, muted)
	if muted:
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func _apply_window() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)


func _apply_pixel() -> void:
	PixelLook.set_pixel_size(pixel_size)
	PixelLook.set_outlines(outlines)
