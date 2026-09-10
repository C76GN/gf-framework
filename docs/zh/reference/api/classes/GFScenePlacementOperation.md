# GFScenePlacementOperation

[API Reference](../index.md) / [Tools](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/scene_placement/gf_scene_placement_operation.gd`
- 模块：`Tools`
- 继承：`GFEditorPickOperation`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`unreleased`

编辑器内显式场景、父节点与命中位置的单次摆放操作。 预览只计算变换，不实例化源场景。确认时才通过编辑器撤销历史创建实例。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`configure`](#member-gfsceneplacementoperation-methods-configure) | `func configure( scene: PackedScene, parent: Node3D, scene_root: Node, options: Dictionary = {} ) -> Error:` |
| 方法 | [`begin`](#member-gfsceneplacementoperation-methods-begin) | `func begin(context: GFEditorToolContext) -> bool:` |
| 方法 | [`pick`](#member-gfsceneplacementoperation-methods-pick) | `func pick(input_data: Dictionary) -> State:` |
| 方法 | [`apply`](#member-gfsceneplacementoperation-methods-apply) | `func apply() -> Dictionary:` |
| 方法 | [`is_destination_valid`](#member-gfsceneplacementoperation-methods-is_destination_valid) | `func is_destination_valid() -> bool:` |
| 方法 | [`_on_pick`](#member-gfsceneplacementoperation-methods-_on_pick) | `func _on_pick(input_data: Dictionary) -> Dictionary:` |
| 方法 | [`_on_can_apply`](#member-gfsceneplacementoperation-methods-_on_can_apply) | `func _on_can_apply() -> bool:` |
| 方法 | [`_on_apply`](#member-gfsceneplacementoperation-methods-_on_apply) | `func _on_apply(tool_context: GFEditorToolContext, result: Dictionary) -> Dictionary:` |
| 方法 | [`_on_cancel`](#member-gfsceneplacementoperation-methods-_on_cancel) | `func _on_cancel(_tool_context: GFEditorToolContext) -> void:` |

## 方法

<a id="member-gfsceneplacementoperation-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func configure( scene: PackedScene, parent: Node3D, scene_root: Node, options: Dictionary = {} ) -> Error:
```

配置一次编辑器摆放；活动操作必须先取消。

参数：

| 名称 | 说明 |
|---|---|
| `scene` | 显式选择的 PackedScene。 |
| `parent` | 当前编辑场景内的父 Node3D。 |
| `scene_root` | 当前编辑场景根。 |
| `options` | 有限的摆放参数。 |

返回：配置错误码；失败不允许产生预览或实例。

结构：

- `options`: Dictionary，支持 mode: String (plane/surface)、plane_normal/plane_origin/anchor/scale: Vector3、grid_step/yaw_degrees/surface_offset/max_distance: float、align_normal: bool。

<a id="member-gfsceneplacementoperation-methods-begin"></a>

### `begin`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func begin(context: GFEditorToolContext) -> bool:
```

开始拾取；提交及其同步补偿期间拒绝重入，不改变当前状态。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 当前编辑器工具上下文。 |

返回：成功开始返回 true；正在提交时返回 false。

<a id="member-gfsceneplacementoperation-methods-pick"></a>

### `pick`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func pick(input_data: Dictionary) -> State:
```

更新最近命中；提交及其同步补偿期间忽略输入并保留当前状态。

参数：

| 名称 | 说明 |
|---|---|
| `input_data` | 视口射线或调用方已经查询到的表面命中。 |

返回：本次输入后的操作状态。

结构：

- `input_data`: Dictionary，平面模式使用 ray_origin/ray_direction: Vector3；表面模式使用 hit: Dictionary，包含 position/normal: Vector3。

<a id="member-gfsceneplacementoperation-methods-apply"></a>

### `apply`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func apply() -> Dictionary:
```

确认一个实例；同步回调中的再次确认会被拒绝。

返回：确认结果；重入返回 ERR_BUSY，不改变外层确认的状态。

结构：

- `return`: Dictionary，至少包含 ok: bool、reason: StringName；实际提交与重入结果另含 error_code: Error、node: Node3D|null。

<a id="member-gfsceneplacementoperation-methods-is_destination_valid"></a>

### `is_destination_valid`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_destination_valid() -> bool:
```

检查原父节点和编辑场景根是否仍有效。

返回：父节点仍位于原场景内，且世界变换可逆时返回 true。

<a id="member-gfsceneplacementoperation-methods-_on_pick"></a>

### `_on_pick`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _on_pick(input_data: Dictionary) -> Dictionary:
```

计算一次平面或碰撞命中的纯变换预览。

参数：

| 名称 | 说明 |
|---|---|
| `input_data` | 平面模式提供 ray_origin/ray_direction；表面模式提供 hit。 |

返回：分阶段拾取响应；任何无效输入都会清除上一有效命中。

结构：

- `input_data`: Dictionary，ray_origin/ray_direction 为 Vector3；hit 为包含 position/normal: Vector3 的 Dictionary。表面模式可附射线以检查最大距离。
- `return`: Dictionary，preview/result 包含 valid: bool、world_transform/local_transform: Transform3D、position/normal: Vector3、reason: StringName；local_transform 是父坐标换算值，top_level 根确认后的原生 transform 使用 world_transform；ready: bool 表示是否可确认。

<a id="member-gfsceneplacementoperation-methods-_on_can_apply"></a>

### `_on_can_apply`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _on_can_apply() -> bool:
```

检查最近命中与原目标仍可应用。

返回：最近命中有效且目标仍有效时返回 true。

<a id="member-gfsceneplacementoperation-methods-_on_apply"></a>

### `_on_apply`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _on_apply(tool_context: GFEditorToolContext, result: Dictionary) -> Dictionary:
```

确认时创建一个原生可撤销动作，不以注册成功冒充实例创建成功。

参数：

| 名称 | 说明 |
|---|---|
| `tool_context` | 必须提供 undo_manager 和同一个 edited_scene_root。 |
| `result` | 最近有效变换。 |

返回：本次确认结果。

结构：

- `result`: Dictionary，world_transform 为 Transform3D。
- `return`: Dictionary，包含 ok: bool、error_code: Error、reason: StringName、node: Node3D|null。

<a id="member-gfsceneplacementoperation-methods-_on_cancel"></a>

### `_on_cancel`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _on_cancel(_tool_context: GFEditorToolContext) -> void:
```

取消会释放源资源与目标引用，不修改任何场景。

参数：

| 名称 | 说明 |
|---|---|
| `_tool_context` | 原拾取上下文。 |
