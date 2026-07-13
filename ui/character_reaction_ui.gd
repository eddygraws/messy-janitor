class_name CharacterReactionUI
extends Control

# Karakter mikro-reaksiyon katmanı.
# Yeni bir "ağır" sistem değil: sadece mevcut sinyalleri dinleyip
# karakter portresinin yanında kısa bir düşünce/mırıltı balonu gösterir.
# Hem Adventure hem Endless modunu besleyen ORTAK bir kişilik katmanıdır.

@export var stress_path: NodePath = ^"../../StressComponent"
@export var combo_path: NodePath = ^"../../ComboComponent"
@export var router_path: NodePath = ^"../../CursorClickerRouter"
@export var room_manager_path: NodePath = ^"../../RoomManager"
@export var tempo_path: NodePath = ^"../../TempoDirector"

@export var hold_time: float = 2.2          # balon ekranda kalma süresi
@export var min_gap: float = 1.6            # düşük öncelikli tepkiler arası min süre
@export var idle_min: float = 15.0
@export var idle_max: float = 26.0

# Öncelik: yüksek olan, düşük öncelikli aktif balonu ezebilir.
const P_IDLE := 0
const P_CLEAN := 1
const P_MISTAKE := 2
const P_MILESTONE := 3
const P_PANIC := 4
const P_CRITICAL := 5
const P_CLIMAX := 3

const PHRASES := {
	"critical": ["Patlayacağım gibiyim!", "Çok fazla... çok fazla!", "Nefes al... nefes al..."],
	"panic": ["Bir tane... sadece bir tane cips...", "Sakin ol, sakin...", "Ellerim titriyor..."],
	"milestone": ["İşte bu!", "Temizlik ustası benim!", "Kimse benden temiz yapamaz!", "Ohh, akıyor bu!"],
	"mistake": ["Ah, kaçırdım.", "Hop!", "Odaklan, odaklan...", "Off ya."],
	"junk": ["Mmm... abur cubur.", "Yememeliydim...", "Şeker krizi geliyor...", "Bir ısırık daha?"],
	"wrong_tool": ["Yanlış alet bu!", "Bununla olmaz ki.", "Hmm, bu değil...", "Doğru aleti seç!"],
	"clean": ["Oh be, bitti.", "Tertemiz!", "Sıradaki oda...", "Pırıl pırıl oldu."],
	"climax": ["Acele et, acele!", "Zaman daralıyor!", "Hızlan, hızlan!", "Yetişemeyeceğim!"],
	"idle": ["*yorgun iç çekiş*", "Ne zaman biter bu iş...", "Bir mola iyi giderdi.", "*mırıldanır*", "Sırtım ağrıyor..."],
}

var _stress: StressComponent
var _combo: ComboComponent
var _router: CursorClickRouter
var _room_manager: Node
var _tempo: TempoDirector

var _bubble: PanelContainer
var _label: Label

var _clock: float = 0.0
var _last_show: float = -100.0
var _visible_until: float = 0.0
var _active_priority: int = -1
var _idle_target: float = 18.0
var _last_activity: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_bubble()

	_stress = get_node_or_null(stress_path) as StressComponent
	_combo = get_node_or_null(combo_path) as ComboComponent
	_router = get_node_or_null(router_path) as CursorClickRouter
	_room_manager = get_node_or_null(room_manager_path)

	if _stress != null:
		_stress.panic_mode_entered.connect(_on_panic)
		_stress.stress_critical.connect(_on_critical)
		_stress.mistake_registered.connect(_on_mistake)
	if _combo != null:
		_combo.combo_milestone.connect(_on_milestone)
	if _router != null:
		_router.junk_food_tempted.connect(_on_junk)
		_router.wrong_tool.connect(_on_wrong_tool)
	if _room_manager != null and _room_manager.has_signal("room_cleared"):
		_room_manager.room_cleared.connect(_on_room_cleared)
	_tempo = get_node_or_null(tempo_path) as TempoDirector
	if _tempo != null:
		_tempo.climax_entered.connect(_on_climax)

	_idle_target = randf_range(idle_min, idle_max)


func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.anchor_left = 1.0
	_bubble.anchor_right = 1.0
	_bubble.anchor_top = 0.0
	_bubble.anchor_bottom = 0.0
	_bubble.offset_left = -540.0
	_bubble.offset_top = 150.0
	_bubble.offset_right = -240.0
	_bubble.offset_bottom = 236.0
	_bubble.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.13, 0.92)
	style.border_color = Color(0.5, 0.42, 0.6, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(14)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 6
	_bubble.add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(272, 0)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.95))
	_bubble.add_child(_label)

	_bubble.modulate = Color(1, 1, 1, 0)
	_bubble.visible = false
	add_child(_bubble)


func _process(delta: float) -> void:
	_clock += delta

	if _bubble.visible and _clock >= _visible_until:
		_hide_bubble()

	# Boşta mırıltı: sadece oyun akışı sakinken ve geçiş yokken.
	if _clock - _last_activity >= _idle_target and not _bubble.visible and not _is_transitioning():
		_react("idle", P_IDLE)
		_idle_target = randf_range(idle_min, idle_max)


func _is_transitioning() -> bool:
	return _room_manager != null and _room_manager.has_method("is_transitioning") and _room_manager.is_transitioning()


func _react(category: String, priority: int) -> void:
	# Aktif balon daha yüksek/eşit öncelikliyse ve hâlâ görünüyorsa, düşüğü ezme.
	if _bubble.visible and priority < _active_priority and _clock < _visible_until:
		return
	# Düşük öncelikli spam'i engelle.
	if priority <= P_CLEAN and _clock - _last_show < min_gap:
		return

	var pool: Array = PHRASES.get(category, [])
	if pool.is_empty():
		return

	_label.text = String(pool[randi() % pool.size()])
	_last_show = _clock
	_last_activity = _clock
	_visible_until = _clock + hold_time
	_active_priority = priority
	_pop_in()


func _pop_in() -> void:
	_bubble.visible = true
	_bubble.pivot_offset = _bubble.size * Vector2(1.0, 0.3)
	_bubble.scale = Vector2(0.8, 0.8)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_bubble, "modulate:a", 1.0, 0.12)
	tween.tween_property(_bubble, "scale", Vector2.ONE, 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_bubble() -> void:
	var tween := create_tween()
	tween.tween_property(_bubble, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func() -> void:
		_bubble.visible = false
		_active_priority = -1)


# ---- Sinyal köprüleri ----

func _on_panic() -> void:
	_react("panic", P_PANIC)


func _on_critical() -> void:
	_react("critical", P_CRITICAL)


func _on_mistake() -> void:
	_react("mistake", P_MISTAKE)


func _on_milestone(_combo_count: int) -> void:
	_react("milestone", P_MILESTONE)


func _on_junk(_pos: Vector2) -> void:
	_react("junk", P_MISTAKE)


func _on_wrong_tool(_pos: Vector2) -> void:
	_react("wrong_tool", P_MISTAKE)


func _on_room_cleared(_room_index: int, _result: Dictionary) -> void:
	_react("clean", P_CLEAN)


func _on_climax() -> void:
	_react("climax", P_CLIMAX)
