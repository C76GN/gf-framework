# GFTweenPreviewRegistry

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/editor/gf_tween_preview_registry.gd`
- 模块：`Action Queue`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`unreleased`

显式选择的有界数值预览适配器目录。 owner 使用弱引用；ID 不自动覆盖，内置样机不进入此目录。注册不读取来源或执行适配器。 工具插件应持有返回句柄并在退出时 release；owner 失效与租约变化使旧会话失效。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`changed`](#member-gftweenpreviewregistry-signals-changed) | `signal changed` |
| 方法 | [`get_shared`](#member-gftweenpreviewregistry-methods-get_shared) | `static func get_shared() -> GFTweenPreviewRegistry:` |
| 方法 | [`register_adapter`](#member-gftweenpreviewregistry-methods-register_adapter) | `func register_adapter(owner: Object, descriptor: Dictionary, adapter: GFTweenPreviewAdapter) -> GFTweenPreviewRegistration:` |
| 方法 | [`get_descriptors`](#member-gftweenpreviewregistry-methods-get_descriptors) | `func get_descriptors() -> Array[Dictionary]:` |
| 方法 | [`get_property_records`](#member-gftweenpreviewregistry-methods-get_property_records) | `func get_property_records(adapter_id: StringName, query: String = "") -> Array[Dictionary]:` |

## 信号

<a id="member-gftweenpreviewregistry-signals-changed"></a>

### `changed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal changed
```

目录有实际增删时发出；观察者应重新获取独立快照。

## 方法

<a id="member-gftweenpreviewregistry-methods-get_shared"></a>

### `get_shared`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func get_shared() -> GFTweenPreviewRegistry:
```

获取原生 Tween Inspector 与步骤选择器使用的共享目录。

返回：共享注册表；不在此处自动发现或执行项目脚本。

<a id="member-gftweenpreviewregistry-methods-register_adapter"></a>

### `register_adapter`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func register_adapter(owner: Object, descriptor: Dictionary, adapter: GFTweenPreviewAdapter) -> GFTweenPreviewRegistration:
```

注册完整描述；重复 ID、无效 owner 或超出 32 个适配器预算时整组拒绝。 revision 改变须先释放旧句柄再重新注册，不做隐式优先级选择。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 有效弱持有者；通常为项目 EditorPlugin。 |
| `descriptor` | 闭合纯值描述。 |
| `adapter` | 受信任的隔离样机实现，不应强持 owner 或来源配置。 |

返回：成功所有权句柄；拒绝返回 null，不产生部分注册。

结构：

- `descriptor`: Dictionary，恰含 id: String（1..64 字符标识符）、revision: int（1..2147483647）、label: String（1..96 字符）、properties: Array[Dictionary]（结构同 GFTweenNumericTimeline.capture 的 properties）。

<a id="member-gftweenpreviewregistry-methods-get_descriptors"></a>

### `get_descriptors`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_descriptors() -> Array[Dictionary]:
```

获取全部有效描述，不暴露 owner、adapter 或内部租约。

返回：最多 32 项独立描述，按 ID 字典序排序。

结构：

- `return`: Array[Dictionary]，每项同 register_adapter 的 descriptor。

<a id="member-gftweenpreviewregistry-methods-get_property_records"></a>

### `get_property_records`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_property_records(adapter_id: StringName, query: String = "") -> Array[Dictionary]:
```

搜索显式适配器的有限属性目录；不触发样机或来源 getter。

参数：

| 名称 | 说明 |
|---|---|
| `adapter_id` | 已注册 ID。 |
| `query` | 大小写无关子串，最多 128 字符。 |

返回：独立匹配记录；失效 ID 或超限搜索为空。

结构：

- `return`: Array[Dictionary]，name: String、type: int、initial: int/float、minimum/maximum: int/float、source: String、supported: bool、reason: String。
