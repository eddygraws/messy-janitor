@tool
extends EditorPlugin

## Dock: Generate Toon Tile Texture (GDScript baker; optional Python CLI).

const Baker = preload("res://addons/toon_tile_generator/toon_tile_baker.gd")

var _dock: Control
var _status: Label
var _pattern: OptionButton
var _seed_spin: SpinBox
var _size_spin: SpinBox
var _tiles_spin: SpinBox
var _main_edit: LineEdit
var _grout_edit: LineEdit
var _stain_edit: LineEdit
var _name_edit: LineEdit
var _use_python: CheckBox


func _enter_tree() -> void:
	_dock = _build_dock()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


func _build_dock() -> Control:
	var root := VBoxContainer.new()
	root.name = "ToonTiles"
	root.custom_minimum_size = Vector2(220, 0)

	var title := Label.new()
	title.text = "Toon Tile Generator"
	title.add_theme_font_size_override("font_size", 16)
	root.add_child(title)

	_pattern = OptionButton.new()
	_pattern.add_item("floor", 0)
	_pattern.add_item("wall_brick", 1)
	root.add_child(_labeled("Pattern", _pattern))

	_name_edit = LineEdit.new()
	_name_edit.text = "custom_tile"
	root.add_child(_labeled("Name", _name_edit))

	_main_edit = LineEdit.new()
	_main_edit.text = "196,182,158"
	root.add_child(_labeled("Main RGB", _main_edit))

	_grout_edit = LineEdit.new()
	_grout_edit.text = "138,126,108"
	root.add_child(_labeled("Grout RGB", _grout_edit))

	_stain_edit = LineEdit.new()
	_stain_edit.text = "168,156,134"
	root.add_child(_labeled("Stain RGB", _stain_edit))

	_seed_spin = SpinBox.new()
	_seed_spin.min_value = 0
	_seed_spin.max_value = 999999
	_seed_spin.value = 7
	root.add_child(_labeled("Seed", _seed_spin))

	_size_spin = SpinBox.new()
	_size_spin.min_value = 256
	_size_spin.max_value = 2048
	_size_spin.step = 256
	_size_spin.value = 1024
	root.add_child(_labeled("Size", _size_spin))

	_tiles_spin = SpinBox.new()
	_tiles_spin.min_value = 2
	_tiles_spin.max_value = 16
	_tiles_spin.value = 4
	root.add_child(_labeled("Tiles", _tiles_spin))

	_use_python = CheckBox.new()
	_use_python.text = "Use Python CLI (if installed)"
	_use_python.button_pressed = false
	root.add_child(_use_python)

	var gen_btn := Button.new()
	gen_btn.text = "Generate Toon Tile Texture"
	gen_btn.pressed.connect(_on_generate_one)
	root.add_child(gen_btn)

	var batch_btn := Button.new()
	batch_btn.text = "Generate Batch (campaign)"
	batch_btn.pressed.connect(_on_generate_batch)
	root.add_child(batch_btn)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "Default: built-in baker (no Python)."
	root.add_child(_status)
	return root


func _labeled(title: String, control: Control) -> Control:
	var row := VBoxContainer.new()
	var lab := Label.new()
	lab.text = title
	row.add_child(lab)
	row.add_child(control)
	return row


func _parse_rgb(text: String) -> Color:
	var parts := text.replace(" ", "").split(",")
	if parts.size() != 3:
		return Color(0.77, 0.71, 0.62)
	return Color8(int(parts[0]), int(parts[1]), int(parts[2]))


func _on_generate_one() -> void:
	if _use_python.button_pressed:
		_run_python_one()
		return
	var pattern: int = Baker.Pattern.FLOOR if _pattern.selected == 0 else Baker.Pattern.WALL_BRICK
	var stem := _name_edit.text.strip_edges()
	if stem.is_empty():
		stem = "custom_tile"
	var path := "res://textures/generated/%s.png" % stem
	_status.text = "Baking…"
	var err: Error = Baker.bake_to_path(
		path,
		pattern,
		_parse_rgb(_main_edit.text),
		_parse_rgb(_grout_edit.text),
		_parse_rgb(_stain_edit.text),
		int(_size_spin.value),
		int(_tiles_spin.value),
		6,
		int(_seed_spin.value),
	)
	if err != OK:
		_status.text = "Bake failed: %s" % error_string(err)
		return
	EditorInterface.get_resource_filesystem().scan()
	_status.text = "Done → %s" % path


func _on_generate_batch() -> void:
	if _use_python.button_pressed:
		_run_python_batch()
		return
	_status.text = "Baking batch…"
	var paths: PackedStringArray = Baker.bake_campaign_batch(
		int(_size_spin.value),
		int(_tiles_spin.value),
	)
	EditorInterface.get_resource_filesystem().scan()
	_status.text = "Batch done (%d files)." % paths.size()
	print("Toon Tile batch:\n", "\n".join(paths))


func _run_python_one() -> void:
	var pattern := "floor" if _pattern.selected == 0 else "wall_brick"
	var stem := _name_edit.text.strip_edges()
	if stem.is_empty():
		stem = "%s_tile" % pattern
	var args := PackedStringArray([
		"tools/generate_tile_texture.py",
		"--pattern", pattern,
		"--main-color", _main_edit.text.strip_edges(),
		"--grout-color", _grout_edit.text.strip_edges(),
		"--stain-color", _stain_edit.text.strip_edges(),
		"--seed", str(int(_seed_spin.value)),
		"--size", str(int(_size_spin.value)),
		"--tiles-per-texture", str(int(_tiles_spin.value)),
		"--output", "textures/generated/%s.png" % stem,
	])
	_run_python(args)


func _run_python_batch() -> void:
	_run_python(PackedStringArray([
		"tools/generate_tile_texture.py",
		"--batch",
		"--size", str(int(_size_spin.value)),
		"--tiles-per-texture", str(int(_tiles_spin.value)),
	]))


func _run_python(script_args: PackedStringArray) -> void:
	var prefix := _python_prefix()
	if prefix.is_empty():
		_status.text = "Python missing — uncheck 'Use Python' for built-in baker."
		return
	_status.text = "Running Python…"
	var args := PackedStringArray()
	args.append_array(prefix.slice(1))
	args.append_array(script_args)
	var output: Array = []
	var exit_code := OS.execute(prefix[0], args, output, true, false)
	var joined := "\n".join(PackedStringArray(output))
	if exit_code != 0:
		_status.text = "Python failed (%d)." % exit_code
		push_error(joined)
		return
	EditorInterface.get_resource_filesystem().scan()
	print(joined)
	_status.text = "Python done → textures/generated/"


func _python_prefix() -> PackedStringArray:
	var out: Array = []
	if OS.execute("py", PackedStringArray(["-3", "--version"]), out, true, false) == 0:
		return PackedStringArray(["py", "-3"])
	out.clear()
	if OS.execute("python3", PackedStringArray(["--version"]), out, true, false) == 0:
		return PackedStringArray(["python3"])
	out.clear()
	if OS.execute("python", PackedStringArray(["--version"]), out, true, false) == 0:
		return PackedStringArray(["python"])
	return PackedStringArray()
