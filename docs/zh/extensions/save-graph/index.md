# Save 场景存档图

GF Save 扩展负责把场景树节点状态组织成可采集、可校验、可应用的存档图。它与标准库 `GFStorageUtility` 配合使用：SaveGraph 负责生成和应用 Dictionary payload，Storage 负责本地读写、编码、同步和槽位文件管理。

## 阅读入口

- [采集、应用与存储闭环](runtime-flow.md)：`GFSaveGraphUtility`、`GFSaveScope`、`GFSaveSource`、`GFSaveDataSource` 和 Storage 组合方式。
- [结构校验与实体恢复](structure-validation.md)：`inspect_scope()`、`validate_payload_for_scope()`、工厂恢复、事务回滚和编辑器诊断。
- [节点序列化器与槽位](serializers-slots.md)：默认节点状态片段、`GFSaveIdentity`、`GFSaveSlotWorkflow`、槽位元数据和卡片 DTO。
- [Pipeline Trace](pipeline-trace.md)：`GFSavePipelineContext`、流程事件和采集/应用诊断日志。
- [Save Profile 运行时](save-profile-runtime.md)：多 section 所有权、异步 generation 合并、flush 屏障、迁移和恢复政策。
- [Save Profile 架构决策](save-profile-adr.md)：状态机、不变量、失败矩阵和故障注入策略。

## 使用边界

`GFStorageUtility`、`GFStorageCodec`、`GFStorageSyncUtility` 和 `GFSnapshotHistoryUtility` 是标准库能力，负责本地读写、编码、同步和快照历史，主说明见 [本地存储、编码、同步与快照](../../standard/utilities/io/storage-snapshot/index.md)。

SaveGraph 只处理场景树级存档图。项目已经有完整 `SaveGamePayload` / Model 聚合对象，并且不需要遍历场景节点时，可以把长期维护边界实现为 `GFSaveSectionProvider` 后交给 Save Profile；只有普通单字典缓存才直接交给 Storage。

## API Reference

完整类、方法和信号列表见 [Save API Reference](../../reference/api/extensions-save.md)。
