class_name MopComponent
extends Node

signal charge_changed(ratio: float)
signal overheated
signal rinsed

@export var stamina_path: NodePath = ^"../StaminaComponent"
@export var bucket_group: StringName = &"MopBucket"

# Denge:
@export var heat_per_100px: float = 0.06      # 100px ovalama başına eklenen kir
@export var reload_per_second: float = 0.85   # kovada saniyede düşen kir
@export var min_effectiveness: float = 0.18   # tam kirliyken temizlik çarpanı
@export var reload_stamina_bonus: float = 22.0

var charge: float = 0.0
var _overheated: bool = false
var _stamina: StaminaComponent
var _bucket: Node


func _ready() -> void:
	_stamina = get_node_or_null(stamina_path) as StaminaComponent
	call_deferred("_bind_bucket")
	charge_changed.emit(0.0)


func _bind_bucket() -> void:
	_bucket = get_tree().get_first_node_in_group(bucket_group)
	_refresh_bucket()


func add_heat(pixels: float) -> void:
	var before := charge
	charge = clampf(charge + (pixels / 100.0) * heat_per_100px, 0.0, 1.0)
	if charge != before:
		charge_changed.emit(charge)
		_refresh_bucket()
	if charge >= 1.0 and not _overheated:
		_overheated = true
		overheated.emit()
		if _bucket != null and _bucket.has_method("set_ready_glow"):
			_bucket.set_ready_glow(true)


func reload(delta: float) -> void:
	if charge <= 0.0:
		return
	charge = maxf(0.0, charge - reload_per_second * delta)
	charge_changed.emit(charge)
	_refresh_bucket()

	if charge < 1.0 and _overheated:
		_overheated = false
		if _bucket != null and _bucket.has_method("set_ready_glow"):
			_bucket.set_ready_glow(false)

	if charge <= 0.0:
		if _stamina != null:
			_stamina.restore(reload_stamina_bonus)
		rinsed.emit()


func get_effectiveness() -> float:
	return lerpf(1.0, min_effectiveness, charge)


func is_overheated() -> bool:
	return _overheated


func get_charge() -> float:
	return charge


func _refresh_bucket() -> void:
	if _bucket != null and _bucket.has_method("set_dirty"):
		_bucket.set_dirty(charge)
