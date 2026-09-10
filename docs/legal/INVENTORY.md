# Lisans envanteri — 0.1.0 ship kararı

Durum: **SHIP-READY** (Windows Coming Soon / ilk depot).
Lisanssız dosyalar build'e **girmez** ve runtime'da **çalınmaz / spawn edilmez**.

| Varlık | Yol | Kaynak | Lisans | Ship |
|---|---|---|---|---|
| Motor | Godot 4.6 | godotengine.org | MIT — credits'te tam notice | OK |
| Varsayılan UI font | Godot built-in | Godot | SIL OFL (ThemeDB) | OK |
| Janitor iskelet + anim | `assets/characters/janitor/*.fbx` | Mixamo | Mixamo ToS: oyunda serbest, ham FBX satışı yok | OK — credits |
| Lantern Drop | `audio/music/Lantern Drop.wav` | doğrulanmadı | ? | **YOK** — skip list + export exclude |
| Drift Circuit 97 | `audio/music/Drift Circuit 97.wav` | doğrulanmadı | ? | **YOK** — skip list + export exclude |
| Orijinal müzik | `mop_waltz`, `crate_trot`, `suds_night`, `last_call`, `menu_loop`, `menu_stinger` | `tools/bake_music.py` | orijinal | OK |
| Orijinal SFX | `audio/sfx/*.wav` | `tools/bake_sfx.py` | orijinal | OK |
| HUD atlas | `assets/ui/hud_icons.png` | `tools/bake_hud_icons.py` | orijinal | OK |
| GodotSteam | `addons/godotsteam/` | henüz binary yok | — | App ID 0: Steam kapalı; DLL+ID sonra |
| Oyun ikonu | `assets/branding/icon.ico` | `tools/bake_icon.py` | orijinal | OK |
| Kök `icon.svg` | Godot robot | Godot | — | **YOK** — export exclude |
| DemoForest mesh/doku | `assets/vegetation/*` | tutorial kopya | lisans yok | **YOK** — spawn kapalı + export exclude |
| Rüzgâr gürültüsü | `textures/generated/wind_noise.tres` | proje FastNoiseLite | orijinal | OK |
| Prop / harita PNG-GLB | `assets/props/`, `assets/map/` | stüdyo / kullanıcı | stüdyo varlığı | OK (placeholder PNG yoksa primitive) |
| Plane tree | `assets/props/foliage/tree_plane_a_treetrunl.png` | stüdyo | stüdyo | OK |
| Toon karo | `textures/generated/` | `toon_tile_generator` çıktısı | orijinal | OK — addon exclude |
| Editor eklentileri | `addons/ai_assistant_hub`, `toon_tile_generator`, `tools/` | — | — | **YOK** — exclude |
| 2D prototip | `levels/`, `node_2d.tscn`, `MainScene.gd` | arşiv | — | **YOK** — exclude |

## Mixamo

Animasyonlar oyuna gömülü. Credits: Mixamo. Ham FBX marketplace'te satılmaz.

## Steam store legal (panel)

- Credits: Godot MIT notice + Mixamo + Messy Janitor original audio/art.
- Gizlilik: `docs/steam/PRIVACY.md` — kişisel veri yok; App ID sonrası cloud sadece cfg.
- Yaş: Steam anketi (temizlik komedisi, şiddet yok).

## Bilinçli dışarıda

Unlicensed müzik ve DemoForest klasörü diskte kalabilir (geliştirme). Export filtresi ve skip list ship'i korur. Lisans çıkarsa envantere "OK" yazılıp exclude kalkar.
