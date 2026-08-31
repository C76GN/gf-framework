## GFProjectileCatalogEntry: 稳定 ID 到 typed projectile definition 的映射。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFProjectileCatalogEntry
extends Resource


## definition 的稳定目录 ID。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var projectile_id: StringName = &""

## 与 ID 关联的 typed projectile definition。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var definition: GFProjectileDefinition = null


## 判断条目是否可参与目录查找。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: ID 非空且 definition 非 null 时为 true。
func is_valid_entry() -> bool:
	return projectile_id != &"" and definition != null
