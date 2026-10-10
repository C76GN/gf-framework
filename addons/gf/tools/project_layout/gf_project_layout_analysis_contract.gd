# Project Layout analysis/graph 的唯一内部契约。
#
# 该 classless helper 只服务 Project Layout，不提供通用图抽象，也不访问文件系统。
extends RefCounted


# --- 常量 ---

## 共用来源声明准入与 binding 身份验证。
## [br]
## @api private
const _CAPTURE_SCOPE_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_capture_scope.gd")

## validate_and_index 接受的顶层 analysis 字段名。
## [br]
## @api private
## [br]
const _ANALYSIS_FIELDS: PackedStringArray = [
	"schema_version",
	"kind",
	"evaluation_status",
	"evaluation_complete",
	"input_complete",
	"success",
	"profile_id",
	"root_path",
	"input_digest",
	"file_count",
	"directory_count",
	"graph",
	"issues",
	"findings",
	"error_count",
	"warning_count",
	"info_count",
	"rule_results",
	"capabilities",
	"effects",
]

## graph 字典的闭合字段名集合。
## [br]
## @api private
## [br]
const _GRAPH_FIELDS: PackedStringArray = [
	"schema_version",
	"kind",
	"complete",
	"capture_status",
	"scope",
	"dependency_coverage",
	"nodes",
	"edges",
	"evidence",
]

## Project Layout scope 字典的闭合字段名集合。
## [br]
## @api private
## [br]
const _SCOPE_FIELDS: PackedStringArray = [
	"kind",
	"root_path",
	"include_hidden",
	"excluded_prefixes",
	"max_scanned_files",
	"max_scanned_directories",
	"max_scan_depth",
	"capture_scope",
	"source_root",
	"protected_roots",
	"profile_source_path",
	"policy_digest",
]

## 本类接收的 inventory 字典字段名集合。
## [br]
## @api private
## [br]
const _INVENTORY_FIELDS: PackedStringArray = [
	"scope",
	"capture_status",
	"complete",
	"root_observed",
	"directories",
	"files",
]

## graph 节点字典的闭合字段名集合。
## [br]
## @api private
## [br]
const _NODE_FIELDS: PackedStringArray = [
	"node_id",
	"node_kind",
	"relative_path",
	"scope",
	"authority",
	"completeness",
	"evidence_ids",
]

## graph 边字典的闭合字段名集合。
## [br]
## @api private
## [br]
const _EDGE_FIELDS: PackedStringArray = [
	"edge_id",
	"edge_kind",
	"from_node_id",
	"to_node_id",
	"scope",
	"evidence_ids",
]

## 文件系统库存证据字典的闭合字段名集合。
## [br]
## @api private
## [br]
const _INVENTORY_EVIDENCE_FIELDS: PackedStringArray = [
	"evidence_id",
	"kind",
	"root_path",
	"relative_path",
	"scope",
	"authority",
	"observed",
]

## 库存边界证据字典的闭合字段名集合。
## [br]
## @api private
## [br]
const _BOUNDARY_EVIDENCE_FIELDS: PackedStringArray = [
	"evidence_id",
	"kind",
	"root_path",
	"scope",
	"capture_scope",
	"capture_status",
	"authority",
	"complete",
	"file_count",
	"directory_count",
	"input_digest",
]

## 不带 reason_code 的 finding 字典字段名集合。
## [br]
## @api private
## [br]
const _FINDING_FIELDS: PackedStringArray = [
	"finding_id",
	"severity",
	"kind",
	"path",
	"message",
	"context",
	"confidence",
	"evidence_ids",
]

## 带 reason_code 的 finding 字典字段名集合。
## [br]
## @api private
## [br]
const _FINDING_FIELDS_WITH_REASON: PackedStringArray = [
	"finding_id",
	"severity",
	"kind",
	"path",
	"message",
	"context",
	"confidence",
	"evidence_ids",
	"reason_code",
]

## rule result 字典的闭合字段名集合。
## [br]
## @api private
## [br]
const _RULE_RESULT_FIELDS: PackedStringArray = [
	"id",
	"kind",
	"severity",
	"checked_count",
	"issue_count",
	"success",
	"evaluation_status",
	"coverage",
]

## capability 字典的闭合字段名集合。
## [br]
## @api private
## [br]
const _CAPABILITY_FIELDS: PackedStringArray = [
	"executor_id",
	"operation",
	"rule_kinds",
	"rule_fields",
	"zone_fields",
]

## 验证器接受的库存捕获状态值。
## [br]
## @api private
## [br]
const _CAPTURE_STATUSES: PackedStringArray = [
	"complete",
	"partial",
	"not_started",
]

## 验证器接受的分析评估状态值。
## [br]
## @api private
## [br]
const _EVALUATION_STATUSES: PackedStringArray = [
	"complete",
	"input_incomplete",
	"evaluation_cancelled",
	"evaluation_work_budget_exhausted",
	"evaluation_finding_budget_exhausted",
	"evaluation_runtime_invalid",
]

## 项目源码库存默认排除的根相对目录前缀。
## [br]
## @api private
## [br]
const _PROJECT_SOURCE_EXCLUDED_PREFIXES: PackedStringArray = [
	".git",
	".godot",
	".import",
]

## analysis 结构遍历允许的最大嵌套深度。
## [br]
## @api private
## [br]
const _MAX_ANALYSIS_DEPTH: int = 64

## analysis 结构遍历允许检查的最大值数。
## [br]
## @api private
## [br]
const _MAX_ANALYSIS_STRUCTURE_VALUES: int = 4_000_000

## 单个 analysis 容器允许的最大元素数。
## [br]
## @api private
## [br]
const _MAX_ANALYSIS_COLLECTION_ITEMS: int = 65_536

## analysis 中任一字符串允许的最大字符数。
## [br]
## @api private
## [br]
const _MAX_ANALYSIS_STRING_LENGTH: int = 16_384

## graph 节点数组允许的最大元素数。
## [br]
## @api private
## [br]
const _MAX_ANALYSIS_NODES: int = 50_001

## graph 边数组允许的最大元素数。
## [br]
## @api private
## [br]
const _MAX_ANALYSIS_EDGES: int = 50_000

## graph evidence 数组允许的最大元素数。
## [br]
## @api private
## [br]
const _MAX_ANALYSIS_EVIDENCE: int = 50_002

## 单个 issues 或 findings 数组允许的最大元素数。
## [br]
## @api private
## [br]
const _MAX_ANALYSIS_FINDINGS: int = 2_048

## rule_results 数组允许的最大元素数。
## [br]
## @api private
## [br]
const _MAX_ANALYSIS_RULE_RESULTS: int = 8_192

## scope 中 excluded_prefixes 数组允许的最大元素数。
## [br]
## @api private
## [br]
const _MAX_SCOPE_EXCLUDED_PREFIXES: int = 64

## 预留的最大验证错误数边界。
## [br]
## @api private
## [br]
const _MAX_VALIDATION_ERRORS: int = 128

## 完整 closed analysis 校验的不可关闭加权工作量上限。
##
## 该边界覆盖结构遍历、字符串字节、排序和索引构建的真实计费；消费方需要执行一次
## 完整校验时必须复用这一上限，不能用较小的通用循环预算截断合法最大库存。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
const MAX_VALIDATION_WORK_UNITS: int = 12_000_000

## Project Layout inventory 在捕获、传输、生产和消费各层共享的不可关闭 envelope。
## [br]
## @api framework_internal
const MAX_INVENTORY_FILES: int = 20_000

## [br]
## @api framework_internal
const MAX_INVENTORY_DIRECTORIES: int = 20_000

## 根节点 + 20k 目录 + 20k 文件。
## [br]
## @api framework_internal
const MAX_INVENTORY_NODES: int = 40_001

## 与 Editor worker 的 data-only UTF-8 envelope 一致。
## [br]
## @api framework_internal
const MAX_INVENTORY_STRING_BYTES: int = 16_777_216

## [br]
## @api framework_internal
const MAX_DATA_STRING_LENGTH: int = 16_384

## `path:` 前缀仍需让生成的 node_id 落在 MAX_DATA_STRING_LENGTH 内。
## [br]
## @api framework_internal
const MAX_RELATIVE_PATH_LENGTH: int = MAX_DATA_STRING_LENGTH - 5

## [br]
## @api framework_internal
const MAX_SCAN_DEPTH: int = 32

## 库存生产阶段结构预检允许检查的最大值数。
## [br]
## @api private
## [br]
const _MAX_PRODUCER_STRUCTURE_VALUES: int = 200_000

## 库存生产阶段单个容器允许的最大元素数。
## [br]
## @api private
## [br]
const _MAX_PRODUCER_COLLECTION_ITEMS: int = 65_536

## 库存生产阶段结构预检允许的最大嵌套深度。
## [br]
## @api private
## [br]
const _MAX_PRODUCER_DEPTH: int = 64

## 单次库存生产操作允许消费的最大工作量。
## [br]
## @api private
## [br]
const _MAX_PRODUCER_WORK_UNITS: int = 2_000_000

## 稳定 ID 输入结构预检允许检查的最大值数。
## [br]
## @api private
## [br]
const _MAX_STABLE_ID_STRUCTURE_VALUES: int = 4_096

## 稳定 ID 输入结构预检单个容器允许的最大元素数。
## [br]
## @api private
## [br]
const _MAX_STABLE_ID_COLLECTION_ITEMS: int = 1_024

## 稳定 ID 输入结构预检允许的最大嵌套深度。
## [br]
## @api private
## [br]
const _MAX_STABLE_ID_DEPTH: int = 11

## finding stable ID occurrence 参数允许的最大值。
## [br]
## @api private
## [br]
const _MAX_STABLE_ID_OCCURRENCE: int = 1_000_000


# --- 私有变量 ---

## 当前 validate_and_index 操作使用的协作式检查回调。
## [br]
## @api private
## [br]
var _active_checkpoint: Callable = Callable()

## 当前分析验证操作累计消费的工作单位数。
## [br]
## @api private
## [br]
var _validation_work_units: int = 0

## 当前分析验证操作是否已因终止条件停止。
## [br]
## @api private
## [br]
var _validation_terminal: bool = false

## 最近一次成功结构预检访问的结构值数量。
## [br]
## @api private
## [br]
var _validation_structure_values: int = 0

## 当前库存生产操作累计消费的工作单位数。
## [br]
## @api private
## [br]
var _producer_work_units: int = 0

## 当前库存生产操作是否已超过资源边界。
## [br]
## @api private
## [br]
var _producer_terminal: bool = false


# --- 框架内部方法 ---

## 快速判断库存计数是否落在共享 production envelope 内。
## [br]
## @api framework_internal
## [br]
## @param file_count: 已捕获的文件数量；必须非负且不超过 MAX_INVENTORY_FILES。
## [br]
## @param directory_count: 已捕获的目录数量；必须非负且不超过 MAX_INVENTORY_DIRECTORIES。
## [br]
## @param root_observed: 是否为已观察到的库存根节点预留一个节点名额。
## [br]
## @return: 各分类计数及包含可选根节点的总节点数是否都落在共享库存边界内。
static func inventory_counts_are_admissible(
	file_count: int,
	directory_count: int,
	root_observed: bool = true
) -> bool:
	if (
		file_count < 0
		or directory_count < 0
		or file_count > MAX_INVENTORY_FILES
		or directory_count > MAX_INVENTORY_DIRECTORIES
	):
		return false
	return (
		file_count + directory_count + (1 if root_observed else 0)
		<= MAX_INVENTORY_NODES
	)


## 与各层早期准入调用点共享的 O(1) 计数检查别名。
## [br]
## @api framework_internal
## [br]
## @param file_count: 已捕获的文件数量；必须非负且不超过 MAX_INVENTORY_FILES。
## [br]
## @param directory_count: 已捕获的目录数量；必须非负且不超过 MAX_INVENTORY_DIRECTORIES。
## [br]
## @param root_observed: 是否为已观察到的库存根节点预留一个节点名额。
## [br]
## @return: inventory_counts_are_admissible 对同一组计数的判定结果。
static func basic_inventory_counts_are_admissible(
	file_count: int,
	directory_count: int,
	root_observed: bool = true
) -> bool:
	return inventory_counts_are_admissible(
		file_count,
		directory_count,
		root_observed
	)


## 快速判断捕获预算是否与共享 production envelope 闭合。
## [br]
## @api framework_internal
## [br]
## @param max_files: 调用方允许捕获的最大文件数；必须为正数且不超过共享上限。
## [br]
## @param max_directories: 调用方允许捕获的最大目录数；必须为正数且不超过共享上限。
## [br]
## @param max_depth: 调用方允许扫描的最大深度；必须为正数且不超过共享上限。
## [br]
## @return: 三项预算是否都为正数并且未放宽共享 production envelope。
static func inventory_budgets_are_admissible(
	max_files: int,
	max_directories: int,
	max_depth: int
) -> bool:
	return (
		max_files > 0
		and max_files <= MAX_INVENTORY_FILES
		and max_directories > 0
		and max_directories <= MAX_INVENTORY_DIRECTORIES
		and max_depth > 0
		and max_depth <= MAX_SCAN_DEPTH
	)


## 在任何 UTF-8 materialization 前应用的共享单串字符上限。
## [br]
## @api framework_internal
## [br]
## @param value: 待准入的 data-only 字符串。
## [br]
## @return: 字符串字符数是否未超过 MAX_DATA_STRING_LENGTH。
static func data_string_length_is_admissible(value: String) -> bool:
	return value.length() <= MAX_DATA_STRING_LENGTH

## 从已归一化库存生成唯一的 graph 与 input digest。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param root_path: 规范 res:// 项目源码根。
## [br]
## @param inventory: Analyzer 内部库存，包含 scope、capture_status、complete、root_observed、directories 和 files。
## [br]
## @schema inventory: Dictionary，精确包含 scope、capture_status、complete、root_observed、directories 和 files；scope 精确包含 kind、root_path、include_hidden、excluded_prefixes、max_scanned_files、max_scanned_directories、max_scan_depth、capture_scope、source_root、protected_roots、profile_source_path、policy_digest。
## [br]
## @param checkpoint: 可选的零参数协作式执行检查。
## [br]
## @return: data-only attachment；checkpoint 拒绝继续时返回空 Dictionary。
## [br]
## @schema return: Dictionary，精确包含 input_digest、file_count、directory_count 和 graph。
func build_inventory_attachment(
	root_path: String,
	inventory: Dictionary,
	checkpoint: Callable = Callable()
) -> Dictionary:
	_begin_producer_operation()
	if not _operation_checkpoint_allows(checkpoint):
		return {}
	if not _inventory_dictionary_is_admissible(root_path, inventory):
		return {}
	var directories: PackedStringArray = _string_list(inventory, "directories")
	var files: PackedStringArray = _string_list(inventory, "files")
	if not _consume_producer_work(_sort_work_units(directories.size())):
		return {}
	directories.sort()
	if not _consume_producer_work(_sort_work_units(files.size())):
		return {}
	files.sort()
	var scope: Dictionary = _dictionary(inventory, "scope").duplicate(true)
	scope["excluded_prefixes"] = Array(_string_list(scope, "excluded_prefixes"))
	var capture_status: String = _string(inventory, "capture_status")
	var complete: bool = _bool(inventory, "complete")
	var root_observed: bool = _bool(inventory, "root_observed")
	var digest: String = _inventory_digest_admitted(
		root_path,
		scope,
		capture_status,
		complete,
		root_observed,
		directories,
		files,
		checkpoint
	)
	if digest.is_empty():
		return {}
	var graph: Dictionary = {
		"schema_version": 2,
		"kind": "project_layout_graph",
		"complete": complete,
		"capture_status": capture_status,
		"scope": scope,
		"dependency_coverage": "filesystem_only",
		"nodes": [],
		"edges": [],
		"evidence": [],
	}
	var nodes: Array = graph["nodes"]
	var edges: Array = graph["edges"]
	var evidence: Array = graph["evidence"]
	if root_observed:
		if not _consume_producer_work():
			return {}
		_append_inventory_entry(nodes, edges, evidence, "directory", ".", root_path)
		if _producer_terminal:
			return {}
	for relative_path: String in directories:
		if (
			not _consume_producer_work()
			or not _operation_checkpoint_allows(checkpoint)
		):
			return {}
		_append_inventory_entry(nodes, edges, evidence, "directory", relative_path, root_path)
		if _producer_terminal:
			return {}
	for relative_path: String in files:
		if (
			not _consume_producer_work()
			or not _operation_checkpoint_allows(checkpoint)
		):
			return {}
		_append_inventory_entry(nodes, edges, evidence, "file", relative_path, root_path)
		if _producer_terminal:
			return {}
	if root_observed:
		evidence.append({
			"evidence_id": "evidence:inventory:%s" % digest.substr(0, 16),
			"kind": "filesystem_inventory_boundary",
			"root_path": root_path,
			"scope": "project_source",
			"capture_scope": scope.duplicate(true),
			"capture_status": capture_status,
			"authority": "filesystem_inventory",
			"complete": complete,
			"file_count": files.size(),
			"directory_count": directories.size(),
			"input_digest": digest,
		})
	return {
		"input_digest": digest,
		"file_count": files.size(),
		"directory_count": directories.size(),
		"graph": graph,
	}


## 计算 scope、捕获终态和排序库存共同绑定的摘要。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param root_path: 规范 res:// 项目源码根。
## [br]
## @param scope: project_source 捕获范围。
## [br]
## @param capture_status: complete、partial 或 not_started。
## [br]
## @param complete: 库存是否具备完整权威。
## [br]
## @param root_observed: 是否观察到库存根。
## [br]
## @param directories: 目录相对路径。
## [br]
## @param files: 文件相对路径。
## [br]
## @param checkpoint: 可选的零参数协作式执行检查。
## [br]
## @schema scope: Dictionary，精确包含 kind、root_path、include_hidden、excluded_prefixes、max_scanned_files、max_scanned_directories、max_scan_depth、capture_scope、source_root、protected_roots、profile_source_path、policy_digest。
## [br]
## @return: 64 位小写 SHA-256。
func inventory_digest(
	root_path: String,
	scope: Dictionary,
	capture_status: String,
	complete: bool,
	root_observed: bool,
	directories: PackedStringArray,
	files: PackedStringArray,
	checkpoint: Callable = Callable()
) -> String:
	_begin_producer_operation()
	if not _operation_checkpoint_allows(checkpoint):
		return ""
	if not _inventory_values_are_admissible(
		root_path,
		scope,
		capture_status,
		complete,
		root_observed,
		directories,
		files
	):
		return ""
	return _inventory_digest_admitted(
		root_path,
		scope,
		capture_status,
		complete,
		root_observed,
		directories,
		files,
		checkpoint
	)


## 生成与 finding 语义和同身份 occurrence 绑定的稳定 ID。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param finding: 不含 finding_id 也可的 finding 语义字段。
## [br]
## @schema finding: Dictionary，包含 severity、kind、path、message、context、confidence、evidence_ids 和可选 reason_code。
## [br]
## @param occurrence: 相同语义身份内从 0 开始的 occurrence。
## [br]
## @return: 不受其他 finding 插入、删除或重排影响的稳定 ID。
func stable_finding_id(finding: Dictionary, occurrence: int) -> String:
	if occurrence < 0 or occurrence > _MAX_STABLE_ID_OCCURRENCE:
		return ""
	var identity_seed: String = _admitted_finding_identity_seed(finding)
	if identity_seed.is_empty():
		return ""
	if not _consume_producer_work(ceili(float(identity_seed.length()) / 256.0)):
		return ""
	return "finding:%s" % ("%s\noccurrence=%d" % [identity_seed, occurrence]).sha256_text().substr(0, 16)


## 生成只由边语义绑定的稳定 edge ID。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param edge_kind: 边类型。
## [br]
## @param from_node_id: 来源节点 ID。
## [br]
## @param to_node_id: 目标节点 ID。
## [br]
## @param scope: 边的 Project Layout scope。
## [br]
## @return: 稳定 edge ID。
func stable_edge_id(
	edge_kind: String,
	from_node_id: String,
	to_node_id: String,
	scope: String
) -> String:
	_begin_producer_operation()
	return _stable_edge_id_admitted(edge_kind, from_node_id, to_node_id, scope)


## 严格校验一份 Project Layout analysis 并一次性构建 O(V+E) 查询索引。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param analysis: 待消费的 Project Layout analysis。
## [br]
## @schema analysis: Dictionary，必须符合闭合 project_layout_analysis/graph/scope/node/edge/evidence/finding 契约。
## [br]
## @param checkpoint: 可选协作式工作检查；有效时接收本批正整数 work_units，返回 false 时结构化中止验证。
## [br]
## @return: 结构校验结果；不决定 Planner 或 Impact 的操作许可。
## [br]
## @schema return: Dictionary，精确包含 valid、errors、capture_status、complete 和 index；index 精确包含 node_by_id、node_id_by_path、children_by_id、evidence_by_id 和 finding_by_id。
func validate_and_index(
	analysis: Dictionary,
	checkpoint: Callable = Callable()
) -> Dictionary:
	_active_checkpoint = checkpoint
	_validation_work_units = 0
	_validation_terminal = false
	_validation_structure_values = 0
	var result: Dictionary = {
		"valid": false,
		"errors": [],
		"capture_status": "",
		"complete": false,
		"index": _empty_index(),
	}
	if checkpoint.is_valid() and checkpoint.get_argument_count() != 1:
		_fail_analysis_contract_checkpoint(
			result,
			"analysis_contract_checkpoint_invalid",
			"Project Layout analysis contract checkpoint 必须接收一个 work_units 参数。"
		)
		return result
	if not _analysis_structure_is_admissible(analysis, result):
		return result
	if not _validation_has_exact_fields(analysis, _ANALYSIS_FIELDS, result):
		_add_validation_error(result, "analysis_schema_invalid", "analysis", "analysis 顶层字段必须精确闭合。")
		return result
	if (
		analysis.get("schema_version") != 2
		or analysis.get("kind") != "project_layout_analysis"
	):
		_add_validation_error(result, "analysis_identity_invalid", "analysis", "analysis schema_version 或 kind 无效。")
		return result
	var root_path_value: Variant = analysis.get("root_path")
	if not root_path_value is String:
		_add_validation_error(result, "analysis_root_invalid", "root_path", "analysis root_path 必须是规范 res:// 或绝对本地根。")
		return result
	var root_path: String = root_path_value
	if not _is_canonical_root(root_path):
		_add_validation_error(result, "analysis_root_invalid", "root_path", "analysis root_path 必须是规范 res:// 或绝对本地根。")
		return result
	var graph_value: Variant = analysis.get("graph")
	if not graph_value is Dictionary:
		_add_validation_error(result, "graph_schema_invalid", "graph", "analysis graph 必须是 Dictionary。")
		return result
	var graph: Dictionary = graph_value
	var graph_state: Dictionary = _validate_graph(graph, root_path, result)
	if not _get_result_errors(result).is_empty():
		return result
	var index: Dictionary = _dictionary(graph_state, "index")
	result["index"] = index
	result["capture_status"] = _string(graph, "capture_status")
	result["complete"] = _bool(graph, "complete")
	_validate_findings(analysis, index, result)
	_validate_rule_results(analysis, result)
	_validate_capabilities(analysis, result)
	_validate_analysis_cross_fields(analysis, graph, graph_state, result)
	result["valid"] = _get_result_errors(result).is_empty()
	return result


# --- 私有/辅助方法 ---

## 为已准入库存排序目录、文件和排除前缀，以根、捕获状态、scope 与预算组成摘要文本；复制、排序、遍历和哈希都计入工作预算，中止返回空串。
## [br]
## @api private
func _inventory_digest_admitted(
	root_path: String,
	scope: Dictionary,
	capture_status: String,
	complete: bool,
	root_observed: bool,
	directories: PackedStringArray,
	files: PackedStringArray,
	checkpoint: Callable = Callable(),
	validation_result: Dictionary = {}
) -> String:
	if not _consume_inventory_digest_work(
		checkpoint,
		validation_result,
		_sort_work_units(directories.size())
	):
		return ""
	var sorted_directories: PackedStringArray = directories.duplicate()
	if not _consume_inventory_digest_work(
		checkpoint,
		validation_result,
		_sort_work_units(files.size())
	):
		return ""
	var sorted_files: PackedStringArray = files.duplicate()
	var excluded_prefixes: PackedStringArray = _string_list(scope, "excluded_prefixes")
	if not _consume_inventory_digest_work(
		checkpoint,
		validation_result,
		_sort_work_units(excluded_prefixes.size())
	):
		return ""
	sorted_directories.sort()
	sorted_files.sort()
	excluded_prefixes.sort()
	var records: PackedStringArray = PackedStringArray([
		"root=%s" % root_path,
		"root_observed=%s" % str(root_observed),
		"capture_status=%s" % capture_status,
		"complete=%s" % str(complete),
		"scope.kind=%s" % _string(scope, "kind"),
		"scope.root_path=%s" % _string(scope, "root_path"),
		"scope.include_hidden=%s" % str(_bool(scope, "include_hidden")),
		"scope.policy_digest=%s" % _string(scope, "policy_digest"),
		"scope.source_root=%s" % _string(scope, "source_root"),
	])
	for excluded_prefix: String in excluded_prefixes:
		if not _consume_inventory_digest_work(checkpoint, validation_result):
			return ""
		var _append_excluded: bool = records.append(
			"scope.excluded_prefix=%s" % excluded_prefix
		)
	for budget_field: String in [
		"max_scanned_files",
		"max_scanned_directories",
		"max_scan_depth",
	]:
		if not _consume_inventory_digest_work(checkpoint, validation_result):
			return ""
		var _append_budget: bool = records.append(
			"scope.%s=%d" % [budget_field, _integer(scope, budget_field)]
		)
	for relative_path: String in sorted_directories:
		if not _consume_inventory_digest_work(checkpoint, validation_result):
			return ""
		var _append_directory: bool = records.append("directory=%s" % relative_path)
	for relative_path: String in sorted_files:
		if not _consume_inventory_digest_work(checkpoint, validation_result):
			return ""
		var _append_file: bool = records.append("file=%s" % relative_path)
	if not _consume_inventory_digest_work(
		checkpoint,
		validation_result,
		ceili(float(_inventory_text_bytes(root_path, scope, directories, files)) / 256.0)
	):
		return ""
	return "\n".join(records).sha256_text()


## 先消费 producer 额度，有校验结果时再消费 validation 额度，否则调用操作检查点；零工作直接通过，先消费的额度不会因后续拒绝回滚。
## [br]
## @api private
func _consume_inventory_digest_work(
	checkpoint: Callable,
	validation_result: Dictionary,
	work_units: int = 1
) -> bool:
	if work_units == 0:
		return true
	if not _consume_producer_work(work_units):
		return false
	if not validation_result.is_empty():
		return _consume_validation_work(validation_result, work_units)
	return _operation_checkpoint_allows(checkpoint)


## 重置 producer 工作状态，在校验预算下重新准入库存值后计算绑定摘要；任一阶段拒绝返回空串供上层判失败。
## [br]
## @api private
func _inventory_digest_for_validation(
	root_path: String,
	scope: Dictionary,
	capture_status: String,
	complete: bool,
	root_observed: bool,
	directories: PackedStringArray,
	files: PackedStringArray,
	result: Dictionary
) -> String:
	_begin_producer_operation()
	if not _inventory_values_are_admissible(
		root_path,
		scope,
		capture_status,
		complete,
		root_observed,
		directories,
		files,
		result
	):
		return ""
	return _inventory_digest_admitted(
		root_path,
		scope,
		capture_status,
		complete,
		root_observed,
		directories,
		files,
		Callable(),
		result
	)

## 先检查领域集合上限，再以显式栈验证有界纯数据结构和有限标量；活动容器身份检测拒绝递归环，成功后记录结构值数供后续预算使用。
## [br]
## @api private
func _analysis_structure_is_admissible(analysis: Dictionary, result: Dictionary) -> bool:
	if not _analysis_domain_collections_are_admissible(analysis, result):
		return false
	var stack: Array = [{
		"value": analysis,
		"depth": 0,
		"exit": false,
	}]
	var active_containers: Array = []
	var structure_value_count: int = 0
	while not stack.is_empty():
		var frame_value: Variant = stack.pop_back()
		if not frame_value is Dictionary:
			_fail_analysis_contract_limit(result)
			return false
		var frame: Dictionary = frame_value
		var value: Variant = frame.get("value")
		if _bool(frame, "exit"):
			if not active_containers.is_empty():
				var _removed_container: Variant = active_containers.pop_back()
			continue
		if not _consume_validation_work(result):
			return false
		structure_value_count += 1
		if structure_value_count > _MAX_ANALYSIS_STRUCTURE_VALUES:
			_fail_analysis_contract_limit(result)
			return false
		var depth: int = _integer(frame, "depth")
		if depth > _MAX_ANALYSIS_DEPTH:
			_fail_analysis_contract_limit(result)
			return false
		if value is String:
			var text: String = value
			if text.length() > _MAX_ANALYSIS_STRING_LENGTH:
				_fail_analysis_contract_limit(result)
				return false
			var text_work_units: int = ceili(float(text.length()) / 256.0)
			if not _consume_validation_work(result, text_work_units):
				return false
			continue
		if value is Dictionary:
			var dictionary_value: Dictionary = value
			if dictionary_value.size() > _MAX_ANALYSIS_COLLECTION_ITEMS:
				_fail_analysis_contract_limit(result)
				return false
			if not _consume_validation_work(result, active_containers.size()):
				return false
			if _active_analysis_container_exists(active_containers, dictionary_value):
				_fail_analysis_contract_limit(result)
				return false
			active_containers.append(dictionary_value)
			stack.append({ "value": dictionary_value, "depth": depth, "exit": true })
			var keys: Array = dictionary_value.keys()
			for key_index: int in range(keys.size() - 1, -1, -1):
				if not _consume_validation_work(result):
					return false
				var key: Variant = keys[key_index]
				if not key is String:
					_fail_analysis_contract_limit(result)
					return false
				stack.append({ "value": dictionary_value[key], "depth": depth + 1, "exit": false })
				stack.append({ "value": key, "depth": depth + 1, "exit": false })
			continue
		if value is Array:
			var array_value: Array = value
			if array_value.size() > _MAX_ANALYSIS_COLLECTION_ITEMS:
				_fail_analysis_contract_limit(result)
				return false
			if not _consume_validation_work(result, active_containers.size()):
				return false
			if _active_analysis_container_exists(active_containers, array_value):
				_fail_analysis_contract_limit(result)
				return false
			active_containers.append(array_value)
			stack.append({ "value": array_value, "depth": depth, "exit": true })
			for item_index: int in range(array_value.size() - 1, -1, -1):
				if not _consume_validation_work(result):
					return false
				stack.append({ "value": array_value[item_index], "depth": depth + 1, "exit": false })
			continue
		if value == null or value is bool or value is int:
			continue
		if value is float:
			var float_value: float = value
			if not is_finite(float_value):
				_fail_analysis_contract_limit(result)
				return false
			continue
		_fail_analysis_contract_limit(result)
		return false
	_validation_structure_values = structure_value_count
	return true


## 提前限制图节点、边、证据、finding 和规则集合及路径长度，避免通用结构遍历前已接收过大领域数据；字段类型由后续契约校验。
## [br]
## @api private
func _analysis_domain_collections_are_admissible(
	analysis: Dictionary,
	result: Dictionary
) -> bool:
	var graph_value: Variant = analysis.get("graph")
	if graph_value is Dictionary:
		var graph: Dictionary = graph_value
		for domain_limit: Dictionary in [
			{ "field": "nodes", "maximum": _MAX_ANALYSIS_NODES },
			{ "field": "edges", "maximum": _MAX_ANALYSIS_EDGES },
			{ "field": "evidence", "maximum": _MAX_ANALYSIS_EVIDENCE },
		]:
			var field_name: String = _string(domain_limit, "field")
			var collection_value: Variant = graph.get(field_name)
			if collection_value is Array:
				var collection: Array = collection_value
				if collection.size() > _integer(domain_limit, "maximum"):
					_fail_analysis_contract_limit(result)
					return false
		var nodes_value: Variant = graph.get("nodes")
		if nodes_value is Array:
			var nodes: Array = nodes_value
			for node_value: Variant in nodes:
				if not _consume_validation_work(result):
					return false
				if not node_value is Dictionary:
					continue
				var node: Dictionary = node_value
				var relative_path_value: Variant = node.get("relative_path")
				if relative_path_value is String:
					var relative_path: String = relative_path_value
					if relative_path.length() > MAX_RELATIVE_PATH_LENGTH:
						_fail_analysis_contract_limit(result)
						return false
		var evidence_items_value: Variant = graph.get("evidence")
		if evidence_items_value is Array:
			var evidence_items: Array = evidence_items_value
			for evidence_value: Variant in evidence_items:
				if not _consume_validation_work(result):
					return false
				if not evidence_value is Dictionary:
					continue
				var evidence: Dictionary = evidence_value
				var evidence_relative_path_value: Variant = evidence.get("relative_path")
				if evidence_relative_path_value is String:
					var evidence_relative_path: String = evidence_relative_path_value
					if evidence_relative_path.length() > MAX_RELATIVE_PATH_LENGTH:
						_fail_analysis_contract_limit(result)
						return false
		var scope_value: Variant = graph.get("scope")
		if scope_value is Dictionary:
			var scope: Dictionary = scope_value
			var excluded_value: Variant = scope.get("excluded_prefixes")
			if excluded_value is Array:
				var excluded_prefixes: Array = excluded_value
				if excluded_prefixes.size() > _MAX_SCOPE_EXCLUDED_PREFIXES:
					_fail_analysis_contract_limit(result)
					return false
	for domain_limit: Dictionary in [
		{ "field": "issues", "maximum": _MAX_ANALYSIS_FINDINGS },
		{ "field": "findings", "maximum": _MAX_ANALYSIS_FINDINGS },
		{ "field": "rule_results", "maximum": _MAX_ANALYSIS_RULE_RESULTS },
	]:
		var field_name: String = _string(domain_limit, "field")
		var collection_value: Variant = analysis.get(field_name)
		if collection_value is Array:
			var collection: Array = collection_value
			if collection.size() > _integer(domain_limit, "maximum"):
				_fail_analysis_contract_limit(result)
				return false
	return true


## 检查容器是否已出现在当前递归路径的活动容器列表中。
## [br]
## @api private
## [br]
func _active_analysis_container_exists(active_containers: Array, value: Variant) -> bool:
	for active_value: Variant in active_containers:
		if is_same(active_value, value):
			return true
	return false


## 在不可关闭总工作上限内计费，并向活动检查点传递本次工作量；超限、非 bool 返回或主动停止都进入终态，后续消费直接拒绝。
## [br]
## @api private
func _consume_validation_work(result: Dictionary, work_units: int = 1) -> bool:
	if _validation_terminal:
		return false
	if work_units < 0 or _validation_work_units > MAX_VALIDATION_WORK_UNITS - work_units:
		_fail_analysis_contract_limit(result)
		return false
	if work_units == 0:
		return true
	_validation_work_units += work_units
	if not _active_checkpoint.is_valid():
		return true
	var checkpoint_value: Variant = _active_checkpoint.call(work_units)
	if not checkpoint_value is bool:
		_fail_analysis_contract_checkpoint(
			result,
			"analysis_contract_checkpoint_invalid",
			"Project Layout analysis contract checkpoint 必须返回 bool。"
		)
		return false
	var checkpoint_allows: bool = checkpoint_value
	if checkpoint_allows:
		return true
	_fail_analysis_contract_checkpoint(
		result,
		"analysis_contract_cancelled",
		"Project Layout analysis contract 验证已协作式中止。"
	)
	return false


## 首次协作检查失败时锁定校验终态，用单个中止错误替换已有错误，并撤销有效性、捕获状态及索引。
## [br]
## @api private
func _fail_analysis_contract_checkpoint(
	result: Dictionary,
	kind: String,
	message: String
) -> void:
	if _validation_terminal:
		return
	_validation_terminal = true
	var errors: Array = _get_result_errors(result)
	errors.clear()
	errors.append({
		"kind": kind,
		"path": "analysis",
		"message": message,
	})
	result["valid"] = false
	result["capture_status"] = ""
	result["complete"] = false
	result["index"] = _empty_index()


## 首次资源边界失败时锁定终态，用统一超限错误替换既有错误并清空可消费索引，防止部分校验结果被误用。
## [br]
## @api private
func _fail_analysis_contract_limit(result: Dictionary) -> void:
	if _validation_terminal:
		return
	_validation_terminal = true
	var errors: Array = _get_result_errors(result)
	errors.clear()
	errors.append({
		"kind": "analysis_contract_resource_limit_exceeded",
		"path": "analysis",
		"message": "Project Layout analysis 超出不可关闭的契约校验资源边界。",
	})
	result["valid"] = false
	result["capture_status"] = ""
	result["complete"] = false
	result["index"] = _empty_index()


## 为新的库存生产操作清零累计工作量并清除终止标记。
## [br]
## @api private
## [br]
func _begin_producer_operation() -> void:
	_producer_work_units = 0
	_producer_terminal = false


## 按本次 producer 操作累计工作量，负数或超限即锁定失败；不调用外部检查点，也不自行生成错误报告。
## [br]
## @api private
func _consume_producer_work(work_units: int = 1) -> bool:
	if _producer_terminal:
		return false
	if work_units < 0 or _producer_work_units > _MAX_PRODUCER_WORK_UNITS - work_units:
		_producer_terminal = true
		return false
	_producer_work_units += work_units
	return true


## 要求库存字典具有精确字段及基础类型，再把目录、文件和捕获状态交给统一库存值准入。
## [br]
## @api private
func _inventory_dictionary_is_admissible(
	root_path: String,
	inventory: Dictionary
) -> bool:
	if (
		inventory.size() != _INVENTORY_FIELDS.size()
		or not _has_exact_fields(inventory, _INVENTORY_FIELDS)
		or not inventory.get("scope") is Dictionary
		or not inventory.get("capture_status") is String
		or not inventory.get("complete") is bool
		or not inventory.get("root_observed") is bool
	):
		return false
	var directories_value: Variant = inventory.get("directories")
	var files_value: Variant = inventory.get("files")
	return _inventory_values_are_admissible(
		root_path,
		_dictionary(inventory, "scope"),
		_string(inventory, "capture_status"),
		_bool(inventory, "complete"),
		_bool(inventory, "root_observed"),
		directories_value,
		files_value
	)


## 验证根与 scope、捕获状态和预算一致性，再检查有界纯数据、路径唯一性、排除范围和父目录闭合；校验调用还会同时计入 validation 额度。
## [br]
## @api private
func _inventory_values_are_admissible(
	root_path: String,
	scope: Dictionary,
	capture_status: String,
	complete: bool,
	root_observed: bool,
	directories_value: Variant,
	files_value: Variant,
	validation_result: Dictionary = {}
) -> bool:
	if (
		root_path.length() > MAX_DATA_STRING_LENGTH
		or not _is_canonical_root(root_path)
		or scope.size() != _SCOPE_FIELDS.size()
		or not _has_exact_fields(scope, _SCOPE_FIELDS)
		or not (directories_value is Array or directories_value is PackedStringArray)
		or not (files_value is Array or files_value is PackedStringArray)
	):
		return false
	var directory_count: int = _string_collection_size(directories_value)
	var file_count: int = _string_collection_size(files_value)
	if (
		directory_count < 0
		or file_count < 0
		or not inventory_counts_are_admissible(
			file_count,
			directory_count,
			root_observed
		)
	):
		return false
	var max_files_value: Variant = scope.get("max_scanned_files")
	var max_directories_value: Variant = scope.get("max_scanned_directories")
	var max_depth_value: Variant = scope.get("max_scan_depth")
	if (
		not max_files_value is int
		or not max_directories_value is int
		or not max_depth_value is int
	):
		return false
	var max_files: int = max_files_value
	var max_directories: int = max_directories_value
	var max_depth: int = max_depth_value
	if (
		not inventory_budgets_are_admissible(
			max_files,
			max_directories,
			max_depth
		)
		or file_count > max_files
		or directory_count > max_directories
	):
		return false
	var excluded_value: Variant = scope.get("excluded_prefixes")
	if not (excluded_value is Array or excluded_value is PackedStringArray):
		return false
	var excluded_count: int = _string_collection_size(excluded_value)
	if excluded_count < 0 or excluded_count > _MAX_SCOPE_EXCLUDED_PREFIXES:
		return false
	if not _consume_producer_structure_work(
		validation_result,
		excluded_count + directory_count + file_count
	):
		return false
	var excluded_prefixes: PackedStringArray = _string_list_from_value(excluded_value)
	var directories: PackedStringArray = _string_list_from_value(directories_value)
	var files: PackedStringArray = _string_list_from_value(files_value)
	if (
		excluded_prefixes.size() != excluded_count
		or directories.size() != directory_count
		or files.size() != file_count
	):
		return false
	if (
		scope.get("kind") != "project_source"
		or scope.get("root_path") != root_path
		or not scope.get("include_hidden") is bool
		or not _CAPTURE_STATUSES.has(capture_status)
		or complete != (capture_status == "complete")
		or (capture_status == "not_started") != (not root_observed)
		or (not root_observed and (directory_count > 0 or file_count > 0))
	):
		return false
	var normalized_scope: Dictionary = {
		"kind": scope.get("kind"),
		"root_path": scope.get("root_path"),
		"include_hidden": scope.get("include_hidden"),
		"excluded_prefixes": Array(excluded_prefixes),
		"max_scanned_files": max_files_value,
		"max_scanned_directories": max_directories_value,
		"max_scan_depth": max_depth_value,
	}
	for field: String in ["capture_scope", "source_root", "protected_roots", "profile_source_path", "policy_digest"]:
		normalized_scope[field] = scope[field]
	if not _CAPTURE_SCOPE_SCRIPT.binding_is_valid(_binding_from_scope(normalized_scope)):
		return false
	var envelope: Dictionary = {
		"root_path": root_path,
		"scope": normalized_scope,
		"capture_status": capture_status,
		"directories": Array(directories),
		"files": Array(files),
	}
	if not _producer_structure_is_admissible(
		envelope,
		_MAX_PRODUCER_STRUCTURE_VALUES,
		_MAX_PRODUCER_COLLECTION_ITEMS,
		_MAX_PRODUCER_DEPTH,
		MAX_INVENTORY_STRING_BYTES,
		validation_result
	):
		return false
	var excluded_seen: Dictionary = {}
	for excluded_prefix: String in excluded_prefixes:
		if (
			not _consume_producer_structure_work(validation_result)
			or excluded_prefix.length() > MAX_RELATIVE_PATH_LENGTH
			or not _is_canonical_relative_path(excluded_prefix, false)
			or excluded_seen.has(excluded_prefix)
		):
			return false
		excluded_seen[excluded_prefix] = true
	var directory_set: Dictionary = {}
	for relative_path: String in directories:
		if (
			not _consume_producer_structure_work(validation_result)
			or relative_path.length() > MAX_RELATIVE_PATH_LENGTH
			or not _is_canonical_relative_path(relative_path, false)
			or directory_set.has(relative_path)
			or _is_under_excluded_prefix(relative_path, excluded_prefixes)
		):
			return false
		directory_set[relative_path] = true
	var file_set: Dictionary = {}
	for relative_path: String in files:
		if (
			not _consume_producer_structure_work(validation_result)
			or relative_path.length() > MAX_RELATIVE_PATH_LENGTH
			or not _is_canonical_relative_path(relative_path, false)
			or directory_set.has(relative_path)
			or file_set.has(relative_path)
			or _is_under_excluded_prefix(relative_path, excluded_prefixes)
		):
			return false
		file_set[relative_path] = true
	for relative_path: String in directories:
		if not _consume_producer_structure_work(validation_result):
			return false
		var parent_path: String = _parent_path(relative_path)
		if not parent_path.is_empty() and not directory_set.has(parent_path):
			return false
	for relative_path: String in files:
		if not _consume_producer_structure_work(validation_result):
			return false
		var parent_path: String = _parent_path(relative_path)
		if not parent_path.is_empty() and not directory_set.has(parent_path):
			return false
	return true


## 以显式栈遍历 producer 数据，限制节点、深度、容器和累计 UTF-8 文本字节，拒绝循环、非文本键及非有限或对象值；失败只返回 false。
## [br]
## @api private
func _producer_structure_is_admissible(
	root_value: Variant,
	max_structure_values: int,
	max_collection_items: int,
	max_depth: int,
	max_string_bytes: int,
	validation_result: Dictionary = {}
) -> bool:
	var stack: Array = [{
		"value": root_value,
		"depth": 0,
		"exit": false,
	}]
	var active_containers: Array = []
	var structure_values: int = 0
	var string_bytes: int = 0
	while not stack.is_empty():
		var frame_value: Variant = stack.pop_back()
		if not frame_value is Dictionary:
			return false
		var frame: Dictionary = frame_value
		var value: Variant = frame.get("value")
		if _bool(frame, "exit"):
			if not active_containers.is_empty():
				var _removed_container: Variant = active_containers.pop_back()
			continue
		if not _consume_producer_structure_work(validation_result):
			return false
		structure_values += 1
		if structure_values > max_structure_values:
			return false
		var depth: int = _integer(frame, "depth")
		if depth > max_depth:
			return false
		if value is String:
			var text: String = value
			if text.length() > MAX_DATA_STRING_LENGTH:
				return false
			var text_bytes: int = text.to_utf8_buffer().size()
			if string_bytes > max_string_bytes - text_bytes:
				return false
			string_bytes += text_bytes
			if not _consume_producer_structure_work(
				validation_result,
				maxi(1, ceili(float(text_bytes) / 256.0))
			):
				return false
			continue
		if value is Dictionary:
			var dictionary_value: Dictionary = value
			if not _consume_producer_structure_work(
				validation_result,
				active_containers.size()
			):
				return false
			if (
				dictionary_value.size() > max_collection_items
				or _active_analysis_container_exists(active_containers, dictionary_value)
			):
				return false
			active_containers.append(dictionary_value)
			stack.append({ "value": dictionary_value, "depth": depth, "exit": true })
			var keys: Array = dictionary_value.keys()
			for key_index: int in range(keys.size() - 1, -1, -1):
				if not _consume_producer_structure_work(validation_result):
					return false
				var key: Variant = keys[key_index]
				if not key is String:
					return false
				stack.append({ "value": dictionary_value[key], "depth": depth + 1, "exit": false })
				stack.append({ "value": key, "depth": depth + 1, "exit": false })
			continue
		if value is Array:
			var array_value: Array = value
			if not _consume_producer_structure_work(
				validation_result,
				active_containers.size()
			):
				return false
			if (
				array_value.size() > max_collection_items
				or _active_analysis_container_exists(active_containers, array_value)
			):
				return false
			active_containers.append(array_value)
			stack.append({ "value": array_value, "depth": depth, "exit": true })
			for item_index: int in range(array_value.size() - 1, -1, -1):
				if not _consume_producer_structure_work(validation_result):
					return false
				stack.append({ "value": array_value[item_index], "depth": depth + 1, "exit": false })
			continue
		if value == null or value is bool or value is int:
			continue
		if value is float:
			var float_value: float = value
			if not is_finite(float_value):
				return false
			continue
		return false
	return true


## 先扣 producer 工作额度，存在校验结果时再扣 validation 额度并触发其检查点；任一步拒绝都停止结构处理。
## [br]
## @api private
func _consume_producer_structure_work(
	validation_result: Dictionary,
	work_units: int = 1
) -> bool:
	if not _consume_producer_work(work_units):
		return false
	return (
		validation_result.is_empty()
		or _consume_validation_work(validation_result, work_units)
	)


## 返回 Array 或 PackedStringArray 的元素数；其他类型返回 -1。
## [br]
## @api private
## [br]
func _string_collection_size(value: Variant) -> int:
	if value is Array:
		var array_value: Array = value
		return array_value.size()
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value.size()
	return -1


## 将 Array 或 PackedStringArray 值按字符串列表读取，其他输入返回空列表。
## [br]
## @api private
## [br]
func _string_list_from_value(value: Variant) -> PackedStringArray:
	var wrapper: Dictionary = { "value": value }
	return _string_list(wrapper, "value")


## 汇总 root、排除前缀及库存路径字符串的 UTF-8 字节数。
## [br]
## @api private
## [br]
func _inventory_text_bytes(
	root_path: String,
	scope: Dictionary,
	directories: PackedStringArray,
	files: PackedStringArray
) -> int:
	var total: int = root_path.to_utf8_buffer().size()
	for excluded_prefix: String in _string_list(scope, "excluded_prefixes"):
		total += excluded_prefix.to_utf8_buffer().size()
	for relative_path: String in directories:
		total += relative_path.to_utf8_buffer().size()
	for relative_path: String in files:
		total += relative_path.to_utf8_buffer().size()
	return total


## 按元素数和逐次折半层数估算排序工作单位数。
## [br]
## @api private
## [br]
func _sort_work_units(item_count: int) -> int:
	if item_count <= 1:
		return item_count
	var levels: int = 0
	var remaining: int = item_count
	while remaining > 1:
		levels += 1
		remaining = ceili(float(remaining) / 2.0)
	return item_count * levels


## 检查四个边身份文本的非空和长度预算，计费后以种类、两端 ID 和 scope 的 SHA-256 前缀构造稳定边 ID。
## [br]
## @api private
func _stable_edge_id_admitted(
	edge_kind: String,
	from_node_id: String,
	to_node_id: String,
	scope: String
) -> String:
	var values: PackedStringArray = [edge_kind, from_node_id, to_node_id, scope]
	var total_bytes: int = 0
	for value: String in values:
		if value.is_empty() or value.length() > MAX_DATA_STRING_LENGTH:
			return ""
		var value_bytes: int = value.to_utf8_buffer().size()
		if total_bytes > MAX_INVENTORY_STRING_BYTES - value_bytes:
			return ""
		total_bytes += value_bytes
	if not _consume_producer_work(4 + ceili(float(total_bytes) / 256.0)):
		return ""
	return "edge:%s" % (
		"%s\n%s\n%s\n%s" % [edge_kind, from_node_id, to_node_id, scope]
	).sha256_text().substr(0, 16)


## 向共享集合追加一个已准入路径的库存节点及其证据；非根路径再追加由规范父目录指向该节点的 contains 边。
## [br]
## @api private
func _append_inventory_entry(
	nodes: Array,
	edges: Array,
	evidence: Array,
	node_kind: String,
	relative_path: String,
	root_path: String
) -> void:
	var node_id: String = _node_id(relative_path)
	var evidence_id: String = _inventory_evidence_id(node_kind, relative_path)
	nodes.append({
		"node_id": node_id,
		"node_kind": node_kind,
		"relative_path": relative_path,
		"scope": "project_source",
		"authority": "filesystem_inventory",
		"completeness": "observed",
		"evidence_ids": [evidence_id],
	})
	evidence.append({
		"evidence_id": evidence_id,
		"kind": "filesystem_inventory",
		"root_path": root_path,
		"relative_path": relative_path,
		"scope": "project_source",
		"authority": "filesystem_inventory",
		"observed": true,
	})
	if relative_path == ".":
		return
	var parent_path: String = _parent_path(relative_path)
	if parent_path.is_empty():
		parent_path = "."
	var parent_id: String = _node_id(parent_path)
	edges.append({
		"edge_id": _stable_edge_id_admitted(
			"contains",
			parent_id,
			node_id,
			"project_source"
		),
		"edge_kind": "contains",
		"from_node_id": parent_id,
		"to_node_id": node_id,
		"scope": "project_source",
		"evidence_ids": [evidence_id],
	})


## 依次校验图身份、scope、节点、证据、边、引用和库存边界，发现阶段错误即停止后续阶段；返回的局部索引仅在整个契约成功后可使用。
## [br]
## @api private
func _validate_graph(
	graph: Dictionary,
	root_path: String,
	result: Dictionary
) -> Dictionary:
	var graph_state: Dictionary = {
		"index": _empty_index(),
		"root_observed": false,
		"file_count": 0,
		"directory_count": 0,
		"digest": "",
	}
	if not _validation_has_exact_fields(graph, _GRAPH_FIELDS, result):
		_add_validation_error(result, "graph_schema_invalid", "graph", "graph 字段必须精确闭合。")
		return graph_state
	if (
		graph.get("schema_version") != 2
		or graph.get("kind") != "project_layout_graph"
		or graph.get("dependency_coverage") != "filesystem_only"
		or not graph.get("complete") is bool
	):
		_add_validation_error(result, "graph_identity_invalid", "graph", "graph 身份、complete 或 dependency_coverage 无效。")
		return graph_state
	var capture_status_value: Variant = graph.get("capture_status")
	if not capture_status_value is String:
		_add_validation_error(result, "graph_status_invalid", "graph.capture_status", "graph capture_status 无效。")
		return graph_state
	var capture_status: String = capture_status_value
	if not _CAPTURE_STATUSES.has(capture_status):
		_add_validation_error(result, "graph_status_invalid", "graph.capture_status", "graph capture_status 无效。")
		return graph_state
	var complete: bool = graph["complete"]
	if complete != (capture_status == "complete"):
		_add_validation_error(result, "graph_status_mismatch", "graph.capture_status", "graph complete 与 capture_status 不一致。")
	var scope_value: Variant = graph.get("scope")
	if not scope_value is Dictionary:
		_add_validation_error(result, "scope_schema_invalid", "graph.scope", "graph scope 必须是 Dictionary。")
		return graph_state
	var scope: Dictionary = scope_value
	_validate_scope(scope, root_path, complete, result)
	if not _get_result_errors(result).is_empty():
		return graph_state
	for array_field: String in ["nodes", "edges", "evidence"]:
		if not graph.get(array_field) is Array:
			_add_validation_error(result, "graph_schema_invalid", "graph.%s" % array_field, "graph 集合字段必须是 Array。")
	if not _get_result_errors(result).is_empty():
		return graph_state
	var index: Dictionary = graph_state["index"]
	_validate_nodes(graph, root_path, scope, index, graph_state, result)
	if not _get_result_errors(result).is_empty():
		return graph_state
	_validate_evidence(graph, root_path, scope, index, graph_state, result)
	if not _get_result_errors(result).is_empty():
		return graph_state
	_validate_edges(graph, index, graph_state, result)
	if not _get_result_errors(result).is_empty():
		return graph_state
	_validate_graph_evidence_refs(graph, root_path, index, graph_state, result)
	if not _get_result_errors(result).is_empty():
		return graph_state
	_validate_graph_boundary(graph, root_path, scope, index, graph_state, result)
	return graph_state


## 要求闭合 project_source 范围、规范唯一排除前缀及合法扫描预算；声明完整时还必须匹配权威的隐藏项和排除范围设置。
## [br]
## @api private
func _validate_scope(
	scope: Dictionary,
	root_path: String,
	complete: bool,
	result: Dictionary
) -> void:
	if not _validation_has_exact_fields(scope, _SCOPE_FIELDS, result):
		_add_validation_error(result, "scope_schema_invalid", "graph.scope", "project_source scope 字段必须精确闭合。")
		return
	if (
		scope.get("kind") != "project_source"
		or scope.get("root_path") != root_path
		or not scope.get("include_hidden") is bool
	):
		_add_validation_error(result, "scope_identity_invalid", "graph.scope", "project_source scope 身份无效。")
		return
	var excluded_value: Variant = scope.get("excluded_prefixes")
	if not excluded_value is Array:
		_add_validation_error(result, "scope_exclusions_invalid", "graph.scope.excluded_prefixes", "scope excluded_prefixes 必须是 Array。")
		return
	var excluded_prefixes: Array = excluded_value
	var seen_prefixes: Dictionary = {}
	for index: int in excluded_prefixes.size():
		if not _checkpoint_allows(index, result):
			return
		var prefix_value: Variant = excluded_prefixes[index]
		if not prefix_value is String:
			_add_validation_error(result, "scope_exclusions_invalid", "graph.scope.excluded_prefixes[%d]" % index, "scope 排除前缀必须是规范相对路径。")
			continue
		var prefix: String = prefix_value
		if not _is_canonical_relative_path(prefix, false):
			_add_validation_error(result, "scope_exclusions_invalid", "graph.scope.excluded_prefixes[%d]" % index, "scope 排除前缀必须是规范相对路径。")
			continue
		if seen_prefixes.has(prefix):
			_add_validation_error(result, "scope_exclusions_invalid", "graph.scope.excluded_prefixes[%d]" % index, "scope 排除前缀必须唯一。")
		seen_prefixes[prefix] = true
	var max_files_value: Variant = scope.get("max_scanned_files")
	var max_directories_value: Variant = scope.get("max_scanned_directories")
	var max_depth_value: Variant = scope.get("max_scan_depth")
	var budgets_are_admissible: bool = false
	if (
		max_files_value is int
		and max_directories_value is int
		and max_depth_value is int
	):
		var max_files: int = max_files_value
		var max_directories: int = max_directories_value
		var max_depth: int = max_depth_value
		budgets_are_admissible = inventory_budgets_are_admissible(
			max_files,
			max_directories,
			max_depth
		)
	if not budgets_are_admissible:
		_add_validation_error(
			result,
			"scope_budget_invalid",
			"graph.scope",
			"scope 捕获预算必须落在共享 inventory envelope 内。"
		)
	if not _CAPTURE_SCOPE_SCRIPT.binding_is_valid(_binding_from_scope(scope)):
		_add_validation_error(result, "scope_policy_invalid", "graph.scope", "scope 声明、来源映射或摘要无效。")
	if complete:
		if not _consume_validation_work(result, excluded_prefixes.size()):
			return
		if (
			scope.get("include_hidden") != true
			or not _CAPTURE_SCOPE_SCRIPT.binding_is_valid(_binding_from_scope(scope))
		):
			_add_validation_error(result, "complete_scope_not_authoritative", "graph.scope", "完整 graph 必须使用权威 project_source scope。")


## 验证库存节点身份与路径唯一性并建立索引，统计非根目录和文件；再核对根状态、scope 预算及每个非根节点的规范父目录。
## [br]
## @api private
func _validate_nodes(
	graph: Dictionary,
	_root_path: String,
	scope: Dictionary,
	index: Dictionary,
	graph_state: Dictionary,
	result: Dictionary
) -> void:
	var node_by_id: Dictionary = index["node_by_id"]
	var node_id_by_path: Dictionary = index["node_id_by_path"]
	var children_by_id: Dictionary = index["children_by_id"]
	var nodes: Array = graph["nodes"]
	var excluded_prefixes: PackedStringArray = _string_list(scope, "excluded_prefixes")
	if not _consume_validation_work(result, excluded_prefixes.size()):
		return
	for node_index: int in nodes.size():
		if not _checkpoint_allows(node_index, result):
			return
		var node_value: Variant = nodes[node_index]
		if not node_value is Dictionary:
			_add_validation_error(result, "node_schema_invalid", "graph.nodes[%d]" % node_index, "graph node 必须是 Dictionary。")
			continue
		var node: Dictionary = node_value
		if not _validation_has_exact_fields(node, _NODE_FIELDS, result):
			_add_validation_error(result, "node_schema_invalid", "graph.nodes[%d]" % node_index, "graph node 字段必须精确闭合。")
			continue
		var relative_path: String = _string(node, "relative_path")
		var node_id: String = _string(node, "node_id")
		var node_kind: String = _string(node, "node_kind")
		if not _consume_validation_work(
			result,
			maxi(1, ceili(float(relative_path.length()) / 256.0))
		):
			return
		if (
			node_id != _node_id(relative_path)
			or not ["file", "directory"].has(node_kind)
			or not _is_canonical_relative_path(relative_path, true)
			or node.get("scope") != "project_source"
			or node.get("authority") != "filesystem_inventory"
			or node.get("completeness") != "observed"
			or not node.get("evidence_ids") is Array
		):
			_add_validation_error(result, "node_value_invalid", "graph.nodes[%d]" % node_index, "graph node 值无效。")
			continue
		if node_by_id.has(node_id) or node_id_by_path.has(relative_path):
			_add_validation_error(result, "node_id_duplicate", "graph.nodes[%d]" % node_index, "graph node ID 与路径必须唯一。")
			continue
		if not _consume_validation_work(result, excluded_prefixes.size()):
			return
		if _is_under_excluded_prefix(relative_path, excluded_prefixes):
			_add_validation_error(result, "node_outside_scope", relative_path, "graph node 位于 scope 排除路径内。")
		node_by_id[node_id] = node
		node_id_by_path[relative_path] = node_id
		children_by_id[node_id] = []
		if relative_path != ".":
			if node_kind == "file":
				graph_state["file_count"] = _integer(graph_state, "file_count") + 1
			else:
				graph_state["directory_count"] = _integer(graph_state, "directory_count") + 1
	if node_id_by_path.has("."):
		graph_state["root_observed"] = true
		var root_node_id: String = node_id_by_path["."]
		var root_node: Dictionary = node_by_id[root_node_id]
		if _string(root_node, "node_kind") != "directory":
			_add_validation_error(result, "graph_root_invalid", "graph.nodes", "graph 根节点必须是 directory。")
	if _bool(graph, "complete") and not _bool(graph_state, "root_observed"):
		_add_validation_error(result, "graph_root_missing", "graph.nodes", "完整 graph 必须包含唯一根节点。")
	if _string(graph, "capture_status") == "partial" and not _bool(graph_state, "root_observed"):
		_add_validation_error(result, "graph_root_missing", "graph.nodes", "partial graph 必须包含已观察根节点。")
	if _string(graph, "capture_status") == "not_started" and not nodes.is_empty():
		_add_validation_error(result, "not_started_graph_not_empty", "graph.nodes", "not_started graph 不能包含库存节点。")
	if _integer(graph_state, "file_count") > _integer(scope, "max_scanned_files"):
		_add_validation_error(result, "scope_budget_mismatch", "graph.nodes", "graph 文件数超过 scope 预算。")
	if _integer(graph_state, "directory_count") > _integer(scope, "max_scanned_directories"):
		_add_validation_error(result, "scope_budget_mismatch", "graph.nodes", "graph 目录数超过 scope 预算。")
	var parent_path_index: int = 0
	for path_value: Variant in node_id_by_path.keys():
		if not _checkpoint_allows(parent_path_index, result):
			return
		parent_path_index += 1
		if not path_value is String:
			continue
		var relative_path: String = path_value
		if relative_path == ".":
			continue
		var parent_path: String = _parent_path(relative_path)
		if parent_path.is_empty():
			parent_path = "."
		if not node_id_by_path.has(parent_path):
			_add_validation_error(result, "node_parent_missing", relative_path, "graph node 缺少规范父目录。")
			continue
		var parent_node_id: String = node_id_by_path[parent_path]
		var parent_node: Dictionary = node_by_id[parent_node_id]
		if _string(parent_node, "node_kind") != "directory":
			_add_validation_error(result, "node_parent_not_directory", relative_path, "graph node 的规范父节点不是目录。")


## 按库存证据或库存边界的闭合联合形状校验唯一 ID、根和 authority；库存证据须关联已观察节点，边界证据须绑定同一 capture scope。
## [br]
## @api private
func _validate_evidence(
	graph: Dictionary,
	root_path: String,
	scope: Dictionary,
	index: Dictionary,
	_graph_state: Dictionary,
	result: Dictionary
) -> void:
	var evidence_by_id: Dictionary = index["evidence_by_id"]
	var evidence_items: Array = graph["evidence"]
	for evidence_index: int in evidence_items.size():
		if not _checkpoint_allows(evidence_index, result):
			return
		var evidence_value: Variant = evidence_items[evidence_index]
		if not evidence_value is Dictionary:
			_add_validation_error(result, "evidence_schema_invalid", "graph.evidence[%d]" % evidence_index, "graph evidence 必须是 Dictionary。")
			continue
		var evidence: Dictionary = evidence_value
		var evidence_kind: String = _string(evidence, "kind")
		var expected_fields: PackedStringArray = (
			_INVENTORY_EVIDENCE_FIELDS
			if evidence_kind == "filesystem_inventory"
			else _BOUNDARY_EVIDENCE_FIELDS
		)
		if (
			not ["filesystem_inventory", "filesystem_inventory_boundary"].has(evidence_kind)
			or not _validation_has_exact_fields(evidence, expected_fields, result)
		):
			_add_validation_error(result, "evidence_schema_invalid", "graph.evidence[%d]" % evidence_index, "graph evidence union 字段无效。")
			continue
		var evidence_id: String = _string(evidence, "evidence_id")
		if evidence_id.is_empty() or evidence_by_id.has(evidence_id):
			_add_validation_error(result, "evidence_id_duplicate", "graph.evidence[%d]" % evidence_index, "graph evidence ID 必须非空且唯一。")
			continue
		if (
			evidence.get("root_path") != root_path
			or evidence.get("scope") != "project_source"
			or evidence.get("authority") != "filesystem_inventory"
		):
			_add_validation_error(result, "evidence_boundary_invalid", "graph.evidence[%d]" % evidence_index, "graph evidence 的 root、scope 或 authority 无效。")
		if evidence_kind == "filesystem_inventory":
			var relative_path: String = _string(evidence, "relative_path")
			if not _consume_validation_work(
				result,
				maxi(1, ceili(float(relative_path.length()) / 256.0))
			):
				return
			var node_id_by_path: Dictionary = index["node_id_by_path"]
			if (
				not _is_canonical_relative_path(relative_path, true)
				or evidence.get("observed") != true
				or not node_id_by_path.has(relative_path)
			):
				_add_validation_error(result, "inventory_evidence_invalid", "graph.evidence[%d]" % evidence_index, "库存 evidence 未绑定已观察节点。")
		else:
			var capture_scope_matches: bool = _validation_values_are_equal(
				evidence.get("capture_scope"),
				scope,
				result
			)
			if _validation_terminal:
				return
			if not capture_scope_matches:
				_add_validation_error(result, "boundary_scope_mismatch", "graph.evidence[%d]" % evidence_index, "库存 boundary 未绑定 graph scope。")
		evidence_by_id[evidence_id] = evidence


## 只接收稳定 ID 的 contains 边，核对端点和规范父目录并构建子节点索引；要求 E=V-1、根无入边且每个非根节点恰有一条父边。
## [br]
## @api private
func _validate_edges(
	graph: Dictionary,
	index: Dictionary,
	graph_state: Dictionary,
	result: Dictionary
) -> void:
	var node_by_id: Dictionary = index["node_by_id"]
	var node_id_by_path: Dictionary = index["node_id_by_path"]
	var children_by_id: Dictionary = index["children_by_id"]
	var incoming_by_id: Dictionary = {}
	var edge_ids: Dictionary = {}
	var parent_edge_by_child: Dictionary = {}
	var edges: Array = graph["edges"]
	for edge_index: int in edges.size():
		if not _checkpoint_allows(edge_index, result):
			return
		var edge_value: Variant = edges[edge_index]
		if not edge_value is Dictionary:
			_add_validation_error(result, "edge_schema_invalid", "graph.edges[%d]" % edge_index, "graph edge 必须是 Dictionary。")
			continue
		var edge: Dictionary = edge_value
		if not _validation_has_exact_fields(edge, _EDGE_FIELDS, result):
			_add_validation_error(result, "edge_schema_invalid", "graph.edges[%d]" % edge_index, "graph edge 字段必须精确闭合。")
			continue
		var from_node_id: String = _string(edge, "from_node_id")
		var to_node_id: String = _string(edge, "to_node_id")
		var edge_id: String = _string(edge, "edge_id")
		var edge_identity_length: int = (
			from_node_id.length()
			+ to_node_id.length()
			+ edge_id.length()
			+ 23
		)
		if not _consume_validation_work(
			result,
			4 + maxi(1, ceili(float(edge_identity_length) / 256.0))
		):
			return
		var expected_edge_id: String = stable_edge_id(
			"contains",
			from_node_id,
			to_node_id,
			"project_source"
		)
		if expected_edge_id.is_empty():
			_fail_analysis_contract_limit(result)
			return
		if (
			edge.get("edge_kind") != "contains"
			or edge.get("scope") != "project_source"
			or not edge.get("evidence_ids") is Array
			or not node_by_id.has(from_node_id)
			or not node_by_id.has(to_node_id)
			or edge_id.is_empty()
			or edge_id != expected_edge_id
		):
			_add_validation_error(result, "edge_value_invalid", "graph.edges[%d]" % edge_index, "contains edge 值或 endpoint 无效。")
			continue
		if edge_ids.has(edge_id):
			_add_validation_error(result, "edge_id_duplicate", "graph.edges[%d]" % edge_index, "edge ID 必须唯一。")
			continue
		edge_ids[edge_id] = true
		incoming_by_id[to_node_id] = _integer_value(incoming_by_id.get(to_node_id, 0)) + 1
		var to_node: Dictionary = node_by_id[to_node_id]
		var relative_path: String = _string(to_node, "relative_path")
		var parent_path: String = _parent_path(relative_path)
		if parent_path.is_empty():
			parent_path = "."
		var expected_parent_id: String = _string_value(node_id_by_path.get(parent_path, ""))
		if from_node_id != expected_parent_id:
			_add_validation_error(result, "edge_parent_mismatch", "graph.edges[%d]" % edge_index, "contains edge 未连接规范父目录。")
		else:
			parent_edge_by_child[to_node_id] = true
		var child_values: Array = children_by_id[from_node_id]
		child_values.append(to_node_id)
	if edges.size() != maxi(node_by_id.size() - 1, 0):
		_add_validation_error(result, "edge_count_mismatch", "graph.edges", "contains 树必须满足 E=V-1。")
	var incoming_index: int = 0
	for node_id_value: Variant in node_by_id.keys():
		if not _checkpoint_allows(incoming_index, result):
			return
		incoming_index += 1
		if not node_id_value is String:
			continue
		var node_id: String = node_id_value
		var node: Dictionary = node_by_id[node_id]
		var relative_path: String = _string(node, "relative_path")
		var incoming_count: int = _integer_value(incoming_by_id.get(node_id, 0))
		if relative_path == ".":
			if incoming_count != 0:
				_add_validation_error(result, "graph_root_incoming_edge", "graph.edges", "graph 根节点不能有 contains 入边。")
		elif incoming_count != 1 or not parent_edge_by_child.has(node_id):
			_add_validation_error(result, "edge_parent_missing", relative_path, "每个非根节点必须恰有一条规范父 contains 边。")
	var child_sort_index: int = 0
	for parent_id_value: Variant in children_by_id.keys():
		if not _checkpoint_allows(child_sort_index, result):
			return
		child_sort_index += 1
		if parent_id_value is String:
			var child_ids: Array = children_by_id[parent_id_value]
			if not _consume_validation_work(result, _sort_work_units(child_ids.size())):
				return
			child_ids.sort()
	if _string(graph, "capture_status") == "not_started" and not edges.is_empty():
		_add_validation_error(result, "not_started_graph_not_empty", "graph.edges", "not_started graph 不能包含 edge。")
	graph_state["root_observed"] = node_id_by_path.has(".")


## 要求每个节点仅引用自身唯一库存证据，每条 contains 边仅引用子节点证据，并检查引用存在及路径、根一致。
## [br]
## @api private
func _validate_graph_evidence_refs(
	graph: Dictionary,
	root_path: String,
	index: Dictionary,
	_graph_state: Dictionary,
	result: Dictionary
) -> void:
	var evidence_by_id: Dictionary = index["evidence_by_id"]
	var node_by_id: Dictionary = index["node_by_id"]
	var node_index: int = 0
	for node_id_value: Variant in node_by_id.keys():
		if not _checkpoint_allows(node_index, result):
			return
		node_index += 1
		if not node_id_value is String:
			continue
		var node_id: String = node_id_value
		var node: Dictionary = node_by_id[node_id]
		var evidence_ids: Array = _array(node, "evidence_ids")
		var expected_evidence_id: String = _inventory_evidence_id(
			_string(node, "node_kind"),
			_string(node, "relative_path")
		)
		if evidence_ids.size() != 1 or evidence_ids[0] != expected_evidence_id:
			_add_validation_error(result, "node_evidence_invalid", _string(node, "relative_path"), "node 必须精确引用自己的库存 evidence。")
			continue
		if not evidence_by_id.has(expected_evidence_id):
			_add_validation_error(result, "evidence_reference_dangling", _string(node, "relative_path"), "node evidence 引用悬空。")
			continue
		var evidence: Dictionary = evidence_by_id[expected_evidence_id]
		if (
			_string(evidence, "kind") != "filesystem_inventory"
			or _string(evidence, "relative_path") != _string(node, "relative_path")
			or _string(evidence, "root_path") != root_path
		):
			_add_validation_error(result, "node_evidence_mismatch", _string(node, "relative_path"), "node 与库存 evidence 不一致。")
	var edge_index: int = 0
	for edge_value: Variant in graph["edges"]:
		if not _checkpoint_allows(edge_index, result):
			return
		edge_index += 1
		if not edge_value is Dictionary:
			continue
		var edge: Dictionary = edge_value
		var to_node_id: String = _string(edge, "to_node_id")
		if not node_by_id.has(to_node_id):
			continue
		var child_node: Dictionary = node_by_id[to_node_id]
		var expected_id: String = _inventory_evidence_id(
			_string(child_node, "node_kind"),
			_string(child_node, "relative_path")
		)
		var edge_evidence_ids: Array = _array(edge, "evidence_ids")
		if (
			edge_evidence_ids.size() != 1
			or edge_evidence_ids[0] != expected_id
			or not evidence_by_id.has(expected_id)
		):
			_add_validation_error(result, "edge_evidence_invalid", _string(edge, "edge_id"), "contains edge 必须精确引用子节点库存 evidence。")


## 从已验证节点重算库存摘要，核对边界证据精确绑定根、scope、状态和计数；已观察图恰有一条边界，未开始图不允许任何证据。
## [br]
## @api private
func _validate_graph_boundary(
	graph: Dictionary,
	root_path: String,
	scope: Dictionary,
	index: Dictionary,
	graph_state: Dictionary,
	result: Dictionary
) -> void:
	var directories: PackedStringArray = PackedStringArray()
	var files: PackedStringArray = PackedStringArray()
	var node_by_id: Dictionary = index["node_by_id"]
	var node_index: int = 0
	for node_value: Variant in node_by_id.values():
		if not _checkpoint_allows(node_index, result):
			return
		node_index += 1
		if not node_value is Dictionary:
			continue
		var node: Dictionary = node_value
		var relative_path: String = _string(node, "relative_path")
		if relative_path == ".":
			continue
		if _string(node, "node_kind") == "directory":
			var _append_directory: bool = directories.append(relative_path)
		else:
			var _append_file: bool = files.append(relative_path)
	var root_observed: bool = _bool(graph_state, "root_observed")
	var digest: String = _inventory_digest_for_validation(
		root_path,
		scope,
		_string(graph, "capture_status"),
		_bool(graph, "complete"),
		root_observed,
		directories,
		files,
		result
	)
	if digest.is_empty():
		if not _validation_terminal:
			_fail_analysis_contract_limit(result)
		return
	if not _consume_validation_work(result):
		return
	graph_state["digest"] = digest
	var boundary_count: int = 0
	var evidence_by_id: Dictionary = index["evidence_by_id"]
	var boundary_index: int = 0
	for evidence_value: Variant in evidence_by_id.values():
		if not _checkpoint_allows(boundary_index, result):
			return
		boundary_index += 1
		if not evidence_value is Dictionary:
			continue
		var evidence: Dictionary = evidence_value
		if _string(evidence, "kind") != "filesystem_inventory_boundary":
			continue
		boundary_count += 1
		var capture_scope_matches: bool = _validation_values_are_equal(
			evidence.get("capture_scope"),
			scope,
			result
		)
		if _validation_terminal:
			return
		if (
			_string(evidence, "evidence_id") != "evidence:inventory:%s" % digest.substr(0, 16)
			or evidence.get("root_path") != root_path
			or not capture_scope_matches
			or evidence.get("capture_status") != graph.get("capture_status")
			or evidence.get("complete") != graph.get("complete")
			or evidence.get("file_count") != _integer(graph_state, "file_count")
			or evidence.get("directory_count") != _integer(graph_state, "directory_count")
			or evidence.get("input_digest") != digest
		):
			_add_validation_error(result, "inventory_boundary_mismatch", "graph.evidence", "库存 boundary 未精确绑定 root、scope、status、counts 或 digest。")
	if root_observed and boundary_count != 1:
		_add_validation_error(result, "inventory_boundary_count_invalid", "graph.evidence", "已观察 graph 必须恰有一条库存 boundary。")
	if not root_observed and boundary_count != 0:
		_add_validation_error(result, "inventory_boundary_count_invalid", "graph.evidence", "未开始 graph 不能包含库存 boundary。")
	var expected_evidence_count: int = node_by_id.size() + (1 if root_observed else 0)
	if evidence_by_id.size() != expected_evidence_count:
		_add_validation_error(result, "evidence_count_mismatch", "graph.evidence", "graph evidence 必须由每节点一条库存证据和可选唯一 boundary 组成。")
	if _string(graph, "capture_status") == "not_started" and not evidence_by_id.is_empty():
		_add_validation_error(result, "not_started_graph_not_empty", "graph.evidence", "not_started graph 不能包含 evidence。")


## 要求 findings 与 issues 内容和类型一致，按语义身份及出现序号重算唯一 ID；同时核对证据引用闭合和顶层严重级别计数。
## [br]
## @api private
func _validate_findings(
	analysis: Dictionary,
	index: Dictionary,
	result: Dictionary
) -> void:
	if not analysis.get("findings") is Array or not analysis.get("issues") is Array:
		_add_validation_error(result, "finding_schema_invalid", "findings", "analysis findings 与 issues 必须是 Array。")
		return
	var findings: Array = analysis["findings"]
	var issues: Array = analysis["issues"]
	if not _validation_values_are_equal(findings, issues, result):
		if _validation_terminal:
			return
		_add_validation_error(result, "finding_issue_mismatch", "findings", "analysis findings 必须与 issues 内容一致。")
	var finding_by_id: Dictionary = index["finding_by_id"]
	var evidence_by_id: Dictionary = index["evidence_by_id"]
	var occurrence_by_identity: Dictionary = {}
	var severity_counts: Dictionary = {
		"error": 0,
		"warning": 0,
		"info": 0,
	}
	for finding_index: int in findings.size():
		if not _checkpoint_allows(finding_index, result):
			return
		var finding_value: Variant = findings[finding_index]
		if not finding_value is Dictionary:
			_add_validation_error(result, "finding_schema_invalid", "findings[%d]" % finding_index, "finding 必须是 Dictionary。")
			continue
		var finding: Dictionary = finding_value
		var expected_fields: PackedStringArray = (
			_FINDING_FIELDS_WITH_REASON if finding.has("reason_code") else _FINDING_FIELDS
		)
		if not _validation_has_exact_fields(finding, expected_fields, result):
			_add_validation_error(result, "finding_schema_invalid", "findings[%d]" % finding_index, "finding 字段必须精确闭合。")
			continue
		var severity: String = _string(finding, "severity")
		var finding_id: String = _string(finding, "finding_id")
		if (
			not severity_counts.has(severity)
			or finding_id.is_empty()
			or _string(finding, "kind").is_empty()
			or _string(finding, "message").is_empty()
			or not finding.get("path") is String
			or not finding.get("context") is Dictionary
			or _string(finding, "confidence").is_empty()
			or not finding.get("evidence_ids") is Array
		):
			_add_validation_error(result, "finding_value_invalid", "findings[%d]" % finding_index, "finding 值无效。")
			continue
		var identity: String = _admitted_finding_identity_seed_for_validation(
			finding,
			result
		)
		if identity.is_empty():
			if not _validation_terminal:
				_fail_analysis_contract_limit(result)
			return
		var occurrence: int = _integer_value(occurrence_by_identity.get(identity, 0))
		occurrence_by_identity[identity] = occurrence + 1
		if not _consume_validation_work(
			result,
			maxi(1, ceili(float(identity.length()) / 256.0))
		):
			return
		var expected_finding_id: String = "finding:%s" % (
			"%s\noccurrence=%d" % [identity, occurrence]
		).sha256_text().substr(0, 16)
		if expected_finding_id.is_empty():
			_fail_analysis_contract_limit(result)
			return
		if finding_id != expected_finding_id or finding_by_id.has(finding_id):
			_add_validation_error(result, "finding_id_invalid", "findings[%d].finding_id" % finding_index, "finding ID 未按语义身份稳定生成或发生重复。")
			continue
		finding_by_id[finding_id] = finding
		severity_counts[severity] = _integer(severity_counts, severity) + 1
		var seen_refs: Dictionary = {}
		var evidence_ref_index: int = 0
		for evidence_id_value: Variant in finding["evidence_ids"]:
			if not _checkpoint_allows(evidence_ref_index, result):
				return
			evidence_ref_index += 1
			if not evidence_id_value is String:
				_add_validation_error(result, "finding_evidence_invalid", "findings[%d].evidence_ids" % finding_index, "finding evidence ID 必须是字符串。")
				continue
			var evidence_id: String = evidence_id_value
			if seen_refs.has(evidence_id) or not evidence_by_id.has(evidence_id):
				_add_validation_error(result, "finding_evidence_dangling", "findings[%d].evidence_ids" % finding_index, "finding evidence 引用必须唯一且闭合。")
			seen_refs[evidence_id] = true
	for severity: String in severity_counts:
		if analysis.get("%s_count" % severity) != severity_counts[severity]:
			_add_validation_error(result, "finding_count_mismatch", "%s_count" % severity, "finding severity count 与顶层计数不一致。")


## 检查闭合规则结果与精确计数；覆盖必须回指冻结捕获声明，零检查不能报告成功。
## [br]
## @api private
func _validate_rule_results(analysis: Dictionary, result: Dictionary) -> void:
	var values: Variant = analysis.get("rule_results")
	if not values is Array:
		_add_validation_error(result, "rule_result_schema_invalid", "rule_results", "rule_results 必须是 Array。")
		return
	var rule_results: Array = values
	var ids: Dictionary = {}
	var scope: Dictionary = _dictionary(_dictionary(analysis, "graph"), "scope")
	var declaration: Dictionary = _dictionary(scope, "capture_scope")
	var expected_exclusions: Array[String] = []
	for excluded_value: Variant in _array(declaration, "excluded_roots"):
		if not _consume_validation_work(result, 1):
			return
		if excluded_value is Dictionary:
			var excluded: Dictionary = excluded_value
			expected_exclusions.append(_string(excluded, "path"))
	for rule_index: int in rule_results.size():
		if not _checkpoint_allows(rule_index, result):
			return
		var rule_value: Variant = rule_results[rule_index]
		if not rule_value is Dictionary:
			_add_validation_error(result, "rule_result_schema_invalid", "rule_results[%d]" % rule_index, "rule result 必须是 Dictionary。")
			continue
		var rule_result: Dictionary = rule_value
		if not _validation_has_exact_fields(rule_result, _RULE_RESULT_FIELDS, result):
			_add_validation_error(result, "rule_result_schema_invalid", "rule_results[%d]" % rule_index, "rule result 字段必须精确闭合。")
			continue
		var rule_id: String = _string(rule_result, "id")
		var checked_count: Variant = rule_result.get("checked_count")
		var issue_count: Variant = rule_result.get("issue_count")
		if (
			rule_id.is_empty()
			or ids.has(rule_id)
			or _string(rule_result, "kind").is_empty()
			or not ["error", "warning", "info"].has(_string(rule_result, "severity"))
			or not checked_count is int
			or checked_count < 0
			or not issue_count is int
			or issue_count < 0
			or not rule_result.get("success") is bool
			or rule_result.get("success") != (issue_count == 0 and checked_count > 0)
			or not ["complete", "scope_limited", "skipped"].has(rule_result.get("evaluation_status"))
			or not rule_result.get("coverage") is Dictionary
		):
			_add_validation_error(result, "rule_result_value_invalid", "rule_results[%d]" % rule_index, "rule result 值无效。")
		var coverage: Dictionary = _dictionary(rule_result, "coverage")
		if (
			not _has_exact_fields(coverage, PackedStringArray(["scope", "excluded_roots"]))
			or coverage.get("scope") != "declared_included"
			or not coverage.get("excluded_roots") is Array
			or coverage.get("excluded_roots") != expected_exclusions
		):
			_add_validation_error(result, "rule_result_coverage_invalid", "rule_results[%d].coverage" % rule_index, "规则覆盖必须精确回指捕获声明的 included scope。")
		if checked_count is int:
			var expected_status: String = (
				"skipped" if checked_count == 0
				else ("scope_limited" if not expected_exclusions.is_empty() else "complete")
			)
			if rule_result.get("evaluation_status") != expected_status:
				_add_validation_error(result, "rule_result_status_invalid", "rule_results[%d].evaluation_status" % rule_index, "规则状态必须与检查计数及捕获声明一致。")
		ids[rule_id] = true


## 允许空能力字典；非空时要求闭合字段、非空执行器 ID、analyze 操作及规则和区域描述的基础容器类型。
## [br]
## @api private
func _validate_capabilities(analysis: Dictionary, result: Dictionary) -> void:
	var capabilities_value: Variant = analysis.get("capabilities")
	if not capabilities_value is Dictionary:
		_add_validation_error(result, "capabilities_schema_invalid", "capabilities", "analysis capabilities 必须是 Dictionary。")
		return
	var capabilities: Dictionary = capabilities_value
	if capabilities.is_empty():
		return
	if not _validation_has_exact_fields(capabilities, _CAPABILITY_FIELDS, result):
		_add_validation_error(result, "capabilities_schema_invalid", "capabilities", "analysis capabilities 字段必须精确闭合。")
		return
	if (
		_string(capabilities, "executor_id").is_empty()
		or _string(capabilities, "operation") != "analyze"
		or not capabilities.get("rule_kinds") is Array
		or not capabilities.get("rule_fields") is Dictionary
		or not capabilities.get("zone_fields") is Array
	):
		_add_validation_error(result, "capabilities_value_invalid", "capabilities", "analysis capabilities 值无效。")


## 核对求值与捕获完整性、图计数和摘要，并要求 success 仅由 error_count 决定；effects 必须精确声明不写项目。
## [br]
## @api private
func _validate_analysis_cross_fields(
	analysis: Dictionary,
	graph: Dictionary,
	graph_state: Dictionary,
	result: Dictionary
) -> void:
	for bool_field: String in [
		"evaluation_complete",
		"input_complete",
		"success",
	]:
		if not analysis.get(bool_field) is bool:
			_add_validation_error(result, "analysis_value_invalid", bool_field, "analysis bool 字段类型无效。")
	var evaluation_status_value: Variant = analysis.get("evaluation_status")
	if not evaluation_status_value is String:
		_add_validation_error(result, "analysis_status_invalid", "evaluation_status", "analysis evaluation_status 无效。")
		return
	var evaluation_status: String = evaluation_status_value
	if not _EVALUATION_STATUSES.has(evaluation_status):
		_add_validation_error(result, "analysis_status_invalid", "evaluation_status", "analysis evaluation_status 无效。")
		return
	var evaluation_complete: bool = _bool(analysis, "evaluation_complete")
	var input_complete: bool = _bool(analysis, "input_complete")
	var capture_status: String = _string(graph, "capture_status")
	if evaluation_complete != (evaluation_status == "complete"):
		_add_validation_error(result, "analysis_status_mismatch", "evaluation_status", "evaluation_status 与 evaluation_complete 不一致。")
	if evaluation_complete and not input_complete:
		_add_validation_error(result, "analysis_status_mismatch", "evaluation_complete", "完整 evaluation 必须建立在完整 input 上。")
	if input_complete != _bool(graph, "complete"):
		_add_validation_error(result, "analysis_status_mismatch", "input_complete", "analysis input_complete 必须与 graph.complete 一致。")
	if evaluation_status == "input_incomplete" and input_complete:
		_add_validation_error(result, "analysis_status_mismatch", "evaluation_status", "input_incomplete 只能用于不完整库存。")
	if capture_status != "complete" and evaluation_status == "complete":
		_add_validation_error(result, "analysis_status_mismatch", "evaluation_status", "不完整捕获不能声明 complete 求值状态。")
	if not analysis.get("profile_id") is String:
		_add_validation_error(result, "analysis_value_invalid", "profile_id", "analysis profile_id 必须是 String。")
	if analysis.get("file_count") != _integer(graph_state, "file_count"):
		_add_validation_error(result, "analysis_count_mismatch", "file_count", "analysis file_count 与 graph 不一致。")
	if analysis.get("directory_count") != _integer(graph_state, "directory_count"):
		_add_validation_error(result, "analysis_count_mismatch", "directory_count", "analysis directory_count 与 graph 不一致。")
	if analysis.get("input_digest") != _string(graph_state, "digest"):
		_add_validation_error(result, "analysis_digest_mismatch", "input_digest", "analysis input_digest 未绑定 scope 与排序库存。")
	var error_count_value: Variant = analysis.get("error_count")
	if not error_count_value is int or error_count_value < 0:
		_add_validation_error(result, "analysis_count_invalid", "error_count", "analysis error_count 必须是非负整数。")
	elif analysis.get("success") != (error_count_value == 0):
		_add_validation_error(result, "analysis_success_mismatch", "success", "analysis success 必须仅由 error_count 决定。")
	for count_field: String in ["warning_count", "info_count", "file_count", "directory_count"]:
		var count_value: Variant = analysis.get(count_field)
		if not count_value is int or count_value < 0:
			_add_validation_error(result, "analysis_count_invalid", count_field, "analysis count 必须是非负整数。")
	var effects_value: Variant = analysis.get("effects")
	if not effects_value is Dictionary:
		_add_validation_error(result, "analysis_effects_invalid", "effects", "analysis effects 必须是 Dictionary。")
	else:
		var effects: Dictionary = effects_value
		if effects.size() != 1 or effects.get("writes_project") != false:
			_add_validation_error(result, "analysis_effects_invalid", "effects", "analysis effects 必须精确声明 writes_project=false。")


## 以严重级别、种类、路径、原因码和规范 context 编码组成语义身份；展示 message 和证据引用不进入该种子。
## [br]
## @api private
func _finding_identity_seed(finding: Dictionary) -> String:
	return "\n".join(PackedStringArray([
		"severity=%s" % _string(finding, "severity"),
		"kind=%s" % _string(finding, "kind"),
		"path=%s" % _string(finding, "path"),
		"reason_code=%s" % _string(finding, "reason_code"),
		"context=%s" % _canonical_value(_dictionary(finding, "context"), 0),
	]))


## 重置 producer 预算并验证 finding 的有界纯数据形状，预留排序工作后生成身份种子；拒绝时返回空串。
## [br]
## @api private
func _admitted_finding_identity_seed(finding: Dictionary) -> String:
	_begin_producer_operation()
	if not _producer_structure_is_admissible(
		finding,
		_MAX_STABLE_ID_STRUCTURE_VALUES,
		_MAX_STABLE_ID_COLLECTION_ITEMS,
		_MAX_STABLE_ID_DEPTH,
		MAX_INVENTORY_STRING_BYTES
	):
		return ""
	if not _consume_producer_work(
		_sort_work_units(_MAX_STABLE_ID_STRUCTURE_VALUES)
	):
		return ""
	return _finding_identity_seed(finding)


## 在 producer 与 validation 双重预算下准入 finding，并逐步编码 context 和身份文本；任何终态或额度拒绝都返回空串。
## [br]
## @api private
func _admitted_finding_identity_seed_for_validation(
	finding: Dictionary,
	result: Dictionary
) -> String:
	_begin_producer_operation()
	if not _producer_structure_is_admissible(
		finding,
		_MAX_STABLE_ID_STRUCTURE_VALUES,
		_MAX_STABLE_ID_COLLECTION_ITEMS,
		_MAX_STABLE_ID_DEPTH,
		MAX_INVENTORY_STRING_BYTES,
		result
	):
		return ""
	var context_text: String = _canonical_value_for_validation(
		_dictionary(finding, "context"),
		0,
		result
	)
	if _validation_terminal:
		return ""
	var identity: String = "\n".join(PackedStringArray([
		"severity=%s" % _string(finding, "severity"),
		"kind=%s" % _string(finding, "kind"),
		"path=%s" % _string(finding, "path"),
		"reason_code=%s" % _string(finding, "reason_code"),
		"context=%s" % context_text,
	]))
	if not _consume_validation_work(
		result,
		maxi(1, ceili(float(identity.length()) / 256.0))
	):
		return ""
	return identity


## 对已准入值生成带类型标记的规范文本，数组保序、字典键排序；遍历和排序均计费，深度或类型不支持时使校验终止。
## [br]
## @api private
func _canonical_value_for_validation(
	value: Variant,
	depth: int,
	result: Dictionary
) -> String:
	if not _consume_validation_work(result):
		return ""
	if depth >= 12:
		_fail_analysis_contract_limit(result)
		return ""
	if value == null:
		return "null"
	if value is bool:
		return "bool:%s" % str(value)
	if value is int:
		return "int:%d" % value
	if value is float:
		return "float:%s" % str(value)
	if value is String:
		var text: String = value
		if not _consume_validation_work(
			result,
			maxi(1, ceili(float(text.length()) / 256.0))
		):
			return ""
		return "string:%d:%s" % [text.length(), text]
	if value is Array:
		var array_value: Array = value
		var items: PackedStringArray = PackedStringArray()
		for item: Variant in array_value:
			var item_text: String = _canonical_value_for_validation(
				item,
				depth + 1,
				result
			)
			if _validation_terminal:
				return ""
			var _append_item: bool = items.append(item_text)
		return "array:[%s]" % "|".join(items)
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		var keys: PackedStringArray = PackedStringArray()
		for key_value: Variant in dictionary_value.keys():
			if not _consume_validation_work(result):
				return ""
			if not key_value is String:
				_fail_analysis_contract_limit(result)
				return ""
			var key: String = key_value
			var _append_key: bool = keys.append(key)
		if not _consume_validation_work(
			result,
			maxi(1, _sort_work_units(keys.size()))
		):
			return ""
		keys.sort()
		if not _consume_validation_work(result):
			return ""
		var entries: PackedStringArray = PackedStringArray()
		for key: String in keys:
			var key_text: String = _canonical_value_for_validation(
				key,
				depth + 1,
				result
			)
			var value_text: String = _canonical_value_for_validation(
				dictionary_value.get(key),
				depth + 1,
				result
			)
			if _validation_terminal:
				return ""
			var _append_entry: bool = entries.append(
				"%s=%s" % [key_text, value_text]
			)
		return "dictionary:{%s}" % "|".join(entries)
	_fail_analysis_contract_limit(result)
	return ""


## 为已准入值生成类型化稳定文本，保留数组顺序并排序字典键；防御性深度和不支持类型返回标记，正式入口先完成有界结构准入。
## [br]
## @api private
func _canonical_value(value: Variant, depth: int) -> String:
	if depth >= 12:
		return "depth_limit"
	if value == null:
		return "null"
	if value is bool:
		return "bool:%s" % str(value)
	if value is int:
		return "int:%d" % value
	if value is float:
		return "float:%s" % str(value)
	if value is String or value is StringName:
		var text: String = _string_value(value)
		return "string:%d:%s" % [text.length(), text]
	if value is PackedStringArray:
		var packed_values: PackedStringArray = value
		return _canonical_value(Array(packed_values), depth + 1)
	if value is Array:
		var array_value: Array = value
		var items: PackedStringArray = PackedStringArray()
		for item: Variant in array_value:
			var _append_item: bool = items.append(_canonical_value(item, depth + 1))
		return "array:[%s]" % "|".join(items)
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		var keys: PackedStringArray = PackedStringArray()
		for key_value: Variant in dictionary_value.keys():
			var _append_key: bool = keys.append(_string_value(key_value))
		keys.sort()
		var entries: PackedStringArray = PackedStringArray()
		for key: String in keys:
			var _append_entry: bool = entries.append(
				"%s=%s" % [_canonical_value(key, depth + 1), _canonical_value(dictionary_value.get(key), depth + 1)]
			)
		return "dictionary:{%s}" % "|".join(entries)
	return "unsupported:%d" % typeof(value)


## 构造 validate_and_index 结果使用的五个空索引字典。
## [br]
## @api private
## [br]
func _empty_index() -> Dictionary:
	return {
		"node_by_id": {},
		"node_id_by_path": {},
		"children_by_id": {},
		"evidence_by_id": {},
		"finding_by_id": {},
	}


## 为一次校验循环步骤消费一个工作单位；item_index 仅保留调用形状，不用于降低检查频率。
## [br]
## @api private
func _checkpoint_allows(_item_index: int, result: Dictionary) -> bool:
	return _consume_validation_work(result)


## 无效回调视为允许继续；有效回调须无参数并返回 true 才允许继续。
## [br]
## @api private
## [br]
func _operation_checkpoint_allows(checkpoint: Callable) -> bool:
	if not checkpoint.is_valid():
		return true
	var checkpoint_value: Variant = checkpoint.call()
	return checkpoint_value is bool and checkpoint_value


## 给已验证的相对路径加 path 前缀，保留路径文本作为库存节点身份。
## [br]
## @api private
func _node_id(relative_path: String) -> String:
	return "path:%s" % relative_path


## 用节点种类和相对路径的 SHA-256 前 16 位生成库存证据 ID，区分同路径的文件和目录身份。
## [br]
## @api private
func _inventory_evidence_id(node_kind: String, relative_path: String) -> String:
	return "evidence:%s" % (
		"%s\n%s" % [node_kind, relative_path]
	).sha256_text().substr(0, 16)


## 返回最后一个斜杠之前的路径；无斜杠时返回空字符串。
## [br]
## @api private
## [br]
func _parent_path(relative_path: String) -> String:
	var slash_index: int = relative_path.rfind("/")
	if slash_index < 0:
		return ""
	return relative_path.substr(0, slash_index)


## 只接受无边缘空白和反斜杠的 res:// 根或规范子路径，不进行磁盘存在性检查。
## [br]
## @api private
func _is_canonical_root(root_path: String) -> bool:
	return _CAPTURE_SCOPE_SCRIPT.root_is_canonical(root_path)


## 提取唯一声明 binding 的字段，不接受数据中额外权威标志。
## [br]
## @api private
func _binding_from_scope(scope: Dictionary) -> Dictionary:
	var binding: Dictionary = {}
	for field: String in ["capture_scope", "source_root", "root_path", "protected_roots", "profile_source_path", "excluded_prefixes", "policy_digest"]:
		if not scope.has(field):
			return {}
		binding[field] = scope[field]
	return binding


## 按 allow_root 决定是否接受点根，其他路径不得为空、绝对路径或包含空段、点段、父段、冒号及反斜杠。
## [br]
## @api private
func _is_canonical_relative_path(relative_path: String, allow_root: bool) -> bool:
	if allow_root and relative_path == ".":
		return true
	if (
		relative_path.is_empty()
		or relative_path != relative_path.strip_edges()
		or relative_path.contains("\\")
		or relative_path.begins_with("/")
		or relative_path.ends_with("/")
		or relative_path.contains(":")
	):
		return false
	for part: String in relative_path.split("/", true):
		if part.is_empty() or part == "." or part == "..":
			return false
	return true


## 按完整路径段匹配排除前缀本身及其后代；项目根点始终不被排除。
## [br]
## @api private
func _is_under_excluded_prefix(
	relative_path: String,
	excluded_prefixes: PackedStringArray
) -> bool:
	if relative_path == ".":
		return false
	for prefix: String in excluded_prefixes:
		if relative_path == prefix or relative_path.begins_with("%s/" % prefix):
			return true
	return false


## 判断字典键是否全部为字符串且与给定字段集合完全相同。
## [br]
## @api private
## [br]
func _has_exact_fields(value: Dictionary, fields: PackedStringArray) -> bool:
	if value.size() != fields.size():
		return false
	for key_value: Variant in value.keys():
		if not key_value is String:
			return false
		var key: String = key_value
		if not fields.has(key):
			return false
	return true


## 先为字典字段检查预留工作量，再验证精确字段集合；预算拒绝与字段不匹配均返回 false，由终态区分原因。
## [br]
## @api private
func _validation_has_exact_fields(
	value: Dictionary,
	fields: PackedStringArray,
	result: Dictionary
) -> bool:
	if not _consume_validation_work(result, 1 + value.size()):
		return false
	return _has_exact_fields(value, fields)


## 在校验预算内迭代比较已准入值，要求类型完全相同、字典文本键集合一致且数组顺序一致；不以数值宽松相等代替结构相等。
## [br]
## @api private
func _validation_values_are_equal(
	left_value: Variant,
	right_value: Variant,
	result: Dictionary
) -> bool:
	var stack: Array = [{ "left": left_value, "right": right_value }]
	while not stack.is_empty():
		if not _consume_validation_work(result):
			return false
		var pair_value: Variant = stack.pop_back()
		if not pair_value is Dictionary:
			_fail_analysis_contract_limit(result)
			return false
		var pair: Dictionary = pair_value
		var left: Variant = pair.get("left")
		var right: Variant = pair.get("right")
		if typeof(left) != typeof(right):
			return false
		if left is Dictionary:
			var left_dictionary: Dictionary = left
			var right_dictionary: Dictionary = right
			if left_dictionary.size() != right_dictionary.size():
				return false
			for key_value: Variant in left_dictionary.keys():
				if not _consume_validation_work(result):
					return false
				if not key_value is String or not right_dictionary.has(key_value):
					return false
				stack.append({
					"left": left_dictionary[key_value],
					"right": right_dictionary[key_value],
				})
			continue
		if left is Array:
			var left_array: Array = left
			var right_array: Array = right
			if left_array.size() != right_array.size():
				return false
			for item_index: int in range(left_array.size() - 1, -1, -1):
				if not _consume_validation_work(result):
					return false
				stack.append({
					"left": left_array[item_index],
					"right": right_array[item_index],
				})
			continue
		if left != right:
			return false
	return true


## 校验尚未终止时追加结构错误；错误数量接近上限时切换为统一资源终态并替换此前错误，防止继续积累。
## [br]
## @api private
func _add_validation_error(
	result: Dictionary,
	kind: String,
	path: String,
	message: String
) -> void:
	if _validation_terminal:
		return
	var errors: Array = _get_result_errors(result)
	if errors.size() >= _MAX_VALIDATION_ERRORS - 1:
		_fail_analysis_contract_limit(result)
		return
	errors.append({
		"kind": kind,
		"path": path,
		"message": message,
	})


## 读取 result.errors 数组；字段不是数组时返回空数组。
## [br]
## @api private
## [br]
func _get_result_errors(result: Dictionary) -> Array:
	var errors_value: Variant = result.get("errors")
	return errors_value if errors_value is Array else []


## 以默认值回退方式读取字典中的 String 或 StringName 字段。
## [br]
## @api private
## [br]
func _string(source: Dictionary, key: String, default_value: String = "") -> String:
	return _string_value(source.get(key, default_value), default_value)


## 将 StringName 转为 String；String 原样返回，其他类型返回默认值。
## [br]
## @api private
## [br]
func _string_value(value: Variant, default_value: String = "") -> String:
	if value is String:
		return value
	if value is StringName:
		var string_name_value: StringName = value
		return String(string_name_value)
	return default_value


## 读取字典中的 bool 字段；字段类型不匹配时返回默认值。
## [br]
## @api private
## [br]
func _bool(source: Dictionary, key: String, default_value: bool = false) -> bool:
	var value: Variant = source.get(key, default_value)
	return value if value is bool else default_value


## 读取字典中的 int 字段；字段类型不匹配时返回默认值。
## [br]
## @api private
## [br]
func _integer(source: Dictionary, key: String, default_value: int = 0) -> int:
	var value: Variant = source.get(key, default_value)
	return _integer_value(value, default_value)


## 返回 int 输入；其他类型返回默认值。
## [br]
## @api private
## [br]
func _integer_value(value: Variant, default_value: int = 0) -> int:
	return value if value is int else default_value


## 返回指定字段中的 Array；字段类型不匹配时返回空数组。
## [br]
## @api private
## [br]
func _array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key)
	return value if value is Array else []


## 返回指定字段中的 Dictionary；字段类型不匹配时返回空字典。
## [br]
## @api private
## [br]
func _dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key)
	return value if value is Dictionary else {}


## 从字典字段构造字符串列表；遇到非字符串数组元素时返回空列表。
## [br]
## @api private
## [br]
func _string_list(source: Dictionary, key: String) -> PackedStringArray:
	var value: Variant = source.get(key)
	var result: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value.duplicate()
	if not value is Array:
		return result
	var array_value: Array = value
	for item: Variant in array_value:
		if not item is String:
			return PackedStringArray()
		var string_item: String = item
		var _append_item: bool = result.append(string_item)
	return result
