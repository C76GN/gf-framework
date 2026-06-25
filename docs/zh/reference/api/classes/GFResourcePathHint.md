# GFResourcePathHint

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_resource_path_hint.gd`
- 模块：`Kernel`
- 继承：`Object`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`6.0.0`

GF 编辑器资源路径字段使用的自定义 PropertyHint 常量。 用于让项目在 `@export_custom()` 或 `_get_property_list()` 中显式声明资源路径字段。 常量只描述编辑器展示语义，不绑定资源业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`RESOURCE_PATH`](#member-gfresourcepathhint-constants-resource_path) | `const RESOURCE_PATH: int = 760010` |
| 常量 | [`RESOURCE_PATH_ARRAY`](#member-gfresourcepathhint-constants-resource_path_array) | `const RESOURCE_PATH_ARRAY: int = 760011` |

## 常量

<a id="member-gfresourcepathhint-constants-resource_path"></a>

### `RESOURCE_PATH`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const RESOURCE_PATH: int = 760010
```

单个资源路径字符串 hint。

<a id="member-gfresourcepathhint-constants-resource_path_array"></a>

### `RESOURCE_PATH_ARRAY`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const RESOURCE_PATH_ARRAY: int = 760011
```

资源路径数组 hint。
