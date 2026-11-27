# GFUITweenMotion

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/ui_motion/gf_ui_tween_motion.gd`
- 模块：`Action Queue`
- 继承：`GFUIMotionEffect`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`unreleased`

在页面或组件轨道中重用已有 GFTweenActionConfig，通过受控时间轴按局部进度采样。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`configuration`](#member-gfuitweenmotion-properties-configuration) | `var configuration: GFTweenActionConfig` |
| 方法 | [`written_properties`](#member-gfuitweenmotion-methods-written_properties) | `func written_properties() -> Array[NodePath]:` |
| 方法 | [`binding_error`](#member-gfuitweenmotion-methods-binding_error) | `func binding_error(target: Object, _inputs: Dictionary) -> String:` |
| 方法 | [`bind_target`](#member-gfuitweenmotion-methods-bind_target) | `func bind_target(target: Object, _inputs: Dictionary) -> GFUIMotionBinding:` |

## 属性

<a id="member-gfuitweenmotion-properties-configuration"></a>

### `configuration`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var configuration: GFTweenActionConfig
```

配置化 Tween 的来源，按每次绑定复制并启用受控定位。

## 方法

<a id="member-gfuitweenmotion-methods-written_properties"></a>

### `written_properties`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func written_properties() -> Array[NodePath]:
```

受控 Tween 从基线重建整个根属性，包括只配置单个分量的步骤。

返回：去重后的属性路径。

<a id="member-gfuitweenmotion-methods-binding_error"></a>

### `binding_error`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func binding_error(target: Object, _inputs: Dictionary) -> String:
```

按受控播放合同检查真实目标。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 项目目标。 |
| `_inputs` | 额外输入。 |

返回：校验说明或空串。

结构：

- `_inputs`: Dictionary，此效果只使用绑定目标。

<a id="member-gfuitweenmotion-methods-bind_target"></a>

### `bind_target`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func bind_target(target: Object, _inputs: Dictionary) -> GFUIMotionBinding:
```

使用 GF 受控动作的求值、取消及恢复语义。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 已验证的树内节点。 |
| `_inputs` | 额外输入。 |

返回：对同一受控动作执行的定位操作。

结构：

- `_inputs`: Dictionary，此效果不消费额外槽位。
