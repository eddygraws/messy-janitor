from __future__ import annotations

bl_info = {
    "name": "Messy Janitor Gradient Toon",
    "author": "messy-janitor",
    "version": (1, 0, 2),
    "blender": (3, 6, 0),
    "location": "View3D > Sidebar > MJ Toon",
    "description": "Gradient Map material workflow for Godot toon albedos",
    "category": "Material",
}

"""
Messy Janitor — Blender Gradient Map workflow
=============================================

Install:
  Edit → Preferences → Add-ons → Install… → bu dosyayı seç → Enable

Veya Scripting workspace'te Run Script (N-panel kalıcı olmaz; addon kur).

Akış:
  1) Gri (value) texture boya / koy
  2) MJ Toon panelinden material + preset uygula
  3) Viewport'ta ColorRamp ile renk dene
  4) Bake Albedo → textures/generated/*.png
  5) Godot'ta toon_shader albedo_texture olarak bağla
"""

import os

import bpy
from bpy.props import (
    BoolProperty,
    EnumProperty,
    IntProperty,
    StringProperty,
)
from bpy.types import Operator, Panel, PropertyGroup


# ---------------------------------------------------------------------------
# Presets — Godot materials / character_toon ile hizalı
# Her stop: (position 0..1, RGB 0..1)
# ---------------------------------------------------------------------------

PRESETS = {
    "warm_maple": {
        "label": "Warm Maple (floor)",
        "interpolation": "CONSTANT",
        "stops": (
            (0.00, (0.29, 0.18, 0.13)),  # grout
            (0.35, (0.58, 0.44, 0.29)),  # stain
            (0.55, (0.66, 0.50, 0.34)),  # main  ~ broom wood
            (0.85, (0.78, 0.64, 0.48)),  # light
        ),
        "shadow": (0.22, 0.16, 0.12),
    },
    "kitchen_clay": {
        "label": "Kitchen Clay",
        "interpolation": "CONSTANT",
        "stops": (
            (0.00, (0.54, 0.49, 0.42)),
            (0.40, (0.66, 0.61, 0.53)),
            (0.60, (0.77, 0.71, 0.62)),
            (0.90, (0.86, 0.82, 0.74)),
        ),
        "shadow": (0.30, 0.26, 0.24),
    },
    "peach_brick": {
        "label": "Peach Brick",
        "interpolation": "CONSTANT",
        "stops": (
            (0.00, (0.38, 0.24, 0.18)),
            (0.35, (0.72, 0.48, 0.38)),
            (0.60, (0.86, 0.62, 0.50)),
            (0.88, (0.94, 0.78, 0.68)),
        ),
        "shadow": (0.30, 0.18, 0.14),
    },
    "mold_green": {
        "label": "Mold Green",
        "interpolation": "CONSTANT",
        "stops": (
            (0.00, (0.23, 0.32, 0.25)),
            (0.40, (0.28, 0.42, 0.31)),
            (0.60, (0.36, 0.50, 0.38)),
            (0.90, (0.48, 0.62, 0.50)),
        ),
        "shadow": (0.14, 0.22, 0.18),
    },
    "slime_teal": {
        "label": "Slime Teal",
        "interpolation": "CONSTANT",
        "stops": (
            (0.00, (0.16, 0.34, 0.31)),
            (0.40, (0.23, 0.44, 0.41)),
            (0.60, (0.27, 0.51, 0.48)),
            (0.90, (0.40, 0.64, 0.60)),
        ),
        "shadow": (0.10, 0.22, 0.22),
    },
    "uniform_purple": {
        "label": "Uniform Purple (char)",
        "interpolation": "CONSTANT",
        "stops": (
            (0.00, (0.14, 0.09, 0.24)),  # shadow
            (0.42, (0.48, 0.30, 0.68)),  # mid
            (0.73, (0.78, 0.66, 0.92)),  # highlight
        ),
        "shadow": (0.14, 0.09, 0.24),
        "character_preview": True,
    },
    "skin": {
        "label": "Skin (char)",
        "interpolation": "CONSTANT",
        "stops": (
            (0.00, (0.42, 0.22, 0.20)),
            (0.40, (0.92, 0.72, 0.58)),
            (0.72, (1.00, 0.88, 0.78)),
        ),
        "shadow": (0.42, 0.22, 0.20),
        "character_preview": True,
    },
}


NODE_PREFIX = "MJGT_"
MAT_NAME = "MJ_GradientToon"
MAT_PREVIEW_NAME = "MJ_ToonLightingPreview"


# Statik enum — dinamik callback + default Blender'da register hatası verir
PRESET_ITEMS = tuple((key, data["label"], "") for key, data in PRESETS.items())


def _set_ramp(ramp_node, stops, interpolation: str) -> None:
    cr = ramp_node.color_ramp
    cr.interpolation = interpolation
    # ColorRamp her zaman en az 2 element tutar; fazlasını sil / ekle
    elements = cr.elements
    while len(elements) > 2:
        elements.remove(elements[-1])
    elements[0].position = stops[0][0]
    elements[0].color = (*stops[0][1], 1.0)
    elements[1].position = stops[1][0]
    elements[1].color = (*stops[1][1], 1.0)
    for pos, rgb in stops[2:]:
        el = elements.new(pos)
        el.color = (*rgb, 1.0)


def _link(links, a, b):
    links.new(a, b)


def _ensure_node(nodes, bl_idname: str, name: str, location=(0, 0)):
    n = nodes.get(name)
    if n is None:
        n = nodes.new(type=bl_idname)
        n.name = name
        n.label = name.replace(NODE_PREFIX, "")
    n.location = location
    return n


def build_gradient_map_material(
    mat_name: str = MAT_NAME,
    preset_key: str = "warm_maple",
    use_emission_preview: bool = True,
) -> bpy.types.Material:
    """Gri albedo → ColorRamp → düz renk (Godot bake için)."""
    mat = bpy.data.materials.get(mat_name)
    if mat is None:
        mat = bpy.data.materials.new(name=mat_name)
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    nodes.clear()

    out = _ensure_node(nodes, "ShaderNodeOutputMaterial", NODE_PREFIX + "Output", (560, 0))
    img = _ensure_node(nodes, "ShaderNodeTexImage", NODE_PREFIX + "ValueTex", (-620, 40))
    img.interpolation = "Closest"  # toon: soft blur yok
    bw = _ensure_node(nodes, "ShaderNodeRGBToBW", NODE_PREFIX + "ToBW", (-360, 40))
    ramp = _ensure_node(nodes, "ShaderNodeValToRGB", NODE_PREFIX + "GradientMap", (-160, 40))
    emit = _ensure_node(nodes, "ShaderNodeEmission", NODE_PREFIX + "Emission", (200, 80))
    bsdf = _ensure_node(nodes, "ShaderNodeBsdfPrincipled", NODE_PREFIX + "Principled", (200, -140))

    # Roughness yüksek — viewport'ta specular parlama az
    if "Roughness" in bsdf.inputs:
        bsdf.inputs["Roughness"].default_value = 1.0
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.0
    elif "Specular" in bsdf.inputs:
        bsdf.inputs["Specular"].default_value = 0.0

    _link(links, img.outputs["Color"], bw.inputs["Color"])
    _link(links, bw.outputs["Val"], ramp.inputs["Fac"])
    _link(links, ramp.outputs["Color"], emit.inputs["Color"])
    _link(links, ramp.outputs["Color"], bsdf.inputs["Base Color"])

    # Bake/preview: Emission (ışıksız düz renk). Modellemeye bakarken Principled'e geç.
    if use_emission_preview:
        _link(links, emit.outputs["Emission"], out.inputs["Surface"])
    else:
        _link(links, bsdf.outputs["BSDF"], out.inputs["Surface"])

    apply_preset_to_material(mat, preset_key)
    return mat


def build_lighting_preview_material(
    mat_name: str = MAT_PREVIEW_NAME,
    preset_key: str = "uniform_purple",
) -> bpy.types.Material:
    """Principled → Shader to RGB → ColorRamp (Constant) — character_toon referansı."""
    mat = bpy.data.materials.get(mat_name)
    if mat is None:
        mat = bpy.data.materials.new(name=mat_name)
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    nodes.clear()

    out = _ensure_node(nodes, "ShaderNodeOutputMaterial", NODE_PREFIX + "Output", (700, 0))
    bsdf = _ensure_node(nodes, "ShaderNodeBsdfPrincipled", NODE_PREFIX + "Principled", (-200, 0))
    s2r = _ensure_node(nodes, "ShaderNodeShaderToRGB", NODE_PREFIX + "ShaderToRGB", (80, 0))
    ramp = _ensure_node(nodes, "ShaderNodeValToRGB", NODE_PREFIX + "LightBands", (300, 0))
    emit = _ensure_node(nodes, "ShaderNodeEmission", NODE_PREFIX + "Emission", (520, 0))

    if "Roughness" in bsdf.inputs:
        bsdf.inputs["Roughness"].default_value = 0.85
    # Mid rengi Principled base'e (ramp gölgeyi çözecek)
    preset = PRESETS[preset_key]
    mid = preset["stops"][len(preset["stops"]) // 2][1]
    bsdf.inputs["Base Color"].default_value = (*mid, 1.0)

    _link(links, bsdf.outputs["BSDF"], s2r.inputs["Shader"])
    _link(links, s2r.outputs["Color"], ramp.inputs["Fac"])
    _link(links, ramp.outputs["Color"], emit.inputs["Color"])
    _link(links, emit.outputs["Emission"], out.inputs["Surface"])

    apply_preset_to_material(mat, preset_key, ramp_name=NODE_PREFIX + "LightBands")
    return mat


def apply_preset_to_material(
    mat: bpy.types.Material,
    preset_key: str,
    ramp_name: str | None = None,
) -> None:
    if preset_key not in PRESETS:
        raise KeyError(f"Unknown preset: {preset_key}")
    preset = PRESETS[preset_key]
    nodes = mat.node_tree.nodes
    ramp = None
    if ramp_name:
        ramp = nodes.get(ramp_name)
    if ramp is None:
        ramp = nodes.get(NODE_PREFIX + "GradientMap") or nodes.get(NODE_PREFIX + "LightBands")
    if ramp is None:
        for n in nodes:
            if n.bl_idname == "ShaderNodeValToRGB":
                ramp = n
                break
    if ramp is None:
        raise RuntimeError("ColorRamp node bulunamadı")
    _set_ramp(ramp, preset["stops"], preset["interpolation"])


def assign_material(obj: bpy.types.Object, mat: bpy.types.Material) -> None:
    if obj.type != "MESH":
        return
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)


def find_value_image_node(mat: bpy.types.Material):
    return mat.node_tree.nodes.get(NODE_PREFIX + "ValueTex")


def default_export_dir() -> str:
    # .../messy-janitor/tools/blender/bu_dosya → repo root
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.abspath(os.path.join(here, "..", ".."))
    out = os.path.join(root, "textures", "generated")
    return out if os.path.isdir(os.path.join(root, "textures")) else bpy.path.abspath("//")


# ---------------------------------------------------------------------------
# Properties / UI
# ---------------------------------------------------------------------------

class MJGT_Props(PropertyGroup):
    preset: EnumProperty(
        name="Preset",
        items=PRESET_ITEMS,
        default="warm_maple",
    )
    export_name: StringProperty(name="Export Name", default="floor_warm_maple")
    export_dir: StringProperty(name="Export Dir", default="", subtype="DIR_PATH")
    bake_size: IntProperty(name="Bake Size", default=1024, min=256, max=4096)
    use_emission: BoolProperty(
        name="Emission Preview",
        description="Işıksız düz renk (Godot albedo bake için önerilir)",
        default=True,
    )
    padding: IntProperty(name="Bake Margin", default=8, min=0, max=64)


class MJGT_OT_create_gradient_mat(Operator):
    bl_idname = "mjgt.create_gradient_mat"
    bl_label = "Create Gradient Map Material"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        props = context.scene.mjgt
        mat = build_gradient_map_material(
            preset_key=props.preset,
            use_emission_preview=props.use_emission,
        )
        obj = context.active_object
        if obj and obj.type == "MESH":
            assign_material(obj, mat)
        self.report({"INFO"}, f"Material ready: {mat.name}")
        return {"FINISHED"}


class MJGT_OT_create_lighting_preview(Operator):
    bl_idname = "mjgt.create_lighting_preview"
    bl_label = "Create Lighting Band Preview"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        props = context.scene.mjgt
        key = props.preset
        if not PRESETS[key].get("character_preview") and key not in ("uniform_purple", "skin"):
            key = "uniform_purple"
        mat = build_lighting_preview_material(preset_key=key)
        obj = context.active_object
        if obj and obj.type == "MESH":
            assign_material(obj, mat)
        self.report({"INFO"}, f"Lighting preview: {mat.name}")
        return {"FINISHED"}


class MJGT_OT_apply_preset(Operator):
    bl_idname = "mjgt.apply_preset"
    bl_label = "Apply Preset to Active Material"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        obj = context.active_object
        if not obj or not obj.active_material:
            self.report({"ERROR"}, "Aktif mesh + material yok")
            return {"CANCELLED"}
        apply_preset_to_material(obj.active_material, context.scene.mjgt.preset)
        self.report({"INFO"}, f"Preset: {context.scene.mjgt.preset}")
        return {"FINISHED"}


class MJGT_OT_load_value_texture(Operator):
    bl_idname = "mjgt.load_value_texture"
    bl_label = "Load Grayscale Value Texture"
    bl_options = {"REGISTER", "UNDO"}

    filepath: StringProperty(subtype="FILE_PATH")
    filter_glob: StringProperty(default="*.png;*.jpg;*.jpeg;*.tif;*.tiff;*.exr", options={"HIDDEN"})

    def invoke(self, context, _event):
        context.window_manager.fileselect_add(self)
        return {"RUNNING_MODAL"}

    def execute(self, context):
        obj = context.active_object
        if not obj or not obj.active_material:
            self.report({"ERROR"}, "Önce Gradient Map material oluştur")
            return {"CANCELLED"}
        mat = obj.active_material
        img_node = find_value_image_node(mat)
        if img_node is None:
            self.report({"ERROR"}, "ValueTex node yok — Create Gradient Map Material çalıştır")
            return {"CANCELLED"}
        img = bpy.data.images.load(self.filepath, check_existing=True)
        img.colorspace_settings.name = "Non-Color"
        img_node.image = img
        self.report({"INFO"}, f"Loaded: {os.path.basename(self.filepath)}")
        return {"FINISHED"}


class MJGT_OT_make_blank_value(Operator):
    bl_idname = "mjgt.make_blank_value"
    bl_label = "New Blank Value Texture"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        props = context.scene.mjgt
        obj = context.active_object
        if not obj or not obj.active_material:
            self.report({"ERROR"}, "Aktif material yok")
            return {"CANCELLED"}
        mat = obj.active_material
        img_node = find_value_image_node(mat)
        if img_node is None:
            self.report({"ERROR"}, "ValueTex node yok")
            return {"CANCELLED"}
        name = f"{props.export_name}_value"
        size = props.bake_size
        img = bpy.data.images.get(name)
        if img is None:
            img = bpy.data.images.new(name=name, width=size, height=size, alpha=False)
        # Mid gray — boyamaya hazır
        pixels = [0.55, 0.55, 0.55, 1.0] * (size * size)
        img.pixels = pixels
        img.colorspace_settings.name = "Non-Color"
        img_node.image = img
        # Texture Paint için aktif yap
        for area in context.screen.areas:
            if area.type == "IMAGE_EDITOR":
                area.spaces.active.image = img
        self.report({"INFO"}, f"Blank value {size}px — Texture Paint ile boya")
        return {"FINISHED"}


class MJGT_OT_toggle_emission(Operator):
    bl_idname = "mjgt.toggle_emission"
    bl_label = "Toggle Emission / Principled"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        obj = context.active_object
        if not obj or not obj.active_material:
            self.report({"ERROR"}, "Aktif material yok")
            return {"CANCELLED"}
        mat = obj.active_material
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        out = nodes.get(NODE_PREFIX + "Output")
        emit = nodes.get(NODE_PREFIX + "Emission")
        bsdf = nodes.get(NODE_PREFIX + "Principled")
        if not out or not emit or not bsdf:
            self.report({"ERROR"}, "Gradient Map material değil")
            return {"CANCELLED"}
        # Surface'e bağlıyı bul
        surface_links = [lk for lk in out.inputs["Surface"].links]
        use_emit = True
        if surface_links and surface_links[0].from_node == emit:
            use_emit = False
        for lk in list(out.inputs["Surface"].links):
            links.remove(lk)
        if use_emit:
            links.new(emit.outputs["Emission"], out.inputs["Surface"])
            self.report({"INFO"}, "Emission (bake/preview)")
        else:
            links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
            self.report({"INFO"}, "Principled (lit viewport)")
        return {"FINISHED"}


class MJGT_OT_bake_albedo(Operator):
    bl_idname = "mjgt.bake_albedo"
    bl_label = "Bake Albedo PNG for Godot"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        props = context.scene.mjgt
        obj = context.active_object
        if not obj or obj.type != "MESH":
            self.report({"ERROR"}, "Aktif mesh seç")
            return {"CANCELLED"}
        mat = obj.active_material
        if not mat:
            self.report({"ERROR"}, "Material yok")
            return {"CANCELLED"}

        # Emission bağlı olmalı (düz renk bake)
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        out = nodes.get(NODE_PREFIX + "Output")
        emit = nodes.get(NODE_PREFIX + "Emission")
        if out and emit:
            for lk in list(out.inputs["Surface"].links):
                links.remove(lk)
            links.new(emit.outputs["Emission"], out.inputs["Surface"])

        size = props.bake_size
        bake_name = f"{props.export_name}_bake"
        bake_img = bpy.data.images.get(bake_name)
        if bake_img is None:
            bake_img = bpy.data.images.new(name=bake_name, width=size, height=size, alpha=False)
        elif bake_img.size[0] != size or bake_img.size[1] != size:
            bake_img.scale(size, size)

        # Bake target node (Image Texture + seçili)
        bake_node = nodes.get(NODE_PREFIX + "BakeTarget")
        if bake_node is None:
            bake_node = nodes.new(type="ShaderNodeTexImage")
            bake_node.name = NODE_PREFIX + "BakeTarget"
            bake_node.label = "BakeTarget"
            bake_node.location = (-620, -220)
        bake_node.image = bake_img
        for n in nodes:
            n.select = False
        bake_node.select = True
        nodes.active = bake_node

        # UV kontrol
        if not obj.data.uv_layers:
            self.report({"ERROR"}, "UV map yok — UV unwrap gerekli")
            return {"CANCELLED"}

        scene = context.scene
        prev_engine = scene.render.engine
        scene.render.engine = "CYCLES"
        scene.cycles.bake_type = "EMIT"
        scene.render.bake.margin = props.padding
        scene.render.bake.use_clear = True

        # Tek objeye bake
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        context.view_layer.objects.active = obj
        try:
            bpy.ops.object.bake(type="EMIT")
        except Exception as exc:  # noqa: BLE001 — Blender API
            scene.render.engine = prev_engine
            self.report({"ERROR"}, f"Bake failed: {exc}")
            return {"CANCELLED"}

        scene.render.engine = prev_engine

        out_dir = props.export_dir.strip() or default_export_dir()
        os.makedirs(out_dir, exist_ok=True)
        path = os.path.join(out_dir, f"{props.export_name}.png")
        bake_img.filepath_raw = path
        bake_img.file_format = "PNG"
        bake_img.colorspace_settings.name = "sRGB"
        bake_img.save()

        self.report({"INFO"}, f"Saved: {path}")
        return {"FINISHED"}


class MJGT_PT_panel(Panel):
    bl_label = "MJ Gradient Toon"
    bl_idname = "MJGT_PT_panel"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "MJ Toon"

    def draw(self, context):
        props = context.scene.mjgt
        layout = self.layout

        col = layout.column(align=True)
        col.label(text="1) Material", icon="MATERIAL")
        col.prop(props, "preset")
        col.prop(props, "use_emission")
        col.operator("mjgt.create_gradient_mat", icon="NODE_MATERIAL")
        col.operator("mjgt.apply_preset", icon="COLOR")
        col.operator("mjgt.create_lighting_preview", icon="LIGHT")
        col.operator("mjgt.toggle_emission", icon="SHADING_RENDERED")

        layout.separator()
        col = layout.column(align=True)
        col.label(text="2) Value texture (gri)", icon="IMAGE_DATA")
        col.operator("mjgt.make_blank_value", icon="FILE_NEW")
        col.operator("mjgt.load_value_texture", icon="FILEBROWSER")
        col.label(text="Texture Paint → sadece gri değer")

        layout.separator()
        col = layout.column(align=True)
        col.label(text="3) Bake → Godot", icon="RENDER_STILL")
        col.prop(props, "export_name")
        col.prop(props, "export_dir")
        col.prop(props, "bake_size")
        col.prop(props, "padding")
        col.operator("mjgt.bake_albedo", icon="EXPORT")
        if not props.export_dir:
            col.label(text=f"Default: …/textures/generated", icon="INFO")


classes = (
    MJGT_Props,
    MJGT_OT_create_gradient_mat,
    MJGT_OT_create_lighting_preview,
    MJGT_OT_apply_preset,
    MJGT_OT_load_value_texture,
    MJGT_OT_make_blank_value,
    MJGT_OT_toggle_emission,
    MJGT_OT_bake_albedo,
    MJGT_PT_panel,
)


def register():
    for cls in classes:
        try:
            bpy.utils.register_class(cls)
        except ValueError:
            # Yeniden Run Script / hot-reload
            bpy.utils.unregister_class(cls)
            bpy.utils.register_class(cls)
    bpy.types.Scene.mjgt = bpy.props.PointerProperty(type=MJGT_Props)


def unregister():
    if hasattr(bpy.types.Scene, "mjgt"):
        del bpy.types.Scene.mjgt
    for cls in reversed(classes):
        try:
            bpy.utils.unregister_class(cls)
        except RuntimeError:
            pass


if __name__ == "__main__":
    # Scripting tabinden Run Script
    try:
        unregister()
    except Exception:
        pass
    register()
    print("MJ Gradient Toon registered — N paneli → MJ Toon")
