# GFUINavigationTarget

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_ui_navigation_target.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

冻结的路由与语义定位参数。 不保存场景节点路径或节点引用。空参数表示只等待内容就绪；非空参数由项目 resolver 解释为页签、条目 ID 等业务定位信息。普通路由打开不需要创建此对象。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`create`](#member-gfuinavigationtarget-methods-create) | `static func create(route_id: StringName, parameters: Dictionary = {}) -> GFUINavigationTarget:` |
| 方法 | [`validate_create`](#member-gfuinavigationtarget-methods-validate_create) | `static func validate_create(route_id: StringName, parameters: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_route_id`](#member-gfuinavigationtarget-methods-get_route_id) | `func get_route_id() -> StringName:` |
| 方法 | [`get_parameters`](#member-gfuinavigationtarget-methods-get_parameters) | `func get_parameters() -> Dictionary:` |
| 方法 | [`has_semantic_target`](#member-gfuinavigationtarget-methods-has_semantic_target) | `func has_semantic_target() -> bool:` |
| 方法 | [`is_equivalent_to`](#member-gfuinavigationtarget-methods-is_equivalent_to) | `func is_equivalent_to(other: GFUINavigationTarget) -> bool:` |

## 方法

<a id="member-gfuinavigationtarget-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func create(route_id: StringName, parameters: Dictionary = {}) -> GFUINavigationTarget:
```

创建一个内容就绪或语义定位请求。

参数：

| 名称 | 说明 |
|---|---|
| `route_id` | 非空路由 ID，最多 256 字符。 |
| `parameters` | 项目定义的语义参数；空字典只等待内容。 |

返回：冻结目标；身份或参数无效时为 null。

结构：

- `parameters`: 由有限原生纯数据组成的 Dictionary；拒绝 Object、环、非有限数值。深度最多 8、节点 256、规范编码 16 KiB。

<a id="member-gfuinavigationtarget-methods-validate_create"></a>

### `validate_create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func validate_create(route_id: StringName, parameters: Dictionary = {}) -> Dictionary:
```

只读检查目标输入，不创建目标或请求，create 仍会重新校验。

参数：

| 名称 | 说明 |
|---|---|
| `route_id` | 与 create 相同的路由身份，仍允许既有首尾空白规范化。 |
| `parameters` | 与 create 相同的纯数据语义参数。 |

返回：当前输入的独立校验报告；不输出错误日志。

结构：

- `parameters`: 与 create.parameters 相同；报告中的位置为 /parameters 整体，不承诺定位纯数据内部叶子。
- `return`: 封闭基础字段 ok:bool、error_kind:String、path:String；成功时后两项为空。容量错误可含 limit:int、observed:int；纯数据错误另含 measurement:Dictionary、limits:Dictionary，并可含 limit_kind:String、observed_is_lower_bound:bool。path 为从输入参数名开始的 / 分段路径，~ 和 / 分别转义为 ~0 和 ~1；空路径指当前服务。observed_is_lower_bound=true 时 observed 只是确定下界，measurement 失败计数只描述已遍历前缀。报告不含对象或可复用准入令牌。

<a id="member-gfuinavigationtarget-methods-get_route_id"></a>

### `get_route_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_route_id() -> StringName:
```

获取规范化路由身份。

返回：冻结的路由 ID；未经 create 的对象为空。

<a id="member-gfuinavigationtarget-methods-get_parameters"></a>

### `get_parameters`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_parameters() -> Dictionary:
```

获取语义定位参数的隔离副本。

返回：创建时验证的纯数据。

结构：

- `return`: Dictionary，结构与 create.parameters 相同，不暴露内部可写容器。

<a id="member-gfuinavigationtarget-methods-has_semantic_target"></a>

### `has_semantic_target`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func has_semantic_target() -> bool:
```

区分只等待内容与需要语义定位的请求。

返回：非空参数需要在内容就绪后执行定位。

<a id="member-gfuinavigationtarget-methods-is_equivalent_to"></a>

### `is_equivalent_to`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_equivalent_to(other: GFUINavigationTarget) -> bool:
```

比较请求意义，用于合并同一 pending 导航。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 待比较目标。 |

返回：路由身份与参数完全一致时为 true。
