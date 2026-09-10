class_name ProductIdentity
extends RefCounted

## P0 kilit — Steam adı ve kısa açıklama. Metin: docs/steam/IDENTITY.md

const APP_NAME := "Messy Janitor"
const EXE_NAME := "messy-janitor"
const VERSION := "0.1.0"
## Steam partner App ID. 0 = Steam kapalı (GDExtension olsa bile init yok).
const STEAM_APP_ID := 0
const COPYRIGHT_YEAR := "2026"
const COMPANY := "Messy Janitor"
const COPYRIGHT := "Copyright (c) 2026 Messy Janitor"
const FILE_DESCRIPTION := "Chaotic 3D cleaning game"
const ENGINE_CREDIT := "Godot Engine 4.6"
const MIXAMO_CREDIT := "Mixamo"
const GODOT_NOTICE := "This game uses Godot Engine, available under the MIT license. Copyright (c) 2014-present Godot Engine contributors. Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur."

const SHORT_TR := "Kaotik 3D temizlik. Paspasla, süpür, koli taşı — süre bitmeden odayı kurtar."
const SHORT_EN := "Chaotic 3D cleaning. Mop, sweep, haul crates — clear the room before time runs out."

const MUSIC_TRACKS: PackedStringArray = [
	"mop_waltz",
	"crate_trot",
	"suds_night",
	"last_call",
	"menu_loop",
]


static func short_blurb() -> String:
	if GameSettings.locale == "en":
		return SHORT_EN
	return SHORT_TR
