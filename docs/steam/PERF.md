# Performans bütçesi (P3)

Hedef: **1080p, `pixel_size` 3, 60 fps**, orta masaüstü (entegré üstü / giriş-orta GPU).
Kod: `systems/perf_budget_3d.gd`. Asla `scaling_3d_scale < 1` (bilinear 3D upsample).

## Sabitler

| Kalem | Değer |
|---|---|
| Viewport | 1920×1080 |
| Pixelize | 3 (≈ 640×360 3D, HUD keskin) |
| FPS tavan | 60 (`Engine.max_fps`; VSync açıksa zaten kilit) |
| MSAA / TAA / SSAA | kapalı |
| Glow / SSAO / SSR / SDFGI / volumetric fog | kapalı |
| Directional shadow | 1024, 2 cascade, hard filter, max 48 m |
| Plane tree (açık hava) | MultiMesh, en fazla 40 örnek |
| Kenar kaya (açık hava) | MultiMesh, 24 |
| Dünya haritası zemin | PlaneMesh 24×16 (eğri vertex için subdiv şart) |
| Dünya haritası uçurum | 16×4 |

## Orman profili (slime / `outdoor`)

Eski yol: her ağaç ayrı `MeshInstance3D` (kenar sırası + %35 ekstra + 8 halka ≈ 60+ alpha-cutout draw).
Yeni yol: tek `MultiMeshInstance3D`. Shader `MODEL_MATRIX` ile instance billboard.

Lisanssız DemoForest çim MultiMesh’i kapalı (`ForestVegetation.USE_UNLICENSED_TUTORIAL_MESHES`).

## Soak / ölçüm (elle)

Editor debug overlay yok (ship yasağı). Steam export veya `--path` ile:

1. Ayarlar: 1080p, pixel 3, VSync açık.
2. Dünya haritası 30 sn dolaş.
3. Balçık (açık hava) seviyesi: intro → filler → fail/retry.
4. Alt-tab + çözünürlük değişimi bir sonraki P3 maddesinde (çökme).

Godot Monitor: FPS, Draw Calls, 3D Primitives. Açık havada draw call’un ağaç başına artmaması gerekir.

## Bilinçli maliyet

Pixelize compositor bir full-screen pass. Kenar çizgisi aynı pass içinde.
Karakter / prop gölgeleri açık — pixel look için silüet; atlas 1024.
