extends RefCounted

## 32px HUD atlas — `res://assets/ui/hud_icons.png`
## Sıra: mop broom brush spray tweezers heart coin job | gold silver bronze bucket trash warning

const ATLAS_PATH := "res://assets/ui/hud_icons.png"
const TILE := 32
const COLS := 8

const NAMES: PackedStringArray = [
	"mop", "broom", "brush", "spray", "tweezers", "heart", "coin", "job",
	"gold", "silver", "bronze", "bucket", "trash", "warning",
]

const EMOJI_MAP := {
	"🧹": "mop",
	"🧺": "broom",
	"🪥": "brush",
	"🧴": "spray",
	"🔬": "tweezers",
	"❤️": "heart",
	"🖤": "heart",
	"🪙": "coin",
	"🥇": "gold",
	"🥈": "silver",
	"🥉": "bronze",
	"🪣": "bucket",
	"📜": "job",
	"📖": "job",
	"📘": "job",
	"👻": "broom",
	"🧪": "spray",
	"🤢": "warning",
	"🍔": "job",
	"👽": "warning",
}

static var _atlas: Texture2D
static var _cache: Dictionary = {}


static func tex(name: String) -> Texture2D:
	if _atlas == null:
		if ResourceLoader.exists(ATLAS_PATH):
			_atlas = load(ATLAS_PATH) as Texture2D
		if _atlas == null:
			return null
	if _cache.has(name):
		return _cache[name] as Texture2D
	var idx := NAMES.find(name)
	if idx < 0:
		idx = NAMES.find("job")
	var at := AtlasTexture.new()
	at.atlas = _atlas
	at.filter_clip = true
	at.region = Rect2(float((idx % COLS) * TILE), float(int(idx / COLS) * TILE), float(TILE), float(TILE))
	_cache[name] = at
	return at


static func tex_for_tool(tool_index: int) -> Texture2D:
	var i := clampi(tool_index, 0, 4)
	return tex(NAMES[i])


static func tex_for_rank(rank: int) -> Texture2D:
	match rank:
		3:
			return tex("gold")
		2:
			return tex("silver")
		1:
			return tex("bronze")
		_:
			return null


static func tex_for_emoji(emoji: String) -> Texture2D:
	var key := String(EMOJI_MAP.get(emoji, "job"))
	return tex(key)


static func make_rect(icon_name: String, size: Vector2 = Vector2(28, 28)) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex(icon_name)
	t.custom_minimum_size = size
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
