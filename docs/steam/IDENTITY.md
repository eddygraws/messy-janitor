## Messy Janitor — ürün kimliği (P0 kilit)

Bu sayfa Steam App Name, kısa açıklama ve kapsamı dondurur.
Değişirse tarih kayar; P1'e geçmeden imzalı sayılır.

| Alan | Kilit |
|---|---|
| Steam App Name | Messy Janitor |
| İç ad / exe | messy-janitor |
| Eski 2D adı | The Gargoyle's Mess — arşiv, ship edilmez |
| Day-1 platform | Windows 10/11, 64-bit |
| Sonra | Steam Deck + macOS = launch+90 |
| Ana sahne | `res://scenes3d/main_3d.tscn` |
| Kapsam | 3D kampanya: 2 tutorial + 10 bölüm × 5 kademe |
| Yan içerik | Daily challenge, curse — kampanyaya ek |
| Hedef süre | 4–8 saat ana hat |
| Diller (day-1) | Menü TR + EN. Oyun içi HUD/görevler P5 yaması |
| Yayıncı / şirket | Messy Janitor (Steam partner kaydında yasal unvan) |
| Steam App ID | 0 — partner kaydı sonrası `ProductIdentity.STEAM_APP_ID`; bkz. `docs/steam/STEAMWORKS.md` |

### Kısa açıklama (Steam capsule altı, ~120 karakter)

**TR:** Kaotik 3D temizlik. Paspasla, süpür, koli taşı — süre bitmeden odayı kurtar.

**EN:** Chaotic 3D cleaning. Mop, sweep, haul crates — clear the room before time runs out.

### Uzun açıklama taslağı (store P4'te cilalanır)

**TR:** Messy Janitor, tempo ve fizik komedisi üzerine kurulu bir 3D temizlik oyunudur. Aletleri sırayla öğrenir, odaları kademe kademe temizler, süreyi ve stresi yönetirsin. Pixelize görüntü, Overcooked tadında bakış.

**EN:** Messy Janitor is a 3D cleaning game built on tempo and physical comedy. Learn tools in order, clear rooms tier by tier, and manage the clock. Pixelized look, Overcooked-style camera.

### Yasaklı (build'e girmez)

- `addons/ai_assistant_hub`
- `addons/toon_tile_generator`
- `tools/`
- 2D hat: `node_2d.tscn`, `MainScene.gd`, `levels/`
- Editor debug overlay, F8 2D prototip
- Godot varsayılan robot ikonu (yerine `assets/branding/icon.svg` + `icon.ico`)
- `assets/vegetation/` (DemoForest — lisans yok)
- `audio/music/Lantern Drop.wav`, `audio/music/Drift Circuit 97.wav`
- `steam_appid.txt`, `docs/`

### Kapı

P0 kapanır: bu dosya + `docs/legal/INVENTORY.md` + release export metadata + pause ayar + credits iskeleti.
