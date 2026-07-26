character: janitor
forward: -Z (oyun ile aynı)

# === Mixamo dosya adları (bu klasöre koy) ===
#
# ZORUNLU (zaten var):
#   janitor-tpose.fbx          — With Skin
#   anim_idle.fbx              — Standing Idle (Without Skin)
#   anim-run.fbx               — Running (Without Skin)
#   anim-carry-idle.fbx        — Holding Idle (Without Skin)
#   anim_hit.fbx               — Punching / Hitting (Without Skin)
#
# EKLENEN (içerik dosya adlarıyla eşleşecek şekilde yer değiştirdi):
#   anim_carry_walk.fbx        — kutu taşırken yürüme
#   anim_dance.fbx             — G dans
#   dash.fbx                   — Shift dash
#
# Import: FPS 30, In Place AÇIK (yürüme/dans/dash için)
#
# === Oyun bağları ===
# idle / run / carry / carry_walk / dance / hit / dash
# dash → dash.fbx (yoksa run hızlı)
# Hips position track silinir (ışınlanma fix)
#
# Toon: sahne prop'larıyla aynı hit_wobble.gdshader + outline
#
# Ölçek (PlayerCharacter Inspector):
#   janitor_size_mult = 0.25–1.75
#   janitor_yaw_offset = 0 (tersse PI)
