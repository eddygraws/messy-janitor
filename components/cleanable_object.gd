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

var _is_clean: bool = false
var _is_broken: bool = false
var _scrub_progress: float = 0.0
var _last_dir_x: int = 0
var _spread_accum: float = 0.0
var _revealed: bool = false
var _base_alpha: float = 1.0
var _sprayed: bool = false


func _ready() -> void:
	add_to_group("Cleanable")
	_base_alpha = modulate.a
	if is_hidden:
		modulate.a = 0.0
		_revealed = false
	else:
		_revealed = true


func _process(delta: float) -> void:
	# Sadece özel varyantlar için işlem yap.
	if _is_clean or _is_broken:
		return

	if is_hidden and not _revealed:
		_check_reveal()
		return

	if spreads:
		_spread_accum += delta * spread_speed_scale
		if _spread_accum >= spread_time:
			_spread_accum = 0.0
			spread_triggered.emit(global_position)


func get_hitbox() -> Rect2:
	return Rect2(global_position - hitbox_size * 0.5, hitbox_size)


func is_cleaned() -> bool:
	return _is_clean or _is_broken


func is_broken() -> bool:
	return _is_broken


func is_revealed() -> bool:
	return not is_hidden or _revealed


func get_scrub_progress() -> float:
	return _scrub_progress


func try_clean(click_pos: Vector2) -> bool:
	if is_cleaned() or not is_revealed() or not get_hitbox().has_point(click_pos):
		return false
	if requires_scrub:
		return false
	_finish_clean()
	return true


# Ovalama hareketiyle temizlik. motion = farenin bu karedeki gerçek hareketi.
func scrub_rub(pos: Vector2, motion: Vector2, effectiveness: float = 1.0) -> bool:
	if is_cleaned() or not is_revealed() or not get_hitbox().has_point(pos):
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

	if _scrub_progress >= 1.0:
		_finish_clean()
		return true
	return false


# Fırça: hızlı tekrarlı tıklama. Her çağrı ilerleme ekler, bitince true döner.
func mash(speed_mult: float = 1.0) -> bool:
	if is_cleaned() or not is_revealed():
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
	if is_cleaned() or not is_revealed():
		return false
	_finish_clean()
	return true


func _check_reveal() -> void:
	var cursor := get_tree().get_first_node_in_group("PlayerCursor")
	if cursor == null or not (cursor is Node2D):
		return
	if global_position.distance_to((cursor as Node2D).global_position) <= reveal_radius:
		_reveal()


func _reveal() -> void:
	if _revealed:
		return
	_revealed = true
	revealed.emit()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", _base_alpha, 0.25)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale = Vector2(1.25, 1.25)
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	modulate.a = 0.35
	cleaned.emit()
	_notify_room()


func _notify_room() -> void:
	var room_manager := get_tree().get_first_node_in_group("RoomManagerGroup")
	if room_manager != null:
		room_manager.check_room_cleared()


func _update_scrub_visual() -> void:
	modulate.a = lerpf(_base_alpha, 0.35, _scrub_progress)
