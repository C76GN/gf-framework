# 旧存档离线导入

当前运行时只接受严格存储文档：外层为 `__gf_storage_document` 与 `payload`，描述区包含 `schema_version=2`、`metadata` 和 `integrity`。业务版本位于 `metadata.data_version`，业务字典始终位于 `payload`。文档格式与物理 family layout 是不同的版本层，详见[本地存档管理器](../storage-utility.md)和[已提交版本](../committed-revisions.md)。

历史版本的纯 JSON、旧 envelope 和宽松 marker 识别不属于当前读取合同，`allow_legacy_plain_json_fallback` 已移除，不能通过打开开关导入。升级前应保留原文件副本，用独立、版本锁定的一次性导入器和对应旧版 codec 读取，再验证业务 schema，最后通过当前 `save_data()` / `save_data_group()` 写入目标 logical identity。验证读取结果及业务数据后再移除导入入口；不要把格式猜测留在主运行时读取路径中。

`normalize_json_numbers` 只影响已通过当前文档校验的 JSON 数值处理，不能把旧纯 JSON 或旧 envelope 变成合法当前文档。旧版数值兼容要求应由锁定版本的导入器显式处理。

11.0 移除了 `GFStorageUtility.allow_absolute_paths`。运行时 Storage 只接受未经改写、已经满足 `portable-ascii-v1` 的 logical identity，并通过 `.gf-storage/v1` 分片 catalog 映射到当前 Storage root 内的私有 family；绝对路径、路径别名、包含 `..` 的跨目录路径和非法非空 `save_dir_name` 始终 fail closed，不再提供可重新开启的兼容开关。旧版直接位于 Storage root 的可见文件不会被自动扫描、领养或迁移，必须由显式离线/编辑器迁移工具读取并重写为新 family。这是 GF API 边界，不替代宿主文件系统对 symlink、junction 或挂载点的隔离。

可信编辑器工具或一次性迁移脚本确实需要访问外部路径时，应在独立工具边界直接使用 `FileAccess` / `DirAccess`，并自行承担来源授权、路径固定和生命周期清理；不要把该能力重新包装进运行时 Storage。

内置整数槽位 facade 已移除。项目应由自己的 slot adapter 定义槽位身份、文件模板、metadata schema 和枚举策略，再通过 `save_data_group()` 完成 data/meta 事务写入，通过 `load_data()`、`query_catalog()` 和 `delete_file()` 组合读取与管理。`load_data()` 返回 `GFStorageReadResult`，必须检查成功状态，不能用空字典推断失败。标准存储层不认识读档 UI、自动存档、预览图或项目业务槽位。

导入器应调用公开存储入口创建当前 family，不直接拼接 catalog、owner、事务或 revision state 的物理路径。`GFStorageRevisionMigration` 只负责已有合法 family 的 layout schema 升级，不承担旧纯 JSON、旧 envelope 或业务 schema 的导入。

异步 `save_data_async()` / `load_data_async()` 会按文件串行和线程预算调度。

如果同一路径需要混合同步和异步读写，先调用 `wait_for_async_tasks()` 收敛已入队任务顺序，再执行同步 `save_data()` / `load_data()`。

`dispose()` 会等待已开始的线程结束并发出对应完成信号，对尚未开始的队列任务发出失败结果，避免调用方一直等待完成通知。
