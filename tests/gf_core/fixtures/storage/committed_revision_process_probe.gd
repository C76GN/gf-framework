# 两个独立 Godot 进程共享本次专用 root 的持久 revision 验收。
extends SceneTree


# --- 私有变量 ---

var _storage: GFStorageUtility
var _phase: String = ""
var _root_name: String = ""
var _failures: Array[String] = []


# --- Godot 生命周期方法 ---

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--revision-phase="):
			_phase = argument.trim_prefix("--revision-phase=")
		elif argument.begins_with("--revision-root="):
			_root_name = argument.trim_prefix("--revision-root=")
		else:
			_failures.append("Unexpected argument")
	var prefix: String = "gf-storage-revision-process-"
	if (
		_phase not in ["seed", "verify"]
		or not _root_name.begins_with(prefix)
		or not GFUuid.is_valid(_root_name.trim_prefix(prefix), 4)
	):
		_failures.append("Invalid owned fixture identity")
	if not _failures.is_empty():
		_finish()
		return
	_storage = GFStorageUtility.new()
	_storage.save_dir_name = _root_name
	if _phase == "seed":
		_seed()
	else:
		_verify()
	_storage.dispose()
	_storage = null
	_finish()


# --- 私有/辅助方法 ---

func _seed() -> void:
	_expect(_storage.create_revision_storage() == OK, "create")
	_expect(_storage.save_data("process.json", {"value": 17}) == OK, "seed save")
	var revision: GFStorageRevisionResult = _storage.query_committed_revision("process.json")
	_expect(revision.is_successful(), "seed revision")
	var file: FileAccess = FileAccess.open(_proof_path(), FileAccess.WRITE)
	if file == null:
		_failures.append("proof open")
		return
	var _written: bool = file.store_string(revision.get_revision()) != null
	file.flush()
	_expect(file.get_error() == OK, "proof write")
	file.close()


func _verify() -> void:
	var original: String = FileAccess.get_file_as_string(_proof_path())
	_expect(not original.is_empty(), "seed proof present")
	var revision: GFStorageRevisionResult = _storage.query_committed_revision("process.json")
	_expect(revision.is_successful(), "restarted query")
	_expect(revision.get_revision() == original, "same token after independent process restart")
	var result: GFStorageReadResult = _storage.load_data("process.json")
	_expect(result.ok and GFVariantData.get_option_int(result.payload, "value") == 17, "restarted payload")
	_expect(result.get_committed_revision().get_revision() == original, "restarted read token pairing")
	_expect(_storage.save_data("process.json", {"value": 17}) == OK, "same bytes rewrite")
	var rewritten: GFStorageRevisionResult = _storage.query_committed_revision("process.json")
	_expect(rewritten.is_successful() and rewritten.get_revision() != original, "rewrite rotates token across process boundary")


func _proof_path() -> String:
	return GFStorageFamilyStore.make_storage_root_path_for_framework(_root_name).path_join("revision-probe.txt")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	print("GF_STORAGE_REVISION_PROCESS_PROBE=" + JSON.stringify({
		"phase": _phase,
		"ok": _failures.is_empty(),
		"failures": _failures,
	}))
	quit(0 if _failures.is_empty() else 1)
