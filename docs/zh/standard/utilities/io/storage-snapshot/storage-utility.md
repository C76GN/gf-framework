# 本地存档管理器

`GFStorageUtility` 是基于 Godot `user://` 的本地持久化工具。它负责把字典和 `Resource` 文件写入项目可写目录，并在读取时执行 codec 解码、完整性校验、事务恢复和版本迁移。

底层 storage 不作为项目槽位门面。项目需要槽位工作流时，应由项目自有的 slot adapter 把槽位身份映射到可配置文件名，再通过 `GFStorageUtility.save_data_group()` 让数据与 metadata 同事务落盘；标准层不规定槽位编号、命名、预览字段或 UI 语义。

`GFStorageCodec` 提供 JSON/Binary 编码、可选压缩、SHA-256 完整性校验、轻量 XOR 混淆和框架存储元信息。框架 envelope 带显式版本和严格保留字段集合；业务字典即使包含 `__gf_storage_envelope`、`data` 或 `_meta` 等相似键，也会作为用户载荷完整往返，不会被宽松 truthy marker 误拆包。这里的混淆只用于降低误编辑概率，不能用于保护敏感数据。

同时原生支持 Godot 的 `Resource` 类型保存，例如 `.tres` 或 `.res`。读取 Resource 会进入 Godot `ResourceLoader`，因此默认关闭；项目必须先显式启用 `allow_resource_loads`，配置 `allowed_resource_load_type_hints` 与扩展名 allowlist，并用存储路径策略收窄加载边界。`load_resource()` 会在加载后再次确认实际资源实例匹配 `type_hint`，这个入口只面向项目生成或项目已确认来源与格式的本地文件，不是沙盒化的资源导入器；对用户下载、导入或可被篡改的资源，项目层应先做来源检查、格式转换，或改用纯 `Dictionary` / JSON 载荷。

`GFStorageCodec` 的 JSON 格式会自动通过 `GFVariantJsonCodec` 把 Vector、Color、PackedArray、AABB、Transform 和 `NaN` / `INF` / `-INF` 等值转换为 JSON 安全标记，再在读取时恢复为 Godot Variant。需要保存 Resource 或 Node 引用时，仍应使用 `GFVariantReferenceCodec` 的显式引用标记，或由 SaveGraph 属性序列化器代为处理。

如果确实需要把受控 `Resource` 属性图编码成字典，再使用 `GFSafeResourceCodec` 与 `GFSafeResourceCodecPolicy`。默认策略不会实例化任何对象，项目必须显式允许类、脚本路径和外部资源路径：

```gdscript
var policy := GFSafeResourceCodecPolicy.new()
policy.allow_class("Resource")
policy.allow_resource_path("res://data/*.tres")

var encoded := GFSafeResourceCodec.encode(my_resource, policy)
var decoded := GFSafeResourceCodec.decode(encoded.data, policy)
```

安全 codec 只处理 allowlist 内的存储属性、集合、重复引用和可选外部资源路径。它不注册 Godot ResourceFormatLoader/Saver，不执行表达式，也不把未知内容变成可直接使用的对象；面对用户下载内容或网络载荷时，应先在项目层完成格式收窄和风险处理。

## 项目级存档聚合

`GFStorageUtility` 只负责把项目给出的载荷可靠落盘，不提供全局 SaveSystem、业务模块注册表或固定存档目录规范。项目可以在自己的 System、Installer、slot adapter 或存档服务中收集多个 Model、Domain 容器、运行时快照和项目配置，再把聚合后的字典交给 `save_data()` 或 `save_data_group()`。

这种聚合结构应由项目定义，例如 schema 版本、玩家资料、世界状态、设置、统计和自定义预览字段。GF 侧只承诺通用机制：路径安全、事务恢复、codec、checksum、压缩、多文件事务、Resource 存取和 `register_migration()` 版本迁移。模块优先级、业务字段含义、奖励发放、云同步账号隔离、平台加密和冲突策略都应留在项目层或独立插件。

大型载荷推荐拆成两段：先用项目自己的分帧流程或 `GFArchitecture.get_global_snapshot_async()` 生成纯 Dictionary，再调用 `save_data_async()` 后台编码和落盘。`GFStorageUtility` 的异步写入线程只处理已经生成的纯数据，不会在线程中遍历场景树、读取 Resource 或调用业务对象。

## 基础用法

```gdscript
var storage := Gf.get_utility(GFStorageUtility) as GFStorageUtility

# -- 字典与多文件事务 --
storage.save_data("profile.json", {"player_hp": 100})
storage.save_data_group({
	"slots/1/data.json": {"player_hp": 100},
	"slots/1/meta.json": {"display_name": "手动槽位 1"},
})

# -- Resource 存档 --
var my_res := Resource.new()
storage.save_resource("my_custom_resource.tres", my_res)

# 仅加载项目自己写入或已确认来源与格式的资源文件。
storage.allow_resource_loads = true
storage.allowed_resource_load_extensions = PackedStringArray(["tres"])
storage.allowed_resource_load_type_hints = PackedStringArray(["Resource"])
var loaded_res := storage.load_resource("my_custom_resource.tres", "Resource")
```

`save_data_group()` 会先把所有成员规范化成唯一 file-family 身份；`group/a.json` 与 `group//a.json` 这类别名会在写入前被拒绝。事务 journal 带版本、transaction id、精确文件集合和数量上限，恢复时磁盘 marker 只能引用本次调用已经授权的 canonical 文件，不能扩大到请求范围之外。提交失败会按同一 file-family 集合恢复备份。

## 文件管理

除槽位和字典读写外，`get_storage_directory_path()`、`ensure_directory()`、`list_files()` 与 `delete_file()` 可用于管理同一存储根目录下的通用文件，例如列出本地缩略图、缓存 manifest 或项目自定义资源文件。

`get_storage_directory_path()` 只解析路径，不创建目录；需要目录实际存在时再调用 `ensure_directory()`。这些 API 复用 `GFStorageUtility` 的路径安全策略：默认拒绝绝对路径并阻止 `..` 跨目录；纯字典读写和多文件事务 API 会直接拒绝空 `file_name` 或任意非法成员，而不是写入内部兜底文件名。

递归枚举默认限制深度和返回数量，可通过 `list_files(..., { "max_scan_depth": 64, "max_file_count": 20000 })` 调整。枚举结果返回存储相对路径，适合交给 `load_data()`、显式启用后的 `load_resource()` 或项目自己的读取流程继续处理。

项目 slot adapter 枚举槽位时应使用自己的受控文件模板，不要把内部事务文件、备份文件或项目临时文件混入读档 UI。
