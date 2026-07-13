class_name DrainZone
extends Node2D

@export var hitbox_size: Vector2 = Vector2(150, 150)
@export var zone_group: StringName = &"Drain"   # "Drain" (gider) veya "TrashBin" (çöp kovası)


func _ready() -> void:
	add_to_group(zone_group)


func get_hitbox() -> Rect2:
	return Rect2(global_position - hitbox_size * 0.5, hitbox_size)
