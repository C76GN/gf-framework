## GFSaveProfileMutationRequest: mutate-and-persist 的一次性所有权请求。
##
## 请求在创建时原子接管每个 `GFSaveSectionMutation`，随后只允许协调器 claim
## 一次。调用方必须放弃传入的 Dictionary、Array 及其全部嵌套 alias；请求
## 不公开任何候选 payload getter，也不接受 Callable 或可执行 patch。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFSaveProfileMutationRequest
extends RefCounted


# --- 常量 ---

const _PERSISTED_VALUE_VALIDATOR_SCRIPT = preload(
	"res://addons/gf/extensions/save/core/gf_save_persisted_value_validator.gd"
)
const _MAX_EPHEMERAL_DEPTH: int = 64
const _MAX_EPHEMERAL_ITEMS: int = 100_000


# --- 私有变量 ---

var _ready: bool = false
var _claimed: bool = false
var _mutation_records: Array[Dictionary] = []
var _document_metadata: Dictionary = {}
var _context: Dictionary = {}
var _result_metadata: Dictionary = {}


# --- 公共方法 ---

## 创建请求并接管全部候选 section 与元数据。
##
## Mutation 必须非空、可用且 section ID 唯一。方法会先完成全部预检，再按输入
## 顺序 claim，因而校验失败不会部分消费 Mutation。输入顺序只用于所有权收集；
## 协调器始终按已注册 Profile 的 Provider 顺序 capture/apply。成功返回后，调用方必须永久
## 放弃 mutations 数组、三个 Dictionary 及其全部嵌套 alias。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param mutations: 待接管的完整候选 sections；输入顺序不定义应用顺序。
## [br]
## @param document_metadata: 写入候选文档的持久化元数据。
## [br]
## @param context: Provider 操作使用的临时纯数据上下文。
## [br]
## @param result_metadata: 只写入当前事务结果的调用方纯数据元数据。
## [br]
## @schema document_metadata: Dictionary accepted by the Save persisted-value contract whose source aliases are abandoned after success.
## [br]
## @schema context: Bounded Dictionary without Callable, Signal, RID, Object, or circular references whose source aliases are abandoned after success.
## [br]
## @schema result_metadata: Bounded Dictionary without Callable, Signal, RID, Object, or circular references whose source aliases are abandoned after success.
## [br]
## @return 可用请求；输入无效时返回 null，且不消费任何 Mutation。
static func take_ownership(
	mutations: Array[GFSaveSectionMutation],
	document_metadata: Dictionary = {},
	context: Dictionary = {},
	result_metadata: Dictionary = {}
) -> GFSaveProfileMutationRequest:
	if mutations.is_empty():
		return null
	var document_report: Dictionary = _PERSISTED_VALUE_VALIDATOR_SCRIPT.validate(
		document_metadata
	)
	if not GFVariantData.get_option_bool(document_report, "ok", false):
		return null
	if not _is_ephemeral_dictionary_supported(context):
		return null
	if not _is_ephemeral_dictionary_supported(result_metadata):
		return null

	var section_ids: Dictionary = {}
	for mutation: GFSaveSectionMutation in mutations:
		if mutation == null or not mutation.is_available():
			return null
		var section_id: StringName = mutation.get_section_id()
		if section_id == &"" or section_ids.has(section_id):
			return null
		section_ids[section_id] = true

	var records: Array[Dictionary] = []
	for mutation: GFSaveSectionMutation in mutations:
		var record: Dictionary = mutation.claim_for_framework()
		if record.is_empty():
			# 预检后仅当前同步调用可 claim；若契约被外部重入破坏，释放已接管记录。
			for claimed_record: Dictionary in records:
				claimed_record.clear()
			return null
		records.append(record)

	var request: GFSaveProfileMutationRequest = GFSaveProfileMutationRequest.new()
	request._mutation_records = records
	request._document_metadata = document_metadata
	request._context = context
	request._result_metadata = result_metadata
	request._ready = true
	return request


## 检查请求是否仍可由协调器接管。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 尚未 claim 时返回 true。
func is_available() -> bool:
	return _ready and not _claimed


## 检查请求是否已经被协调器接管。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已成功 claim 时返回 true。
func is_claimed() -> bool:
	return _claimed


## 获取候选 section 数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 尚未 claim 时返回候选数；claim 后为 0。
func get_mutation_count() -> int:
	return _mutation_records.size()


## 获取候选 section ID 的隔离快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 按请求收集顺序排列的 section ID；不包含候选载荷。
func get_section_ids() -> PackedStringArray:
	var section_ids: PackedStringArray = PackedStringArray()
	for record: Dictionary in _mutation_records:
		var _appended: bool = section_ids.append(
			String(GFVariantData.get_option_string_name(record, "section_id"))
		)
	return section_ids


# --- 框架内部方法 ---

## 获取不含请求载荷的所有权快照。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 包含 available、claimed、mutation_count、section_ids 和 mutations 的快照。
## [br]
## @schema return: Payload-free Dictionary with available, claimed, mutation_count, section_ids, and mutations descriptors containing section_id and schema_version.
func inspect_for_framework() -> Dictionary:
	return {
		"available": is_available(),
		"claimed": _claimed,
		"mutation_count": _mutation_records.size(),
		"section_ids": get_section_ids(),
		"mutations": _get_mutation_descriptors(),
	}


## 一次性移出候选记录与请求元数据。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 所有权记录；请求不可用时返回空字典。
## [br]
## @schema return: Internal Dictionary with mutations, document_metadata, context, and result_metadata ownership fields.
func claim_for_framework() -> Dictionary:
	if not is_available():
		return {}
	var claim: Dictionary = {
		"mutations": _mutation_records,
		"document_metadata": _document_metadata,
		"context": _context,
		"result_metadata": _result_metadata,
	}
	_mutation_records = []
	_document_metadata = {}
	_context = {}
	_result_metadata = {}
	_ready = false
	_claimed = true
	return claim


# --- 私有/辅助方法 ---

func _get_mutation_descriptors() -> Array[Dictionary]:
	var descriptors: Array[Dictionary] = []
	for record: Dictionary in _mutation_records:
		descriptors.append({
			"section_id": GFVariantData.get_option_string_name(record, "section_id"),
			"schema_version": GFVariantData.get_option_int(record, "schema_version"),
		})
	return descriptors

static func _is_ephemeral_dictionary_supported(value: Dictionary) -> bool:
	var state: Dictionary = {
		"items": 0,
		"visited": [],
	}
	return _is_ephemeral_value_supported(value, 0, state)


static func _is_ephemeral_value_supported(
	value: Variant,
	depth: int,
	state: Dictionary
) -> bool:
	if depth > _MAX_EPHEMERAL_DEPTH:
		return false
	var item_count: int = GFVariantData.get_option_int(state, "items") + 1
	state["items"] = item_count
	if item_count > _MAX_EPHEMERAL_ITEMS:
		return false

	match typeof(value):
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return false
		TYPE_ARRAY:
			var array_value: Array = value
			var visited: Array = _get_visited(state)
			if _contains_collection_identity(visited, array_value):
				return false
			visited.append(array_value)
			for entry: Variant in array_value:
				if not _is_ephemeral_value_supported(entry, depth + 1, state):
					var _removed_array_failure: Variant = visited.pop_back()
					return false
			var _removed_array: Variant = visited.pop_back()
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			var visited: Array = _get_visited(state)
			if _contains_collection_identity(visited, dictionary_value):
				return false
			visited.append(dictionary_value)
			for key: Variant in dictionary_value.keys():
				if (
					not _is_ephemeral_value_supported(key, depth + 1, state)
					or not _is_ephemeral_value_supported(dictionary_value[key], depth + 1, state)
				):
					var _removed_dictionary_failure: Variant = visited.pop_back()
					return false
			var _removed_dictionary: Variant = visited.pop_back()
	return true


static func _get_visited(state: Dictionary) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(state, "visited"))


static func _contains_collection_identity(collections: Array, candidate: Variant) -> bool:
	for collection: Variant in collections:
		if is_same(collection, candidate):
			return true
	return false
