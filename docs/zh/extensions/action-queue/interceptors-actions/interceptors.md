# 动作拦截器

当项目需要让状态、配置或调试工具在动作执行前后做横切处理时，可以继承 `GFActionInterceptor` 并注册到队列。

拦截器返回 `GFActionInterceptionResult`，可继续、跳过、替换当前动作，或停止后续队列。

默认没有拦截器时，`GFActionQueueSystem` 行为保持不变。

```gdscript
class_name SkipInvalidTargetVisuals
extends GFActionInterceptor


func before_execute(action: GFVisualAction, _queue: GFActionQueueSystem) -> GFActionInterceptionResult:
	if action.has_method("has_target") and not action.call("has_target"):
		return GFActionInterceptionResult.skip_action()
	return GFActionInterceptionResult.continue_action()


var q_sys := Gf.get_system(GFActionQueueSystem) as GFActionQueueSystem
q_sys.add_interceptor(SkipInvalidTargetVisuals.new())
```

队列在执行前、执行后分别构建拦截器阶段快照，并按当时观察到的 `priority` 从高到低执行；注册后修改优先级会影响下一次阶段快照。相同优先级按注册顺序稳定执行。`set_interceptors()` 会先完成过滤、去重和注入，再统一排序并发布一次最终状态。

它不提供卡牌、Buff、剧情或回合规则；这些规则应留在项目自己的 System、Command 或 Action 子类中。
