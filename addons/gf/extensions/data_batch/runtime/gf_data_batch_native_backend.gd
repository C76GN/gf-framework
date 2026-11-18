## GFDataBatchNativeBackend: 连接可选的原生 PackedArray gather 服务。
##
## 仅连接项目已经安装并加载的 GDExtension，不安装二进制、不运行编译器。
## 发布者默认尝试连接，当前分发 Windows x64 实现。项目也可以显式取得适配器。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 12.0.0
class_name GFDataBatchNativeBackend
extends GFDataBatchBackend


# --- 常量 ---

## 参考实现向引擎登记服务时使用的名称和原生类名。
## [br]
## @api private
const _NATIVE_SERVICE: StringName = &"GfPackedGatherBackend"


# --- 私有变量 ---

## 已验证的无状态计算服务，由扩展在引擎中注册并管理生命期。
## [br]
## @api private
var _native: Object = null


# --- 公共方法 ---

## 在主线程连接已加载的参考后端。每次调用创建独立适配器，计算服务由引擎管理。
## [br]
## @api public
## [br]
## @since 12.0.0
## [br]
## @return: 已加载的协议 1 后端。其他线程、服务缺失或协议不兼容时返回 null。
static func create() -> GFDataBatchNativeBackend:
	if not Thread.is_main_thread() or not Engine.has_singleton(_NATIVE_SERVICE):
		return null
	var native: Object = Engine.get_singleton(_NATIVE_SERVICE)
	if not is_instance_valid(native) or not native.is_class(_NATIVE_SERVICE):
		return null
	if not native.has_method(&"protocol_version") or not native.has_method(&"gather"):
		return null
	var version: Variant = native.call(&"protocol_version")
	if not version is int or version != 1:
		return null
	var backend: GFDataBatchNativeBackend = GFDataBatchNativeBackend.new()
	backend._native = native
	return backend


## 返回参考后端的固定协议身份。
## [br]
## @api public
## [br]
## @since 12.0.0
## [br]
## @return: 已连接为 1，否则为零。
func get_protocol_version() -> int:
	return 1 if is_instance_valid(_native) else 0


## 参考后端只支持精确 Int32 和 Int64 gather。
## [br]
## @api public
## [br]
## @since 12.0.0
## [br]
## @param numeric_type: GFDataBatchSchema.NumericType 值。
## [br]
## @return: 已连接且类型受支持时为 true。
func supports_type(numeric_type: int) -> bool:
	return is_instance_valid(_native) and numeric_type in [GFDataBatchSchema.NumericType.INT32, GFDataBatchSchema.NumericType.INT64]


## 同步跨原生边界一次，返回完整输出或失败空数组。
## [br]
## @api public
## [br]
## @since 12.0.0
## [br]
## @param columns: 调用期间只读的有序 PackedArray 列。
## [br]
## @schema columns: Array of PackedInt32Array or PackedInt64Array with source_count valid elements.
## [br]
## @param indices: 保留顺序和重复的已校验选择。
## [br]
## @param source_count: 有效前缀长度。
## [br]
## @return: 精确类型的独立列；原生调用拒绝时为空。
## [br]
## @schema return: Array matching input column types, each length equal to indices.size, or empty on failure.
func gather(
	columns: Array,
	indices: PackedInt32Array,
	source_count: int
) -> Array:
	if not Thread.is_main_thread() or not is_instance_valid(_native):
		return []
	var result: Variant = _native.call(
		&"gather",
		columns,
		indices,
		source_count
	)
	if result is Array:
		var output: Array = result
		return output
	return []
