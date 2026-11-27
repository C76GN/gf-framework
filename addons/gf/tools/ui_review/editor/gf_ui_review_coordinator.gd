# 独立轻量调度进程，启动真实项目之前隔离用户目录，并串行持有一个图形子进程。
extends SceneTree


# --- 私有变量 ---

## 由编辑器指定的批次目录。
## [br]
## @api private
var _folder: String

## 独立批次配置。
## [br]
## @api private
var _job: Dictionary

## 正在采集的用例索引。
## [br]
## @api private
var _index: int = 0

## 唯一活动的图形进程。
## [br]
## @api private
var _pid: int = -1

## 当前用例的开始时刻。
## [br]
## @api private
var _started: int = 0

## 各用例结果按顺序记录。
## [br]
## @api private
var _results: Array[Dictionary] = []


# --- Godot 生命周期方法 ---

func _initialize() -> void:
	call_deferred("_start")


# --- 私有/辅助方法 ---

## 环境变量只写入这个调度进程，随后由子游戏继承。
## [br]
## @api private
func _start() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	_folder = args[0].get_base_dir()
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not decoded is Dictionary:
		quit(2)
		return
	_job = decoded
	_next()


## 每个组合都从独立且空白的用户目录开始。
## [br]
## @api private
func _isolate_case() -> bool:
	var private_dir: String = str(_job.private_dir).path_join("case_%03d" % _index)
	var folders: Dictionary = {
		"APPDATA": "roaming",
		"LOCALAPPDATA": "local",
		"USERPROFILE": "profile",
		"HOME": "profile",
		"XDG_DATA_HOME": "data",
		"XDG_CONFIG_HOME": "config",
		"XDG_CACHE_HOME": "cache",
		"XDG_STATE_HOME": "state",
		"TMPDIR": "temp",
		"TEMP": "temp",
		"TMP": "temp",
	}
	for key: String in folders:
		var directory: String = private_dir.path_join(str(folders[key]))
		var error: Error = DirAccess.make_dir_recursive_absolute(directory)
		if error != OK:
			return false
		OS.set_environment(key, directory)
	return true


## 每个尺寸和语言组合由全新的游戏进程运行。
## [br]
## @api private
func _next() -> void:
	if FileAccess.file_exists(_folder.path_join("cancel")):
		_done("已取消")
		return
	var cases: Array = _job.cases
	if _index >= cases.size():
		_done("")
		return
	if not _isolate_case():
		_done("无法创建当前组合的隔离目录")
		return
	var options: Dictionary = cases[_index]
	var args: PackedStringArray = PackedStringArray(
		[
			"--path",
			str(_job.project),
			"--audio-driver",
			"Dummy",
			"--windowed",
			"--resolution",
			"%dx%d"
			% [options.width, options.height],
			"--log-file",
			_folder.path_join("case_%03d.log" % _index),
			"--script",
			str(_job.worker),
			"--",
			_folder.path_join("job.json"),
			str(_index),
		]
	)
	if _job.has("renderer"):
		var _method_added: int = args.insert(
			0,
			str(_job.renderer)
		)
		var _flag_added: int = args.insert(0, "--rendering-method")
	_pid = OS.create_instance(args)
	if _pid <= 0:
		_done("游戏进程启动失败")
		return
	_started = Time.get_ticks_msec()
	_poll.call_deferred()


## 保留当前运行的图片和诊断，取消及超时终止本次持有的游戏进程。
## [br]
## @api private
func _poll() -> void:
	while OS.is_process_running(_pid):
		var expired: bool = not _job.get("interactive", false) and Time.get_ticks_msec() - _started > 90000
		if FileAccess.file_exists(_folder.path_join("cancel")) or expired:
			var _killed: Error = OS.kill(_pid)
			_done("采样已取消或超过 90 秒")
			return
		await create_timer(0.15).timeout
	var path: String = _folder.path_join("case_%03d.json" % _index)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	var result: Dictionary = {}
	if parsed is Dictionary:
		result = parsed
	var log_path: String = _folder.path_join("case_%03d.log" % _index)
	var messages: String = FileAccess.get_file_as_string(log_path) if FileAccess.file_exists(log_path) else ""
	if result.has("error"):
		_results.append({ "index": _index, "error": result.error })
	elif messages.contains("ERROR:"):
		_results.append({ "index": _index, "error": "游戏运行报错，见 " + log_path })
	elif _job.get("interactive", false):
		if result.get("played", false):
			_results.append({ "index": _index, "played": true })
		else:
			_results.append({ "index": _index, "error": "实播在场景就绪前结束" })
	elif result.has("image"):
		_results.append({ "index": _index, "image": result.image })
	else:
		_results.append({ "index": _index, "error": "运行无截图" })
	_index += 1
	_next()


## 先写临时文件再重命名，编辑器只读取完整结果。
## [br]
## @api private
func _done(message: String) -> void:
	var path: String = _folder.path_join("report.json")
	var file: FileAccess = FileAccess.open(
		path + ".tmp",
		FileAccess.WRITE
	)
	if file != null:
		var written: bool = file.store_string(
			JSON.stringify(
				{
					"results": _results,
					"message": message,
					"interactive": _job.get("interactive", false),
				},
				"\t"
			)
		)
		file.close()
		if not written:
			quit(1)
			return
		var _renamed: Error = DirAccess.rename_absolute(
			path + ".tmp",
			path
		)
	if file == null or not FileAccess.file_exists(path):
		quit(1)
		return
	for result: Dictionary in _results:
		if result.has("error"):
			quit(1)
			return
	quit(0 if message.is_empty() else 1)
