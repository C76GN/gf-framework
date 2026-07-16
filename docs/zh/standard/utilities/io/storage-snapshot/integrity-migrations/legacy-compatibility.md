# 兼容旧存档

2.0 默认关闭旧版纯 JSON 回退。当项目已经配置混淆、压缩或 Binary 格式时，解码失败不会再自动尝试按未混淆 JSON 读取原始 bytes。

迁移旧文件时可临时启用 `allow_legacy_plain_json_fallback`。即使当前 codec 开启压缩，读取也会先识别原始 plain JSON，再决定是否进入解压路径，避免解压错误提前截断旧 JSON 迁移。

JSON 读取默认保留解析出的数字类型。如果旧存档列表或元数据依赖把接近整数的 float 归一为 int，可临时开启 `GFStorageUtility.normalize_json_numbers` 或 `GFStorageCodec.normalize_json_numbers` 后读出并重写。

`allow_absolute_paths` 默认关闭，绝对路径会被拒绝；包含 `..` 的跨目录相对路径同样会 fail closed，不再收敛到同名文件。

只有可信编辑器工具或迁移脚本确实需要写入外部路径时，才应显式设为 `true`。

内置整数槽位 facade 已移除。项目应由自己的 slot adapter 定义槽位身份、文件模板、metadata schema 和枚举策略，再通过 `save_data_group()` 完成 data/meta 事务写入，通过 `load_data_result()`、`list_files()` 和 `delete_file()` 组合读取与管理。标准存储层不认识读档 UI、自动存档、预览图或项目业务槽位。

存储 envelope 现在要求精确的 `__gf_storage_envelope=true`、`__gf_storage_envelope_version=1`、`data` 和受限保留字段集合。旧版本写出的无版本 envelope 不再被自动拆包，否则普通业务字典中的同名 marker 仍可能被误识别并丢字段。升级前应先用旧版 codec 读出这类文件，再用当前 `GFStorageCodec` 重写；不要在新运行时重新开启宽松 marker 识别。

异步 `save_data_async()` / `load_data_async()` 会按文件串行和线程预算调度。

如果同一路径需要混合同步和异步读写，先调用 `wait_for_async_tasks()` 收敛已入队任务顺序，再执行同步 `save_data()` / `load_data()`。

`dispose()` 会等待已开始的线程结束并发出对应完成信号，对尚未开始的队列任务发出失败结果，避免调用方一直等待完成通知。
