class_name FloatingPop3D
extends Label3D

## Dünya uzayında kısa +N / COMBO pop — yukarı kayıp solar.


static func spawn(
	parent: Node,
	world_pos: Vector3,
	text: String,
	color: Color = Color(1.0, 0.92, 0.45),
	font_px: int = 64,
) -> void:
	if parent == null or text.is_empty():
		return
	var pop := FloatingPop3D.new()
	pop.text = text
	pop.font_size = font_px
	pop.modulate = color
	pop.outline_size = 10
	pop.outline_modulate = Color(0, 0, 0, 0.85)
	pop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pop.no_depth_test = true
	pop.pixel_size = 0.012
	parent.add_child(pop)
	pop.global_position = world_pos + Vector3(0.0, 1.15, 0.0)
	pop._play()


func _play() -> void:
	var start := global_position
	var end := start + Vector3(0.0, 1.1, 0.0)
	scale = Vector3(0.55, 0.55, 0.55)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position", end, 0.55)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3.ONE, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.55)\
		.set_delay(0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
