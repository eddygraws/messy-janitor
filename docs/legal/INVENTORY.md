# Lisans envanteri — ship kararı

Durum: **OPEN** (eski iki parça lisanssız; ship mix orijinal bed + menü).
P0 çıktısı: her satır kaynak + lisans + ship OK/BLOCKER.

| Varlık | Yol | Kaynak | Lisans | Ship |
|---|---|---|---|---|
| Motor | Godot 4.6 | godotengine.org | MIT | OK — credits |
| Varsayılan UI font | Godot built-in | Godot | SIL OFL (ThemeDB) | OK |
| Janitor iskelet + anim | `assets/characters/janitor/*.fbx` | Mixamo (Adobe) | Mixamo ToS: oyunda kullanım serbest, ham FBX satışı yok | OK — credits: Mixamo |
| Lantern Drop | `audio/music/Lantern Drop.wav` | **Doğrulanmadı** | ? | **SHIP ETME** — çalınmıyor, export exclude |
| Drift Circuit 97 | `audio/music/Drift Circuit 97.wav` | **Doğrulanmadı** | ? | **SHIP ETME** — çalınmıyor, export exclude |
| Orijinal müzik loop | `audio/music/mop_waltz.wav` vb. | `tools/bake_music.py` | orijinal | OK geçici — üzerine lisanslı loop konabilir |
| Menü | `menu_loop.wav`, `menu_stinger.wav` | `tools/bake_music.py` | orijinal | OK geçici |
| Orijinal SFX bankası | `audio/sfx/*.wav` | `tools/bake_sfx.py` | orijinal | OK geçici — üzerine kayıtlı/lisanslı WAV konabilir |
| HUD ikon atlası | `assets/ui/hud_icons.png` | `tools/bake_hud_icons.py` | orijinal | OK geçici — üzerine el çizimi konabilir |
| GodotSteam | `addons/godotsteam/` (henüz binary yok) | GodotSteam 4.18.1 / Steamworks | BSD-style GodotSteam + Valve redistributable | App ID 0 iken kapalı; DLL düşünce ship |
| Oyun ikonu | `assets/branding/icon.svg`, `icon.ico` | `tools/bake_icon.py` | orijinal | OK taslak — Windows native ICO |
| Godot robot `icon.svg` (kök) | `res://icon.svg` | Godot | Godot | **Ship etme** — branding ikonu kullan |
| DemoForest/tutorial kopya shader-doku | `assets/vegetation/` | 3D Pixel Art Vegetation tutorial | **Lisans yok** | **SHIP ETME** — P2'de orijinal/lisanslı varlıkla değişecek |
| Prop PNG (kutu, kaya, yaprak) | `assets/props/`, `assets/map/` | karışık / PLACE_ASSETS | **Doğrula** | OPEN — eksikler P2 taramada |
| Plane tree PNG | `assets/props/foliage/tree_plane_a_treetrunl.png` | proje | kullanıcı varlığı — harita/kenar | OK geçici |
| toon tile / duvar | `materials/`, `addons/toon_tile_generator` | proje aracı | orijinal çıktı OK; addon ship değil | addon exclude |

## P2 placeholder tarama (1 Eyl 2026)

Oyunda yeşil küre ağaç / silindir gövde **kullanılmıyor**. Harita ve açık hava kenarı plane tree PNG; kayalar `rock_a` / `rock_b` GLB.

Hâlâ PLACE_ASSETS (sanat bekler, primitive yok):

| Beklenen | Durum | Etki |
|---|---|---|
| `assets/map/forest/map_bg_forest.png` | yok | Ufuk prosedürel gradient (geçici) |
| `assets/map/forest/map_horizon_forest.png` | yok | aynı |
| `assets/map/forest/map_ground_forest.png` | yok | düz renk + curve shader |
| `tree_plane_b/c.png`, `bush_plane_*.png` | yok | tek ağaç varyantı |
| `assets/tools/` ikon/cursor | HUD atlas `assets/ui/hud_icons.png` | bake_hud_icons.py; el çizimi üstüne konabilir |

## Mixamo notu

Mixamo animasyonları oyuna gömülebilir. Credits: "Animations from Mixamo".
Ham FBX marketplace'te satılmaz.

## Müzik aksiyonu

Ship mix: orijinal 4 loop + menü (`tools/bake_music.py`).
`Lantern Drop` / `Drift Circuit 97` çalınmıyor ve export'ta yok. Lisans çıkarsa havuza alınır.

## Font

Özel font yok. Godot varsayılanı. İleride özel font eklenirse satır buraya.

## SFX envanteri (P2 bankası)

| Event | Kind | Dosya | Not |
|---|---|---|---|
| Vuruş / ovala | HIT | `hit.wav` | ıslak paspas |
| Yerden al | PICKUP | `pickup.wav` | koli lift |
| Bırak | DROP | `drop.wav` | karton |
| Fırlat | THROW | `throw.wav` | whoosh |
| Dash | DASH | `dash.wav` | kumaş |
| Kova durula | RINSE | `rinse.wav` | su |
| Çöpe at | DISPOSE | `dispose.wav` | metal |
| Alet değiştir | SWITCH | `switch.wav` | UI tık |
| Dans | DANCE | `dance.wav` | sting |
| Çarpışma | BUMP | `bump.wav` | gövde |
| Görev | TASK | `task.wav` | UI |
| Görev OK | TASK_OK | `task_ok.wav` | olumlu |
| Görev fail | TASK_FAIL | `task_fail.wav` | olumsuz |
| Tempo faz | PHASE | `phase.wav` | riser |
| DUR | STOP | `stop.wav` | uyarı |

Aynı isimle WAV/OGG bırakınca banka onu okur. Müzik `res://audio/music/` — SFX bus ayrı.
