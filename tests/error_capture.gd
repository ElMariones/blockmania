extends Logger
## Counts engine/script errors raised while a test runs, so a runtime error that aborts a
## test method is reported as a failure instead of a silent pass.

var _mutex := Mutex.new()
var _capturing := false
var _errors := PackedStringArray()


func begin_capture() -> void:
	_mutex.lock()
	_capturing = true
	_errors.clear()
	_mutex.unlock()


func end_capture() -> PackedStringArray:
	_mutex.lock()
	var captured := _errors.duplicate()
	_capturing = false
	_errors.clear()
	_mutex.unlock()
	return captured


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	_mutex.lock()
	if _capturing:
		var text := rationale if not rationale.is_empty() else code
		_errors.append("%s (%s:%d in %s)" % [text, file, line, function])
	_mutex.unlock()
