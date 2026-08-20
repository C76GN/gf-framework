# GFTurnPhaseCompletionHandle

[API Reference](../index.md) / [Turn Based](../extensions-turn-based.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/turn_based/runtime/gf_turn_phase_completion_handle.gd`
- 模块：`Turn Based`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

单次阶段运行的完成能力句柄。 有效句柄只会由 GFTurnFlowSystem 传给当前 GFTurnPhase._execute() 调用；项目手工 new() 的实例没有完成权限。 首次对有效运行调用 try_complete() 会完成该阶段；停止、超时、释放、dispose、重启后的旧句柄及重复调用都返回 false，不影响其他代际。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`try_complete`](#member-gfturnphasecompletionhandle-methods-try_complete) | `func try_complete() -> bool:` |

## 方法

<a id="member-gfturnphasecompletionhandle-methods-try_complete"></a>

### `try_complete`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func try_complete() -> bool:
```

尝试完成创建此句柄的精确阶段运行。

返回：当前主线程首次完成仍有效的精确运行时返回 true；失效、重复或非主线程调用返回 false。
