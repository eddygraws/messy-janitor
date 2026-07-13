# The Gargoyle's Mess — Proje Devir Raporu (Handoff)

> Bu belge; ekip arkadaşlarına ve devralacak AI agent'lara projenin **mevcut durumunu**, **mimarisini**, **mekaniklerini** ve **sıradaki adımları** aktarmak için yazılmıştır.
> Son güncelleme: Level/Ekipman sistemi entegrasyonu tamamlandıktan sonra.

---

## 1. Proje Özeti

- **Ad:** The Gargoyle's Mess
- **Tür:** 2D, retro-gotik, low-poly kaotik temizlik/refleks oyunu
- **Motor:** Godot 4 (GDScript)
- **Konsept:** Fantastik mekanları temizleyen bir temizlikçi. Zaafı "junk food" (abur cubur). Hata yaptıkça stresi artar; stres %100'e ulaşınca karakter şişip patlar (Game Over).
- **Tasarım önceliği:** Game juice — ekran sarsıntısı (screen shake), partiküller, UI Tween animasyonları.

### Temel mimari ilkeler
- **Component tabanlı:** Her davranış ayrı bir Node component'inde; iletişim **Signals** ile.
- **Fizik motoru YOK:** Çarpışmalar matematiksel **`Rect2` hitbox**'larla hesaplanıyor (`get_hitbox()`).
- **Duck-typing + grup sorguları:** Godot 4'ün `class_name` çözüm sorunlarını aşmak için bazı yerlerde tip yerine `node.call(...)` ve `get_nodes_in_group(...)` kullanılıyor (özellikle sürüklenebilir objelerde).

---

## 2. Nasıl Çalıştırılır / Test Edilir

1. Godot 4 ile projeyi aç. Ana sahne: **`node_2d.tscn`** (kök node adı `Main`).
2. Yeni script/`class_name`'ler ve `.tscn` kaynakları için projeyi **bir kez yeniden yükle** (Project > Reload Current Project). Bu, yeni eklenen `equipment_component.gd` ve `equipment_bar.gd` için UID atanmasını sağlar.
3. Oyunu çalıştır → Başlangıç ekranında "TEMİZLİĞE BAŞLA".
4. **Kontroller:**
   - **Sol tık:** Aktif ekipmanla etkileşim (ovala / mash / sürükle / sprey / cımbız).
   - **`1`–`5` tuşları:** Ekipman değiştir (sadece kilidi açık olanlar).
   - Kova ikonuna basılı tutmak: paspası durular (reload/skill-check).

---

## 3. Oynanış Mekanikleri (Mevcut Durum)

### 3.1 Çekirdek sistemler
- **StaminaComponent:** Enerji. Düşünce imleç kontrolden çıkar; sürüklerken obje elden kayabilir.
- **StressComponent:** Hata → stres. Eşikler: **panik %70**, kritik %85, patlama %100.
  - **Panik modu:** İmleç titremesi (Perlin noise) artar + hitbox toleransı daralır (yanlış tıklama artar).
  - **Gecikmeli stres ("sugar crash"):** Junk food anında stamina verir, birkaç saniye sonra ekstra stres ekler.
- **TiredCursor:** Donanım imlecinden bağımsız, staminaya göre ağırlaşan, Perlin noise ile titreyen custom imleç. **Aktif ekipmanın rengiyle boyanır** (görsel ipucu).
- **ComboComponent:** Ardışık doğru temizlik → combo; belirli aralıklarla stamina bonusu. Hata/junk → combo sıfırlanır, combo yüksekse ekstra stres.
- **MopComponent:** Paspas "kir/ısı" birikimi; kovada durulama gerekir (overheat mekaniği).
- **RoomScoreTracker + RoomRating:** Oda başına puan (combo, hata, junk, panik, süre, flawless bonus) → SWEET/AMAZING vb. derecelendirme.
- **JuiceDirector:** Tüm juice'u tetikleyen merkez (shake, partikül, portre flaşı).
- **MoldSpawner / JunkFoodSpawner:** Yayılan küf ve rastgele junk food üretimi.

### 3.2 Kir/obje varyantları (`CleanableObject` ve alt sınıfı)
- **Leke:** Basılı tut + ovala (paspas).
- **Çöp/instant:** Tek tıkla temizlenir.
- **Kırılgan (Vazo):** Çok hızlı/sert ovalanırsa **kırılır** → ekstra stres cezası (`object_broken`).
- **Yayılan Küf:** Süre içinde temizlenmezse yakın boş alana yeni küf spawnlar.
- **Gizli Kir:** Görünmez; imleç `reveal_radius` içine girince Tween ile belirir.
- **Kayan Leke / Slime (sürüklenebilir):** Tıklamayla değil, **sürükleyip Gider (`Drain`)** bölgesine itilerek temizlenir.

### 3.3 Ekipman sistemi (YENİ)
`EquipmentComponent.Type` sıralaması `CleanableObject.EQ_*` sabitleriyle **birebir aynı**:

| int | Ekipman | Input davranışı | Hedef kir |
|----|---------|-----------------|-----------|
| 0 | **Paspas** | basılı tut + ovala | Leke |
| 1 | **Süpürge** | yakala + **Çöp Kovası**'na sürükle | Kırıntı |
| 2 | **Fırça** | hızlı tekrarlı tıklama (mash) | İnatçı/kuru kir |
| 3 | **Sprey+Bez** | iki aşamalı: önce tıkla-ıslat → sonra ovala | Cam/ayna lekesi |
| 4 | **Cımbız** | tek hassas tıklama | Cam kırığı / iğne |

- Her obje `required_equipment` taşır. **Yanlış alet:** işe yaramaz + hafif stres cezası; cımbız gereken tehlikeli objeye yanlış aletle dokunmak **sert ceza** (`wrong_tool` sinyali).
- **HUD:** Ekran altında ekipman şeridi (`EquipmentBar`) — aktif olan renkli/büyük, kilitliler soluk.

### 3.4 Oda geçişi
- **RoomManager** odaları dikey eksende Tween ile kaydırır; derecelendirme ekranı → havalı geçiş animasyonu → sonraki oda.

---

## 4. Level İlerlemesi (10 Oda)

Ekipmanlar level ilerledikçe açılır (`RoomManager._apply_equipment_unlock`):

| Level (Oda) | Açık ekipman | İçerik odağı |
|---|---|---|
| 1–3 | Paspas | Öğretici: leke, çöp, kırılgan vazo, küf, gizli kir |
| 4–6 | + Süpürge | Kırıntı → çöp kovası (drag-drop tanıtımı) |
| 7–9 | + Fırça | İnatçı kir (mash) + küf/gizli kir karışımı |
| 10 | + Sprey+Bez, Cımbız | Cam lekesi (2 aşama) + cam kırığı (hassasiyet/risk) |

> Not: Kilit açık olmayan bir ekipman gerektiren obje ilgili level'a konmadı (bulmaca tutarlılığı).

---

## 5. Dosya Haritası

### Component'ler (`components/`)
- `cleanable_object.gd` — **Çekirdek temizlenebilir sınıf** (`class_name CleanableObject`). Hitbox, ovala, mash, spray, pluck, kırılgan/küf/gizli varyantları, `EQ_*` sabitleri.
- `draggable_cleanable.gd` — Sürüklenebilir alt sınıf (`extends "res://components/cleanable_object.gd"`, **path-based extends**, `class_name` YOK). `target_group` ile Drain/TrashBin'e teslim.
- `drain_zone.gd` — Hedef bölge (`class_name DrainZone`). `zone_group` ile "Drain" (gider) veya "TrashBin" (çöp kovası).
- `stamina_component.gd`, `stress_component.gd`, `mop_component.gd`, `mop_bucket.gd`, `junk_food_object.gd`

### Sistemler (`systems/`)
- `cursor_click_router.gd` — **Girdi yönlendiren beyin** (`class_name CursorClickRouter`). Ekipman-duyarlı press/process, sürükleme, mash/spray/pluck, yanlış-alet cezası.
- `equipment_component.gd` — **YENİ** (`class_name EquipmentComponent`). Ekipman enum'u, 1–5 tuş, kilit açılım.
- `combo_component.gd`, `mold_spawner.gd`, `junk_food_spawner.gd`, `room_rating.gd`

### UI (`ui/`)
- `equipment_bar.gd` — **YENİ** (`class_name EquipmentBar`). Dinamik ekipman HUD şeridi.
- `room_feedback_ui.gd`, `game_screens.gd`

### Juice (`juice/`)
- `juice_director.gd`, `screen_shake.gd`, `particle_burst.gd`

### Kök
- `MainScene.gd` — Ana kontrolcü; tüm sinyal bağlantıları, imleç renk ipucu, ekipman/combo/objective UI.
- `RoomManager.gd` — Oda/level yönetimi, ekipman kilidi, `rooms_per_level=10`.
- `tired_cursor.gd` — Custom imleç.
- `node_2d.tscn` — **Ana sahne** (10 oda + tüm component node'ları + UI).

---

## 6. Önemli Sinyaller (entegrasyon için)

**`CursorClickRouter`**
- `scrub_tick(pos)`, `reload_tick(pos)`, `junk_food_tempted(pos)`
- `object_cleaned(pos)` — her temizlik (combo + juice tetikler)
- `on_drag_start(pos)`, `on_drag_end(pos)`, `object_disposed(pos)` — sürükleme akışı
- `wrong_tool(pos)` — yanlış alet cezası

**`EquipmentComponent`**
- `equipment_changed(type: int)`, `unlocked_changed(count: int)`

**`StressComponent`**
- `stress_changed`, `mistake_registered`, `stress_critical`, `stress_exploded`, `panic_mode_entered`, `panic_mode_exited`

**`CleanableObject`**
- `cleaned`, `scrub_progress_changed(progress)`, `object_broken(pos)`, `spread_triggered(origin)`, `revealed`

**`RoomManager`**
- `room_cleared`, `room_transition_started/finished`, `level_completed`, `objective_changed(remaining, total)`

---

## 7. Yeni İçerik Nasıl Eklenir? (AI agent kılavuzu)

**Yeni bir kir/obje eklemek için** (sahnede, oda altına):
```
[node name="YeniKir" type="Node2D" parent="RoomManager/Oda_X" groups=["Room"...]]
position = Vector2(x, y)          # merkezi tut: x∈[500,1400], y∈[350,780]
script = ExtResource("7_cleanable")
hitbox_size = Vector2(w, h)
requires_scrub = true/false       # ovala mı, tıkla mı
required_equipment = 0..4         # 0=Paspas 1=Süpürge 2=Fırça 3=Sprey 4=Cımbız
# + bir "Visual" Polygon2D child ekle
```
- **Süpürülen çöp:** `script = 20_drag`, `groups=["Draggable"]`, `required_equipment = 1`, `target_group = &"TrashBin"` + odaya bir `TrashBin` (script `21_drain`, `zone_group=&"TrashBin"`).
- **Fırça objesi:** `required_equipment = 2`, `mash_per_hit` ile zorluk ayarla.
- **Sprey objesi:** `required_equipment = 3`, `requires_scrub = true`.
- **Cımbız objesi:** `required_equipment = 4`, küçük `hitbox_size` (hassasiyet).

**Yeni ekipman eklemek için:**
1. `equipment_component.gd` → `Type` enum'una ekle + `LABELS/ICONS/COLORS` dizilerine karşılık ekle.
2. `cleanable_object.gd` → `EQ_*` sabiti ekle (**aynı sıra!**) + gerekiyorsa yeni etkileşim metodu.
3. `cursor_click_router.gd` → `_handle_press` içindeki `match eq:` bloğuna davranışı ekle.
4. `RoomManager._apply_equipment_unlock` → hangi level'da açılacağını tanımla.

---

## 8. Bilinen Kısıtlar / Dikkat Edilecekler

- **Godot `class_name` çözüm hassasiyeti:** `DraggableCleanable` bilerek `class_name` taşımıyor ve path-based extend kullanıyor; router onunla **duck-typing** ile konuşuyor. Bu deseni bozmayın (döngüsel bağımlılık hatası geri gelir).
- **`EQ_*` ↔ `Type` sırası:** İki taraf da aynı int sırasında olmalı, yoksa yanlış alet eşleşir.
- **`unique_id` alanları:** `.tscn` içindeki node'larda mevcut desene uygun benzersiz id kullanın (çakışma olmasın).
- Yeni script `.tscn`'e `uid` olmadan eklendi; Godot ilk açılışta UID atar — bu yüzden **ilk reload** gerekli.

---

## 9. Sıradaki Adımlar (Backlog / TODO)

**İleri faz ekipmanlar (tasarımda "pasif/alan etkili" olarak planlandı):**
- [ ] **Elektrikli Süpürge:** basılı tut + imleci gezdir → yakındaki hafif objeleri (saç/toz) mıknatıs gibi çeker (alan etkili).
- [ ] **UV Lamba:** hover/tara → gizli kiri ortaya çıkarır (şu an gizli kir herhangi bir aletle, imleç yakınlığıyla beliriyor; UV'ye bağlanabilir).

**Cila / denge:**
- [ ] Ekipman değişimine ses efekti + daha belirgin imleç görseli (araç başına farklı uç).
- [ ] Sprey+Bez için "ıslaklık zamanla kurur" opsiyonu (ekstra zorluk).
- [ ] Level 10 sonrası endless/skor tablosu.
- [ ] Yanlış-alet cezası dengesini playtest ile ayarla (`wrong_tool_stress`, `dangerous_wrong_stress`).

**Tasarım kararı (kapsam dışı):**
- ❌ **Toz Bezi (tüylü)** mekaniği — kullanıcı isteği üzerine **dahil edilmedi**.

---

## 10. Hızlı Durum Özeti (TL;DR)
- 5 ekipmanlı, input-çeşitli tam bir temizlik sistemi + 10 level **çalışır durumda**.
- Ekipmanlar kademeli açılıyor, HUD ve imleç renk ipucu mevcut.
- Kod lint-temiz. İlk çalıştırmada Godot reload gerekli.
- Devralacak agent: yeni içerik için **Bölüm 7**'yi, dikkat için **Bölüm 8**'i, iş listesi için **Bölüm 9**'u kullansın.
