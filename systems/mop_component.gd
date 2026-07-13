class_name MopComponent
extends Node

signal charge_changed(ratio: float)
signal overheated
signal rinsed

@export var stamina_path: NodePath = ^"../StaminaComponent"
@export var bucket_group: StringName = &"MopBucket"
@export var modifier_path: NodePath = ^"../RunModifierDirector"

## Her 100 px ovalama hareketinde eklenen kir miktarı (0–1). Düşük = daha yavaş kirlenir.
@export_group("Kirlenme")
@export_range(0.01, 0.2, 0.005) var heat_per_100px: float = 0.045
## Hareket pikseli böleni. Yüksek = aynı sürüklemede daha az kir (ör. 120 = %20 daha yavaş).
@export_range(50.0, 250.0, 5.0, "suffix:px") var motion_reference_px: float = 100.0
## Genel kirlenme çarpanı. 0.7 = %30 daha yavaş kirlenme.
@export_range(0.2, 2.0, 0.05) var dirt_rate_multiplier: float = 1.0
## Tam kir eşiği; altına inince "overheated" kalkar.
@export_range(0.5, 1.0, 0.05) var overheat_threshold: float = 1.0

@export_group("Durulama")
@export_range(0.1, 2.0, 0.05, "suffix:/s") var reload_per_second: float = 0.85
@export_range(0.0, 0.5, 0.01) var passive_reload_scale: float = 0.1
## Great skill check: mevcut kirin ne kadarı silinsin (1.0 = tamamen temiz).
@export_range(0.5, 1.0, 0.05) var skill_great_clean_ratio: float = 1.0
## Good skill check: mevcut kirin ne kadarı silinsin (0.7 = %70 temizlenir).
@export_range(0.1, 1.0, 0.05) var skill_good_clean_ratio: float = 0.7
@export_range(0.0, 0.2, 0.005) var skill_miss_penalty: float = 0.07
@export_range(0.0, 50.0, 1.0) var reload_stamina_bonus: float = 22.0

@export_group("Kirli Paspas Cezası")
@export_range(0.0, 0.5, 0.01) var min_effectiveness: float = 0.05
@export_range(0.5, 4.0, 0.1) var dirty_curve_power: float = 2.0
@export_range(1.0, 5.0, 0.1) var dirty_stamina_mult: float = 2.6

var charge: float = 0.0
var _overheated: bool = false
var _stamina: StaminaComponent
var _modifiers: RunModifierDirector
var _bucket: Node


func _ready() -> void:
	_stamina = get_node_or_null(stamina_path) as StaminaComponent
	_modifiers = get_node_or_null(modifier_path) as RunModifierDirector
	call_deferred("_bind_bucket")
	charge_changed.emit(0.0)


func _bind_bucket() -> void:
	_bucket = get_tree().get_first_node_in_group(bucket_group)
	_refresh_bucket()


func add_heat(pixels: float) -> void:
	var ref := maxf(1.0, motion_reference_px)
	var gain := (pixels / ref) * heat_per_100px * dirt_rate_multiplier
	if _modifiers != null:
		gain *= _modifiers.get_mult(&"mop_heat_mult", 1.0)
	var before := charge
	charge = clampf(charge + gain, 0.0, 1.0)
	if charge != before:
		charge_changed.emit(charge)
		_refresh_bucket()
	if charge >= overheat_threshold and not _overheated:
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

	if charge < overheat_threshold and _overheated:
		_overheated = false
		if _bucket != null and _bucket.has_method("set_ready_glow"):
			_bucket.set_ready_glow(false)

	if charge <= 0.0:
		if _stamina != null:
			_stamina.restore(reload_stamina_bonus)
		rinsed.emit()


func get_effectiveness() -> float:
	var t := pow(charge, dirty_curve_power)
	return lerpf(1.0, min_effectiveness, t)


func get_stamina_drain_multiplier() -> float:
	return lerpf(1.0, dirty_stamina_mult, pow(charge, 1.35))


func apply_skill_result(tier: int) -> void:
	var before := charge
	match tier:
		2:
			charge *= 1.0 - clampf(skill_great_clean_ratio, 0.0, 1.0)
		1:
			charge *= 1.0 - _resolved_good_clean_ratio()
		_:
			charge = minf(overheat_threshold, charge + skill_miss_penalty)
	charge = maxf(0.0, charge)
	if charge != before:
		charge_changed.emit(charge)
		_refresh_bucket()
	if charge < overheat_threshold and _overheated:
		_overheated = false
		if _bucket != null and _bucket.has_method("set_ready_glow"):
			_bucket.set_ready_glow(false)
	if charge <= 0.0 and before > 0.0:
		if _stamina != null:
			_stamina.restore(reload_stamina_bonus)
		rinsed.emit()


func is_overheated() -> bool:
	return _overheated


func get_charge() -> float:
	return charge


func _resolved_good_clean_ratio() -> float:
	var ratio := skill_good_clean_ratio
	if _modifiers != null:
		ratio = _modifiers.get_mop_good_clean_ratio(ratio)
	return clampf(ratio, 0.0, 1.0)


func _refresh_bucket() -> void:
	if _bucket != null and _bucket.has_method("set_dirty"):
		_bucket.set_dirty(charge)
