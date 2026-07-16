## GFSourceTextLoader: 受根路径约束的源码文本加载器。
##
## 将逻辑 key 解析、文本加载、内存注册文本、缓存 key 和诊断报告拆开，
## 供生成器、导入器、编辑器工具或校验器读取 UTF-8 文本。文件访问默认要求
## root_path，避免 include 或片段加载越过调用方声明的根目录。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFSourceTextLoader
extends RefCounted


# --- 公共变量 ---

## 文件加载根路径；读取文件时必须非空。
## [br]
## @api public
## [br]
## @since 7.0.0
var root_path: String = ""

## 是否允许读取通过 register_text() 注册的内存文本。
## [br]
## @api public
## [br]
## @since 7.0.0
var allow_registered_text: bool = true

## 是否允许调用自定义文本加载器。
## [br]
## @api public
## [br]
## @since 8.0.0
var allow_custom_loaders: bool = true

## 是否允许文件系统访问。
## [br]
## @api public
## [br]
## @since 7.0.0
var allow_file_access: bool = true

## 是否缓存加载结果。
## [br]
## @api public
## [br]
## @since 7.0.0
var cache_enabled: bool = true

## 最大文本字节数；小于等于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_bytes: int = 0

## 调用方附加元数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema metadata: Dictionary，包含调用方定义的加载器上下文。
var metadata: Dictionary = {}


# --- 私有变量 ---

var _registered_texts: Dictionary = {}
var _custom_loaders: Array[Dictionary] = []
var _cache: Dictionary = {}
var _report: GFValidationReport = GFValidationReport.new("Source text loader")


# --- Godot 生命周期方法 ---

## 创建源码文本加载器。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param p_root_path: 文件加载根路径。
## [br]
## @param options: 可选配置，支持 allow_registered_text、allow_custom_loaders、allow_file_access、cache_enabled、max_bytes、subject 和 metadata。
## [br]
## @schema options: Dictionary，包含加载器配置。
func _init(p_root_path: String = "", options: Dictionary = {}) -> void:
	var _configured_loader: GFSourceTextLoader = configure(p_root_path, options)


# --- 公共方法 ---

## 配置加载器并清空诊断。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param p_root_path: 文件加载根路径。
## [br]
## @param options: 可选配置，支持 allow_registered_text、allow_custom_loaders、allow_file_access、cache_enabled、max_bytes、subject 和 metadata。
## [br]
## @return 当前加载器。
## [br]
## @schema options: Dictionary，包含加载器配置。
func configure(p_root_path: String = "", options: Dictionary = {}) -> GFSourceTextLoader:
	root_path = _normalize_path(p_root_path)
	allow_registered_text = GFVariantData.get_option_bool(options, "allow_registered_text", allow_registered_text)
	allow_custom_loaders = GFVariantData.get_option_bool(options, "allow_custom_loaders", allow_custom_loaders)
	allow_file_access = GFVariantData.get_option_bool(options, "allow_file_access", allow_file_access)
	cache_enabled = GFVariantData.get_option_bool(options, "cache_enabled", cache_enabled)
	max_bytes = maxi(GFVariantData.get_option_int(options, "max_bytes", max_bytes), 0)
	metadata = GFVariantData.get_option_dictionary(options, "metadata", metadata)
	_report = GFValidationReport.new(GFVariantData.get_option_string(options, "subject", "Source text loader"), metadata)
	return self


## 清空注册文本、自定义加载器、缓存和诊断。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_registered_texts.clear()
	_custom_loaders.clear()
	_cache.clear()
	_report = GFValidationReport.new("Source text loader")


## 清空加载结果缓存。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear_cache() -> void:
	_cache.clear()


## 注册内存文本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param source_key: 逻辑 key。
## [br]
## @param text: 文本内容。
## [br]
## @param entry_metadata: 条目元数据。
## [br]
## @return 注册成功时返回 true。
## [br]
## @schema entry_metadata: Dictionary，包含调用方定义的文本条目上下文。
func register_text(source_key: String, text: String, entry_metadata: Dictionary = {}) -> bool:
	if source_key.is_empty():
		return false
	_registered_texts[source_key] = {
		"text": text,
		"metadata": entry_metadata.duplicate(true),
	}
	var _cache_erase_result: bool = _cache.erase(source_key)
	return true


## 移除注册文本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param source_key: 逻辑 key。
## [br]
## @return 移除成功时返回 true。
func unregister_text(source_key: String) -> bool:
	var _cache_erase_result: bool = _cache.erase(source_key)
	return _registered_texts.erase(source_key)


## 添加一个自定义文本加载器。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param loader: 自定义加载回调。
## [br]
## @param loader_metadata: 加载器元数据。
## [br]
## @return 添加成功时返回 true。
## [br]
## @schema loader: Callable，会以 (source_key: String, context: Dictionary) 调用；返回 null 或 { "handled": false } 表示继续尝试后续来源，返回 String、PackedByteArray，或包含 text/content/bytes 的 Dictionary 表示已加载。
## [br]
## @schema loader_metadata: Dictionary，会复制进回调上下文和加载结果。
func add_custom_loader(loader: Callable, loader_metadata: Dictionary = {}) -> bool:
	if not loader.is_valid():
		return false
	_custom_loaders.append({
		"loader": loader,
		"metadata": loader_metadata.duplicate(true),
	})
	return true


## 清空全部自定义文本加载器和缓存。
## [br]
## @api public
## [br]
## @since 8.0.0
func clear_custom_loaders() -> void:
	_custom_loaders.clear()
	clear_cache()


## 解析逻辑 key。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param source_key: 逻辑 key 或 root_path 内的相对路径。
## [br]
## @param caller_span: 可选调用点源码定位。
## [br]
## @return 解析结果字典。
## [br]
## @schema caller_span: Variant，可传 GFSourceSpan 或兼容字典。
## [br]
## @schema return: Dictionary，包含 ok、source_key、resolved_path、cache_key、registered 和 report。
func resolve_key(source_key: String, caller_span: Variant = null) -> Dictionary:
	if source_key.is_empty():
		return _failure(&"empty_key", "Source text key is empty.", caller_span, { "source_key": source_key })

	if allow_registered_text and _registered_texts.has(source_key):
		return GFResultDictionary.make_success({
			"source_key": source_key,
			"resolved_path": source_key,
			"cache_key": source_key,
			"registered": true,
			"root_path": root_path,
			"report": duplicate_report(),
		})

	if not allow_file_access:
		return _failure(&"file_access_disabled", "Source text file access is disabled.", caller_span, { "source_key": source_key })
	if root_path.is_empty():
		return _failure(&"missing_root_path", "Source text root_path is required for file access.", caller_span, { "source_key": source_key })

	var normalized_root: String = _normalize_path(root_path)
	var resolved_path: String = _resolve_file_path(source_key, normalized_root)
	if not _is_under_root(resolved_path, normalized_root):
		return _failure(
			&"path_outside_root",
			"Source text path is outside root_path.",
			caller_span,
			{
				"source_key": source_key,
				"root_path": normalized_root,
				"resolved_path": resolved_path,
			}
		)

	return GFResultDictionary.make_success({
		"source_key": source_key,
		"resolved_path": resolved_path,
		"cache_key": resolved_path,
		"registered": false,
		"root_path": normalized_root,
		"report": duplicate_report(),
	})


## 加载 UTF-8 文本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param source_key: 逻辑 key 或 root_path 内的相对路径。
## [br]
## @param caller_span: 可选调用点源码定位。
## [br]
## @return 加载结果字典。
## [br]
## @schema caller_span: Variant，可传 GFSourceSpan 或兼容字典。
## [br]
## @schema return: Dictionary，包含 ok、text、content_hash、byte_size、source_key、resolved_path、registered、custom_loader、from_cache 和 report。
func load_text(source_key: String, caller_span: Variant = null) -> Dictionary:
	if source_key.is_empty():
		return resolve_key(source_key, caller_span)

	if not (allow_registered_text and _registered_texts.has(source_key)):
		var custom_result: Dictionary = _load_custom_text(source_key, caller_span)
		if not custom_result.is_empty():
			return custom_result

	var resolved: Dictionary = resolve_key(source_key, caller_span)
	if not GFResultDictionary.is_ok(resolved):
		return resolved

	var cache_key: String = GFVariantData.get_option_string(resolved, "cache_key")
	if cache_enabled and _cache.has(cache_key):
		var cached: Dictionary = GFVariantData.get_option_dictionary(_cache, cache_key)
		cached["from_cache"] = true
		cached["report"] = duplicate_report()
		return GFResultDictionary.normalize(cached, true)

	var result: Dictionary
	if GFVariantData.get_option_bool(resolved, "registered", false):
		result = _load_registered_text(source_key, resolved, caller_span)
	else:
		result = _load_file_text(GFVariantData.get_option_string(resolved, "resolved_path"), resolved, caller_span)

	if cache_enabled and GFResultDictionary.is_ok(result):
		_cache[cache_key] = result.duplicate(true)
	return result


## 获取当前报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 校验报告。
func get_report() -> GFValidationReport:
	return _report


## 创建报告副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 校验报告副本。
func duplicate_report() -> GFValidationReport:
	var duplicated: RefCounted = _report.duplicate_report()
	if duplicated is GFValidationReport:
		var report: GFValidationReport = duplicated
		return report
	return GFValidationReport.new("Source text loader")


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 加载器状态字典。
## [br]
## @schema return: Dictionary，包含 root、缓存和注册文本状态。
func get_debug_snapshot() -> Dictionary:
	return {
		"root_path": root_path,
		"allow_registered_text": allow_registered_text,
		"allow_custom_loaders": allow_custom_loaders,
		"allow_file_access": allow_file_access,
		"cache_enabled": cache_enabled,
		"max_bytes": max_bytes,
		"registered_count": _registered_texts.size(),
		"custom_loader_count": _custom_loaders.size(),
		"cache_count": _cache.size(),
		"issue_count": _report.issues.size(),
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _load_registered_text(source_key: String, resolved: Dictionary, caller_span: Variant) -> Dictionary:
	var entry: Dictionary = GFVariantData.get_option_dictionary(_registered_texts, source_key)
	var text: String = GFVariantData.get_option_string(entry, "text")
	return _make_loaded_result(text, resolved, true, false, caller_span, GFVariantData.get_option_dictionary(entry, "metadata"))


func _load_file_text(path: String, resolved: Dictionary, caller_span: Variant) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure(&"file_not_found", "Source text file does not exist.", caller_span, resolved)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure(
			&"open_failed",
			"Source text file could not be opened: %s" % error_string(FileAccess.get_open_error()),
			caller_span,
			resolved
		)

	var byte_size: int = int(file.get_length())
	if max_bytes > 0 and byte_size > max_bytes:
		file.close()
		return _failure(&"file_too_large", "Source text file exceeds max_bytes.", caller_span, resolved)

	var text: String = file.get_as_text()
	file.close()
	return _make_loaded_result(text, resolved, false, false, caller_span)


func _load_custom_text(source_key: String, caller_span: Variant) -> Dictionary:
	if not allow_custom_loaders or _custom_loaders.is_empty():
		return {}

	var cache_key: String = _make_custom_cache_key(source_key)
	if cache_enabled and _cache.has(cache_key):
		var cached: Dictionary = GFVariantData.get_option_dictionary(_cache, cache_key)
		cached["from_cache"] = true
		cached["report"] = duplicate_report()
		return GFResultDictionary.normalize(cached, true)

	for loader_index: int in range(_custom_loaders.size()):
		var entry: Dictionary = GFVariantData.as_dictionary(_custom_loaders[loader_index])
		var loader_value: Variant = GFVariantData.get_option_value(entry, "loader")
		if not (loader_value is Callable):
			continue
		var loader: Callable = loader_value
		if not loader.is_valid():
			continue

		var loader_metadata: Dictionary = GFVariantData.get_option_dictionary(entry, "metadata")
		var raw_result: Variant = loader.call(source_key, _make_custom_loader_context(source_key, loader_index, loader_metadata, caller_span))
		var normalized: Dictionary = _normalize_custom_loader_result(
			raw_result,
			source_key,
			cache_key,
			loader_index,
			caller_span,
			loader_metadata
		)
		if normalized.is_empty():
			continue
		if cache_enabled and GFResultDictionary.is_ok(normalized):
			_cache[cache_key] = normalized.duplicate(true)
		return normalized
	return {}


func _make_loaded_result(
	text: String,
	resolved: Dictionary,
	registered: bool,
	from_cache: bool,
	caller_span: Variant,
	entry_metadata: Dictionary = {}
) -> Dictionary:
	var byte_size: int = text.to_utf8_buffer().size()
	if max_bytes > 0 and byte_size > max_bytes:
		return _failure(&"text_too_large", "Source text exceeds max_bytes.", caller_span, resolved)
	var source_key: String = GFVariantData.get_option_string(resolved, "source_key")
	var resolved_path: String = GFVariantData.get_option_string(resolved, "resolved_path")
	return GFResultDictionary.make_success({
		"source_key": source_key,
		"resolved_path": resolved_path,
		"cache_key": GFVariantData.get_option_string(resolved, "cache_key"),
		"registered": registered,
		"custom_loader": GFVariantData.get_option_bool(resolved, "custom_loader", false),
		"from_cache": from_cache,
		"text": text,
		"content": text,
		"content_hash": text.sha256_text(),
		"byte_size": byte_size,
		"root_path": root_path,
		"entry_metadata": entry_metadata.duplicate(true),
		"report": duplicate_report(),
	})


func _normalize_custom_loader_result(
	raw_result: Variant,
	source_key: String,
	cache_key: String,
	loader_index: int,
	caller_span: Variant,
	loader_metadata: Dictionary
) -> Dictionary:
	if raw_result == null:
		return {}
	if raw_result is String:
		var text: String = raw_result
		return _make_custom_loaded_result(text, {}, source_key, cache_key, loader_index, caller_span, loader_metadata)
	if raw_result is PackedByteArray:
		var bytes: PackedByteArray = raw_result
		return _make_custom_loaded_result(bytes.get_string_from_utf8(), {}, source_key, cache_key, loader_index, caller_span, loader_metadata)
	if raw_result is Dictionary:
		var data: Dictionary = GFVariantData.as_dictionary(raw_result)
		if data.has("handled") and not GFVariantData.get_option_bool(data, "handled", false):
			return {}
		if data.has(GFResultDictionary.KEY_OK) and not GFResultDictionary.is_ok(data, true):
			return _make_custom_loader_failure(data, source_key, loader_index, caller_span)
		if data.has("text"):
			return _make_custom_text_value_result(data["text"], data, source_key, cache_key, loader_index, caller_span, loader_metadata)
		if data.has("content"):
			return _make_custom_text_value_result(data["content"], data, source_key, cache_key, loader_index, caller_span, loader_metadata)
		if data.has("bytes"):
			return _make_custom_text_value_result(data["bytes"], data, source_key, cache_key, loader_index, caller_span, loader_metadata)
		if GFVariantData.get_option_bool(data, "handled", false):
			return _failure(&"invalid_custom_loader_result", "Custom source text loader returned no text.", caller_span, {
				"source_key": source_key,
				"custom_loader": true,
				"loader_index": loader_index,
			})
		return {}
	return _failure(&"invalid_custom_loader_result", "Custom source text loader returned an unsupported value.", caller_span, {
		"source_key": source_key,
		"custom_loader": true,
		"loader_index": loader_index,
	})


func _make_custom_text_value_result(
	text_value: Variant,
	data: Dictionary,
	source_key: String,
	cache_key: String,
	loader_index: int,
	caller_span: Variant,
	loader_metadata: Dictionary
) -> Dictionary:
	if text_value is String:
		var text: String = text_value
		return _make_custom_loaded_result(text, data, source_key, cache_key, loader_index, caller_span, loader_metadata)
	if text_value is PackedByteArray:
		var bytes: PackedByteArray = text_value
		return _make_custom_loaded_result(bytes.get_string_from_utf8(), data, source_key, cache_key, loader_index, caller_span, loader_metadata)
	return _failure(&"invalid_custom_loader_result", "Custom source text loader text must be String or PackedByteArray.", caller_span, {
		"source_key": source_key,
		"custom_loader": true,
		"loader_index": loader_index,
	})


func _make_custom_loaded_result(
	text: String,
	data: Dictionary,
	source_key: String,
	cache_key: String,
	loader_index: int,
	caller_span: Variant,
	loader_metadata: Dictionary
) -> Dictionary:
	var entry_metadata: Dictionary = loader_metadata.duplicate(true)
	var _merged_metadata: Dictionary = GFVariantData.merge_dictionary(
		entry_metadata,
		GFVariantData.get_option_dictionary(data, "metadata"),
		true,
		true
	)
	var resolved: Dictionary = {
		"source_key": source_key,
		"resolved_path": GFVariantData.get_option_string(data, "resolved_path", source_key),
		"cache_key": cache_key,
		"registered": false,
		"custom_loader": true,
		"root_path": root_path,
		"report": duplicate_report(),
	}
	var result: Dictionary = _make_loaded_result(text, resolved, false, false, caller_span, entry_metadata)
	result["custom_loader"] = true
	result["loader_index"] = loader_index
	return result


func _make_custom_loader_failure(data: Dictionary, source_key: String, loader_index: int, caller_span: Variant) -> Dictionary:
	var reason: StringName = GFVariantData.get_option_string_name(data, GFResultDictionary.KEY_REASON, &"custom_loader_failed")
	var message: String = GFVariantData.get_option_string(data, GFResultDictionary.KEY_MESSAGE, "Custom source text loader failed.")
	_add_error(reason, message, caller_span, {
		"source_key": source_key,
		"custom_loader": true,
		"loader_index": loader_index,
	})
	var result: Dictionary = GFResultDictionary.normalize(data, false)
	result["source_key"] = source_key
	result["custom_loader"] = true
	result["loader_index"] = loader_index
	result["report"] = duplicate_report()
	return result


func _failure(reason: StringName, message: String, caller_span: Variant, fields: Dictionary = {}) -> Dictionary:
	_add_error(reason, message, caller_span, fields)
	var result: Dictionary = fields.duplicate(true)
	result["report"] = duplicate_report()
	return GFResultDictionary.make_rejected(reason, message, result)


func _add_error(reason: StringName, message: String, caller_span: Variant, fields: Dictionary) -> void:
	var issue_metadata: Dictionary = metadata.duplicate(true)
	var _merged_fields: Dictionary = GFVariantData.merge_dictionary(issue_metadata, fields, true, true)
	if caller_span is GFSourceSpan or caller_span is Dictionary:
		var _source_issue: RefCounted = _report.add_source_error(reason, message, caller_span, null, "", issue_metadata)
	else:
		var _issue: RefCounted = _report.add_error(reason, message, null, "", issue_metadata)


static func _resolve_file_path(source_key: String, normalized_root: String) -> String:
	var normalized_key: String = _normalize_path(source_key)
	if _is_absolute_source_path(normalized_key):
		return normalized_key
	return _normalize_path(normalized_root.path_join(source_key))


static func _normalize_path(path: String) -> String:
	var normalized: String = path.replace("\\", "/").simplify_path()
	if normalized == "res://" or normalized == "user://":
		return normalized
	return normalized.trim_suffix("/")


static func _is_under_root(path: String, root: String) -> bool:
	var normalized_path: String = _normalize_path(path)
	var normalized_root: String = _normalize_path(root)
	if normalized_root.is_empty() or normalized_path.is_empty():
		return false
	var comparable_path: String = _to_comparable_path(normalized_path)
	var comparable_root: String = _to_comparable_path(normalized_root)
	return comparable_path == comparable_root or comparable_path.begins_with("%s/" % comparable_root)


static func _is_absolute_source_path(path: String) -> bool:
	return path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path()


static func _to_comparable_path(path: String) -> String:
	var normalized: String = _normalize_path(path)
	if normalized.find(":") >= 0 and not normalized.begins_with("res://") and not normalized.begins_with("user://"):
		return normalized.to_lower()
	return normalized


static func _make_custom_loader_context(source_key: String, loader_index: int, loader_metadata: Dictionary, caller_span: Variant) -> Dictionary:
	return {
		"source_key": source_key,
		"loader_index": loader_index,
		"caller_span": caller_span,
		"loader_metadata": loader_metadata.duplicate(true),
	}


static func _make_custom_cache_key(source_key: String) -> String:
	return "custom:%s" % source_key
