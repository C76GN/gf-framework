## GFDataBatchBackend: 可选同步 PackedArray gather 协议。
##
## 后端只计算列，不拥有 GF 的 schema、版本或发布权。输入在调用期间只读且不得保留；
## 输出必须独立拥有，类型、顺序和整数值精确保持。返回空数组表示失败，不允许部分结果。
## 这是同进程可信代码边界，不是 native sandbox；首版仅在主线程调用，不启动后台任务。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 12.0.0
class_name GFDataBatchBackend
extends RefCounted


# --- 公共方法 ---

## 返回协议版本；发布者只接受版本 1，构造后不再切换后端。
## [br]
## @api public
## [br]
## @since 12.0.0
## [br]
## @return: 已实现协议版本；默认零表示不可用。
func get_protocol_version() -> int:
	return 0


## 判断固定数值类型是否支持，禁止隐式数值转换。
## [br]
## @api public
## [br]
## @since 12.0.0
## [br]
## @param _numeric_type: GFDataBatchSchema.NumericType 值。
## [br]
## @return: 能精确执行 gather 时为 true。
func supports_type(_numeric_type: int) -> bool:
	return false


## 提供额外临时 payload 的保守上界，GF 在调用前计入峰值预算。
## [br]
## @api public
## [br]
## @since 12.0.0
## [br]
## @param _output_bytes: 已由 GF 计算的全部输出列 payload。
## [br]
## @return: 非负额外字节数；负值表示拒绝。零表示没有额外 payload 缓冲。
func get_scratch_bytes(_output_bytes: int) -> int:
	return 0


## 批量选择记录，禁止更改输入、回调项目或重入发布；失败不得返回部分列。
## [br]
## @api public
## [br]
## @since 12.0.0
## [br]
## @param _columns: GF 已验证的有序只读列，后端仍负责原生内存访问边界。
## [br]
## @schema _columns: Array containing only PackedInt32Array or PackedInt64Array, ordered by the publication schema.
## [br]
## @param _indices: 已验证的零起始选择位置，保留顺序和重复项。
## [br]
## @param _source_count: 有效前缀长度，不能使用 capacity 尾部。
## [br]
## @return: 完整独立输出列，长度均等于 indices.size；失败为空。
## [br]
## @schema return: Array of PackedInt32Array or PackedInt64Array matching input types and column order, or empty on failure. Caller takes exclusive ownership; backend retains no output aliases.
func gather(
	_columns: Array,
	_indices: PackedInt32Array,
	_source_count: int
) -> Array:
	return []
