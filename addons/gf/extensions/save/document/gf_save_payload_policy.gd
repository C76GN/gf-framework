## GFSavePayloadPolicy: 已知载荷结构与显式保留范围。
##
## schema 只解释项目声明的运行数据；未声明字段及内容条目默认拒绝。
## 保留内容由 Profile 的持久化基线承载，不进入 Provider 的运行投影。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFSavePayloadPolicy
extends Resource


# --- 常量 ---

## 执行载荷投影和身份合并的内部实现。
## [br]
## @api private
const _ROUNDTRIP_SCRIPT = preload("res://addons/gf/extensions/save/document/gf_save_payload_roundtrip.gd")


# --- 导出变量 ---

## 根值声明；field_name 必须非空，根可以是标量、数组或字典。
## [br]
## @api public
## [br]
## @since unreleased
@export var schema: GFSchemaField = null

## 字典节点允许保留的未知字段；空路径表示根，数组元素用 /*。
##
## 路径采用 JSON Pointer 转义；字段名 * 保留给数组元素。列表中的 * 表示明确
## 允许该节点的全部未知字段。已知字段仍必须通过 schema 校验。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @schema retained_fields: Dictionary[String, PackedStringArray]，键为 schema 节点路径，值为允许保留的字段名。
@export var retained_fields: Dictionary = {}

## 有稳定身份的内容集合规则；没有规则的数组不保留按元素关联的未知数据。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @schema collections: Dictionary，键为数组 schema 路径，值含 id_field: StringName/String，可选 active_ids: Array[int/String/StringName] 和 preserve_unknown: bool（默认 false）；省略 active_ids 表示所有身份均已知。
@export var collections: Dictionary = {}

## 载荷及持久化基线的最大嵌套深度。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(1, 64, 1) var max_depth: int = 32

## 单个完整载荷或基线允许的最大节点数。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(1, 100000, 1) var max_nodes: int = 10000

## 规范编码的字节上限；覆盖保留内容，不等于磁盘压缩后的大小。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(1, 67108864, 1) var max_bytes: int = 16777216


# --- 公共方法 ---

## 验证声明及其路径，拒绝隐式转换和无稳定身份的元素保留。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 结构化准入结果。
## [br]
## @schema return: Dictionary，含 ok: bool、error_kind: StringName、path: String。
func validate_policy() -> Dictionary:
	return _ROUNDTRIP_SCRIPT.validate_policy(self)


## 获取此政策当前的有效预算；硬上限仍由 validate_policy() 验证。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 独立预算记录。
## [br]
## @schema return: Dictionary with max_depth:int,max_nodes:int,max_bytes:int.
func get_limits() -> Dictionary:
	return {
		"max_depth": max_depth,
		"max_nodes": max_nodes,
		"max_bytes": max_bytes,
	}


## 只读测量完整载荷的原生值与预算，不创建投影或基线副本。
##
## 先验证政策；成功不代表已知字段通过 schema，完整语义仍由 project() 验证。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param payload: 调用期间保持不变的完整载荷。
## [br]
## @schema payload: 与 project() 相同的 Save 原生持久化值。
## [br]
## @return 预算诊断；失败计量可能仅为已遍历部分。
## [br]
## @schema return: Dictionary with ok:bool,error_kind:StringName,path:String,layer:StringName,limits:Dictionary,observed:Dictionary; observed contains native and optional canonical validation reports.
func measure_payload(payload: Variant) -> Dictionary:
	var validation: Dictionary = validate_policy()
	if not GFVariantData.get_option_bool(validation, "ok"):
		validation["layer"] = &"save_payload_policy"
		validation["limits"] = get_limits()
		validation["observed"] = {}
		return validation
	return _ROUNDTRIP_SCRIPT.measure_payload(self, payload)


## 创建独立政策副本；非法声明返回 null。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 政策副本，不与作者资源共享可变 schema 集合。
func duplicate_policy() -> GFSavePayloadPolicy:
	if not GFVariantData.get_option_bool(
		validate_policy(),
		"ok"
	):
		return null
	var copy: GFSavePayloadPolicy = GFSavePayloadPolicy.new()
	copy.schema = schema.duplicate_field()
	copy.retained_fields = retained_fields.duplicate(true)
	copy.collections = collections.duplicate(true)
	copy.max_depth = max_depth
	copy.max_nodes = max_nodes
	copy.max_bytes = max_bytes
	return copy


## 将完整持久化载荷拆为运行投影与独立持久化基线。
##
## 基线包括已知值，用于稳定身份匹配与无修改往返；它不能直接应用到业务状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param payload: 已通过文档版本检查的载荷。
## [br]
## @schema payload: Variant，属于 Save 的可持久化值。
## [br]
## @return 完整成功结果或不含部分投影的失败。
## [br]
## @schema return: Dictionary，含 ok、error_kind、path；成功另含 projection: Variant、baseline: Variant。
func project(payload: Variant) -> Dictionary:
	return _ROUNDTRIP_SCRIPT.project(self, payload)


## 将当前运行值与旧基线合并，已知当前值和显式删除优先。
##
## 缺少的已知字段/条目视为删除，不能由旧基线复活；未知内容只在声明范围保留。
## 集合重排以当前已知条目顺序为准，未知条目沿原有后继锚点插入。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param projection: 当前运行候选。
## [br]
## @schema projection: Variant，必须符合已知 schema。
## [br]
## @param baseline: 此 Profile/section 上次接受的完整载荷，首次保存可为 null。
## [br]
## @schema baseline: Variant，由 project() 返回的独立基线。
## [br]
## @param deletions: 本次捕获的显式删除指令。
## [br]
## @schema deletions: Dictionary[String, Array]，键为具体字典/集合路径；字典值列出要删除的保留字段名，集合值列出要删除的稳定 ID。数组元素路径使用 item_path()，不用下标。
## [br]
## @return 完整持久化候选及其运行投影。
## [br]
## @schema return: Dictionary，含 ok、error_kind、path；成功另含 payload: Variant、projection: Variant、baseline: Variant。
func merge(
	projection: Variant,
	baseline: Variant,
	deletions: Dictionary = {}
) -> Dictionary:
	return _ROUNDTRIP_SCRIPT.merge(
		self,
		projection,
		baseline,
		deletions
	)


## 构造稳定身份对应的具体元素路径，供删除指令使用。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param collection_path: 所属集合的具体路径。
## [br]
## @param item_id: 整数或非空字符串身份。
## [br]
## @schema item_id: int、String 或 StringName；String 与 StringName 表示同一文本身份。
## [br]
## @return 具体元素路径；身份无效时为空。
static func item_path(collection_path: String, item_id: Variant) -> String:
	return _ROUNDTRIP_SCRIPT.item_path(collection_path, item_id)
