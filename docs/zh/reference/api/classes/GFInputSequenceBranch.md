# GFInputSequenceBranch

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/sequences/gf_input_sequence_branch.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

输入序列触发器的一条可选分支。 多分支允许同一动作由不同抽象动作序列触发，适合格斗、快捷指令或可替代输入路径。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`steps`](#member-gfinputsequencebranch-properties-steps) | `var steps: Array[GFInputSequenceStep] = []` |
| 属性 | [`max_gap_seconds`](#member-gfinputsequencebranch-properties-max_gap_seconds) | `var max_gap_seconds: float = -1.0:` |
| 方法 | [`is_valid_branch`](#member-gfinputsequencebranch-methods-is_valid_branch) | `func is_valid_branch() -> bool:` |
| 方法 | [`duplicate_branch`](#member-gfinputsequencebranch-methods-duplicate_branch) | `func duplicate_branch() -> GFInputSequenceBranch:` |
| 方法 | [`from_action_ids`](#member-gfinputsequencebranch-methods-from_action_ids) | `static func from_action_ids( action_ids: Array[StringName], p_max_gap_seconds: float = -1.0 ) -> GFInputSequenceBranch:` |

## 属性

<a id="member-gfinputsequencebranch-properties-steps"></a>

### `steps`

- API：`public`

```gdscript
var steps: Array[GFInputSequenceStep] = []
```

本分支的步骤列表。

<a id="member-gfinputsequencebranch-properties-max_gap_seconds"></a>

### `max_gap_seconds`

- API：`public`

```gdscript
var max_gap_seconds: float = -1.0:
```

本分支默认最大步骤间隔。小于 0 表示使用触发器默认值，0 表示不限制。

## 方法

<a id="member-gfinputsequencebranch-methods-is_valid_branch"></a>

### `is_valid_branch`

- API：`public`

```gdscript
func is_valid_branch() -> bool:
```

检查分支是否至少包含一个有效动作步骤。

返回：有效返回 true。

<a id="member-gfinputsequencebranch-methods-duplicate_branch"></a>

### `duplicate_branch`

- API：`public`

```gdscript
func duplicate_branch() -> GFInputSequenceBranch:
```

创建当前分支的深拷贝。

返回：分支副本。

<a id="member-gfinputsequencebranch-methods-from_action_ids"></a>

### `from_action_ids`

- API：`public`

```gdscript
static func from_action_ids( action_ids: Array[StringName], p_max_gap_seconds: float = -1.0 ) -> GFInputSequenceBranch:
```

从动作 ID 数组创建分支。

参数：

| 名称 | 说明 |
|---|---|
| `action_ids` | 动作 ID 数组。 |
| `p_max_gap_seconds` | 默认最大步骤间隔。 |

返回：新分支。

结构：

- `action_ids`: Array[StringName]，会复制到 GFInputSequenceStep 资源中。
