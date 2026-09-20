# ActionQueue 表现动作队列

ActionQueue 扩展负责表现动作的排队、并行、取消和横切拦截。它把“规则已经结算完成”和“表现仍在播放”分开，避免动画等待、音效播放、UI 过渡和粒子生命周期反向污染战斗、回合、剧情或教程系统。

动作可以继承 `GFVisualAction`，也可以实现动作协议方法，例如 `execute()`、`can_execute()`、`cancel()` 和 `should_wait_for_result()`。

## 阅读入口

- [视觉动作与入队](visual-actions/index.md)：`GFActionQueueSystem`、`GFVisualActionGroup`、自定义动作和 fire-and-forget。
- [命名队列与生命周期](queue-streams.md)：多条表现流、节点绑定队列、清空、跳过和运行时控制。
- [拦截器与动作工厂](interceptors-actions/index.md)：`GFActionInterceptor`、内置动作、`GFAction` 工厂和等待语义。
- [配置化 Tween 动作](tween-config.md)：步骤校验、曲线、运行时定位与往返、同属性替换和 Inspector 预览。

## 使用边界

- 适合：卡牌移动、命中特效、对白展示、教程高亮、UI 入场、表现层等待和可取消表现流。
- 不适合：回合推进、伤害结算、剧情状态写入、背包变更、存档修改或其他业务状态事实。
- 规则系统应先产出稳定结果，再把需要播放的表现动作交给 ActionQueue。
- 如果某个动作需要调用 Combat、Dialogue、Network、Save 或项目专属模块，应由项目层显式依赖这些模块并创建动作。

ActionQueue 只定义队列协议和通用动作，不内置面向其他 GF 内置扩展的适配动作，也不通过类名、路径或 manifest ID 硬编码跨扩展适配。

## API Reference

完整类、方法和信号列表见 [Action Queue API Reference](../../reference/api/extensions-action-queue.md)。
