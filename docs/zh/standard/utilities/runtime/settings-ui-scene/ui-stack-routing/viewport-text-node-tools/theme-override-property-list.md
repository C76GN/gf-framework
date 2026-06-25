# 主题 Override 属性列表

自定义 `Control` 如果需要把少量 theme override 暴露到 Inspector，可用 `GFThemeOverridePropertyList` 生成 `_get_property_list()` 所需的属性描述，并复用 Godot 的 `theme_override_*` 路径。

## Inspector 属性

```gdscript
@tool
extends Control

const THEME_OVERRIDES := [
	GFThemeOverridePropertyList.make_definition(&"accent", Theme.DATA_TYPE_COLOR),
	GFThemeOverridePropertyList.make_definition(&"gap", Theme.DATA_TYPE_CONSTANT, {
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,64,1",
	}),
]

func _get_property_list() -> Array:
	return GFThemeOverridePropertyList.make_property_list(self, THEME_OVERRIDES)

func _property_can_revert(property: StringName) -> bool:
	return GFThemeOverridePropertyList.can_revert(property, THEME_OVERRIDES)

func _property_get_revert(property: StringName) -> Variant:
	return GFThemeOverridePropertyList.get_revert_value(property)
```

`make_definition()` 接收 `Theme.DATA_TYPE_*`，并按主题数据类型映射到 `theme_override_colors`、`theme_override_constants`、`theme_override_fonts`、`theme_override_font_sizes`、`theme_override_icons` 和 `theme_override_styles`。生成的属性默认可 check、可编辑；当控件已经持有对应 override 时会带 storage usage，便于场景保存。

## 批处理

同一组定义也可以用于批量处理当前控件的 override：

```gdscript
var values := GFThemeOverridePropertyList.collect_override_values(self, THEME_OVERRIDES)
var theme := GFThemeOverridePropertyList.make_theme_from_values(THEME_OVERRIDES, values, &"Panel")
var clear_report := GFThemeOverridePropertyList.clear_overrides(self, THEME_OVERRIDES)
```

`collect_override_values()` 只收集定义列表里已设置的 override；`make_theme_from_control()` 或 `make_theme_from_values()` 可把这些值转换成新的 `Theme`；`clear_overrides()` 只清空定义列表声明的项，并返回 `ok`、`cleared_count`、`skipped_count` 和 `issues`。这些 API 适合自定义 Inspector、主题迁移工具或编辑器批处理复用同一份声明。

## 边界

这个 helper 只负责 Inspector 属性列表、路径判断和按声明处理 override，不负责控件绘制、主题 token 设计、默认值来源或项目视觉规范。
