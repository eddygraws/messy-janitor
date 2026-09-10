# Steam 0.1.0 — bugün yükleme

Binary: Windows 64-bit, tek exe (PCK gömülü), konsol kapalı, native ICO.
Lisans: `docs/legal/INVENTORY.md`. Gizlilik metni: `docs/steam/PRIVACY.md`.

## 1. Export (bu makine)

Godot 4.6.2 export template yüklü olmalı (`Editor → Manage Export Templates`).

```
Godot_v4.6.2-stable_win64.exe --headless --path "C:\Users\eddyn\Documents\messy-janitor" --export-release "Windows Desktop" "C:\Users\eddyn\Documents\buildler\MessyJanitor.exe"
```

Çıktı: `C:\Users\eddyn\Documents\buildler\MessyJanitor.exe`

Kontrol: exe açılınca konsol penceresi yok, ikon branding, ana menü TR/EN.

**Depoya koyma:** `steam_appid.txt`, `icon.svg`, `addons/ai_assistant_hub`, `assets/vegetation`, `Lantern Drop`, `Drift Circuit 97`.

## 2. Steamworks (partner)

1. Steamworks'te uygulama oluştur → **App ID** gelir.
2. `systems/product_identity.gd` → `STEAM_APP_ID` doldur (0 bırakırsan overlay/cloud/achievement kapalı; oyun yine çalışır).
3. GodotSteam 4.18.1 DLL'leri `addons/godotsteam/` — `docs/steam/STEAMWORKS.md`.
4. App ID geldikten sonra **yeniden export**. Spacewar 480 kullanma.

## 3. SteamPipe depot

Tek klasör: `MessyJanitor.exe` (gömülü pck).
Windows depot, 64-bit. Launch option: `MessyJanitor.exe`.

Coming Soon için store görselleri P4 (capsule 616×353 vb.) — binary olmadan da sayfa taslağı açılır.

## 4. Panel legal

- Age rating anketi (Casual / komedi temizlik).
- Privacy: `PRIVACY.md` özetini store gizlilik alanına yapıştır.
- Credits: Godot MIT + Mixamo + original audio/art.

## 5. Bu build'de kapalı (bilinçli)

- Steam overlay / cloud / achievements (App ID 0).
- Lisanssız müzik ve DemoForest vegetation.
- 2D prototip ve editor eklentileri.
