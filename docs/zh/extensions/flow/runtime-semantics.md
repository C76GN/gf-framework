# 运行时语义

## 节点执行与报告

运行器优先使用本次节点执行显式选择的后继列表；没有显式覆盖时，将节点默认后继与节点级 `connections` 的目标按顺序去重合并。带端口的连接不参与这条运行时后继路径。如果节点需要明确停止，可调用 `execution.set_next_nodes(PackedStringArray())`，显式空列表同样会覆盖默认后继和连接。

`completed` 表示本轮所有已调度节点都解析并完成，而不是“队列碰巧耗尽”。起始节点或动态后继在执行时不存在会以 `aborted / missing_node` 终止，并进入 `flow_cancelled(report)`；报告中的 `missing_node_count` 和 trace 会保留定位证据。

节点 `wait_for_result` 且 `execute()` 返回 Signal 时，`GFFlowRunner` 会安全等待发射源或节点离树，并使用 `with_signal_timeout(seconds, respect_time_scale)` 控制等待上限。超时配置必须是有限数；`NaN` 或正负无穷会回退到 30 秒默认值，有限的零或负数关闭超时。默认超时同样跟随 `GFTimeUtility` 的暂停与 `time_scale`。Signal 可以带任意载荷参数，运行器只把发射本身视为等待完成。

等待期间调用 `cancel()` 后，运行器会停止在当前等待点，不再发送当前节点完成事件或推进后继节点。如果自定义节点在 `execute()` 内部自行 await 且永不返回，运行器无法替它取消这段内部逻辑，项目层应把等待对象作为 Signal 返回。

每次 `run()` 都返回一份普通 Dictionary 运行报告，`flow_completed(report)` 与 `flow_cancelled(report)` 发出同一结构；也可用 `get_last_run_report()` 读取隔离副本。`outcome` 区分 `completed`、`cancelled`、`aborted` 和开始前的 `rejected`，`reason` 给出稳定原因；报告还包含单调起止时间、耗时、已执行/已完成/缺失/待执行节点数量，以及 `signal_wait_count`、超时/取消/无效等待计数和每个已保留节点的 `status`、`wait_status`、耗时。这让任务链、过场编排、导入流水线等项目系统能够回答“停在哪里、是等待超时还是保护条件中止”，而无需让 Flow 理解具体业务。同一 Runner 尚未结束时再次调用 `run()` 会得到独立的 `rejected / run_in_progress` 报告，不会修改正在执行的图状态；原运行结束后，最近报告更新为它自己的终态。`is_running` 只是只读观察状态，调用方写入会被拒绝；取消流程必须调用 `cancel()`。

节点 trace 默认最多保留最新 128 条，由 `max_report_trace_entries` 调整；设为 `0` 可只保留汇总计数。`trace_entry_count` 始终统计完整数量，`retained_trace_entry_count`、`dropped_trace_entry_count` 和 `trace_truncated` 明确说明截断状态，因此循环图或长批处理不会让诊断数据无限增长。报告只记录节点标识和通用运行事实，不复制 context、节点对象、Signal 载荷或项目数据；需要记录领域结果时，由项目在自己的日志或 metadata 边界补充。

`GFFlowContext` 可注册条件查询处理器。`register_condition_handler(condition_id, handler)` 接收一个通用 `Callable`，`query_condition()` 会把返回值归一化为 `ok`、`value`、`reason` 和 `metadata`。这适合把“某个条件如何判断”留在项目层，同时让节点、导入器或编辑器工具使用同一套查询结果结构。

## 业务数据与运行数据

`GFFlowGraph` 和节点资源保存流程定义。可以用 `instantiate_graph()` 复制定义。每次接纳 `run(graph, context, initial_nodes)` 时，Runner 新建一个 `GFFlowRunState`。同一 Runner 的重叠启动会被拒绝。不同 Runner 可以同时使用同一个业务 Context，各自执行独立的队列、分支、等待和取消，分别返回自己的报告。终态信号发送前会封闭旧执行并释放 Runner，因此完成或取消信号的监听器可以立即开始下一次运行。

省略 Context 时 Runner 会使用自己的架构创建业务上下文；传入 Context 时使用项目配置的架构。自定义节点可在有效的 `execute` 或等待回调中按本轮临时进度选择后继，`get_next_nodes(context)` 负责根据配置或业务值计算默认后继。

`GFFlowContext.values`、条件处理器和业务模型按引用共享。两个流程修改同一键时，后读取者看到最近一次实际写入的值。读值、等待 Signal、再写回是多个步骤，项目应由拥有该数据的模型或服务裁决冲突。已经发放的奖励、库存修改和外部副作用由项目负责去重与补偿。两个独立 Context 也可各自持有同一个模型对象；构造函数会复制传入的字典，顶层键的后续写入各自独立。这里的重叠指主线程上的嵌套调用和等待交错。

Runner 为每次节点执行签发独立的 `GFFlowNodeExecution`。使用 `set_runtime_value()` 和 `get_runtime_value()` 存取该调用帧中本节点的进度。循环再次进入同一节点时会读到该帧的原有进度，并取得新的写入句柄。异步回调需在启动任务时捕获收到的句柄，不能在回调时重新寻找“当前执行”。写入或选分支返回 `false` 表示该执行已经结束或被取消，项目应放弃此次更新。共享业务对象的直接修改仍由项目代码决定。

## 子图与独立流程

任务流程临时进入一段对话，可以让任务节点调用 `execution.call_subgraph(dialogue_graph)`。当前节点结束后，Runner 先执行子图，再返回父图安排好的后继。每次子调用有自己的节点进度和待执行队列，父子使用同一 Context、同一个运行报告、节点数量上限和取消请求。每次节点执行最多接纳一次子调用。子图中的错误或取消结束整次运行。

独立的奖励流程可以使用另一个 Runner 调用 `run(reward_graph, context)`。两个运行的节点即使使用相同 ID，只要是不同资源也能独立执行。共享同一个节点资源且先前执行仍占用它时，新运行返回 `aborted / node_runtime_state_busy`。该冲突同样适用于两个 Context 使用同一个节点资源。

等待型节点的资源租约在 Signal 完成、超时或取消时释放。若后台任务在取消或超时后仍可能发射完成事件，每次启动都必须返回该任务独立的完成 Signal。例如，为每次请求创建一个操作对象，让节点返回该对象的完成信号。不同任务复用同一对象的同名裸 Signal 时，Runner 无法判断一次迟到发射来自哪次任务；项目可通过关联原请求身份的代理将完成事件转到所属操作。非等待节点返回 Signal 后立即推进后继并封闭逻辑写权限，但其节点资源一直占用到 Signal 真正发出。项目须确保此 Signal 最终发出。

## 显式初始化与数据快照

长期任务进度应交给项目的任务模型。新运行默认使用空的节点进度。需要按指定数据重新开始，可以向 `run()` 第三个参数传入 `{ &"node_id": { "cursor": 2 } }`。Runner 校验节点 ID 和字典类型后复制该映射，非法数据得到 `rejected / invalid_initial_nodes`。子图每次调用都从新帧开始。

持有 `runner.get_run_state()` 的项目也可在该对象上调用 `cancel()`，请求只影响这一次运行。`get_report()` 返回此轮的报告副本，等待期间可见 `waiting_node_id`。Runner 开始下一轮后，旧状态仍保留它自己的结果。

`runner.get_run_state().create_data_snapshot()` 返回根图进度的副本，`nodes` 可以显式作为随后运行的初始数据，两次运行都从图起点开始。需要观察调用栈时读取 `describe_frames()`。这些输出没有等待对象、项目副作用或可继续执行的完整调用栈。业务 Context 使用 `create_data_snapshot()` 单独捕获共享值；JSON 日志可传 `{ "json_compatible": true }`，将循环集合、对象和非有限数转为诊断标记。

旧节点应把 `execute(context)` 改为双参数签名，把在 Context 或节点资源上写入的运行态迁到 `execution`。迁移旧 Context 存档时，将快照中的 `values` 恢复到业务模型或新 Context；取出 `runtime_state.nodes`，作为 `run(graph, context, initial_nodes)` 的第三个参数。更早的快照可能把 `nodes` 放在顶层，这时取顶层的 `nodes` 即可。参数只接收节点进度表，整份旧快照不能直接传入。旧的待选分支及其业务意义由项目迁移逻辑处理，新运行仍从图起点开始。
