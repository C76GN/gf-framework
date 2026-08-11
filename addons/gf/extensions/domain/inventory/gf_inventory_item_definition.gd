## GFInventoryItemDefinition: 通用库存物品定义。
##
## 只描述库存系统需要理解的堆叠、分类和实例数据匹配规则，
## 不规定品质、装备、货币、掉落等项目业务语义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInventoryItemDefinition
extends Resource


# --- 导出变量 ---

## 物品稳定标识。
## [br]
## @api public
@export var item_id: StringName = &""

## 显示名称，供项目 UI 或编辑器工具使用。
## [br]
## @api public
@export var display_name: String = ""

## 描述文本，供项目 UI 或编辑器工具使用。
## [br]
## @api public
@export_multiline var description: String = ""

## 可选图标资源。
## [br]
## @api public
@export var icon: Texture2D = null

## 单个堆叠最多容纳的数量。
## [br]
## @api public
@export var max_stack_amount: int:
	get:
		return _max_stack_amount
	set(value):
		_max_stack_amount = maxi(value, 1)

## 同一物品最多占用的堆叠数量。小于等于 0 表示不限制。
## [br]
## @api public
@export var max_stack_count: int:
	get:
		return _max_stack_count
	set(value):
		_max_stack_count = maxi(value, 0)

## 分类标签。框架只保存和匹配，不解释具体含义。
## [br]
## @api public
## [br]
## @schema categories: Array[StringName]，用于项目自定义筛选的分类标签列表。
@export var categories: Array[StringName] = []

## 默认实例数据。空堆叠或空输入会按这些默认值参与兼容性比较。
## [br]
## @api public
## [br]
## @schema default_instance_data: Dictionary，物品实例数据默认值；用于堆叠兼容性比较和序列化。
@export var default_instance_data: Dictionary = {}

## 用于判断堆叠兼容性的实例数据字段。为空时比较完整实例数据。
## [br]
## @api public
@export var stack_key_fields: PackedStringArray = PackedStringArray()

## 项目自定义元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，项目自定义物品定义元数据；GF 不读取或改写其中字段。
@export var metadata: Dictionary = {}


# --- 公共变量 ---

## 可选堆叠兼容性回调。签名为
## `Callable(left: Dictionary, right: Dictionary, definition: GFInventoryItemDefinition) -> bool`。
## 回调必须同步、确定、只读且有界，不得执行 I/O、产生外部副作用或依赖调用次数；
## 一次 mutation 或事务的 prepare/commit 重规划可能调用零次或多次。回调必须指向
## 可反射参数元数据的具名 Object 方法；匿名 lambda 和其他不透明 Callable 会在
## 调用前失败关闭。
## [br]
## @api public
## [br]
## @since 3.3.0
var compatibility_checker: Callable = Callable()


# --- 私有变量 ---

var _max_stack_amount: int = 99
var _max_stack_count: int = 0


# --- 公共方法 ---

## 获取稳定物品标识。
## [br]
## @api public
## [br]
## @return: 物品标识。
func get_item_id() -> StringName:
	return item_id


## 获取可显示名称。
## [br]
## @api public
## [br]
## @return: 显示名称；为空时回退到 item_id 或资源文件名。
func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if item_id != &"":
		return String(item_id)
	if not resource_path.is_empty():
		return resource_path.get_file().get_basename().capitalize()
	return "Inventory Item"


## 检查是否包含分类标签。
## [br]
## @api public
## [br]
## @param category: 分类标签。
## [br]
## @return: 包含时返回 true。
func has_category(category: StringName) -> bool:
	return categories.has(category)


## 检查是否满足全部分类标签。
## [br]
## @api public
## [br]
## @param required_categories: 需要匹配的分类标签。
## [br]
## @return: 全部满足时返回 true。
## [br]
## @schema required_categories: Array[StringName]，必须全部存在于 categories 中的分类标签列表。
func matches_categories(required_categories: Array[StringName]) -> bool:
	for category: StringName in required_categories:
		if not categories.has(category):
			return false
	return true


## 规范化实例数据。与默认实例数据等价时返回空字典。
## [br]
## @api public
## [br]
## @param instance_data: 实例数据。
## [br]
## @return: 规范化后的实例数据副本。
## [br]
## @schema instance_data: Dictionary，项目自定义物品实例数据。
## [br]
## @schema return: Dictionary，规范化后的物品实例数据副本；等价于默认实例数据时为空字典。
func normalize_instance_data(instance_data: Dictionary = {}) -> Dictionary:
	var data: Dictionary = instance_data.duplicate(true)
	if _with_defaults(data) == _with_defaults({}):
		return {}
	return data


## 判断两份实例数据是否可以合并到同一堆叠。
## [br]
## @api public
## [br]
## @param left: 左侧实例数据。
## [br]
## @param right: 右侧实例数据。
## [br]
## @return: 可合并返回 true。
## [br]
## @schema left: Dictionary，左侧物品实例数据。
## [br]
## @schema right: Dictionary，右侧物品实例数据。
func are_instance_data_compatible(left: Dictionary = {}, right: Dictionary = {}) -> bool:
	var left_data: Dictionary = _with_defaults(left)
	var right_data: Dictionary = _with_defaults(right)
	if compatibility_checker.is_valid():
		var arguments: Array = [
			left_data.duplicate(true),
			right_data.duplicate(true),
			self,
		]
		var result_output: Array = []
		if not GFInventoryRuleCallableSupport.try_call_for_framework(
			compatibility_checker,
			arguments,
			result_output
		):
			return false
		return GFVariantData.to_bool(result_output[0])
	if stack_key_fields.is_empty():
		return left_data == right_data

	for field_name: String in stack_key_fields:
		if GFVariantData.get_option_value(left_data, field_name) != GFVariantData.get_option_value(right_data, field_name):
			return false
	return true


## 转换为字典。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: Godot Variant 字典；不保证可直接编码为 JSON。
## [br]
## @schema return: Dictionary，包含 item_id、display_name、description、max_stack_amount、max_stack_count、categories、default_instance_data、stack_key_fields 与 metadata。
func to_dict() -> Dictionary:
	var category_names: PackedStringArray = PackedStringArray()
	for category: StringName in categories:
		var _category_appended: bool = category_names.append(String(category))
	return {
		"item_id": String(item_id),
		"display_name": display_name,
		"description": description,
		"max_stack_amount": max_stack_amount,
		"max_stack_count": max_stack_count,
		"categories": category_names,
		"default_instance_data": default_instance_data.duplicate(true),
		"stack_key_fields": stack_key_fields.duplicate(),
		"metadata": metadata.duplicate(true),
	}


## 应用字典数据。
## [br]
## @api public
## [br]
## @param data: 字典数据。
## [br]
## @schema data: Dictionary，可包含 item_id、display_name、description、max_stack_amount、max_stack_count、categories、default_instance_data、stack_key_fields 与 metadata。
func apply_dict(data: Dictionary) -> void:
	item_id = GFVariantData.get_option_string_name(data, "item_id", item_id)
	display_name = GFVariantData.get_option_string(data, "display_name", display_name)
	description = GFVariantData.get_option_string(data, "description", description)
	max_stack_amount = GFVariantData.get_option_int(data, "max_stack_amount", max_stack_amount)
	max_stack_count = GFVariantData.get_option_int(data, "max_stack_count", max_stack_count)
	categories.clear()
	var raw_categories: PackedStringArray = GFVariantData.get_option_packed_string_array(data, "categories")
	for category: Variant in raw_categories:
		categories.append(StringName(GFVariantData.to_text(category)))
	default_instance_data = GFVariantData.get_option_dictionary(data, "default_instance_data")
	var raw_stack_fields: PackedStringArray = GFVariantData.get_option_packed_string_array(data, "stack_key_fields")
	stack_key_fields = PackedStringArray()
	for field_name: Variant in raw_stack_fields:
		var _field_appended: bool = stack_key_fields.append(GFVariantData.to_text(field_name))
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 从字典创建物品定义。
## [br]
## @api public
## [br]
## @param data: 字典数据。
## [br]
## @return: 物品定义。
## [br]
## @schema data: Dictionary，可包含 item_id、display_name、description、max_stack_amount、max_stack_count、categories、default_instance_data、stack_key_fields 与 metadata。
static func from_dict(data: Dictionary) -> GFInventoryItemDefinition:
	var definition: GFInventoryItemDefinition = GFInventoryItemDefinition.new()
	definition.apply_dict(data)
	return definition


# --- 私有/辅助方法 ---

func _with_defaults(instance_data: Dictionary) -> Dictionary:
	var result: Dictionary = default_instance_data.duplicate(true)
	for key: Variant in instance_data.keys():
		result[key] = instance_data[key]
	return result
