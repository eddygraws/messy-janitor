extends RefCounted

## P3 — orta PC bütçesi: 1080p / pixel 3 / 60fps.
## Hotspot: açık hava (slime) plane-tree sırası + dünya haritası eğri zemin.
## Ölçüm: docs/steam/PERF.md

const TARGET_FPS := 60
const PIXEL_SIZE := 3
const SHADOW_SIZE := 1024
const SHADOW_MAX_DISTANCE := 48.0
const MAP_GROUND_SUBDIV_X := 24
const MAP_GROUND_SUBDIV_Z := 16
const MAP_CLIFF_SUBDIV_X := 16
const MAP_CLIFF_SUBDIV_Z := 4
const MAX_PLANE_TREES := 40
const MAX_RING_TREES := 6
const MAX_OUTSKIRT_ROCKS := 24
const OUTDOOR_SCATTER_SPOTS := 48
const PLANE_SPACING_MUL := 1.35
const PLANE_EXTRA_CHANCE := 0.12


static func apply_engine() -> void:
	Engine.max_fps = TARGET_FPS
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var vp := tree.root
	if vp == null:
		return
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.msaa_2d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	vp.scaling_3d_scale = 1.0
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)


static func apply_sun(sun: DirectionalLight3D) -> void:
	if sun == null:
		return
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = SHADOW_MAX_DISTANCE
	sun.shadow_blur = 0.5
	sun.shadow_bias = 0.04


static func apply_environment(env: Environment) -> void:
	if env == null:
		return
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.ssr_enabled = false
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false
	env.adjustment_enabled = false
