# GFControlEditSession

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_control_edit_session.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

一个控件的运行期输入会话。 保存编辑开始时的值和文本，保留 SpinBox 尚未提交的数字原文。 宿主负责连接焦点/提交事件、业务转换、验证、模型写入和撤销命令。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`begin_edit`](#member-gfcontroleditsession-methods-begin_edit) | `func begin_edit(control: Control) -> int:` |
| 方法 | [`is_current`](#member-gfcontroleditsession-methods-is_current) | `func is_current(token: int) -> bool:` |
| 方法 | [`get_baseline`](#member-gfcontroleditsession-methods-get_baseline) | `func get_baseline(token: int) -> Dictionary:` |
| 方法 | [`capture_draft`](#member-gfcontroleditsession-methods-capture_draft) | `func capture_draft(token: int) -> Dictionary:` |
| 方法 | [`has_ime_composition`](#member-gfcontroleditsession-methods-has_ime_composition) | `func has_ime_composition(token: int) -> bool:` |
| 方法 | [`commit_edit`](#member-gfcontroleditsession-methods-commit_edit) | `func commit_edit(token: int) -> Dictionary:` |
| 方法 | [`cancel_edit`](#member-gfcontroleditsession-methods-cancel_edit) | `func cancel_edit(token: int) -> bool:` |
| 方法 | [`clear`](#member-gfcontroleditsession-methods-clear) | `func clear() -> void:` |

## 方法

<a id="member-gfcontroleditsession-methods-begin_edit"></a>

### `begin_edit`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func begin_edit(control: Control) -> int:
```

开始输入并返回本实例的会话令牌；同一活动控件重复开始保留原基线。

参数：

| 名称 | 说明 |
|---|---|
| `control` | 支持 LineEdit、TextEdit、SpinBox、Range、OptionButton、BaseButton、ColorPickerButton 和 ItemList。 |

返回：正数令牌；无效/不支持的控件、另一活动控件或恢复期间返回零。

<a id="member-gfcontroleditsession-methods-is_current"></a>

### `is_current`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_current(token: int) -> bool:
```

检查令牌是否仍属于活动会话；延期回调必须携带开始时的令牌。

参数：

| 名称 | 说明 |
|---|---|
| `token` | begin_edit 返回的令牌，仅在同一个会话实例内有效。 |

返回：控件仍有效且令牌属于活动会话时返回 true。

<a id="member-gfcontroleditsession-methods-get_baseline"></a>

### `get_baseline`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_baseline(token: int) -> Dictionary:
```

返回本次输入最初的快照，不因重复开始或当前输入变化而更新。

参数：

| 名称 | 说明 |
|---|---|
| `token` | 当前会话令牌。 |

返回：独立快照；过期令牌返回空字典。

结构：

- `return`: Dictionary，value 为控件值；文本控件及 SpinBox 另有 raw_text: String。没有控件或业务对象引用。

<a id="member-gfcontroleditsession-methods-capture_draft"></a>

### `capture_draft`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func capture_draft(token: int) -> Dictionary:
```

捕获当前草稿；SpinBox 的原文独立于 Range.value，非法中间输入也会保留。

参数：

| 名称 | 说明 |
|---|---|
| `token` | 当前会话令牌。 |

返回：独立快照；过期令牌返回空字典。

结构：

- `return`: Dictionary，value 为控件值；文本控件及 SpinBox 另有 raw_text: String。没有控件或业务对象引用。

<a id="member-gfcontroleditsession-methods-has_ime_composition"></a>

### `has_ime_composition`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func has_ime_composition(token: int) -> bool:
```

检查原生文本控件的输入法组合；组合尚未结束时提交与取消均拒绝。

参数：

| 名称 | 说明 |
|---|---|
| `token` | 当前会话令牌。 |

返回：有未完成组合时返回 true；其他控件或过期令牌返回 false。

<a id="member-gfcontroleditsession-methods-commit_edit"></a>

### `commit_edit`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func commit_edit(token: int) -> Dictionary:
```

结束会话并交付输入边界，不解析数字、不应用模型、不生成历史。 宿主应先验证草稿，接受后调用本方法；净零变化由 changed=false 表示。

参数：

| 名称 | 说明 |
|---|---|
| `token` | 当前会话令牌。 |

返回：独立的提交快照；过期令牌或未完成输入法组合返回空字典且不结束当前会话。

结构：

- `return`: Dictionary，成功时含 changed: bool、before: Dictionary、after: Dictionary；before/after 含 value 和可选 raw_text: String。失败为空字典。

<a id="member-gfcontroleditsession-methods-cancel_edit"></a>

### `cancel_edit`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel_edit(token: int) -> bool:
```

尝试恢复本次输入最初的控件值与原文并结束会话；不发起模型写入。 原生值变化信号可能发出，宿主需要自己的写入门禁；恢复期间不能开启新会话。 原生约束或宿主回调使恢复失败时保留实际控件状态，不承诺原子回滚。 SpinBox 的原生延期格式化后再校正原文；clear、新会话或数值不再等于基线会撤销这次延期校正。

参数：

| 名称 | 说明 |
|---|---|
| `token` | 当前会话令牌。 |

返回：控件值和原文均恢复且会话未失效时返回 true，包括没有净变化；恢复失败仍结束本次会话并返回 false。过期令牌或输入法组合返回 false，不开始恢复。

<a id="member-gfcontroleditsession-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func clear() -> void:
```

放弃会话并失效所有旧令牌，不恢复控件、不写入模型。 宿主在字段解绑、文档切换、退树或释放时调用。
