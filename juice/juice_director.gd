class_name JuiceDirector
extends Node

@export var screen_shake_path: NodePath = ^"../ScreenShake"
@export var particle_burst_path: NodePath = ^"../ParticleBurst"
@export var stress_path: NodePath = ^"../StressComponent"
@export var router_path: NodePath = ^"../CursorClickerRouter"
@export var portrait_path: NodePath = ^"../UI/KarakterPortresi"
@export var break_stress: float = 18.0

var _shake: ScreenShake
var _particles: ParticleBurst
var _stress: StressComponent
var _router: CursorClickRouter
var _portrait: Sprite2D
var _scrub_cooldown: float = 0.0


func _ready() -> void:
	_shake = get_node(screen_shake_path) as ScreenShake
	_particles = get_node(particle_burst_path) as ParticleBurst
	_stress = get_node(stress_path) as StressComponent
	_router = get_node(router_path) as CursorClickRouter
	_portrait = get_node(portrait_path) as Sprite2D

	_stress.mistake_registered.connect(_on_mistake)
	_stress.stress_critical.connect(_on_stress_critical)
	_stress.stress_exploded.connect(_on_stress_exploded)
	_router.scrub_tick.connect(_on_scrub_tick)
	_router.reload_tick.connect(_on_reload_tick)
	_router.junk_food_tempted.connect(_on_junk_food)
	_router.object_cleaned.connect(_on_object_cleaned)
	_router.object_disposed.connect(_on_object_disposed)
	_router.wrong_tool.connect(_on_wrong_tool)

	call_deferred("_connect_cleanables")


func _process(delta: float) -> void:
	_scrub_cooldown = maxf(0.0, _scrub_cooldown - delta)


func _connect_cleanables() -> void:
	for node in get_tree().get_nodes_in_group("Cleanable"):
		if node is CleanableObject and node.is_fragile:
			if not node.object_broken.is_connected(_on_object_broken):
				node.object_broken.connect(_on_object_broken)


func _on_mistake() -> void:
	var pos := _router.get_last_click_pos()
	_shake.shake(0.25)
	_particles.spawn(ParticleBurst.BurstType.MISTAKE, pos)
	_flash_portrait(Color(1.2, 0.6, 0.6))


func _on_stress_critical() -> void:
	_shake.shake(0.55)
	_flash_portrait(Color(1.4, 0.45, 0.45))


func _on_stress_exploded() -> void:
	# Portre CanvasLayer'da (ekran uzayı), partiküller WorldLayer'da (dünya uzayı).
	# Doğru konumda patlaması için ekran koordinatını dünyaya çeviriyoruz.
	var world_pos := Vector2.ZERO
	if _portrait:
		var canvas_xform := get_viewport().get_canvas_transform()
		world_pos = canvas_xform.affine_inverse() * _portrait.global_position
	_shake.shake(1.0)
	_particles.spawn(ParticleBurst.BurstType.EXPLOSION, world_pos)


func _on_object_cleaned(world_pos: Vector2) -> void:
	_shake.shake(0.12)
	_particles.spawn(ParticleBurst.BurstType.CLEAN, world_pos)


func _on_object_broken(world_pos: Vector2) -> void:
	# Kırılgan eşya sert paspaslanınca kırıldı: ceza olarak stres + sert sarsıntı.
	_stress.add_stress(break_stress)
	_shake.shake(0.6)
	_particles.spawn(ParticleBurst.BurstType.MISTAKE, world_pos)
	_flash_portrait(Color(1.3, 0.5, 0.5))


func _on_object_disposed(world_pos: Vector2) -> void:
	# Çöp kovasına / gidere teslim: tatmin edici küçük patlama.
	_shake.shake(0.16)
	_particles.spawn(ParticleBurst.BurstType.CLEAN, world_pos)


func _on_wrong_tool(world_pos: Vector2) -> void:
	# Yanlış alet: küçük uyarı sarsıntısı + portre flaşı (ceza hissi).
	_shake.shake(0.2)
	_particles.spawn(ParticleBurst.BurstType.MISTAKE, world_pos)
	_flash_portrait(Color(1.1, 0.8, 0.5))


func _on_scrub_tick(world_pos: Vector2) -> void:
	if _scrub_cooldown > 0.0:
		return
	_scrub_cooldown = 0.06
	_particles.spawn(ParticleBurst.BurstType.SCRUB, world_pos)


func _on_reload_tick(world_pos: Vector2) -> void:
	if _scrub_cooldown > 0.0:
		return
	_scrub_cooldown = 0.05
	_particles.spawn(ParticleBurst.BurstType.SCRUB, world_pos)


func _on_junk_food(world_pos: Vector2) -> void:
	_shake.shake(0.45)
	_particles.spawn(ParticleBurst.BurstType.JUNK, world_pos)
	_flash_portrait(Color(1.5, 0.7, 0.2))


func _flash_portrait(flash_color: Color) -> void:
	if _portrait == null:
		return
	var tween := create_tween()
	tween.tween_property(_portrait, "modulate", flash_color, 0.06)
	tween.tween_property(_portrait, "modulate", Color.WHITE, 0.14)
