# Save 内部同步 checkpoint 的闭合数据契约。
extends RefCounted


# --- 常量 ---

## 框架保留的文档元数据键；项目保存请求不得写入。
## [br]
## @api framework_internal
## [br]
## @since unreleased
const METADATA_KEY: String = "_gf_sync"


# --- 框架内部方法 ---

## 创建尚未绑定账号的初始 checkpoint。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 独立的初始状态。
## [br]
## @schema return: Closed Dictionary with format_version:int(1),local_generation:int>=0,namespace:String,record_key:String,revision:String,acknowledged_generation:int>=0,intent:Dictionary.
static func initial() -> Dictionary:
	return {
		"format_version": 1,
		"local_generation": 0,
		"namespace": "",
		"record_key": "",
		"revision": "",
		"acknowledged_generation": 0,
		"intent": {},
	}


## 严格验证 checkpoint；意图与账号、记录、本地代际必须一致。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param checkpoint: 本地框架元数据。
## [br]
## @schema checkpoint: Closed Dictionary returned by initial(); intent is empty or a canonical GFStorageSyncRequest record. Entire checkpoint limited to depth68,100032 nodes,17MiB canonical bytes.
## [br]
## @return 有效时为 true，不执行宽容转换。
static func validate(checkpoint: Dictionary) -> bool:
	if checkpoint.size() != 7:
		return false
	for key: String in [
		"format_version",
		"local_generation",
		"acknowledged_generation",
	]:
		if not checkpoint.get(key) is int:
			return false
	for key: String in [
		"namespace",
		"record_key",
		"revision",
	]:
		if not checkpoint.get(key) is String:
			return false
	if not checkpoint.get("intent") is Dictionary:
		return false
	var generation: int = GFVariantData.get_option_int(checkpoint, "local_generation")
	var acknowledged: int = GFVariantData.get_option_int(checkpoint, "acknowledged_generation")
	var record_namespace: String = GFVariantData.get_option_string(checkpoint, "namespace")
	var key: String = GFVariantData.get_option_string(checkpoint, "record_key")
	var revision: String = GFVariantData.get_option_string(checkpoint, "revision")
	var intent: Dictionary = GFVariantData.get_option_dictionary(checkpoint, "intent")
	if (
		checkpoint.get("format_version") != 1
		or generation < 0
		or acknowledged < 0
		or acknowledged > generation
	):
		return false
	if record_namespace.is_empty() != key.is_empty() or revision.length() > 65536:
		return false
	if record_namespace.is_empty():
		if (
			not intent.is_empty()
			or not revision.is_empty()
			or acknowledged != 0
		):
			return false
	elif GFStorageSyncRequest.create(
		record_namespace,
		key,
		"validation"
	) == null:
		return false
	if not intent.is_empty():
		var request: GFStorageSyncRequest = GFStorageSyncRequest.from_record(intent)
		if (
			request == null
			or request.get_namespace() != record_namespace
			or request.get_key() != key
			or request.get_local_generation() > generation
		):
			return false
	var measured: Dictionary = GFDeterministicVariantSerializer.measure_canonical(
		checkpoint,
		{
			"allow_floats": true,
			"max_depth": 68,
			"max_items": 100032,
			"max_output_bytes": 17825792,
			"max_string_length": 16777216,
		}
	)
	return GFVariantData.get_option_bool(measured, "ok")


## 移除框架 checkpoint，返回项目可投影的文档副本。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param document: 已验证的本地文档。
## [br]
## @return 不含本地 checkpoint 的文档；空输入返回 null。
static func project_document(document: GFSaveDocument) -> GFSaveDocument:
	if document == null:
		return null
	var metadata: Dictionary = document.get_metadata()
	var _removed: bool = metadata.erase(METADATA_KEY)
	return GFSaveDocument.new().configure(
		document.get_schema_id(),
		document.get_schema_version(),
		document.get_sections(),
		metadata
	)
