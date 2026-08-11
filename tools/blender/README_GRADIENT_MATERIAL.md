# Blender Gradient Map → Godot Toon

Zaman kazandıran akış: **bir kez gri value boya**, ColorRamp ile renklendir, bake al, Godot’a at.

Script: `tools/blender/mj_gradient_toon.py`

## Kurulum

1. Blender 3.6+ / 4.x
2. **Edit → Preferences → Add-ons → Install…** → `mj_gradient_toon.py`
3. **Messy Janitor Gradient Toon**’u enable et
4. 3D View’da **N** → **MJ Toon** paneli

Geçici test: Scripting workspace → dosyayı aç → **Run Script**.

Cycles bake için: Render Engine’in Cycles’a geçebilmesi yeterli (script bake anında geçici açar).

## Workflow (oda yüzeyi / tile)

```
gri value texture  →  ColorRamp (Constant)  →  Emission bake  →  PNG
                                                              ↓
                                              textures/generated/*.png
                                                              ↓
                                         Godot toon_shader albedo_texture
```

### Adımlar

1. Mesh’i UV unwrap et (tile için 0–1 square yeter).
2. Panel: **Create Gradient Map Material** (preset seç: Warm Maple, Peach Brick…).
3. **New Blank Value Texture** veya **Load Grayscale Value Texture**.
4. **Texture Paint** — sadece gri:
   - ~0.15 derz / çizgi
   - ~0.35 leke
   - ~0.55 ana yüzey
   - ~0.85 hafif varyasyon
5. ColorRamp node’unda stop renklerini kaydır (veya panelden başka preset **Apply**).
6. **Export Name** ver → **Bake Albedo PNG for Godot**.
7. Godot material: `albedo_color = beyaz`, `albedo_texture = PNG`, `shadow_color` = mid’in koyusu.

Aynı gri maskeyi farklı preset’lerle bake ederek palette swap yap — yeniden boyama yok.

## İki material tipi

| Material | Ne işe yarar |
|----------|----------------|
| **Gradient Map** (`MJ_GradientToon`) | Oda/floor/wall albedo. Gri → ramp → düz renk. Bake bunu kullan. |
| **Lighting Band Preview** (`MJ_ToonLightingPreview`) | Karakter toon referansı. Principled → Shader to RGB → Constant ramp (`character_toon.gdshader` ile aynı fikir). Bake etme. |

**Toggle Emission / Principled:** bake öncesi Emission; form görmek için Principled.

## Godot tarafı (hatırlatma)

- Texture’a gölge boyama — ışık `toon_shader` band’larında.
- Import: mipmaps on, sRGB.
- `shade_bands = 3`, `shadow_strength ≈ 0.5`.

## Value boyama ipuçları

- Soft brush yok; flat / hard edge.
- En fazla 4–5 değer bandı.
- Seamless tile: paint’te wrap.
- Image Texture interpolation script’te **Closest** (toon keskinlik).

## Preset listesi

Warm Maple, Kitchen Clay, Peach Brick, Mold Green, Slime Teal, Uniform Purple, Skin.

Yeni preset: `mj_gradient_toon.py` içindeki `PRESETS` dict’ine stop ekle.
