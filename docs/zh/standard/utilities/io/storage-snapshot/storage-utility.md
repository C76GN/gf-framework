# 本地存档管理器

`GFStorageUtility` 是基于 Godot `user://` 的本地持久化工具。它负责把字典、槽位元数据和 `Resource` 文件写入项目可写目录，并在读取时执行 codec 解码、完整性校验、事务恢复和版本迁移。

槽位存储会把核心数据和展示用 Metadata 分开，读档列表 UI 可以只读取 Metadata 与修改时间，不必加载完整存档载荷。

`GFStorageCodec` 提供 JSON/Binary 编码、可选压缩、SHA-256 完整性校验、轻量 XOR 混淆和框架存储元信息。若业务载荷根字典本身已有 `_meta` 字段，codec 会把框架元信息写入独立 envelope，读取时仍还原用户自己的 `_meta`，避免存档格式和业务数据抢同一个键。这里的混淆只用于降低误编辑概率，不能用于保护敏感数据。

同时原生支持 Godot 的 `Resource` 类型直接存取，例如 `.tres` 或 `.res`。

`GFStorageCodec` 的 JSON 格式面向普通 JSON 数据。需要保留 Vector、Color、PackedArray 等 Godot 值类型时，先用 `GFVariantJsonCodec` 转换；需要保存 Resource 或 Node 引用时，使用 `GFVariantReferenceCodec` 的显式引用标记，或由 SaveGraph 属性序列化器代为处理。

## 项目级存档聚合

`GFStorageUtility` 只负责把项目给出的载荷可靠落盘，不提供全局 SaveSystem、业务模块注册表或固定存档目录规范。项目可以在自己的 System、Installer 或存档服务中收集多个 Model、Domain 容器、运行时快照和项目配置，再把聚合后的字典交给 `save_data()` 或 `save_slot()`。

这种聚合结构应由项目定义，例如 schema 版本、玩家资料、世界状态、设置、统计和自定义预览字段。GF 侧只承诺通用机制：路径安全、事务恢复、codec、checksum、压缩、槽位 metadata、Resource 存取和 `register_migration()` 版本迁移。模块优先级、业务字段含义、奖励发放、云同步账号隔离、平台加密和冲突策略都应留在项目层或独立插件。

大型载荷推荐拆成两段：先用项目自己的分帧流程或 `GFArchitecture.get_global_snapshot_async()` 生成纯 Dictionary，再调用 `save_data_async()` 后台编码和落盘。`GFStorageUtility` 的异步写入线程只处理已经生成的纯数据，不会在线程中遍历场景树、读取 Resource 或调用业务对象。

## 基础用法

```gdscript
var storage := Gf.get_utility(GFStorageUtility) as GFStorageUtility

# -- 字典与槽位存档 --
# 保存槽位，后一个字典是高层预览专用的 Metadata
storage.save_slot(1, {"player_hp": 100}, {"play_time": "12:00", "level": 5})

# 在读档选单展示
var meta := storage.load_slot_meta(1)
print(meta.get("level"))

# 枚举所有有效槽位，只读取 metadata 和修改时间
for slot_info in storage.list_slots():
	print(slot_info["slot_id"], slot_info["metadata"])

# 正式进入游戏后再读取完整核心数据
var full_data := storage.load_slot(1)

# -- Resource 存档 --
var my_res := Resource.new()
storage.save_resource("my_custom_resource.tres", my_res)

var loaded_res := storage.load_resource("my_custom_resource.tres")
```

## 文件管理

除槽位和字典读写外，`get_storage_directory_path()`、`ensure_directory()`、`list_files()` 与 `delete_file()` 可用于管理同一存储根目录下的通用文件，例如列出本地缩略图、缓存 manifest 或项目自定义资源文件。

`get_storage_directory_path()` 只解析路径，不创建目录；需要目录实际存在时再调用 `ensure_directory()`。这些 API 复用 `GFStorageUtility` 的路径安全策略：默认拒绝绝对路径并阻止 `..` 跨目录；纯字典读写 API 会直接拒绝空 `file_name`，而不是写入内部兜底文件名。

递归枚举默认限制深度和返回数量，可通过 `list_files(..., { "max_scan_depth": 64, "max_file_count": 20000 })` 调整。枚举结果返回存储相对路径，适合交给 `load_data()`、`load_resource()` 或项目自己的读取流程继续处理。

槽位列表仍应优先使用 `list_slots()`，避免把内部事务文件、备份文件或项目临时文件混入读档 UI。
