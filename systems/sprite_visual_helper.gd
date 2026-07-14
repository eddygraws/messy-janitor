class_name SpriteVisualHelper
extends RefCounted

const GRIME_META := &"grime_target"


static func make_sprite(
	texture: Texture2D,
	tint: Color = Color.WHITE,
	scale_factor: float = 1.0,
	apply_grime: bool = true,
) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = texture
	spr.centered = true
	spr.modulate = tint
	spr.scale = Vector2.ONE * scale_factor
	spr.material = null
	if apply_grime:
		spr.set_meta(GRIME_META, true)
	return spr


static func add_dirt_sprite(parent: Node2D, dirt_type: String, tint: Color = Color.WHITE) -> Sprite2D:
	var spr := make_sprite(
		GameAssets.get_dirt_texture(dirt_type),
		tint,
		GameAssets.get_dirt_scale(dirt_type),
		true,
	)
	parent.add_child(spr)
	return spr


static func add_zone_sprite(parent: Node2D, group: StringName, tint: Color = Color.WHITE) -> Sprite2D:
	var spr := make_sprite(GameAssets.get_zone_texture(group), tint, 1.0, false)
	parent.add_child(spr)
	return spr
