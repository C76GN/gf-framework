# 快照历史与查看器

需要做“状态快照级别”的撤回、回滚或编辑器预览恢复时，可以注册 `GFSnapshotHistoryUtility`。

它默认使用所属 `GFArchitecture.get_global_snapshot()` / `restore_global_snapshot()` 捕获和恢复已注册 Model 及可选命令历史，也可以通过回调接入任意项目自定义状态。默认路径会解包 Architecture 的显式 Result：捕获失败时不新增历史记录，恢复事务失败时不移动当前索引。

```gdscript
var snapshots := Gf.get_utility(GFSnapshotHistoryUtility) as GFSnapshotHistoryUtility
snapshots.max_history_size = 32
snapshots.capture({ "reason": "before_preview" })

# 修改项目状态后恢复上一份快照
snapshots.step_back()
```

如果状态不在 `GFArchitecture` 里，使用 `configure(capture_callback, restore_callback, options)` 明确传入捕获和恢复逻辑。

`push_snapshot(data, metadata)` 可把外部已经生成的状态压入历史；`restore_index()` / `restore_snapshot_id()` 可按位置或稳定 ID 恢复；`get_debug_snapshot()` 会报告当前索引、可前进/后退状态和保留的 ID 列表。

该工具只管理快照栈和深拷贝，不替代 `GFCommandHistoryUtility` 的逐命令 undo/redo，也不替代 `GFStorageUtility` 的持久化写盘。恢复快照涉及业务对象重建、命令反序列化或远端同步时，仍应由项目层提供对应 builder 或回调。

## Storage Viewer

插件启用后也会在独立 `GF Workspace` 中提供 `GF Storage Viewer` 页面。它由标准库中的 `GFStorageViewerDock` 承载，用于按 codec 选项查看本地存档内容、校验状态并复制 JSON，方便调试而不绑定任何项目业务结构。

状态采集器、对象重建和场景节点协议由项目层或独立扩展提供；标准快照历史只接收已经形成的 Variant 数据和恢复回调。
