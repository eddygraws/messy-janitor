class_name RiskModeComponent
extends Node

# Riskli Temizlik modu (ORTAK risk/ödül katmanı).
# Oyuncu "R" ile açar: puan çarpanı yükselir AMA hata payı daralır
# (hitbox küçülür), hatalar daha çok stres verir, temizlik hızlanır.
# Oyuncu kendi zorluk/ödül seviyesini seçer; hem Adventure hem Endless besler.

signal risk_changed(active: bool)

@export var stress_path: NodePath = ^"../StressComponent"
@export var toggle_action_keycode: int = KEY_R

@export var score_multiplier: float = 1.6      # oda puanına uygulanır
@export var stress_multiplier: float = 1.6     # hataların stres cezası
@export var clean_speed_multiplier: float = 1.35  # ovala/mash hızlanır
@export var hitbox_scale: float = 0.82         # hata payı daralır

var _stress: StressComponent
var _active: bool = false


func _ready() -> void:
	_stress = get_node_or_null(stress_path) as StressComponent


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == toggle_action_keycode:
			set_active(not _active)


func set_active(value: bool) -> void:
	if value == _active:
		return
	_active = value
	if _stress != null:
		_stress.mistake_multiplier = stress_multiplier if _active else 1.0
	risk_changed.emit(_active)


func is_active() -> bool:
	return _active


func get_score_multiplier() -> float:
	return score_multiplier if _active else 1.0


func get_clean_speed_multiplier() -> float:
	return clean_speed_multiplier if _active else 1.0


func get_hitbox_scale() -> float:
	return hitbox_scale if _active else 1.0
