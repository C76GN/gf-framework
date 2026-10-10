# GFTweenPreviewAdapter

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/editor/gf_tween_preview_adapter.gd`
- 模块：`Action Queue`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`unreleased`

受信任的编辑器数值样机绘制协议。 适配器只获得新建样机与冻结数值，不获得来源配置、真实目标或业务上下文。 GDScript 不是沙箱；实现者负责不访问来源、全局业务、持久化、标记或导航。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`_create_sample`](#member-gftweenpreviewadapter-methods-_create_sample) | `func _create_sample() -> Control:` |
| 方法 | [`_apply_sample`](#member-gftweenpreviewadapter-methods-_apply_sample) | `func _apply_sample(_sample: Control, _values: Dictionary) -> void:` |

## 方法

<a id="member-gftweenpreviewadapter-methods-_create_sample"></a>

### `_create_sample`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _create_sample() -> Control:
```

创建全新、未入树、无父节点的 Control 样机，至多 128 节点与 8 层。 成功接收后样机归 GF 所有，GF 负责挂载与释放；不能返回真实场景节点。

返回：独立样机；null 表示拒绝。

<a id="member-gftweenpreviewadapter-methods-_apply_sample"></a>

### `_apply_sample`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _apply_sample(_sample: Control, _values: Dictionary) -> void:
```

将冻结快照映射到工具自有样机；不得保留、改写来源或产生业务副作用。

参数：

| 名称 | 说明 |
|---|---|
| `_sample` | 本适配器新建、GF 持有的有效样机。 |
| `_values` | 可独立修改的采样副本；不含对象或来源引用。 |

结构：

- `_values`: Dictionary，String 声明属性名映射到有限 int/float。
