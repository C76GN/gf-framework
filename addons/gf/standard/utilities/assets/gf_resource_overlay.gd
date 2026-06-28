## GFResourceOverlay: 通用资源覆盖链。
##
## 通过 base Resource 与一组 GFResourcePropertyPatch 构建资源变体。
## 覆盖链只关心属性差异和应用顺序，不绑定主题、材质、皮肤或项目目录策略。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 7.0.0
class_name GFResourceOverlay
extends Resource


# --- 导出变量 ---

## 覆盖链的来源资源。
## [br]
## @api public
## [br]
## @since 7.0.0
@export var base_resource: Resource = null

## 按顺序应用的属性补丁列表。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema patches: Array[GFResourcePropertyPatch]，越靠后的补丁优先级越高。
@export var patches: Array = []

## 调用方自定义元数据。GF 不解释该字段。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema metadata: Dictionary[String, Variant]，项目工具或编辑器 UI 自行读取的补充信息。
@export var metadata: Dictionary = {}

## resolve() 时是否默认复制 base Resource 后再应用覆盖链。
## [br]
## @api public
## [br]
## @since 7.0.0
var duplicate_base_on_resolve: bool = true

## 应用覆盖链时是否默认要求目标对象已经声明对应属性。
## [br]
## @api public
## [br]
## @since 7.0.0
var require_existing_property: bool = true

## 写入目标前是否默认复制 Array、Dictionary 与 Resource 值。
## [br]
## @api public
## [br]
## @since 7.0.0
var copy_values: bool = true

## 复制值时是否默认复制 Resource 实例。
## [br]
## @api public
## [br]
## @since 7.0.0
var duplicate_resources: bool = false

## 是否默认跳过和目标当前值相同的覆盖值。
## [br]
## @api public
## [br]
## @since 7.0.0
var skip_unchanged: bool = false


# --- 公共方法 ---

## 配置覆盖链。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param p_base_resource: 来源资源。
## [br]
## @param p_patches: 覆盖补丁列表。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @return 当前覆盖链实例。
## [br]
## @schema p_patches: Array[GFResourcePropertyPatch] copied into patches.
## [br]
## @schema p_metadata: Dictionary copied into metadata.
func configure(
	p_base_resource: Resource,
	p_patches: Array = [],
	p_metadata: Dictionary = {}
) -> GFResourceOverlay:
	base_resource = p_base_resource
	patches = p_patches.duplicate()
	metadata = p_metadata.duplicate(true)
	emit_changed()
	return self


## 追加一个属性补丁。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param patch: 要追加的补丁。
## [br]
## @return 追加成功返回 true。
func add_patch(patch: GFResourcePropertyPatch) -> bool:
	if patch == null:
		return false
	patches.append(patch)
	emit_changed()
	return true


## 清空覆盖补丁。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear_patches() -> void:
	patches.clear()
	emit_changed()


## 解析覆盖链并返回资源构建报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 解析选项。
## [br]
## @return 覆盖链构建报告，成功或部分成功时 resource 字段为结果资源。
## [br]
## @schema options: Dictionary，支持 duplicate_base、require_existing_property、copy_values、duplicate_resources、skip_unchanged、include_patch_reports、stop_on_failure 与 metadata。
## [br]
## @schema return: Dictionary，包含 ok、resource、patch_count、计数、路径、errors、patch_reports 和 metadata。
func resolve(options: Dictionary = {}) -> Dictionary:
	return GFResourcePropertyPatch.build_resource_chain(
		base_resource,
		patches,
		_merge_default_options(options)
	)


## 把覆盖链直接应用到现有对象。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param target: 目标对象。
## [br]
## @param options: 应用选项。
## [br]
## @return 覆盖链应用报告。
## [br]
## @schema options: Dictionary，支持 require_existing_property、copy_values、duplicate_resources、skip_unchanged、include_patch_reports、stop_on_failure 与 metadata。
## [br]
## @schema return: Dictionary，包含 ok、patch_count、计数、路径、errors、patch_reports 和 metadata。
func apply_to(target: Object, options: Dictionary = {}) -> Dictionary:
	return GFResourcePropertyPatch.apply_patch_chain(
		target,
		patches,
		_merge_default_options(options)
	)


## 获取补丁数量。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 补丁数量。
func get_patch_count() -> int:
	return patches.size()


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 覆盖链调试快照。
## [br]
## @schema return: Dictionary，包含 base_resource、base_resource_path、patch_count、patch_metadata、options 和 metadata。
func get_debug_snapshot() -> Dictionary:
	var patch_metadata: Array[Dictionary] = []
	for patch_variant: Variant in patches:
		var patch: GFResourcePropertyPatch = patch_variant if patch_variant is GFResourcePropertyPatch else null
		patch_metadata.append(patch.metadata.duplicate(true) if patch != null else {})
	return {
		"base_resource": base_resource,
		"base_resource_path": base_resource.resource_path if base_resource != null else "",
		"patch_count": patches.size(),
		"patch_metadata": patch_metadata,
		"options": {
			"duplicate_base_on_resolve": duplicate_base_on_resolve,
			"require_existing_property": require_existing_property,
			"copy_values": copy_values,
			"duplicate_resources": duplicate_resources,
			"skip_unchanged": skip_unchanged,
		},
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _merge_default_options(options: Dictionary) -> Dictionary:
	var merged: Dictionary = options.duplicate(true)
	if not merged.has("duplicate_base"):
		merged["duplicate_base"] = duplicate_base_on_resolve
	if not merged.has("require_existing_property"):
		merged["require_existing_property"] = require_existing_property
	if not merged.has("copy_values"):
		merged["copy_values"] = copy_values
	if not merged.has("duplicate_resources"):
		merged["duplicate_resources"] = duplicate_resources
	if not merged.has("skip_unchanged"):
		merged["skip_unchanged"] = skip_unchanged
	var overlay_metadata: Dictionary = metadata.duplicate(true)
	var option_metadata: Dictionary = GFVariantData.get_option_dictionary(merged, "metadata")
	var _merge_result: Dictionary = GFVariantData.merge_dictionary(overlay_metadata, option_metadata, true, true)
	merged["metadata"] = overlay_metadata
	return merged
