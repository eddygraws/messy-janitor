class_name DrainZone
extends Node2D

@export var hitbox_size: Vector2 = Vector2(150, 150)


func _ready() -> void:
	add_to_group("Drain")


func get_hitbox() -> Rect2:
	return Rect2(global_position - hitbox_size * 0.5, hitbox_size)
