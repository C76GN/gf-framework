# 层级切换、守卫与事件

`GFStateMachine` 支持通过 `parent_state_name` 建立父子状态路径，让状态切换只退出和进入必要分支。

当从 `Grounded/Idle` 切换到 `Grounded/Run` 时，`Grounded` 会保持激活，只退出 `Idle` 并进入 `Run`；当切换到 `Airborne` 时，则会先退出 `Idle`，再退出 `Grounded`，最后进入 `Airborne`。这就是典型 HSM 的最近公共祖先切换语义。

## 守卫

`GFState` 可重写 `can_enter()` / `can_exit()` 作为进入和退出守卫。守卫拒绝时，状态机发出 `transition_blocked`，并保持当前激活路径不变。

守卫应优先保持无副作用，便于推理和测试；框架仍安全支持守卫同步调用 `change_state()`、`stop()` 或改写状态注册关系。只要回调启动了更新的状态事务，更新事务即取得优先权，旧切换计划会在回调返回后终止，不会再次退出旧状态或进入过时目标。`enter()` 中发起的嵌套切换沿用同一规则。

## 状态事件

需要让子状态把未处理输入或领域事件交给父状态时，调用：

```gdscript
fsm.dispatch_state_event(&"cancel", { "source": "input" })
```

事件会从当前叶子状态开始，沿父状态路径向上调用 `handle_state_event()`，直到某个状态返回 `true`。一次派发只属于开始时的激活周期：若处理器同步切换、停止或替换激活状态，派发会在该处理器返回后终止并返回 `false`，不会把旧事件继续交给已退出的父状态或新激活状态，也不会发出过时的 `state_event_handled`。

运行时可用 `get_active_state_path()`、`is_in_state()`、`get_state_snapshot()` 和共享 `blackboard` 做调试、诊断或 UI 展示。

`update(delta, true)` 可按 root -> leaf 顺序更新整条激活路径，默认只更新当前叶子状态，适合大多数有限状态机的单活跃状态逻辑。
