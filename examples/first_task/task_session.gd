# 独立项目会话：只有设置服务需要架构管理，计数状态不强制拆成 Model/System。
extends RefCounted


# --- 信号 ---

signal changed


# --- 常量 ---

const TASK_SERVICE = preload("res://examples/first_task/task_service.gd")
const MAX_COUNT: int = 1000000000


# --- 公共变量 ---

var count: int = 0
var last_error: String = ""
var ready: bool = false
var closing: bool = false
var closed: bool = false


# --- 私有变量 ---

var _architecture: GFArchitecture = GFArchitecture.new()
var _settings: GFSettingsUtility = GFSettingsUtility.new()
var _service: TASK_SERVICE = null
var _close_in_progress: bool = false
var _started: bool = false
var _closed_successfully: bool = false
var _pending_increments: int = 0


# --- 公共方法 ---

## 两个模式共享状态、存储与退出合同；异步模式只增加一个项目服务。
func start(file_name: String, asynchronous: bool = false, store: GFSettingsStoreUtility = null) -> bool:
	if _started:
		last_error = "会话已启动；切换模式需要关闭并创建新会话。"
		return false
	_started = true
	_settings.storage_file_name = file_name
	_settings.auto_load_on_init = false
	_settings.auto_save_on_change = false
	# 保留原值再验证，避免类型强制转换将损坏输入悄悄变成 0。
	var definition: GFSettingDefinition = _settings.register_setting(&"count", 0, GFSettingDefinition.ValueType.ANY)
	if definition == null:
		last_error = "无法注册计数设置。"
		return false
	var actual_store: GFSettingsStoreUtility = store if store != null else GFSettingsFileStoreUtility.new()
	var registered: bool = await _architecture.register_utility_instance(actual_store)
	registered = await _architecture.register_utility_instance(_settings) and registered
	if asynchronous:
		_service = TASK_SERVICE.new()
		registered = await _architecture.register_utility_instance(_service) and registered
	if not registered or not await _architecture.init():
		last_error = "架构启动失败：%s" % _architecture.last_initialization_error
		var _failed_shutdown: GFArchitectureShutdownResult = await _architecture.shutdown_async()
		_closed_successfully = _failed_shutdown.is_successful()
		closed = true
		return false
	var recovery: GFSettingsRecoveryPolicy = GFSettingsRecoveryPolicy.new()
	recovery.missing_file_action = GFSettingsRecoveryPolicy.ACTION_RESET_TO_DEFAULTS
	var loaded: GFSettingsLoadResult = _settings.load_settings("", recovery)
	if not loaded.is_successful():
		last_error = "设置读取失败，原文件未覆盖：%s" % loaded.get_error()
		var _load_shutdown: GFArchitectureShutdownResult = await _architecture.shutdown_async()
		_closed_successfully = _load_shutdown.is_successful()
		closed = true
		return false
	var stored_count: Variant = _settings.get_value(&"count", 0)
	if not GFVariantData.is_exact_integer(stored_count) or GFVariantData.to_int(stored_count) < 0 or GFVariantData.to_int(stored_count) > MAX_COUNT:
		last_error = "计数设置无效，原文件未覆盖。"
		var _invalid_shutdown: GFArchitectureShutdownResult = await _architecture.shutdown_async()
		_closed_successfully = _invalid_shutdown.is_successful()
		closed = true
		return false
	count = GFVariantData.to_int(stored_count)
	ready = true
	changed.emit()
	return true


## 每帧推进本会话；关闭真正进入架构静默后由架构自身推进生命周期。
func tick(delta: float) -> void:
	if not closed:
		_architecture.tick(delta)


## 接纳一次加分。成功只提交一次；失败和取消不改变状态。
func increment() -> GFAsyncCompletion:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	if not ready or closing:
		var _refused: bool = completion.fail("会话未就绪或正在关闭。")
		return completion
	if count + _pending_increments >= MAX_COUNT:
		var _limit: bool = completion.fail("计数已达到上限。")
		return completion
	if _service != null:
		completion = _service.request_increment()
	else:
		var _finished: bool = completion.succeed(1)
	if completion.is_failed():
		last_error = completion.get_error()
		changed.emit()
		return completion
	_pending_increments += 1
	if completion.is_completed():
		_on_increment_completed(completion)
	else:
		var _connected: Error = completion.completed.connect(_on_increment_completed, CONNECT_ONE_SHOT) as Error
	return completion


## 保存失败时保留内存状态供重试，不显示虚假的成功。
func save() -> Error:
	if not ready or closed:
		return ERR_UNAVAILABLE
	_settings.set_value(&"count", count, false)
	var error: Error = _settings.save_settings()
	last_error = "" if error == OK else "保存失败：%s。内存状态仍保留，可重试。" % error_string(error)
	changed.emit()
	return error


## 先阻止新工作并排空，再保存，再关闭架构。失败保留页面，重复请求不会并发执行退出。
func close() -> bool:
	if closed:
		return _closed_successfully
	if _close_in_progress or not ready:
		return false
	_close_in_progress = true
	closing = true
	changed.emit()
	if _service != null:
		var drain: GFAsyncCompletion = _service.begin_quiesce(null)
		if drain.is_pending():
			await drain.completed
		if not drain.is_successful():
			last_error = "服务未完成收尾，不能报告安全退出。"
			_close_in_progress = false
			changed.emit()
			return false
	if save() != OK:
		_close_in_progress = false
		return false
	var shutdown: GFArchitectureShutdownResult = await _architecture.shutdown_async()
	_close_in_progress = false
	ready = false
	closed = true
	_closed_successfully = shutdown.is_successful()
	if not shutdown.is_successful():
		last_error = "架构关闭未完全成功：%s" % shutdown.get_error()
	changed.emit()
	return _closed_successfully


## 场景被外部强制卸载时只释放本会话；正常用户退出必须走 close()。
func dispose() -> void:
	ready = false
	closing = true
	closed = true
	_architecture.dispose()


# --- 信号处理函数 ---

func _on_increment_completed(completion: GFAsyncCompletion) -> void:
	_pending_increments = maxi(_pending_increments - 1, 0)
	if closed:
		return
	if completion.is_successful():
		count += 1
		last_error = ""
	elif completion.is_failed():
		last_error = completion.get_error()
	changed.emit()
