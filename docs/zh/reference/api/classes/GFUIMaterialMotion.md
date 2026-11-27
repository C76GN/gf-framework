# GFUIMaterialMotion

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/ui_motion/gf_ui_material_motion.gd`
- 模块：`Action Queue`
- 继承：`GFUIMotionEffect`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`unreleased`

将独立材质装到表现节点，显式绑定纹理输入并随轨道驱动一个 uniform。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`material`](#member-gfuimaterialmotion-properties-material) | `var material: ShaderMaterial` |
| 属性 | [`progress_parameter`](#member-gfuimaterialmotion-properties-progress_parameter) | `var progress_parameter: StringName = &"progress"` |
| 属性 | [`textures`](#member-gfuimaterialmotion-properties-textures) | `var textures: Dictionary[StringName, StringName] = {}` |
| 属性 | [`hide_on_end`](#member-gfuimaterialmotion-properties-hide_on_end) | `var hide_on_end: bool = true` |
| 方法 | [`input_types`](#member-gfuimaterialmotion-methods-input_types) | `func input_types() -> Dictionary:` |
| 方法 | [`written_properties`](#member-gfuimaterialmotion-methods-written_properties) | `func written_properties() -> Array[NodePath]:` |
| 方法 | [`binding_error`](#member-gfuimaterialmotion-methods-binding_error) | `func binding_error(target: Object, _inputs: Dictionary) -> String:` |
| 方法 | [`bind_target`](#member-gfuimaterialmotion-methods-bind_target) | `func bind_target(target: Object, inputs: Dictionary) -> GFUIMotionBinding:` |

## 属性

<a id="member-gfuimaterialmotion-properties-material"></a>

### `material`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var material: ShaderMaterial
```

各运行会话复制的材质模板。可使用项目自己的 canvas_item shader。

<a id="member-gfuimaterialmotion-properties-progress_parameter"></a>

### `progress_parameter`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var progress_parameter: StringName = &"progress"
```

接受局部进度的浮点 uniform。

<a id="member-gfuimaterialmotion-properties-textures"></a>

### `textures`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var textures: Dictionary[StringName, StringName] = {}
```

把项目提供的具名纹理绑定到独立的 sampler2D。

结构：

- `textures`: Dictionary[StringName, StringName]，键是 shader uniform，值是输入槽。

<a id="member-gfuimaterialmotion-properties-hide_on_end"></a>

### `hide_on_end`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var hide_on_end: bool = true
```

在自然或立即完成后隐藏临时合成面，暴露宿主提供的目标页面。

## 方法

<a id="member-gfuimaterialmotion-methods-input_types"></a>

### `input_types`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func input_types() -> Dictionary:
```

声明材质要用到的独立二维纹理。

返回：需要绑定的纹理类型。

结构：

- `return`: Dictionary，输入名映射到 Texture2D。

<a id="member-gfuimaterialmotion-methods-written_properties"></a>

### `written_properties`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func written_properties() -> Array[NodePath]:
```

一个表现节点在会话内只装配一套合成材质。

返回：独占的材质和局部可见性属性。

<a id="member-gfuimaterialmotion-methods-binding_error"></a>

### `binding_error`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func binding_error(target: Object, _inputs: Dictionary) -> String:
```

验证材质进度及纹理 uniform 的实际类型。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 材质的宿主。 |
| `_inputs` | 项目纹理。 |

返回：失败原因或空串。

结构：

- `_inputs`: Dictionary，名称对应已验证的 Texture2D。

<a id="member-gfuimaterialmotion-methods-bind_target"></a>

### `bind_target`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func bind_target(target: Object, inputs: Dictionary) -> GFUIMotionBinding:
```

绑定纹理并持有本实例的材质，结束时恢复先前材质。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 画面宿主。 |
| `inputs` | 项目纹理输入。 |

返回：可定位的进度采样操作。

结构：

- `inputs`: Dictionary，具名 Texture2D，可包含实时 ViewportTexture。
