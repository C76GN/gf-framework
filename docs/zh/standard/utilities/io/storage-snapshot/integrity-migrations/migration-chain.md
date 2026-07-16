# 迁移链

项目如需复杂迁移，可继承 `GFStorageUtility` 并重写 `migrate_data(data, from_version, to_version)`。

如果迁移只是按版本分段的小步骤，也可以用 `register_migration(from_version, to_version, callback)` 注册迁移链。

```gdscript
storage.save_version = 3
storage.register_migration(1, 2, func(data: Dictionary, _from: int, _to: int) -> Dictionary:
	data["settings"] = data.get("settings", {})
	return data
)
storage.register_migration(2, 3, func(data: Dictionary, _from: int, _to: int) -> Dictionary:
	data["profile_version"] = 3
	return data
)
```

如果已经注册了分段迁移，旧存档版本到当前 `save_version` 必须能解析出完整链路。解析器按最短可达路径选择迁移步骤，并使用稳定次序处理同长度候选；存在直达目标的迁移时，不会因为较小版本分支先被枚举而走入断链。

缺失某一段时读取会失败并发出 `data_integrity_failed`，不会把旧结构伪标记成当前版本。

只依赖 `default_values_for_new_keys` 补齐字段、且没有注册迁移步骤的项目仍可继续使用默认迁移路径。

需要把“没有迁移步骤但版本升高”也视为失败时，设置 `strict_schema_migrations = true`。

当存档 `_meta.version` 高于当前 `save_version` 时，读取始终 fail closed 并报告 future version，不会合并当前默认值或把未来 schema 重新保存成旧版本。需要查看未来格式时，应使用只读迁移工具直接检查原始文件，而不是让旧运行时加载并覆盖它。
