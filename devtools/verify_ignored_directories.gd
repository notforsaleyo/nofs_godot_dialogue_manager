extends Node

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	var root: String = "user://dm_scan_check_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(root.path_join("normal"))
	DirAccess.make_dir_recursive_absolute(root.path_join("ignored/deep"))
	var content: Dictionary[String, String] = {
		"visible.dialogue": "~ start\nTester: Visible.\n=> END",
		"normal/nested.dialogue": "~ start\nTester: Nested.\n=> END",
		"ignored/.gdignore": "",
		"ignored/hidden.dialogue": "~ start\nTester: Hidden.\n=> END",
		"ignored/deep/hidden.dialogue": "~ start\nTester: Deep.\n=> END",
	}
	for relative_path: String in content:
		_write_file(root.path_join(relative_path), content[relative_path])

	var files: PackedStringArray = DMCache._get_dialogue_files_in_filesystem(root)
	_check(files.has(root.path_join("visible.dialogue")) and
		files.has(root.path_join("normal/nested.dialogue")), "ordinary directories remain discoverable")
	_check(files.size() == 2, "ignored files and descendants are excluded")
	_check(DMCache._get_dialogue_files_in_filesystem(root.path_join("ignored")).is_empty(),
		"direct discovery of an ignored directory returns no files")
	_write_file(root.path_join(".gdignore"), "")
	_check(DMCache._get_dialogue_files_in_filesystem(root).is_empty(),
		"a marker on the search root excludes the whole subtree")

	for relative_path: String in content:
		DirAccess.remove_absolute(root.path_join(relative_path))
	DirAccess.remove_absolute(root.path_join(".gdignore"))
	DirAccess.remove_absolute(root.path_join("ignored/deep"))
	DirAccess.remove_absolute(root.path_join("ignored"))
	DirAccess.remove_absolute(root.path_join("normal"))
	_check(DirAccess.remove_absolute(root) == OK, "temporary fixtures are removed")

	print("ignored directories: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _write_file(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)
