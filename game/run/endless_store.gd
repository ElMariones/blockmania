class_name BMEndlessStore
extends RefCounted
## Endless progress and local top ten live apart from the campaign save.

const PATH := "user://endless.json"
const SCORES_PATH := "user://endless_scores.json"
static var game_path := PATH
static var scores_path := SCORES_PATH


static func _write(path: String, value: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


static func load_game() -> BMEndless:
	if not FileAccess.file_exists(game_path):
		return null
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(game_path))
	if not d is Dictionary or d.get("schema", 0) != BMEndless.SCHEMA:
		return null
	var game := BMEndless.from_dict(d)
	return null if game == null or game.over else game


static func record(game: BMEndless) -> void:
	if game.over:
		if FileAccess.file_exists(game_path):
			DirAccess.remove_absolute(game_path)
		var scores := high_scores()
		scores.append({"score": game.score, "seed": game.seed, "lines": game.lines,
			"combo": game.best_combo, "date": Time.get_date_string_from_system()})
		scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.score) > int(b.score))
		scores.resize(mini(scores.size(), 10))
		_write(scores_path, {"schema": 1, "scores": scores})
	else:
		_write(game_path, game.to_dict())


static func high_scores() -> Array:
	if not FileAccess.file_exists(scores_path):
		return []
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(scores_path))
	return d.get("scores", []) if d is Dictionary and int(d.get("schema", 0)) == 1 else []
