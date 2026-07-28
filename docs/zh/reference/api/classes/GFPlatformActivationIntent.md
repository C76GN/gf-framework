# GFPlatformActivationIntent

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/platform/gf_platform_activation_intent.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：事件契约 (`event_contract`)
- 首次版本：`10.0.0`

平台激活入口事件。 统一表达命令行启动、邀请加入、深链、前台恢复或平台入口参数。该值对象只记录 平台事实，不解释奖励、导航、匹配或其他项目策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`intent_id`](#member-gfplatformactivationintent-properties-intent_id) | `var intent_id: StringName = &""` |
| 属性 | [`intent_type`](#member-gfplatformactivationintent-properties-intent_type) | `var intent_type: StringName = &""` |
| 属性 | [`platform_id`](#member-gfplatformactivationintent-properties-platform_id) | `var platform_id: StringName = &""` |
| 属性 | [`adapter_id`](#member-gfplatformactivationintent-properties-adapter_id) | `var adapter_id: StringName = &""` |
| 属性 | [`source`](#member-gfplatformactivationintent-properties-source) | `var source: StringName = &""` |
| 属性 | [`timestamp_msec`](#member-gfplatformactivationintent-properties-timestamp_msec) | `var timestamp_msec: int = 0` |
| 属性 | [`payload`](#member-gfplatformactivationintent-properties-payload) | `var payload: Dictionary = {}` |
| 属性 | [`metadata`](#member-gfplatformactivationintent-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfplatformactivationintent-methods-configure) | `func configure( p_intent_id: StringName, p_intent_type: StringName, p_payload: Dictionary = {}, options: Dictionary = {} ) -> GFPlatformActivationIntent:` |
| 方法 | [`is_empty`](#member-gfplatformactivationintent-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`to_dict`](#member-gfplatformactivationintent-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfplatformactivationintent-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_intent`](#member-gfplatformactivationintent-methods-duplicate_intent) | `func duplicate_intent() -> GFPlatformActivationIntent:` |
| 方法 | [`from_dict`](#member-gfplatformactivationintent-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFPlatformActivationIntent:` |

## 属性

<a id="member-gfplatformactivationintent-properties-intent_id"></a>

### `intent_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var intent_id: StringName = &""
```

平台侧或 adapter 生成的幂等 ID。

<a id="member-gfplatformactivationintent-properties-intent_type"></a>

### `intent_type`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var intent_type: StringName = &""
```

Provider-neutral 意图类型。

<a id="member-gfplatformactivationintent-properties-platform_id"></a>

### `platform_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var platform_id: StringName = &""
```

来源平台 ID。

<a id="member-gfplatformactivationintent-properties-adapter_id"></a>

### `adapter_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var adapter_id: StringName = &""
```

来源 Adapter ID。

<a id="member-gfplatformactivationintent-properties-source"></a>

### `source`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var source: StringName = &""
```

平台入口来源，例如 command_line、invite、deep_link 或 resume。

<a id="member-gfplatformactivationintent-properties-timestamp_msec"></a>

### `timestamp_msec`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var timestamp_msec: int = 0
```

单调时间戳，单位毫秒。

<a id="member-gfplatformactivationintent-properties-payload"></a>

### `payload`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var payload: Dictionary = {}
```

Provider-neutral 入口载荷。

结构：

- `payload`: Dictionary platform activation payload.

<a id="member-gfplatformactivationintent-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var metadata: Dictionary = {}
```

Adapter 定义的非敏感元数据。

结构：

- `metadata`: Dictionary platform activation metadata.

## 方法

<a id="member-gfplatformactivationintent-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func configure( p_intent_id: StringName, p_intent_type: StringName, p_payload: Dictionary = {}, options: Dictionary = {} ) -> GFPlatformActivationIntent:
```

配置激活意图。

参数：

| 名称 | 说明 |
|---|---|
| `p_intent_id` | 幂等 ID。 |
| `p_intent_type` | Provider-neutral 意图类型。 |
| `p_payload` | 入口载荷。 |
| `options` | 可包含 platform_id、adapter_id、source、timestamp_msec 和 metadata。 |

返回：当前意图。

结构：

- `p_payload`: Dictionary platform activation payload.
- `options`: Dictionary platform activation options.

<a id="member-gfplatformactivationintent-methods-is_empty"></a>

### `is_empty`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_empty() -> bool:
```

检查是否缺少最小身份字段。

返回：缺少 intent_id 或 intent_type 时返回 true。

<a id="member-gfplatformactivationintent-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：激活意图字典。

结构：

- `return`: Dictionary platform activation intent.

<a id="member-gfplatformactivationintent-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 激活意图字典。 |

结构：

- `data`: Dictionary platform activation intent.

<a id="member-gfplatformactivationintent-methods-duplicate_intent"></a>

### `duplicate_intent`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func duplicate_intent() -> GFPlatformActivationIntent:
```

创建意图深拷贝。

返回：新意图。

<a id="member-gfplatformactivationintent-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFPlatformActivationIntent:
```

从字典创建意图。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 激活意图字典。 |

返回：新意图。

结构：

- `data`: Dictionary platform activation intent.
