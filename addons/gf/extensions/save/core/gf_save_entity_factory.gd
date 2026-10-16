## GFSaveEntityFactory: 存档恢复实体工厂基类。
##
## 由 GFSaveGraphUtility 在缺失 Source 且 Scope 允许工厂恢复时调用。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFSaveEntityFactory
extends Resource


# --- 导出变量 ---

## 工厂可创建的实体类型键。
## [br]
## @api public
@export var type_key: StringName = &""

## 可选场景模板。项目也可继承 _create_entity 实现自定义创建。
## [br]
## @api public
@export var packed_scene: PackedScene


# --- 公共方法 ---

## 获取实体类型键。
## [br]
## @api public
## [br]
## @return 类型键。
func get_type_key() -> StringName:
	return type_key


# --- 可重写钩子 / 虚方法 ---

## 创建实体节点。
## [br]
## @api protected
## [br]
## @param _descriptor: 存档中的实体描述。
## [br]
## @param _context: 调用上下文字典。
## [br]
## @return 创建出的节点；失败时返回 null。
## [br]
## @schema _descriptor: Dictionary，通常包含 persistent_id、type_key、phase 与 Source 描述字段。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
func _create_entity(_descriptor: Dictionary, _context: Dictionary = {}) -> Node:
	if packed_scene == null:
		return null
	return packed_scene.instantiate()


## 实体加入场景树后调用。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param _entity: 创建出的实体。
## [br]
## @param _descriptor: 存档中的实体描述。
## [br]
## @param _context: 调用上下文字典。
## [br]
## @schema _descriptor: Dictionary，通常包含 persistent_id、type_key、phase 与 Source 描述字段。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
func _after_entity_created(
	_entity: Node,
	_descriptor: Dictionary,
	_context: Dictionary = {}
) -> void:
	pass
