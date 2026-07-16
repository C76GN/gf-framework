# 端口、连接与拓扑校验

`GFFlowPort` 可为节点声明输入/输出端口、值类型提示和自定义元数据。`GFFlowGraph.connections` 可描述节点级或端口级连接，`validate_graph()` 可提前检查缺失后继节点、重复节点 ID、端口 ID、连接端点和单连接端口约束。

```gdscript
graph.add_connection(&"check_door", &"", &"open", &"")
graph.add_connection(&"check_door", &"", &"locked", &"")
```

端口身份必须来自显式 `port_id`。框架不会再用 `resource_path` 作为端口 ID 回退，因为资源移动、重命名或导入器路径变化都会改变连接身份并把项目路径泄漏到诊断报告。编辑器工具、导入器和代码生成器应在创建端口时写入稳定 ID。

`GFFlowGraph` 默认启用 `validate_port_compatibility`。它会使用端口的 `value_type` 和 Object 端口的 `class_name_hint` 检查端口级连接，避免编辑器或导入流程把明显不兼容的数据线写入资源。

迁移旧资源时可以临时关闭 `validate_port_compatibility`。需要独立检查时，可调用 `check_connection_compatibility()` 或 `get_connection_compatibility_report()`。

`validate_graph()` 还会输出通用拓扑诊断：

- `warn_unreachable_nodes`：默认提示从 `start_node_id` 无法到达的节点。
- `warn_cycles`：默认提示循环结构。
- `warn_terminal_nodes`：可显式开启，用于提示无后继节点。

这些诊断只作为 warning，不假设循环或终端节点一定错误。项目可以在编辑器、导入流程或 CI 中按自己的资源规范决定是否把某类 warning 提升为错误。
