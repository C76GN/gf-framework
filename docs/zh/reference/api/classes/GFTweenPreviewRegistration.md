# GFTweenPreviewRegistration

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/editor/gf_tween_preview_registration.gd`
- 模块：`Action Queue`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

一次编辑器数值预览注册的所有权句柄。 release 幂等且只撤销自身租约；旧句柄不能撤销同 ID 后续注册。持有者应在插件卸载时显式释放。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`release`](#member-gftweenpreviewregistration-methods-release) | `func release() -> void:` |
| 方法 | [`is_active`](#member-gftweenpreviewregistration-methods-is_active) | `func is_active() -> bool:` |

## 方法

<a id="member-gftweenpreviewregistration-methods-release"></a>

### `release`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func release() -> void:
```

撤销本句柄注册，允许重复调用。

<a id="member-gftweenpreviewregistration-methods-is_active"></a>

### `is_active`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_active() -> bool:
```

返回当前句柄是否仍对应有效 owner 和租约。

返回：有效时为 true。
