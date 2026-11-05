# 计数、保存、读回与退出

本例把一个计数留在场景 Node 中，用原生 `Label` 和 `Button` 显示、修改它，只注册 `GFStorageUtility`。适合先验证小型项目的基本接入；不需要启用可选扩展。

## 场景准备与运行

1. 按[安装与 AutoLoad](install-autoload.md)启用插件，确认项目中有 `Gf`。
2. 新建根节点为普通 `Node` 的场景，保存为项目自己的 `counter.tscn`，挂载下面的完整脚本。控件由脚本创建，无需另建子节点或连接信号。
3. 按 **F6** 单独运行该场景。本例自己注册 Storage 并调用 `Gf.init()`；不要同时从已完成初始化的 Boot 再运行这段启动装配，也不要再创建第二个写入同一存储目录的 Storage。
4. 点击 **加一** 两次，再点 **保存**；再加一次，点击 **读回**，计数应恢复为 `2`。使用 **保存并退出** 后重新运行，再点 **读回**，应取得退出前保存的值。

## 完整脚本

```gdscript
# 独立运行的计数场景：本入口负责装配 Storage、初始化架构和应用退出。
# 只用于尚未初始化 GF 的项目；普通业务场景应复用 Boot 已注册的服务。
extends Node


## Storage 内的逻辑路径，由服务映射到私有存储目录。
const SAVE_PATH: String = "quickstart/counter.json"

## 仅属于当前场景的业务状态，读回成功且载荷合法后才覆盖。
var _count: int = 0

## 每次入树和离树均递增，使上一次入树发起的异步等待失去写回资格。
var _entry_serial: int = 0

## 只有当前架构初始化成功后才接受保存、读回和计数操作。
var _ready_for_input: bool = false

## 关闭一旦开始便停止编辑，避免保存之后又出现未保存的修改。
var _closing: bool = false

## 正常关闭失败后，下一次退出请求才视为用户确认放弃正常关闭。
var _shutdown_failed: bool = false

## 记录本入口启动的架构身份；异步初始化返回时必须仍是同一实例。
var _architecture: GFArchitecture = null

## 借用架构管理的 Storage，场景不单独释放这个服务。
var _storage: GFStorageUtility = null

# 控件由 _build_ui() 创建并挂到本场景下，随场景节点一起释放。
var _value_label: Label = null
var _status_label: Label = null
var _quit_button: Button = null
var _edit_buttons: Array[Button] = []


## 为本轮入树分配身份，不允许旧等待仅凭节点实例相同就继续。
func _enter_tree() -> void:
	_entry_serial += 1


## 接管窗口关闭请求，并在控件建立后延迟启动 GF。
func _ready() -> void:
	get_tree().auto_accept_quit = false
	_build_ui()
	_start.call_deferred()


## 让系统窗口关闭与界面按钮共用保存、关闭和失败确认流程。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_quit()


## 离树只撤销界面写回资格；全局架构由应用退出流程显式关闭。
func _exit_tree() -> void:
	_entry_serial += 1
	_ready_for_input = false


## 注册并初始化本入口拥有的架构；任一步失败都保持编辑入口关闭。
func _start() -> void:
	var serial: int = _entry_serial
	_architecture = Gf.create_architecture()
	if _architecture == null:
		_report_error("无法创建 GF 架构。")
		return
	var registered: bool = await _architecture.register_utility_instance(GFStorageUtility.new())
	# 等待期间可能切场景、离树后重入，或替换全局架构，必须重新确认身份。
	if not _is_current_screen(serial):
		return
	if not registered:
		_report_error("Storage 注册失败。")
		return
	if not _is_current_runtime(serial):
		_report_error("启动使用的架构已改变。")
		return
	var initialized: bool = await Gf.init()
	if not _is_current_screen(serial):
		return
	if not initialized:
		_report_error("GF 初始化失败：" + _architecture.last_initialization_error)
		return
	if not _is_current_runtime(serial):
		_report_error("初始化完成后架构已失效。")
		return
	_storage = _architecture.get_utility(GFStorageUtility) as GFStorageUtility
	if _storage == null:
		_report_error("Storage 不可用。")
		return
	_ready_for_input = true
	_set_edit_enabled(true)
	_quit_button.text = "保存并退出"
	_status_label.text = "就绪；读回只在点击时进行。"


## 创建本场景拥有的控件，服务就绪前只允许退出。
func _build_ui() -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(24.0, 24.0)
	add_child(column)
	_value_label = Label.new()
	column.add_child(_value_label)
	_refresh_count()
	_status_label = Label.new()
	_status_label.text = "正在初始化……"
	column.add_child(_status_label)
	_edit_buttons = [
		_add_button(column, "加一", _increment),
		_add_button(column, "保存", _save_pressed),
		_add_button(column, "读回", _read_pressed),
	]
	_quit_button = _add_button(column, "退出", _request_quit)
	_set_edit_enabled(false)


## 返回挂到 parent 下的按钮，便于调用方后续控制可用状态。
func _add_button(parent: VBoxContainer, title: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = title
	parent.add_child(button)
	var _connected: Error = button.pressed.connect(callback)
	return button


## 仅当前场景、本轮入树且尚未申请删除的节点可接收异步结果。
func _is_current_screen(serial: int) -> bool:
	return (
		serial == _entry_serial
		and is_inside_tree()
		and not is_queued_for_deletion()
		and get_tree().current_scene == self
	)


## 启动结果还必须属于当前全局架构，不能使用被替换的服务容器。
func _is_current_runtime(serial: int) -> bool:
	return (
		_is_current_screen(serial)
		and Gf.has_architecture()
		and Gf.get_architecture() == _architecture
	)


## 统一控制修改和存取按钮；退出按钮由关闭流程单独管理。
func _set_edit_enabled(enabled: bool) -> void:
	for button: Button in _edit_buttons:
		button.disabled = not enabled


## 将内存计数投影到已创建的 Label，不从存储隐式读取数据。
func _refresh_count() -> void:
	_value_label.text = "计数：%d" % _count


## 同时向界面和调试器暴露失败，不改变当前计数或替用户决定退出。
func _report_error(message: String) -> void:
	_status_label.text = message
	push_error(message)


## 只修改场景内存；是否持久化由用户显式保存或退出流程决定。
func _increment() -> void:
	if not _ready_for_input or _closing:
		return
	_count += 1
	_refresh_count()
	_status_label.text = "当前值尚未保存。"


## 按钮入口复用带结果检查的保存流程，由该流程向界面报告失败。
func _save_pressed() -> void:
	var _saved: bool = _save_counter()


## 同步写入这个小载荷；只有 Storage 返回 OK 才允许退出流程继续。
func _save_counter() -> bool:
	if not _ready_for_input or _closing:
		return false
	var error: Error = _storage.save_data(SAVE_PATH, {"count": _count})
	if error != OK:
		_report_error("保存失败，当前值仍保留，可重试：" + error_string(error))
		return false
	_status_label.text = "已保存到 Storage。"
	return true


## 区分无存档、读取失败与非法载荷；全部检查通过后才替换内存计数。
func _read_pressed() -> void:
	if not _ready_for_input or _closing:
		return
	var result: GFStorageReadResult = _storage.load_data(SAVE_PATH)
	if not result.ok:
		if result.failure_kind == GFStorageReadResult.FailureKind.NOT_FOUND:
			_status_label.text = "尚无存档；当前值保持不变，请先保存。"
		else:
			_report_error("读回失败，当前值保持不变：" + result.error)
		return
	var saved_count: int = GFVariantData.to_exact_int(result.payload.get("count"), -1)
	if saved_count < 0:
		_report_error("存档不包含合法计数，当前值保持不变。")
		return
	_count = saved_count
	_refresh_count()
	_status_label.text = "已从磁盘读回。"


## 先保存再关闭架构；关闭失败后保留错误，等待下一次明确退出请求。
func _request_quit() -> void:
	if _shutdown_failed:
		# 架构已进入关闭流程，不能恢复编辑；再次请求表示放弃正常关闭。
		get_tree().quit()
		return
	if _closing:
		return
	if not _ready_for_input:
		get_tree().quit()
		return
	if not _save_counter():
		return
	_closing = true
	_set_edit_enabled(false)
	_quit_button.disabled = true
	_status_label.text = "已保存，正在关闭服务……"
	var serial: int = _entry_serial
	var result: GFArchitectureShutdownResult = await _architecture.shutdown_async(null, 10.0)
	# 关闭仍可能继续完成，但离开本场景后，这个等待不能再操作旧界面或退出新场景。
	if not _is_current_screen(serial):
		return
	if not result.is_successful():
		_shutdown_failed = true
		_report_error("服务未正常关闭：" + result.get_error())
		_quit_button.text = "确认直接退出"
		_quit_button.disabled = false
		return
	get_tree().quit()
```

## 保存与退出边界

这是固定且很小的字典，使用同步 `save_data()` / `load_data()`；保存检查 `Error`，读取检查 `GFStorageReadResult.ok`，缺失存档与损坏、IO 失败分开处理。读回失败不会把当前值清零，保存失败不会继续退出。Storage 把逻辑路径映射到 `user://` 下的私有存储布局，不要按这个逻辑文件名自行拼接物理路径。

窗口关闭请求和按钮走同一条保存、关闭路径；编辑器的停止按钮、进程被终止等强制退出无法等待这段流程。关闭失败会保留错误并停止编辑；再次点击 **确认直接退出** 或再次请求关闭窗口，才放弃正常关闭。`shutdown_async()` 不是保存入口，所以先确认保存成功，再关闭整个应用拥有的 Architecture。每个 `await` 后都检查场景与本轮入树身份，初始化还检查架构身份，旧等待不会接管另一场景或重新入树的节点。

大型载荷或需要界面持续响应时，改用[Storage 请求句柄](../../standard/utilities/io/storage-snapshot/storage-utility.md#异步请求身份)：等待 `wait_physical_result_async()` 并检查 `is_successful()` 后才能宣称写入完成；caller 超时或结束观察不证明磁盘没有写入。等待后仍需核对当前页面、请求身份和业务来源，不能把本例的同步写入结果替换成“入队成功”。

需要共享状态或集中装配时，继续阅读[最小启动与 Installer](minimal-installer.md)。
