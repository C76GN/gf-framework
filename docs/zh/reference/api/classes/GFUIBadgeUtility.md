# GFUIBadgeUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_ui_badge_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

显式树结构的叶子计数与父级聚合。 主线程、只维护派生显示状态，不保存业务事实。结构在首次有效 configure 后冻结； 最多 4096 节点、64 层、4096 个绑定，每个叶子计数为 0 到 1000000000。 通知队列最多 4096 批；每次排空最多发送 256 批，其余在 tick 中继续。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`counts_changed`](#member-gfuibadgeutility-signals-counts_changed) | `signal counts_changed(changes: Dictionary)` |
| 方法 | [`tick`](#member-gfuibadgeutility-methods-tick) | `func tick(_delta: float) -> void:` |
| 方法 | [`dispose`](#member-gfuibadgeutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`configure`](#member-gfuibadgeutility-methods-configure) | `func configure(parents: Dictionary) -> bool:` |
| 方法 | [`validate_configuration`](#member-gfuibadgeutility-methods-validate_configuration) | `func validate_configuration(parents: Dictionary) -> Dictionary:` |
| 方法 | [`set_leaf_count`](#member-gfuibadgeutility-methods-set_leaf_count) | `func set_leaf_count(badge_id: StringName, count: int) -> bool:` |
| 方法 | [`is_leaf`](#member-gfuibadgeutility-methods-is_leaf) | `func is_leaf(badge_id: StringName) -> bool:` |
| 方法 | [`get_count`](#member-gfuibadgeutility-methods-get_count) | `func get_count(badge_id: StringName) -> int:` |
| 方法 | [`bind_count`](#member-gfuibadgeutility-methods-bind_count) | `func bind_count( badge_id: StringName, callback: Callable, owner: Object = null ) -> GFSubscriptionToken:` |

## 信号

<a id="member-gfuibadgeutility-signals-counts_changed"></a>

### `counts_changed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal counts_changed(changes: Dictionary)
```

一次叶子更新所影响的节点计数；状态先完整提交，再按更新顺序通知。

参数：

| 名称 | 说明 |
|---|---|
| `changes` | 仅包含数值改变的叶子与祖先。 |

结构：

- `changes`: Dictionary[StringName, int]，节点 ID 对应新的非负聚合值。

## 方法

<a id="member-gfuibadgeutility-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func tick(_delta: float) -> void:
```

清理已销毁的普通 Object owner 与失效回调。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 未使用的帧间隔。 |

<a id="member-gfuibadgeutility-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func dispose() -> void:
```

使全部 token 失效，丢弃等待通知并释放树数据。

<a id="member-gfuibadgeutility-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func configure(parents: Dictionary) -> bool:
```

原子验证并冻结树；无效输入不会占用配置机会。

参数：

| 名称 | 说明 |
|---|---|
| `parents` | ID 到父级 ID；允许多个根，不允许缺失父级、自环或环。 |

返回：首次有效配置为 true；失败不改变状态。

结构：

- `parents`: Dictionary[String or StringName, String or StringName]。空父级为根；节点 ID 非空、无首尾空白且不超过 256 字符，规范化重复 ID 被拒绝。

<a id="member-gfuibadgeutility-methods-validate_configuration"></a>

### `validate_configuration`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func validate_configuration(parents: Dictionary) -> Dictionary:
```

只读检查当前服务能否接受树配置，不占用配置机会、不创建绑定或发布计数。 configure 在执行时重新校验；有效报告不会为后来修改的树提供准入资格。

参数：

| 名称 | 说明 |
|---|---|
| `parents` | 与 configure 相同的 ID 到父级映射。 |

返回：当前服务与输入的独立校验报告；不输出错误日志。

结构：

- `parents`: 与 configure.parents 相同；错误路径中的节点 ID 按 / 分段路径转义。
- `return`: 封闭基础字段 ok:bool、error_kind:String、path:String；成功时后两项为空。容量错误可含 limit:int、observed:int；纯数据错误另含 measurement:Dictionary、limits:Dictionary，并可含 limit_kind:String、observed_is_lower_bound:bool。path 为从输入参数名开始的 / 分段路径，~ 和 / 分别转义为 ~0 和 ~1；空路径指当前服务。observed_is_lower_bound=true 时 observed 只是确定下界，measurement 失败计数只描述已遍历前缀。报告不含对象或可复用准入令牌。 depth_limit 的 observed 为已确认链长度下界。

<a id="member-gfuibadgeutility-methods-set_leaf_count"></a>

### `set_leaf_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func set_leaf_count(badge_id: StringName, count: int) -> bool:
```

写入项目计算出的一个叶子计数，沿唯一父链增量更新。

参数：

| 名称 | 说明 |
|---|---|
| `badge_id` | 已声明的叶子 ID。 |
| `count` | 0 到 1000000000 的计数。 |

返回：写入有效时为 true；相同值不发通知。

<a id="member-gfuibadgeutility-methods-is_leaf"></a>

### `is_leaf`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_leaf(badge_id: StringName) -> bool:
```

判断节点能否接受业务计数输入。

参数：

| 名称 | 说明 |
|---|---|
| `badge_id` | 节点 ID。 |

返回：已声明且没有子节点时为 true。

<a id="member-gfuibadgeutility-methods-get_count"></a>

### `get_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_count(badge_id: StringName) -> int:
```

查询当前计数，不把未知 ID 当作没有红点。

参数：

| 名称 | 说明 |
|---|---|
| `badge_id` | 节点 ID。 |

返回：聚合值；未知节点或已释放服务返回 -1。

<a id="member-gfuibadgeutility-methods-bind_count"></a>

### `bind_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func bind_count( badge_id: StringName, callback: Callable, owner: Object = null ) -> GFSubscriptionToken:
```

为一个控件建立独立绑定，并立即发送当前计数。 回调接收一个 int；可以在回调中更新其他叶子或解除绑定。 无 owner 时必须显式 cancel；回调自身不得强持有期望自动释放的 owner。

参数：

| 名称 | 说明 |
|---|---|
| `badge_id` | 已声明节点 ID。 |
| `callback` | 接收 count:int 的有效 Callable。 |
| `owner` | 可选弱生命周期 owner；Node 必须在树中。 |

返回：独立取消 token；无效参数、超限或已释放返回 null。
