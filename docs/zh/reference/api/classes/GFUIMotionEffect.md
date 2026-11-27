# GFUIMotionEffect

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/ui_motion/gf_ui_motion_effect.gd`
- 模块：`Action Queue`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`unreleased`

可由项目资源实现的界面动效。配置资源共享，所有播放状态由 bind_target 返回的实例持有。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`input_types`](#member-gfuimotioneffect-methods-input_types) | `func input_types() -> Dictionary:` |
| 方法 | [`written_properties`](#member-gfuimotioneffect-methods-written_properties) | `func written_properties() -> Array[NodePath]:` |
| 方法 | [`binding_error`](#member-gfuimotioneffect-methods-binding_error) | `func binding_error(_target: Object, _inputs: Dictionary) -> String:` |
| 方法 | [`bind_target`](#member-gfuimotioneffect-methods-bind_target) | `func bind_target(_target: Object, _inputs: Dictionary) -> GFUIMotionBinding:` |

## 方法

<a id="member-gfuimotioneffect-methods-input_types"></a>

### `input_types`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func input_types() -> Dictionary:
```

声明从项目具名输入读取的类型，供播放器在替换旧会话前检查。

返回：输入名到 Godot 类型的映射。

结构：

- `return`: Dictionary，StringName 输入名映射到 typeof 常量、原生类或项目 Script。

<a id="member-gfuimotioneffect-methods-written_properties"></a>

### `written_properties`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func written_properties() -> Array[NodePath]:
```

返回该效果在一个目标上写入的属性，用于定位冲突。空集合适合独占自绘子节点的效果。

返回：相对目标的属性路径。

<a id="member-gfuimotioneffect-methods-binding_error"></a>

### `binding_error`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func binding_error(_target: Object, _inputs: Dictionary) -> String:
```

检查目标和输入的额外约束，无副作用。

参数：

| 名称 | 说明 |
|---|---|
| `_target` | 绑定目标。 |
| `_inputs` | 调用方提供的输入。 |

返回：空串表示有效，其他值是诊断。

结构：

- `_inputs`: Dictionary，以 StringName 映射到声明的运行时输入。

<a id="member-gfuimotioneffect-methods-bind_target"></a>

### `bind_target`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func bind_target(_target: Object, _inputs: Dictionary) -> GFUIMotionBinding:
```

创建本次播放的操作。准备阶段只捕获基线，首次采样才向目标写入。

参数：

| 名称 | 说明 |
|---|---|
| `_target` | 已验证的目标。 |
| `_inputs` | 已验证的项目输入。 |

返回：新建的绑定，null 表示无法准备。

结构：

- `_inputs`: Dictionary，以 StringName 映射到运行时输入。
