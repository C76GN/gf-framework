@tool

## GFResourcePathHint: GF 编辑器资源路径字段使用的自定义 PropertyHint 常量。
##
## 用于让项目在 `@export_custom()` 或 `_get_property_list()` 中显式声明资源路径字段。
## 常量只描述编辑器展示语义，不绑定资源业务含义。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 6.0.0
## [br]
## @layer kernel/editor
class_name GFResourcePathHint
extends Object


# --- 常量 ---

## 单个资源路径字符串 hint。
## [br]
## @api public
## [br]
## @since 6.0.0
const RESOURCE_PATH: int = 760010

## 资源路径数组 hint。
## [br]
## @api public
## [br]
## @since 6.0.0
const RESOURCE_PATH_ARRAY: int = 760011
