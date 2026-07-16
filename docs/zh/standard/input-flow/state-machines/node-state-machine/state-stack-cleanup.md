# 状态栈与动态清理

如需把弹窗、瞄准、短暂硬直等“覆盖式”状态叠加在当前状态之上，可使用状态栈。

`push_state()` 会调用旧状态的 `_pause()` 并进入新状态，`pop_state()` 会退出当前子状态并调用上一层状态的 `_resume()`。

```gdscript
machine.push_state(&"Inventory", { "source": "shortcut" })
machine.pop_state()
```

如果叠加状态或暂停栈状态在 `_exit()` 中请求切换到其他状态，状态组会先完成本轮栈清理，再按最后一次退出重定向进入目标状态。

当前叠加状态不会因为后续重定向被重复 `_exit()`。

普通 `transition_to()` 折叠暂停栈时默认使用 `StackExitPolicy.REQUIRE_GUARDS`，会先检查每个待退出状态的 `can_exit()`；任一 guard 拒绝时整次切换保持原状。只有明确执行恢复、强制清理或项目已经完成外部确认时，才应传 `StackExitPolicy.FORCE` 绕过这些 guard。

如果当前叠加状态在运行时被 `GFNodeStateGroup.remove_state()` 移除，状态组会先让该状态执行 `_exit()`，再恢复暂停栈顶状态并调用 `_resume()`。这样编辑器工具、动态技能槽或临时 UI 状态清理时不会把状态机留在“无当前状态但栈里还有父状态”的中间状态。

移除非当前的暂停栈状态只会把它从栈中摘除，不会改变当前状态。

`GFNodeStateGroup.stop()` 会退出当前状态和暂停栈，但保留已注册状态节点。

`GFNodeStateMachine.clear_state_groups()` 会先停止外部状态组再从状态机解绑，避免旧组被清理后仍保持 active state。`remove_state()`、`clear_states()`、`remove_state_group()` 与 `clear_state_groups()` 都会解除 state/group 持有的 machine 和 group 引用；项目即使保留被移除对象，也不能再通过它访问旧状态机上下文。

`clear_states(true)` 与 `clear_state_groups(true)` 会先把被释放的状态或状态组从场景树移除，再进入释放队列，便于运行时重建结构时同一帧拿到干净的子节点列表。
