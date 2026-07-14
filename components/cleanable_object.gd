class_name CleanableObject
extends Node2D

signal cleaned
signal scrub_progress_changed(progress: float)
signal object_broken(position: Vector2)
signal spread_triggered(origin_position: Vector2)
signal revealed

# Ekipman kimlikleri (EquipmentComponent.Type ile AYNI sıra).
const EQ_MOP := 0
const EQ_BROOM := 1
const EQ_BRUSH := 2
const EQ_SPRAY := 3
const EQ_TWEEZERS := 4

@export var hitbox_size: Vector2 = Vector2(80, 80)
@export var requires_scrub: bool = false
@export_enum("Mop", "Broom", "Brush", "Spray", "Tweezers") var required_equipment: int = 0
@export var mash_per_hit: float = 0.22   # Fırça: her tıklamada eklenen ilerleme

# Ovalama (rubbing) dengesi:
@export var scrub_move_factor: float = 0.0016   # her piksel hareket başına ilerleme
@export var reversal_bonus: float = 0.07        # sağ<->sol yön değişimi başına bonus

@export_group("Fragile (Kırılgan)")
@export var is_fragile: bool = false
@export var fragile_threshold: float = 34.0     # bu hızın üstünde ovalama kırar (px/kare)

@export_group("Timed Mold (Yayılan Küf)")
@export var spreads: bool = false
@export var spread_time: float = 5.0            # bu süre temizlenmezse yayılır
var spread_speed_scale: float = 1.0             # TempoDirector climax'ta hızlandırır

@export_group("Hidden Grime (Gizli Kir)")
@export var is_hidden: bool = false
@export var reveal_radius: float = 130.0        # imleç bu yarıçapa girince belirir

@export_group("Commission Rules")
@export var is_forbidden: bool = false          # "SAKIN dokunma" — temizlenemez, dokunmak ceza

@export_group("Target Highlight")
@export var target_highlight: float = 0.75
@export var highlight_pulse_speed: float = 1.8

@export_group("Potion / Drunk")
@export var applies_drunk: bool = false
@export var drunk_on_scrub: float = 0.28
@export var drunk_on_touch: float = 0.12

## RoomFactory tarafından set edilir (powerup hedefleme için).
var dirt_kind: String = ""

var _is_clean: bool = false
var _is_broken: bool = false
var _scrub_progress: float = 0.0
var _last_dir_x: int = 0
var _spread_accum: float = 0.0
var _reveal_amount: float = 1.0   # gizli kir: imleç yakınlığına göre 0..1
var _in_range: bool = false       # imleç şu an aydınlatma yarıçapında mı
var _base_alpha: float = 1.0
var _sprayed: bool = false
var _grime_materials: Array[ShaderMaterial] = []
var _highlight_time: float = 0.0


func _ready() -> void:
	add_to_group("Cleanable")
	_base_alpha = modulate.a
	if is_hidden:
		_reveal_amount = 0.0
		_in_range = false
		modulate.a = 0.0
	else:
		_reveal_amount = 1.0
		_in_range = true
	call_deferred("_setup_grime_shaders")


func _process(delta: float) -> void:
	# Sadece özel varyantlar için işlem yap.
	if _is_clean or _is_broken:
		return

	if is_hidden:
		_update_reveal(delta)

	if spreads:
		_spread_accum += delta * spread_speed_scale
		if _spread_accum >= spread_time:
			_spread_accum = 0.0
			spread_triggered.emit(global_position)

	_update_target_highlight(delta)


func get_hitbox() -> Rect2:
	return Rect2(global_position - hitbox_size * 0.5, hitbox_size)


func is_cleaned() -> bool:
	return _is_clean or _is_broken


func is_broken() -> bool:
	return _is_broken


func is_revealed() -> bool:
	return not is_hidden or _in_range


func get_scrub_progress() -> float:
	return _scrub_progress


## Powerup: ilerleme ekle. allow_finish=false iken tam temizlemez (cap uygulanır).
func apply_clean_progress(amount: float, allow_finish: bool = true, cap: float = 1.0) -> bool:
	if is_forbidden or is_cleaned() or not is_revealed():
		return false
	if not requires_scrub:
		if allow_finish and amount >= 0.99:
			_finish_clean()
			return true
		return false
	var limit := 1.0 if allow_finish else clampf(cap, 0.0, 0.99)
	_scrub_progress = minf(limit, _scrub_progress + amount)
	scrub_progress_changed.emit(_scrub_progress)
	_update_scrub_visual()
	if allow_finish and _scrub_progress >= 1.0:
		_finish_clean()
		return true
	return false


func force_clean() -> bool:
	if is_forbidden or is_cleaned():
		return false
	_finish_clean()
	return true


func try_clean(click_pos: Vector2) -> bool:
	if is_forbidden or is_cleaned() or not is_revealed() or not get_hitbox().has_point(click_pos):
		return false
	if requires_scrub:
		return false
	_finish_clean()
	return true


# Ovalama hareketiyle temizlik. motion = farenin bu karedeki gerçek hareketi.
func scrub_rub(pos: Vector2, motion: Vector2, effectiveness: float = 1.0) -> bool:
	if is_forbidden or is_cleaned() or not is_revealed() or not get_hitbox().has_point(pos):
		_last_dir_x = 0
		return false

	# Sprey+Bez: önce sprey sıkılmadan ovalama işe yaramaz.
	if required_equipment == EQ_SPRAY and not _sprayed:
		return false

	# Kırılgan eşya: çok sert/hızlı ovalama kırar (ceza).
	if is_fragile and motion.length() > fragile_threshold:
		_break()
		return true

	var effort := absf(motion.x) + absf(motion.y) * 0.4
	if effort <= 0.5:
		return false

	var gain := effort * scrub_move_factor * effectiveness

	var dir := 0
	if motion.x > 1.5:
		dir = 1
	elif motion.x < -1.5:
		dir = -1
	if dir != 0 and _last_dir_x != 0 and dir != _last_dir_x:
		gain += reversal_bonus * effectiveness
	if dir != 0:
		_last_dir_x = dir

	_scrub_progress = minf(1.0, _scrub_progress + gain)
	scrub_progress_changed.emit(_scrub_progress)
	_update_scrub_visual()
	if applies_drunk:
		_apply_drunk(drunk_on_scrub * clampf(effort / 40.0, 0.35, 1.0))

	if _scrub_progress >= 1.0:
		_finish_clean()
		return true
	return false


func _apply_drunk(amount: float) -> void:
	var cursor := get_tree().get_first_node_in_group("PlayerCursor")
	if cursor != null and cursor.has_method("add_drunk"):
		cursor.call("add_drunk", amount)


# Fırça: hızlı tekrarlı tıklama. Her çağrı ilerleme ekler, bitince true döner.
func mash(speed_mult: float = 1.0) -> bool:
	if is_forbidden or is_cleaned() or not is_revealed():
		return false
	_scrub_progress = minf(1.0, _scrub_progress + mash_per_hit * speed_mult)
	scrub_progress_changed.emit(_scrub_progress)
	_update_scrub_visual()
	if _scrub_progress >= 1.0:
		_finish_clean()
		return true
	return false


# Sprey+Bez birinci aşama: yüzeyi ıslat.
func spray() -> void:
	if _sprayed or is_cleaned():
		return
	_sprayed = true
	var wet := create_tween()
	wet.tween_property(self, "modulate", modulate.lerp(Color(0.6, 0.85, 1.0, modulate.a), 0.6), 0.15)


func is_sprayed() -> bool:
	return _sprayed


# Cımbız: tek hassas tıklamayla topla.
func pluck() -> bool:
	if is_forbidden or is_cleaned() or not is_revealed():
		return false
	_finish_clean()
	return true


# Commission: bu objeyi "gizli kir" moduna çevir (imleçle belirir).
func enable_hidden(radius: float = 150.0) -> void:
	is_hidden = true
	reveal_radius = radius
	_reveal_amount = 0.0
	_in_range = false
	modulate.a = 0.0


# Commission: bu objeyi "yasak" işaretle (kırmızı halka + temizlenemez).
func mark_forbidden() -> void:
	is_forbidden = true
	var ring := Sprite2D.new()
	ring.texture = GameAssets.get_forbidden_ring()
	ring.centered = true
	ring.scale = Vector2(
		(hitbox_size.x + 24.0) / 128.0,
		(hitbox_size.y + 24.0) / 128.0,
	)
	ring.z_index = -1
	add_child(ring)
	var warn := Label.new()
	warn.text = "⛔"
	warn.add_theme_font_size_override("font_size", 40)
	warn.position = Vector2(-20, -hitbox_size.y * 0.5 - 44)
	add_child(warn)


# El feneri: imleç yakınlığına göre görünürlük. Uzaklaşınca tekrar kaybolur.
func _update_reveal(delta: float) -> void:
	var target := 0.0
	var cursor := get_tree().get_first_node_in_group("PlayerCursor")
	if cursor is Node2D:
		var dist := global_position.distance_to((cursor as Node2D).global_position)
		if dist <= reveal_radius:
			# Merkeze yakınken parlak, kenarda sönük (torch gradyanı).
			target = clampf(1.0 - dist / reveal_radius, 0.0, 1.0)

	var was_in_range := _in_range
	_in_range = target > 0.02

	# İlk kez aydınlanınca dinleyicilere haber ver.
	if _in_range and not was_in_range:
		revealed.emit()

	_reveal_amount = lerpf(_reveal_amount, target, clampf(delta * 12.0, 0.0, 1.0))
	_refresh_alpha()


func _break() -> void:
	if _is_broken or _is_clean:
		return
	_is_broken = true
	object_broken.emit(global_position)

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.4, 0.6), 0.06)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)

	_notify_room()


func _finish_clean() -> void:
	if is_cleaned():
		return

	_is_clean = true
	_scrub_progress = 1.0
	_update_grime_dissolve(1.0)
	_apply_highlight()
	cleaned.emit()
	_notify_room()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.22)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale", scale * 0.85, 0.22)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _notify_room() -> void:
	var room_manager := get_tree().get_first_node_in_group("RoomManagerGroup")
	if room_manager != null:
		room_manager.check_room_cleared()


func _setup_grime_shaders() -> void:
	_grime_materials.clear()
	for child in get_children():
		if child is CanvasItem and child.z_index >= 0 and _is_grime_target(child):
			_grime_materials.append(GrimeShaderHelper.apply_to_canvas_item(child as CanvasItem))
	_update_grime_dissolve()
	_apply_highlight()


func _is_grime_target(node: Node) -> bool:
	if node is Sprite2D:
		return node.get_meta(SpriteVisualHelper.GRIME_META, true)
	if node is Polygon2D:
		return true
	return false


func _update_grime_dissolve(pulse: float = 0.0) -> void:
	for mat in _grime_materials:
		GrimeShaderHelper.set_dissolve(mat, _scrub_progress, pulse)


func _update_scrub_visual() -> void:
	_update_grime_dissolve(0.15 if _scrub_progress > 0.05 else 0.0)
	_refresh_alpha()
	_apply_highlight()


func _update_target_highlight(delta: float) -> void:
	_highlight_time += delta * highlight_pulse_speed
	_apply_highlight()


func _apply_highlight() -> void:
	var amount := 0.0
	var pulse := 0.0
	if not _is_clean and not _is_broken and not is_forbidden:
		if not is_hidden or _in_range:
			var fade := 1.0 - _scrub_progress * 0.65
			if is_hidden:
				fade *= _reveal_amount
			amount = target_highlight * fade
			pulse = (sin(_highlight_time) * 0.5 + 0.5) * amount
	for mat in _grime_materials:
		GrimeShaderHelper.set_highlight(mat, amount, pulse)


# Alfayı hem temizlik ilerlemesine hem de (gizliyse) imleç aydınlatmasına göre ayarlar.
func _refresh_alpha() -> void:
	if _is_clean or _is_broken:
		return
	if not _grime_materials.is_empty():
		if is_hidden:
			modulate.a = _base_alpha * _reveal_amount
		else:
			modulate.a = _base_alpha
		return
	var base := lerpf(_base_alpha, 0.35, _scrub_progress)
	if is_hidden:
		modulate.a = base * _reveal_amount
	else:
		modulate.a = base
