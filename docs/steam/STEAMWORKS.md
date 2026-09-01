# Steamworks (P3) — App ID, overlay, cloud, başarılar

Kod köprüsü: autoload `SteamService` (`systems/steam_service.gd`).
GDExtension veya App ID yoksa oyun Steam'siz çalışır.

## App ID

Steam partner kaydı + uygulama oluşturunca sayı gelir.

1. `systems/product_identity.gd` içinde `STEAM_APP_ID` alanını doldur (0 = kapalı).
2. Geçici test: ortam değişkeni `MESSY_STEAM_APP_ID`.
3. Editörden Steam client dışında deneme: proje köküne `steam_appid.txt` (sadece sayı). **Export'a girmez; Valve ship etmemeni ister.**

Spacewar (480) yalnızca SDK örneği içindir — bu ürüne koyma.

## GodotSteam GDExtension

Godot 4.6.2 ile eşleşen prebuilt: GodotSteam **4.18.1** (Steamworks 1.64).
Kaynak: [GodotSteam GDExtension how-to](https://godotsteam.com/howto/gdextension/) / Codeberg `godotsteam/godotsteam`.

Hedef klasör:

```
addons/godotsteam/
  godotsteam.gdextension
  win64/
    libgodotsteam.windows.template_debug.x86_64.dll
    libgodotsteam.windows.template_release.x86_64.dll
    steam_api64.dll
```

Eklenti Project Settings'te "enable" istemez. `Steam` singleton görünür.
Export: **normal Godot şablonları** (GodotSteam editor template değil). `addons/godotsteam` exclude listesinde **yok**.

Overlay: Vulkan editor'da çoğu zaman çalışmaz; Steam'den çalışan export'ta Shift-Tab.

## Cloud

`SteamService` şu `user://` dosyalarını Remote Storage'a yazar / daha yeniyse çeker:

- `messy3d_progress_v2.cfg`
- `messy3d_settings.cfg`
- `messy3d_scores.cfg`
- `messy3d_curses.cfg`

Steamworks Auto-Cloud yedek: Windows kökü Godot userdata —

`%APPDATA%\Godot\app_userdata\Messy Janitor\`

Partner panelinde bu klasör + `*.cfg` eşlemesi P4 gizlilik metninden önce açılmalı.

## Achievements v1 (API adı = paneldeki ID)

| ID | Ne zaman |
|---|---|
| `TUTORIAL_DONE` | Tutorial kilitleri aşıldı (`highest_unlocked > 2`) |
| `CHAPTERS_3` | 3. bölüm (world slot ≥ 3) bitmiş |
| `FIRST_GOLD` | Herhangi bir seviyede altın rozet |
| `DAILY_CLEAR` | Günlük meydan okuma kaydı |

Panelde yayınlanmadan `setAchievement` sessizce no-op / false döner.

## Gizlilik (P4 store)

Cloud açıkken Steam sayfasında kayıt senkronu belirtilir. Kişisel veri yok; sadece ilerleme / ayar cfg.
