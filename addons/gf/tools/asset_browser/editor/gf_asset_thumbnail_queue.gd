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

## 尚未收到原生完成回调的预览任务上限；撤销视图订阅不会提前腾出任务槽。
## [br]
## @api private
const _MAX_IN_FLIGHT: int = 4

## 单次可见订阅最多接纳的去重资源路径数，超出部分不加入待提交队列。
## [br]
## @api private
const _MAX_VISIBLE: int = 100

## 预览结果缓存的路径容量，超出后按首次进入缓存的顺序淘汰。
## [br]
## @api private
const _MAX_CACHE: int = 128


# --- 私有变量 ---

## 当前可见订阅代次，替换路径或暂停时递增；旧代次的原生结果不能通知当前视图。
## [br]
## @api private
var _generation: int = 0

## 内容缓存的有效期，失效或释放时递增；同一内容代次的旧视图结果仍可填充缓存。
## [br]
## @api private
var _content_revision: int = 0

## 当前订阅尚未提交的路径队列；新订阅和暂停均清空，不包含已经交给原生服务的任务。
## [br]
## @api private
var _pending: PackedStringArray = PackedStringArray()

## 当前视图订阅的路径集合，用于去重及过滤完成通知；不代表原生在途任务集合。
## [br]
## @api private
var _visible: Dictionary = {}

## 以视图代次、内容代次和路径组成任务键，提交前占槽，收到相应回调时清槽；暂停或释放不取消原生任务。
## [br]
## @api private
var _in_flight: Dictionary = {}

## 按路径保留预览纹理或 null 结果；null 也视为缓存命中，内容失效或释放时全部清空。
## [br]
## @api private
var _cache: Dictionary = {}

## 缓存路径首次插入的顺序，用于容量淘汰；命中或更新已有路径不会把它移动到末尾。
## [br]
## @api private
var _cache_order: PackedStringArray = PackedStringArray()

## 借用编辑器提供的原生预览服务；释放队列时仅清空引用，不销毁该服务。
## [br]
## @api private
var _previewer: EditorResourcePreview = null

## 释放后阻止提交、缓存写入及完成通知；晚到回调仍先归还在途槽，setup 才重新开放队列。
## [br]
## @api private
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

## 在原生在途上限内消费待提交路径；缓存命中会同步发出结果，未命中则先占槽再提交携带两种代次的原生请求。
## [br]
## @api private
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

## 从字典回传信息归还在途槽，再按释放状态和内容代次决定是否缓存；只有路径仍可见且视图代次匹配才通知，最后延迟继续排队。
## [br]
## @api private
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
