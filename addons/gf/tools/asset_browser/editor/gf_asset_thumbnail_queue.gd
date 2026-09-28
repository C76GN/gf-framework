@tool

# 原生预览的有界可见项队列。取消只撤销订阅，原生在途任务仍计入上限。
extends RefCounted


# --- 信号 ---

## 当前可见请求完成；texture 为 null 时使用方保留类型图标。
## [br]
## @api framework_internal
## [br]
## @param path: 资源路径。
## [br]
## @param texture: 原生预览或 null。
## [br]
## @param generation: 当前视图代次。
signal preview_ready(path: String, texture: Texture2D, generation: int)


# --- 常量 ---

const _MAX_IN_FLIGHT: int = 4
const _MAX_VISIBLE: int = 100
const _MAX_CACHE: int = 128


# --- 私有变量 ---

var _generation: int = 0
var _content_revision: int = 0
var _pending: PackedStringArray = PackedStringArray()
var _visible: Dictionary = {}
var _in_flight: Dictionary = {}
var _cache: Dictionary = {}
var _cache_order: PackedStringArray = PackedStringArray()
var _previewer: EditorResourcePreview = null
var _disposed: bool = false


# --- 框架内部方法 ---

## 绑定原生预览器；调用方只在真实编辑器生命周期提供它。
## [br]
## @api framework_internal
## [br]
## @param previewer: 原生预览服务。
func setup(previewer: EditorResourcePreview) -> void:
	_previewer = previewer
	_disposed = false


## 替换可见订阅，并将旧在途回调与当前视图隔离。
## [br]
## @api framework_internal
## [br]
## @param paths: 最多一页的项目资源路径。
## [br]
## @return 当前视图代次。
func request_visible(paths: PackedStringArray) -> int:
	_generation += 1
	_pending.clear()
	_visible.clear()
	for path: String in paths:
		if _visible.size() >= _MAX_VISIBLE:
			break
		if not path.begins_with("res://") or _visible.has(path):
			continue
		_visible[path] = true
		var _appended: bool = _pending.append(path)
	_pump.call_deferred()
	return _generation


## 内容改变时清除缓存；在途结果仍占槽但不能进入缓存或新视图。
## [br]
## @api framework_internal
func invalidate() -> void:
	_content_revision += 1
	_cache.clear()
	_cache_order.clear()
	var paths: PackedStringArray = PackedStringArray()
	for path: String in _visible:
		var _appended: bool = paths.append(path)
	var _next_generation: int = request_visible(paths)


## 隐藏页面时停止新提交并作废旧订阅。
## [br]
## @api framework_internal
func pause() -> void:
	_generation += 1
	_pending.clear()
	_visible.clear()


## 卸载后不接收原生晚到结果，不保留纹理与服务引用。
## [br]
## @api framework_internal
func dispose() -> void:
	pause()
	_content_revision += 1
	_disposed = true
	_cache.clear()
	_cache_order.clear()
	_previewer = null


# --- 私有/辅助方法 ---

func _pump() -> void:
	if _disposed or _previewer == null:
		return
	while not _pending.is_empty() and _in_flight.size() < _MAX_IN_FLIGHT:
		var path: String = _pending[0]
		_pending.remove_at(0)
		if _cache.has(path):
			var cached: Variant = _cache[path]
			var texture: Texture2D = cached if cached is Texture2D else null
			preview_ready.emit(path, texture, _generation)
			continue
		var request_key: String = "%d:%d:%s" % [_generation, _content_revision, path]
		_in_flight[request_key] = true
		_previewer.queue_resource_preview(path, self, &"_on_preview_ready", {
			"key": request_key, "generation": _generation, "revision": _content_revision,
		})


# --- 信号处理函数 ---

func _on_preview_ready(path: String, preview: Texture2D, small_preview: Texture2D, userdata: Variant) -> void:
	if not userdata is Dictionary:
		return
	var request: Dictionary = userdata
	var request_key: String = GFVariantData.get_option_string(request, "key")
	var _removed: bool = _in_flight.erase(request_key)
	if _disposed:
		return
	if GFVariantData.get_option_int(request, "revision", -1) == _content_revision:
		var texture: Texture2D = preview if preview != null else small_preview
		if not _cache.has(path):
			var _appended: bool = _cache_order.append(path)
		_cache[path] = texture
		while _cache_order.size() > _MAX_CACHE:
			var oldest: String = _cache_order[0]
			_cache_order.remove_at(0)
			var _evicted: bool = _cache.erase(oldest)
		if _visible.has(path) and GFVariantData.get_option_int(request, "generation", -1) == _generation:
			preview_ready.emit(path, texture, _generation)
	_pump.call_deferred()
