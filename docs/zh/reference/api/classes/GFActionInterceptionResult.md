# GFActionInterceptionResult

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/core/gf_action_interception_result.gd`
- 模块：`Action Queue`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

动作队列拦截器的处理结果。 用于在动作执行前后表达继续、跳过、替换或停止队列等通用决策。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Decision`](#member-gfactioninterceptionresult-enums-decision) | `enum Decision` |
| 属性 | [`decision`](#member-gfactioninterceptionresult-properties-decision) | `var decision: Decision = Decision.CONTINUE` |
| 属性 | [`replacement_action`](#member-gfactioninterceptionresult-properties-replacement_action) | `var replacement_action: Object = null` |
| 属性 | [`metadata`](#member-gfactioninterceptionresult-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`is_continue`](#member-gfactioninterceptionresult-methods-is_continue) | `func is_continue() -> bool:` |
| 方法 | [`is_skip`](#member-gfactioninterceptionresult-methods-is_skip) | `func is_skip() -> bool:` |
| 方法 | [`is_replace`](#member-gfactioninterceptionresult-methods-is_replace) | `func is_replace() -> bool:` |
| 方法 | [`is_stop_queue`](#member-gfactioninterceptionresult-methods-is_stop_queue) | `func is_stop_queue() -> bool:` |
| 方法 | [`continue_action`](#member-gfactioninterceptionresult-methods-continue_action) | `static func continue_action(p_metadata: Dictionary = {}) -> GFActionInterceptionResult:` |
| 方法 | [`skip_action`](#member-gfactioninterceptionresult-methods-skip_action) | `static func skip_action(p_metadata: Dictionary = {}) -> GFActionInterceptionResult:` |
| 方法 | [`replace_with`](#member-gfactioninterceptionresult-methods-replace_with) | `static func replace_with( action: Object, p_metadata: Dictionary = {} ) -> GFActionInterceptionResult:` |
| 方法 | [`stop_queue`](#member-gfactioninterceptionresult-methods-stop_queue) | `static func stop_queue(p_metadata: Dictionary = {}) -> GFActionInterceptionResult:` |

## 枚举

<a id="member-gfactioninterceptionresult-enums-decision"></a>

### `Decision`

- API：`public`

```gdscript
enum Decision {
	## 继续当前动作。
	CONTINUE,
	## 跳过当前动作并继续后续队列。
	SKIP,
	## 用 replacement_action 替换当前动作。
	REPLACE,
	## 停止并清空当前队列。
	STOP_QUEUE,
}
```

拦截器决策类型。

## 属性

<a id="member-gfactioninterceptionresult-properties-decision"></a>

### `decision`

- API：`public`

```gdscript
var decision: Decision = Decision.CONTINUE
```

当前决策。

<a id="member-gfactioninterceptionresult-properties-replacement_action"></a>

### `replacement_action`

- API：`public`

```gdscript
var replacement_action: Object = null
```

替换动作，仅在 decision 为 REPLACE 时使用。

<a id="member-gfactioninterceptionresult-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

调用方自定义元数据。

结构：

- `metadata`: Dictionary，由项目或拦截器定义的附加诊断数据。

## 方法

<a id="member-gfactioninterceptionresult-methods-is_continue"></a>

### `is_continue`

- API：`public`

```gdscript
func is_continue() -> bool:
```

判断结果是否表示继续当前动作。

返回：继续时返回 true。

<a id="member-gfactioninterceptionresult-methods-is_skip"></a>

### `is_skip`

- API：`public`

```gdscript
func is_skip() -> bool:
```

判断结果是否表示跳过当前动作。

返回：跳过时返回 true。

<a id="member-gfactioninterceptionresult-methods-is_replace"></a>

### `is_replace`

- API：`public`

```gdscript
func is_replace() -> bool:
```

判断结果是否表示替换当前动作。

返回：替换时返回 true。

<a id="member-gfactioninterceptionresult-methods-is_stop_queue"></a>

### `is_stop_queue`

- API：`public`

```gdscript
func is_stop_queue() -> bool:
```

判断结果是否表示停止队列。

返回：停止时返回 true。

<a id="member-gfactioninterceptionresult-methods-continue_action"></a>

### `continue_action`

- API：`public`

```gdscript
static func continue_action(p_metadata: Dictionary = {}) -> GFActionInterceptionResult:
```

创建继续结果。

参数：

| 名称 | 说明 |
|---|---|
| `p_metadata` | 可选元数据。 |

返回：继续结果。

结构：

- `p_metadata`: Dictionary，由项目或拦截器定义的附加诊断数据。

<a id="member-gfactioninterceptionresult-methods-skip_action"></a>

### `skip_action`

- API：`public`

```gdscript
static func skip_action(p_metadata: Dictionary = {}) -> GFActionInterceptionResult:
```

创建跳过结果。

参数：

| 名称 | 说明 |
|---|---|
| `p_metadata` | 可选元数据。 |

返回：跳过结果。

结构：

- `p_metadata`: Dictionary，由项目或拦截器定义的附加诊断数据。

<a id="member-gfactioninterceptionresult-methods-replace_with"></a>

### `replace_with`

- API：`public`

```gdscript
static func replace_with( action: Object, p_metadata: Dictionary = {} ) -> GFActionInterceptionResult:
```

创建替换结果。

参数：

| 名称 | 说明 |
|---|---|
| `action` | 替换动作。 |
| `p_metadata` | 可选元数据。 |

返回：替换结果。

结构：

- `p_metadata`: Dictionary，由项目或拦截器定义的附加诊断数据。

<a id="member-gfactioninterceptionresult-methods-stop_queue"></a>

### `stop_queue`

- API：`public`

```gdscript
static func stop_queue(p_metadata: Dictionary = {}) -> GFActionInterceptionResult:
```

创建停止队列结果。

参数：

| 名称 | 说明 |
|---|---|
| `p_metadata` | 可选元数据。 |

返回：停止队列结果。

结构：

- `p_metadata`: Dictionary，由项目或拦截器定义的附加诊断数据。
