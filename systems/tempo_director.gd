class_name TempoDirector
extends Node

# Oda içi tempo / climax alt yapısı (ORTAK — hem Adventure hem Endless besler).
# Oda içinde geçen süreyi izler, 0..1 arası bir "intensity" üretir ve eşiği
# aşınca climax (son sprint) sinyali verir. Spawner'lar bu değeri okuyup hızlanır.
#
# - Adventure: climax = "gargoyle sabırsızlanıyor, son saniyelerde ekstra baskı".
# - Endless: base_intensity oda ilerledikçe artırılarak zorluk eğrisine bağlanır.

signal intensity_changed(value: float)
signal climax_entered
signal climax_exited

@export var room_manager_path: NodePath = ^"../RoomManager"

@export var calm_time: float = 12.0        # bu süreye kadar sakin (intensity düşük)
@export var ramp_time: float = 10.0        # bu pencere boyunca 0 -> 1 tırmanır
@export var climax_threshold: float = 0.7  # bu değerin üstü = climax

var base_intensity: float = 0.0            # Endless: oda başına artırılır

var _room_manager: Node
var _elapsed: float = 0.0
var _intensity: float = 0.0
var _in_climax: bool = false


func _ready() -> void:
	_room_manager = get_node_or_null(room_manager_path)
	if _room_manager != null and _room_manager.has_signal("room_transition_finished"):
		_room_manager.room_transition_finished.connect(_on_room_reset)


func _process(delta: float) -> void:
	# Geçiş sırasında zamanı dondur (feedback ekranı sayılmasın).
	if not _is_transitioning():
		_elapsed += delta

	var raw := 0.0
	if _elapsed > calm_time:
		raw = (_elapsed - calm_time) / maxf(ramp_time, 0.01)
	var inten := clampf(base_intensity + raw, 0.0, 1.0)

	if absf(inten - _intensity) > 0.01:
		_intensity = inten
		intensity_changed.emit(_intensity)

	var climax_now := _intensity >= climax_threshold
	if climax_now and not _in_climax:
		_in_climax = true
		climax_entered.emit()
	elif not climax_now and _in_climax:
		_in_climax = false
		climax_exited.emit()


func _is_transitioning() -> bool:
	return _room_manager != null and _room_manager.has_method("is_transitioning") and _room_manager.is_transitioning()


func _on_room_reset() -> void:
	_elapsed = 0.0


func get_intensity() -> float:
	return _intensity


func is_climax() -> bool:
	return _in_climax


# Endless zorluk eğrisi için: oda başına taban yoğunluğu ayarla.
func set_base_intensity(value: float) -> void:
	base_intensity = clampf(value, 0.0, 1.0)
