extends Node

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	# Retire the autoload only after the scene tree finishes attaching this scene.
	_run.call_deferred()


func _run() -> void:
	var manager: Node = get_node("/root/DialogueManager")
	var debugging: bool = EngineDebugger.is_active()
	_check(EngineDebugger.has_capture("dm") == debugging,
		"capture is registered exactly when the debugger is active")

	var resource: DialogueResource = manager.create_resource_from_text(
		"~ start\nNathan: Hello.\n=> END")
	_check(resource != null, "basic dialogue compiles")
	var line: DialogueLine = await manager.get_next_dialogue_line(resource, "start")
	_check(line != null and line.text == "Hello.", "basic dialogue still advances")
	var end: DialogueLine = await manager.get_next_dialogue_line(resource, line.next_id)
	_check(end == null, "basic dialogue ends normally")

	if debugging:
		_check(not manager._capture("unknown", []), "unknown debugger messages stay unhandled")
		_check(manager._capture("select_node", [get_instance_id()]),
			"node selection debugger callback remains functional")

	if "retire" in OS.get_cmdline_user_args():
		get_tree().root.remove_child(manager)
		_check(not EngineDebugger.has_capture("dm"), "tree exit unregisters the capture")
		# This fixture retires the autoload early; retire its unrelated singleton too.
		Engine.unregister_singleton("DialogueManager")
		manager.free()
		if debugging and not EngineDebugger.has_capture("dm"):
			EngineDebugger.register_message_capture("dm", _capture)
			_check(EngineDebugger.has_capture("dm"), "the retired capture name can be reused")
			EngineDebugger.unregister_message_capture("dm")
			_check(not EngineDebugger.has_capture("dm"), "replacement capture can be cleaned up")

	print("debug capture: %d checks, %d failures; debugger=%s; args=%s" %
		[_checks, _failures, debugging, OS.get_cmdline_user_args()])
	get_tree().quit(0 if _failures == 0 else 1)


func _capture(_message: String, _data: Array) -> bool:
	return false


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)
