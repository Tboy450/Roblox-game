extends RefCounted
## A validated temp write replaces the primary; the previous valid save is kept.
const State = preload("res://scripts/retail_state.gd")
const DEFAULT_PATH := "user://cornerfield-save.json"
const MAX_BYTES := 65536

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "No save found."}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Cannot read save."}
	if file.get_length() > MAX_BYTES:
		file.close()
		return {"ok": false, "error": "Save is too large."}
	var json = JSON.new()
	var parse_error = json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {"ok": false, "error": "Save JSON is damaged."}
	if json.data is Dictionary and State._whole(json.data.get("version"), 2, 1000000000):
		return {"ok": false, "future": true, "error": "Save belongs to a newer game version; it was left unchanged."}
	var probe = State.new()
	var validation = probe.apply_save(json.data)
	if not validation.is_empty():
		return {"ok": false, "error": validation}
	return {"ok": true, "data": json.data}

static func save(state, path: String = DEFAULT_PATH) -> Dictionary:
	var data = state.save_data()
	var probe = State.new()
	var validation = probe.apply_save(data)
	if not validation.is_empty():
		return {"ok": false, "error": validation}
	var current = _read(path)
	if current.get("future", false):
		return current
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Cannot write save. Existing progress was left unchanged."}
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK or not _read(path + ".tmp").ok:
		return {"ok": false, "error": "Save verification failed. Existing progress was left unchanged."}
	if current.ok:
		var copied = DirAccess.copy_absolute(path, path + ".bak.tmp")
		if copied != OK or DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak") != OK:
			return {"ok": false, "error": "Could not retain previous save; primary was left unchanged."}
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		return {"ok": false, "error": "Could not replace save. Previous progress is retained."}
	return {"ok": true}

static func load_into(state, path: String = DEFAULT_PATH) -> Dictionary:
	var primary = _read(path)
	if primary.get("future", false):
		return primary
	var candidate = primary if primary.ok else _read(path + ".bak")
	if not candidate.ok:
		return {"ok": false, "error": primary.error, "backup_error": candidate.error}
	var error = state.apply_save(candidate.data)
	if not error.is_empty():
		return {"ok": false, "error": error}
	return {"ok": true, "recovered": not primary.ok}
