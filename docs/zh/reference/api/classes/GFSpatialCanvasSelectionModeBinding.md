# GFSpatialCanvasSelectionModeBinding

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/spatial_canvas/gf_spatial_canvas_selection_mode_binding.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`11.0.0`

空间画布选择修饰键绑定。 只描述修饰键掩码到 [code]GFSpatialCanvas2D.SelectionMode[/code] 的映射， 不读取设备状态，也不拥有输入生命周期。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`modifier_mask`](#member-gfspatialcanvasselectionmodebinding-properties-modifier_mask) | `var modifier_mask: int = 0` |
| 属性 | [`selection_mode`](#member-gfspatialcanvasselectionmodebinding-properties-selection_mode) | `var selection_mode: GFSpatialCanvas2D.SelectionMode = ( 	GFSpatialCanvas2D.SelectionMode.REPLACE )` |
| 方法 | [`duplicate_binding`](#member-gfspatialcanvasselectionmodebinding-methods-duplicate_binding) | `func duplicate_binding() -> GFSpatialCanvasSelectionModeBinding:` |

## 属性

<a id="member-gfspatialcanvasselectionmodebinding-properties-modifier_mask"></a>

### `modifier_mask`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var modifier_mask: int = 0
```

需要精确匹配的 [code]GFSpatialCanvasInputPolicy.ModifierMask[/code] 掩码。

<a id="member-gfspatialcanvasselectionmodebinding-properties-selection_mode"></a>

### `selection_mode`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var selection_mode: GFSpatialCanvas2D.SelectionMode = (
	GFSpatialCanvas2D.SelectionMode.REPLACE
)
```

匹配时使用的 [code]GFSpatialCanvas2D.SelectionMode[/code] 值。

## 方法

<a id="member-gfspatialcanvasselectionmodebinding-methods-duplicate_binding"></a>

### `duplicate_binding`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func duplicate_binding() -> GFSpatialCanvasSelectionModeBinding:
```

创建隔离副本。

返回：新绑定。
