# GFTweenPreviewRegistry

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/editor/gf_tween_preview_registry.gd`
- 模块：`Action Queue`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`unreleased`

编辑器预览样机与资源关联的有界目录。 owner 使用弱引用；ID 不自动覆盖，内置样机不进入此目录。注册不读取来源或执行适配器。 工具插件应持有返回句柄并在退出时 release；owner 失效与租约变化使旧会话失效。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`changed`](#member-gftweenpreviewregistry-signals-changed) | `signal changed` |
| 方法 | [`get_shared`](#member-gftweenpreviewregistry-methods-get_shared) | `static func get_shared() -> GFTweenPreviewRegistry:` |
| 方法 | [`register_adapter`](#member-gftweenpreviewregistry-methods-register_adapter) | `func register_adapter( owner: Object, descriptor: Dictionary, adapter: GFTweenPreviewAdapter ) -> GFTweenPreviewRegistration:` |
| 方法 | [`get_descriptors`](#member-gftweenpreviewregistry-methods-get_descriptors) | `func get_descriptors() -> Array[Dictionary]:` |
| 方法 | [`get_property_records`](#member-gftweenpreviewregistry-methods-get_property_records) | `func get_property_records(adapter_id: StringName, query: String = "") -> Array[Dictionary]:` |
| 方法 | [`register_binding`](#member-gftweenpreviewregistry-methods-register_binding) | `func register_binding( owner: Object, resource_path: String, target_id: StringName, initial_values: Dictionary = {}, label: String = "" ) -> GFTweenPreviewRegistration:` |
| 方法 | [`get_binding`](#member-gftweenpreviewregistry-methods-get_binding) | `func get_binding(resource_path: String) -> Dictionary:` |

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
func register_adapter( owner: Object, descriptor: Dictionary, adapter: GFTweenPreviewAdapter ) -> GFTweenPreviewRegistration:
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

<a id="member-gftweenpreviewregistry-methods-register_binding"></a>

### `register_binding`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func register_binding( owner: Object, resource_path: String, target_id: StringName, initial_values: Dictionary = {}, label: String = "" ) -> GFTweenPreviewRegistration:
```

声明已保存资源的默认预览用途和起态；不改写或加载运行配置。 每个规范 res:// 路径只能有一个有效声明，最多 256 条；目标可稍后注册。 初值按目标属性目录二次校验，错误声明不会自动回退其他样机。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 弱持有的编辑器插件所有者。 |
| `resource_path` | 至多 1024 字符的规范 res:// 资源路径，可包含子资源标识。 |
| `target_id` | 项目适配器 ID，或 gf.preview.2d、gf.preview.ui、gf.preview.3d。 |
| `initial_values` | 至多 32 个样机初值表根属性的覆盖；不接受分量路径。原生旋转使用 rotation 弧度，不以 rotation_degrees 别名声明初值。 |
| `label` | 可选用途名称，至多 96 字符；空串使用样机名称。 |

返回：成功租约；无效声明、重复路径或超出预算返回 null，不产生部分登记。

结构：

- `initial_values`: Dictionary，String 属性名映射到有限 int/float/Vector2/Vector3/Color，分量绝对值不超过 1000000。

<a id="member-gftweenpreviewregistry-methods-get_binding"></a>

### `get_binding`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_binding(resource_path: String) -> Dictionary:
```

查询资源默认预览声明的独立纯值副本；不执行适配器或资源方法。

参数：

| 名称 | 说明 |
|---|---|
| `resource_path` | 注册时的规范资源路径。 |

返回：有效声明；没有声明或所有者失效时为空。

结构：

- `return`: Dictionary，空或 resource_path: String、target_id: StringName、initial_values: Dictionary（同 register_binding）、label: String；不含所有者或租约。
