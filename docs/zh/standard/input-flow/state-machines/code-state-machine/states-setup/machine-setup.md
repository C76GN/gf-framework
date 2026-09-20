# 初始化状态机

```gdscript
var fsm := GFStateMachine.new()
fsm.add_state(&"Grounded", GroundedState.new())
fsm.add_state(&"Idle", IdleState.new(), &"Grounded")
fsm.add_state(&"Run", MoveState.new(), &"Grounded")
fsm.add_state(&"Airborne", AirborneState.new())

fsm.start(&"Idle")
fsm.change_state(&"Run")

# 在你自己的任何主循环 (Tick 或 _process) 中驱动分发
fsm.update(delta)
```

状态机可以由项目自己的 tick、`_process()`、测试代码或局部系统驱动。GFStateMachine 只负责状态组织和切换语义，不规定主循环来源。

`add_state()` 替换活跃叶子且保持父级时，会先退出旧实例，再沿转换流程进入新实例；退出 hook 请求的重定向优先。新注册关系在旧实例的 `dispose()` 回调前提交，该回调发起的新操作也会终止旧替换流程，同名跳转只会找到新实例。修改活跃状态的父级（包括重新注册同一实例）或替换活跃祖先时，状态机会先停止整条路径，注册完成后由调用方显式 `start()`。
