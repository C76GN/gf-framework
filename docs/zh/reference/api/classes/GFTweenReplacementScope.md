# GFTweenReplacementScope

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/tween/gf_tween_replacement_scope.gd`
- 模块：`Action Queue`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

配置化 Tween 显式共享的属性替换作用域。 仅管理主动加入本作用域的动作，不查找目标上的其他 Tween。 相同目标的同一顶层属性及其分量互斥；Node2D、Node3D 的 rotation_degrees 与 rotation 视为同一属性。其他属性别名和项目 setter 的关联不作推断。 作用域只弱引用动作与目标；持有者应在自身生命周期结束时调用 dispose()。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`dispose`](#member-gftweenreplacementscope-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`is_disposed`](#member-gftweenreplacementscope-methods-is_disposed) | `func is_disposed() -> bool:` |
| 方法 | [`get_active_count`](#member-gftweenreplacementscope-methods-get_active_count) | `func get_active_count() -> int:` |

## 方法

<a id="member-gftweenreplacementscope-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func dispose() -> void:
```

永久关闭作用域并停止仍登记的动作；重复调用无副作用。 先撤销全部登记并停止全部动作，再通知动作完成，不恢复被替换动作的初值。 完成通知中的重入登记会被拒绝。

<a id="member-gftweenreplacementscope-methods-is_disposed"></a>

### `is_disposed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_disposed() -> bool:
```

查询作用域是否已永久关闭。

返回：dispose() 调用后返回 true。

<a id="member-gftweenreplacementscope-methods-get_active_count"></a>

### `get_active_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_active_count() -> int:
```

查询仍具有有效动作和目标的登记数，并移除失效的弱引用登记。

返回：当前登记的动作数量，不是属性或步骤数量。
