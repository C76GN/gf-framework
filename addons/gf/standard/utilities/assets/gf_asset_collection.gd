## GFAssetCollection: 有序资产 ID 集合。
##
## 集合只保存稳定 `asset_id`、展示信息和调用方元数据，不持有已加载资源，
## 也不规定目录、分类、预览或业务用途。调用方可以用 `GFAssetCatalog`
## 解析条目，并在使用前获得缺失、重复和无效 ID 的完整性报告。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFAssetCollection
extends Resource


# --- 导出变量 ---

## 集合稳定 ID。
## [br]
## @api public
## [br]
## @since unreleased
@export var collection_id: StringName = &""

## 集合展示标题。
## [br]
## @api public
## [br]
## @since unreleased
@export var title: String = ""

## 集合用途说明。
## [br]
## @api public
## [br]
## @since unreleased
@export_multiline var description: String = ""

## 按调用方期望顺序保存的稳定资产 ID。
## [br]
## @api public
## [br]
## @since unreleased
@export var asset_ids: PackedStringArray = PackedStringArray()

## 调用方自定义元数据；框架不解释其中字段。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @schema metadata: Dictionary，包含调用方自定义且可序列化的集合元数据。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置集合。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param p_collection_id: 集合稳定 ID。
## [br]
## @param p_asset_ids: 有序资产 ID。
## [br]
## @param options: 可选 title、description 和 metadata。
## [br]
## @schema options: Dictionary，包含 title: String、description: String 和 metadata: Dictionary。
## [br]
## @return 当前集合。
func configure(
	p_collection_id: StringName,
	p_asset_ids: PackedStringArray = PackedStringArray(),
	options: Dictionary = {}
) -> GFAssetCollection:
	collection_id = p_collection_id
	title = GFVariantData.get_option_string(options, "title")
	description = GFVariantData.get_option_string(options, "description")
	asset_ids = p_asset_ids.duplicate()
	metadata = GFVariantData.get_option_dictionary(options, "metadata")
	return self


## 在指定位置添加资产 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param asset_id: 要添加的稳定资产 ID。
## [br]
## @param index: 插入位置；负数或超出末尾时追加。
## [br]
## @return 成功添加时返回 true；空 ID 或重复 ID 返回 false。
func add_asset_id(asset_id: StringName, index: int = -1) -> bool:
	if asset_id == &"" or has_asset_id(asset_id):
		return false
	var safe_index: int = index
	if safe_index < 0 or safe_index > asset_ids.size():
		safe_index = asset_ids.size()
	var insert_error: Error = asset_ids.insert(safe_index, String(asset_id)) as Error
	return insert_error == OK


## 移除首次出现的资产 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param asset_id: 要移除的稳定资产 ID。
## [br]
## @return 找到并移除时返回 true。
func remove_asset_id(asset_id: StringName) -> bool:
	var index: int = asset_ids.find(String(asset_id))
	if index < 0:
		return false
	asset_ids.remove_at(index)
	return true


## 移动资产 ID 到新的有序位置。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param asset_id: 要移动的稳定资产 ID。
## [br]
## @param target_index: 移除原位置后使用的目标下标；自动钳制到有效范围。
## [br]
## @return 找到并完成移动时返回 true。
func move_asset_id(asset_id: StringName, target_index: int) -> bool:
	var source_index: int = asset_ids.find(String(asset_id))
	if source_index < 0:
		return false
	var asset_id_text: String = asset_ids[source_index]
	asset_ids.remove_at(source_index)
	var safe_index: int = clampi(target_index, 0, asset_ids.size())
	var insert_error: Error = asset_ids.insert(safe_index, asset_id_text) as Error
	return insert_error == OK


## 检查集合是否包含资产 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param asset_id: 要查询的稳定资产 ID。
## [br]
## @return 至少出现一次时返回 true。
func has_asset_id(asset_id: StringName) -> bool:
	return asset_id != &"" and asset_ids.has(String(asset_id))


## 按集合顺序解析存在于目录中的资产条目。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param catalog: 用于解析稳定资产 ID 的目录。
## [br]
## @return 已解析条目；缺失、空或重复 ID 被跳过。
func resolve_entries(catalog: GFAssetCatalog) -> Array[GFAssetCatalogEntry]:
	var result: Array[GFAssetCatalogEntry] = []
	if catalog == null:
		return result
	var seen: Dictionary = {}
	for asset_id_text: String in asset_ids:
		var asset_id: StringName = StringName(asset_id_text.strip_edges())
		if asset_id == &"" or seen.has(asset_id):
			continue
		seen[asset_id] = true
		var entry: GFAssetCatalogEntry = catalog.get_entry(asset_id)
		if entry != null:
			result.append(entry)
	return result


## 对照资产目录校验集合完整性。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param catalog: 用于解析稳定资产 ID 的目录。
## [br]
## @return 包含缺失、重复、空 ID 和有序解析摘要的通用校验报告。
func validate_against(catalog: GFAssetCatalog) -> GFValidationReport:
	var subject: String = String(collection_id) if collection_id != &"" else "asset_collection"
	var report: GFValidationReport = GFValidationReport.new(subject, {
		"collection_id": collection_id,
		"title": title,
	})
	var resolved_ids: PackedStringArray = PackedStringArray()
	var missing_ids: PackedStringArray = PackedStringArray()
	var duplicate_ids: PackedStringArray = PackedStringArray()
	var invalid_indices: PackedInt32Array = PackedInt32Array()
	var seen: Dictionary = {}

	if collection_id == &"":
		var _missing_collection_id: RefCounted = report.add_error(
			&"missing_collection_id",
			"Asset collection requires a non-empty collection_id."
		)
	if catalog == null:
		var _missing_catalog: RefCounted = report.add_error(
			&"missing_catalog",
			"Asset collection validation requires a catalog."
		)

	for index: int in asset_ids.size():
		var asset_id_text: String = asset_ids[index].strip_edges()
		var asset_id: StringName = StringName(asset_id_text)
		if asset_id == &"":
			var _invalid_index_append: bool = invalid_indices.append(index)
			var _empty_asset_id: RefCounted = report.add_error(
				&"empty_asset_id",
				"Asset collection contains an empty asset_id.",
				index
			)
			continue
		if seen.has(asset_id):
			if not duplicate_ids.has(asset_id_text):
				var _duplicate_append: bool = duplicate_ids.append(asset_id_text)
			var _duplicate_asset_id: RefCounted = report.add_error(
				&"duplicate_asset_id",
				"Asset collection contains a duplicate asset_id.",
				asset_id_text
			)
			continue
		seen[asset_id] = true
		if catalog == null or not catalog.has_entry(asset_id):
			var _missing_append: bool = missing_ids.append(asset_id_text)
			if catalog != null:
				var _missing_asset_id: RefCounted = report.add_error(
					&"missing_asset_id",
					"Asset collection references an asset_id that is absent from the catalog.",
					asset_id_text
				)
			continue
		var _resolved_append: bool = resolved_ids.append(asset_id_text)

	report.extra_fields = {
		"requested_count": asset_ids.size(),
		"unique_count": seen.size(),
		"resolved_count": resolved_ids.size(),
		"resolved_asset_ids": resolved_ids,
		"missing_asset_ids": missing_ids,
		"duplicate_asset_ids": duplicate_ids,
		"invalid_indices": invalid_indices,
	}
	return report


## 创建集合深拷贝。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 新集合实例。
func duplicate_collection() -> GFAssetCollection:
	return from_dict(to_dict())


## 转换为可序列化字典。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 集合字段深拷贝。
## [br]
## @schema return: Dictionary，包含 collection_id、title、description、asset_ids 和 metadata。
func to_dict() -> Dictionary:
	return {
		"collection_id": collection_id,
		"title": title,
		"description": description,
		"asset_ids": asset_ids.duplicate(),
		"metadata": metadata.duplicate(true),
	}


## 从字典应用集合字段。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param data: GFAssetCollection.to_dict() 输出或兼容字段。
## [br]
## @schema data: Dictionary，包含 collection_id、title、description、asset_ids 和 metadata。
func apply_dict(data: Dictionary) -> void:
	collection_id = GFVariantData.get_option_string_name(data, "collection_id")
	title = GFVariantData.get_option_string(data, "title")
	description = GFVariantData.get_option_string(data, "description")
	asset_ids = GFVariantData.get_option_packed_string_array(data, "asset_ids")
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 从字典创建集合。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param data: GFAssetCollection.to_dict() 输出或兼容字段。
## [br]
## @schema data: Dictionary，包含 collection_id、title、description、asset_ids 和 metadata。
## [br]
## @return 新集合实例。
static func from_dict(data: Dictionary) -> GFAssetCollection:
	var collection: GFAssetCollection = GFAssetCollection.new()
	collection.apply_dict(data)
	return collection
