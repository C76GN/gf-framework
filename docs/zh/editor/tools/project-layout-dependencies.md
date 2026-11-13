# Project Layout 资源依赖证据

[Project Layout](project-layout.md) 的库存回答文件是否被观察到；资源依赖证据回答哪些已记录的引用连接了这些文件。二者分别保留捕获状态。文件系统库存完整，并不代表动态加载、导出包或某次运行的所有依赖都已覆盖。

## 捕获与来源

编辑器“扫描项目”完成目录库存后，分批调用当前已打开项目的 [ResourceLoader.get_dependencies](https://docs.godotengine.org/en/stable/classes/class_resourceloader.html#class-resourceloader-method-get-dependencies)。工具不调用资源加载或场景实例化，不启动另一个项目。引擎返回普通资源路径，或 `UID::::fallback`；有效 UID 优先，未知 UID 使用规范 fallback，无有效目标时保留未解析证据。原始文本、UID、fallback、解析方式和最终目标都随报告保留。

捕获记录绑定库存范围与路径摘要，保存每个已读取文件的 SHA-256 和源文件字节数，并记录引擎版本及捕获方法。发布前再次读取捕获文件、检查 UID 映射；发现变化则标为 `stale`，分析器不使用其中的静态边与字节统计。摘要用于发现内容或范围不一致，不能认证第三方提供的证据来源。

每步最多处理 8 个文件；总计最多 4096 个文件、16384 条静态引用，每个源文件 4 MiB、累计源文件 32 MiB，最终复核最多再读相同字节数。达到预算返回 `partial`，无法捕获返回 `unavailable`。原生依赖解析调用不能逐条中断，因此这些限额不构成每帧毫秒保证。自定义 ResourceFormatLoader 的行为由已打开项目负责。无法识别的文件只计源文件字节，不据此声明其没有运行依赖。

## 项目声明

在项目 Profile 中加入可选 `dependency_policy`，即可显式指定启动根、资源所有者、额外依赖和源文件预算：

```json
{
  "startup_roots": ["app/main.tscn"],
  "owners": [
    { "id": "bootstrap", "roots": ["app"], "max_source_bytes": 1048576 },
    { "id": "inventory", "roots": ["features/inventory"], "max_source_bytes": -1 }
  ],
  "edges": [
    { "from": "app/main.tscn", "to": "features/inventory/entry.tscn" }
  ],
  "max_startup_files": 64,
  "max_startup_source_bytes": 4194304
}
```

路径相对于所声明的库存根，必须规范且不含 `..`；所有权根可用 `.` 表示整个范围。预算 `-1` 表示未声明。省略字段使用空集合或 `-1`。最多 256 个启动根、256 个所有者和 4096 条声明引用。所有者条目必须给出 `id`、`roots`、`max_source_bytes`；重叠拥有会报告，工具不会替项目决定谁应拥有资源。

`startup_files` 是从显式根出发的已知引用闭包，循环用有限遍历处理。`unreachable_files` 仅表示未从这些根通过现有证据到达，不等于无用资源。`startup_source_bytes` 统计闭包中已捕获的源文件字节；`startup_complete` 只表示这份静态捕获对已知闭包是否充分。部分捕获时，字节统计只是已观察到的下限。源文件大小不代表导出大小、解压内存、GPU 内存或启动耗时。

## 三类证据与冻结输入

快照可附加 `dependencies`，其字段精确为 `capture`、`declaration`、`observations`。`capture` 是捕获器返回的封存记录，未取得时为 `{}`；`declaration` 使用上面的项目声明。带 Profile 分析时，以编译后的 `dependency_policy` 为声明权威。

`observations` 是项目显式提交的运行历史，每项精确包含 `from`、`to`、`sample_id`、`config_digest`、`observed_at_msec`。路径使用同一库存相对范围，配置摘要为 64 位小写 SHA-256，时间为不超过 `2^53-1` 的非负整数。观测只证明对应样本发生过该引用，不证明其他执行路径没有依赖。

报告中的边分别标记 `static_resource_dependency`、`project_declared_dependency`、`runtime_dependency_observation`，保留独立来源。所有输入先经过结构、总量、范围绑定与摘要校验；外部提供的完整报告还会重新计算推导结果，拒绝伪造的闭包或修改后的摘要。分析不写项目文件，也不访问捕获来源。

冻结输入可以通过 `GFProjectLayoutEditorSnapshotBuilder.make_snapshot()` 取得，由项目工具显式保存 JSON。维护 CLI 接受这份快照：

```powershell
python tools/gf_maintenance.py project-profile-boundary --root D:/my_game --snapshot evidence/layout.json --json
```

快照文件必须在 `--root` 内，最多 1 MiB；此参数与 `--profile` 互斥。显式指定的快照缺失时会失败，包括其父目录不存在的情况；只有未指定输入的自动发现允许项目尚未配置。严格 JSON 拒绝重复键与不安全数值；数值只接受十进制整数记法，不接受小数或指数记法。CLI 只在 GF 自身的可信工具 fixture 中解释快照，不启动来源项目的 autoload、编辑器插件或业务脚本，也不会重新捕获快照指向的文件。`GFProjectLayoutSession.open_snapshot_text()` 使用同一入口；同样的冻结输入产生同样分析。历史快照可重现历史结果，但不承诺其仍反映当前磁盘内容。

## 变更与性能判断

删除、移动或重命名存在已知入边的路径时，影响报告列出反向可达的文件与证据，给出需要审查引用改写的 blocker。即使静态边全部采集，动态拼接路径和未观测执行路径仍然未知，工具不会自动给出安全应用结论，也不会替项目搬目录、改引用或重新分包。

启动关键路径必须通过真实运行采样判断。可将每个加载步骤的开始、完成、依赖等待、配置摘要和设备信息交给[惰性诊断 Provider](../../standard/utilities/runtime/debug-observability/runtime-telemetry/build-diagnostics/diagnostics-commands/lazy-providers.md)，以相同场景和条件复测；不要用本报告的文件字节数替代耗时测量。
