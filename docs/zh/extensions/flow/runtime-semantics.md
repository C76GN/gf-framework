# 运行时语义

运行器优先使用节点或上下文提供的后继列表。当节点没有默认后继、上下文也没有显式覆盖时，才会回退到 `connections`。如果节点需要明确停止，可调用 `context.set_next_nodes(PackedStringArray())`。

`completed` 表示本轮所有已调度节点都解析并完成，而不是“队列碰巧耗尽”。起始节点或动态后继在执行时不存在会以 `aborted / missing_node` 终止，并进入 `flow_cancelled(report)`；报告中的 `missing_node_count` 和 trace 会保留定位证据。

节点 `wait_for_result` 且 `execute()` 返回 Signal 时，`GFFlowRunner` 会安全等待发射源或节点离树，并使用 `with_signal_timeout(seconds, respect_time_scale)` 控制等待上限。超时配置必须是有限数；`NaN` 或正负无穷会回退到 30 秒默认值，有限的零或负数关闭超时。默认超时同样跟随 `GFTimeUtility` 的暂停与 `time_scale`。Signal 可以带任意载荷参数，运行器只把发射本身视为等待完成。

等待期间调用 `cancel()` 后，运行器会停止在当前等待点，不再发送当前节点完成事件或推进后继节点。如果自定义节点在 `execute()` 内部自行 await 且永不返回，运行器无法替它取消这段内部逻辑，项目层应把等待对象作为 Signal 返回。

每次 `run()` 都返回一份普通 Dictionary 运行报告，`flow_completed(report)` 与 `flow_cancelled(report)` 发出同一结构；也可用 `get_last_run_report()` 读取隔离副本。`outcome` 区分 `completed`、`cancelled`、`aborted` 和开始前的 `rejected`，`reason` 给出稳定原因；报告还包含单调起止时间、耗时、已执行/已完成/缺失/待执行节点数量，以及 `signal_wait_count`、超时/取消/无效等待计数和每个已保留节点的 `status`、`wait_status`、耗时。这让任务链、过场编排、导入流水线等项目系统能够回答“停在哪里、是等待超时还是保护条件中止”，而无需让 Flow 理解具体业务。同一 Runner 尚未结束时再次调用 `run()` 会得到独立的 `rejected / run_in_progress` 报告，不会修改正在执行的图状态；原运行结束后，最近报告更新为它自己的终态。`is_running` 只是只读观察状态，调用方写入会被拒绝；取消流程必须调用 `cancel()`。

节点 trace 默认最多保留最新 128 条，由 `max_report_trace_entries` 调整；设为 `0` 可只保留汇总计数。`trace_entry_count` 始终统计完整数量，`retained_trace_entry_count`、`dropped_trace_entry_count` 和 `trace_truncated` 明确说明截断状态，因此循环图或长批处理不会让诊断数据无限增长。报告只记录节点标识和通用运行事实，不复制 context、节点对象、Signal 载荷或项目数据；需要记录领域结果时，由项目在自己的日志或 metadata 边界补充。

`GFFlowContext` 可注册条件查询处理器。`register_condition_handler(condition_id, handler)` 接收一个通用 `Callable`，`query_condition()` 会把返回值归一化为 `ok`、`value`、`reason` 和 `metadata`。这适合把“某个条件如何判断”留在项目层，同时让节点、导入器或编辑器工具使用同一套查询结果结构。

运行态默认写入 `GFFlowContext` 的节点状态表。节点可通过 `set_node_runtime_value(node_id, key, value)`、`get_node_runtime_value(node_id, key, default)` 和 `clear_node_runtime_state(node_id)` 保存跨 tick 进度；`serialize_runtime_state()` 和 `deserialize_runtime_state()` 可把这份上下文运行态随项目存档保存。

需要保存一次流程上下文的完整运行数据时，使用 `create_runtime_snapshot()`；恢复时调用 `restore_runtime_snapshot(snapshot)`。恢复入口要求 `values: Dictionary`、`next_node_ids: PackedStringArray`、`has_next_node_override: bool` 和 `runtime_state.nodes: Dictionary` 的完整形状；也接受旧快照把 `nodes` 放在顶层的既有形状。所有节点 ID 和节点状态会先完整校验，任何字段缺失或类型错误都返回 `false`，并保持当前 Context 原子不变。快照包含共享 `values`、显式后继覆盖和节点运行态，并可附带条件处理器 ID 供诊断展示。条件处理器 Callable、架构实例和正在等待的 Signal 不会被序列化，项目应在恢复后重新注册运行时服务与交互入口。

诊断、CLI 或日志需要直接写 JSON 时，使用 `serialize_runtime_state(true)` 或 `create_runtime_snapshot({ "json_compatible": true })`。默认快照保留原始 Variant，只适合内存恢复或项目自有编码器；JSON-safe 快照会保持 `nodes`、节点运行态、`values` 和 `metadata` 的固定字符串键 object 外壳，并把叶值中的 Object、Resource、循环集合和非有限数收束为报告 marker。`next_node_ids`、`condition_handler_ids` 等 PackedArray 使用当前 `__gf_report_value__` PackedArray marker，不回退到旧的 variant marker 形态。JSON-safe 输出是诊断投影，不是 `restore_runtime_snapshot()` 可直接接受的运行快照；需要持久化恢复时，项目必须用自己的版本 envelope 和解码/迁移层重建原始 Variant 形状。

`GFFlowRunner.isolate_graph_runtime_state` 默认开启。运行同一个 `GFFlowGraph` 资源时，它会把图内节点运行态隔离到当前 context，再在运行结束后恢复资源原状态，避免多个 NPC、任务实例或测试共享同一资源时串状态。返回 Signal 且要求等待的节点会持有运行态租约直到 Signal 完成、超时或取消，然后统一释放；因此超时不会留下永久占用的节点资源。返回 Signal 但 `wait_for_result = false` 的节点不会阻塞后继推进，不过租约仍保留到该 Signal 真正发出，防止异步回调在流程已继续后污染共享图资源；这类节点必须保证终态 Signal 最终发出。

`GFFlowGraph.deserialize_runtime_state()` 和 `clear_runtime_state()` 会先检查整张图；只要任一节点仍持有执行租约，操作就整体拒绝并保持所有节点状态不变。不要把资源运行态恢复当作取消或强制接管正在执行节点的手段。

需要从资源创建独立配置副本时，仍可使用 `instantiate_graph()`。
