# GFInventoryTransferTransaction

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/inventory/gf_inventory_transfer_transaction.gd`
- 模块：`Domain`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

两个槽位库存之间的一次性原子转移句柄。 `prepare()` 只构建有界隔离候选；`commit()` 会重新取得稳定顺序锁、校验 model identity 与 revision，并重新规划后才执行无回调的内存替换。跨模型成功 时先同时写入两边状态，再依次派发来源、目标和事务终态通知。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`completed`](#member-gfinventorytransfertransaction-signals-completed) | `signal completed(result: GFInventoryTransferResult)` |
| 方法 | [`prepare`](#member-gfinventorytransfertransaction-methods-prepare) | `static func prepare( source: GFSlotInventoryModel, target: GFSlotInventoryModel, source_slot: int, target_slot: int = -1, amount: int = 0, allow_partial: bool = false ) -> GFInventoryTransferTransaction:` |
| 方法 | [`is_prepared`](#member-gfinventorytransfertransaction-methods-is_prepared) | `func is_prepared() -> bool:` |
| 方法 | [`is_completed`](#member-gfinventorytransfertransaction-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`get_prepare_result`](#member-gfinventorytransfertransaction-methods-get_prepare_result) | `func get_prepare_result() -> GFInventoryTransferResult:` |
| 方法 | [`get_result`](#member-gfinventorytransfertransaction-methods-get_result) | `func get_result() -> GFInventoryTransferResult:` |
| 方法 | [`commit`](#member-gfinventorytransfertransaction-methods-commit) | `func commit() -> GFInventoryTransferResult:` |

## 信号

<a id="member-gfinventorytransfertransaction-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal completed(result: GFInventoryTransferResult)
```

事务提交尝试进入终态时发出一次。成功提交时，该信号只在所有参与库存的 内存状态提交且库存通知派发完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 不保留模型或候选堆叠的隔离终态结果。 |

## 方法

<a id="member-gfinventorytransfertransaction-methods-prepare"></a>

### `prepare`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func prepare( source: GFSlotInventoryModel, target: GFSlotInventoryModel, source_slot: int, target_slot: int = -1, amount: int = 0, allow_partial: bool = false ) -> GFInventoryTransferTransaction:
```

构建一次不写入模型的有界转移计划。 `target_slot == -1` 复用目标库存 `add_item()` 的合并、空槽和增长顺序； 非负目标槽复用 `add_item_to_slot()` 的单槽规则。`amount <= 0` 请求来源 堆叠全部数量。同一模型只接受显式目标槽，并按 `move_between_slots()` 规则生成候选后经框架内部原子替换提交，不动态调用可重写公共方法。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 来源槽位库存。 |
| `target` | 目标槽位库存。 |
| `source_slot` | 来源槽位索引。 |
| `target_slot` | 目标槽位索引；-1 表示按目标库存自动选择。 |
| `amount` | 请求数量；小于等于 0 表示来源堆叠全部数量。 |
| `allow_partial` | 来源或目标容量不足时是否允许部分转移。 |

返回：一次性事务句柄；使用 `get_prepare_result()` 检查规划结果。

<a id="member-gfinventorytransfertransaction-methods-is_prepared"></a>

### `is_prepared`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_prepared() -> bool:
```

检查 prepare 是否生成可提交计划。

返回：当前未完成且 prepare 状态有效时返回 true。

<a id="member-gfinventorytransfertransaction-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_completed() -> bool:
```

检查句柄是否已进入唯一终态。

返回：`commit()` 已被消费时返回 true。

<a id="member-gfinventorytransfertransaction-methods-get_prepare_result"></a>

### `get_prepare_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_prepare_result() -> GFInventoryTransferResult:
```

获取 prepare 阶段结果副本。

返回：隔离规划结果；配置尚未完成时返回 null。

<a id="member-gfinventorytransfertransaction-methods-get_result"></a>

### `get_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_result() -> GFInventoryTransferResult:
```

获取终态结果副本。

返回：`commit()` 后的隔离结果；尚未提交时返回 null。

<a id="member-gfinventorytransfertransaction-methods-commit"></a>

### `commit`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func commit() -> GFInventoryTransferResult:
```

一次性提交已准备计划。 跨模型提交重新规划并完成全部验证后，最终阶段只替换已验证内存候选， 不调用规则或项目回调，因此没有需要补偿或表示 unknown state 的失败阶段。

返回：唯一终态结果；重复调用返回首次终态的隔离副本。
