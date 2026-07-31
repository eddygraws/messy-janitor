# Toon tile albedo generator (Python)

Requires: `pip install -r tools/requirements-tiles.txt`

```bash
# Single floor tile
python tools/generate_tile_texture.py --pattern floor --output textures/generated/floor_demo.png

# Offset brick wall
python tools/generate_tile_texture.py --pattern wall_brick --main-color 168,112,92 --seed 47

# Campaign batch → textures/generated/*.png + .import (mipmaps on)
python tools/generate_tile_texture.py --batch
```

Godot editor: enable **Toon Tile Generator** plugin (Project → Plugins). Dock button uses a built-in GDScript baker by default; optional checkbox runs this Python CLI.

Shader sampling: `toon_shader.gdshader` uses `repeat_enable` + `filter_linear_mipmap`. Import sidecars set `mipmaps/generate=true`.
