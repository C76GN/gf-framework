# 兼容性、产物与激活预检

这一组类型把“当前环境能否满足目标要求”“本地产物是否仍新鲜”“一组显式启用步骤是否能安全提交”整理成通用报告。它们只处理声明式数据、文件元数据和调用方显式传入的 `Callable`，不下载资源、不加载脚本、不决定包管理、远程发布或项目业务策略。

## 核心类

- `GFCompatibilityProfile` 是资源化的能力描述，记录 Godot 版本、GF 版本、平台、功能标识、包条目、artifact 条目和自定义 metadata。
- `GFCompatibilityPreflight` 把版本、平台、功能、包、artifact 声明和外部报告合并为 `GFValidationReportDictionary` 兼容报告。
- `GFArtifactFreshnessReport` 检查本地文件是否存在、可读、大小和 `sha256` 是否匹配，以及记录的 source digest 是否仍等于当前 source digest。
- `GFActivationTransaction` 用显式步骤表达 prepare、commit 和 rollback，失败时会把已应用步骤按逆序回滚并返回事务报告。

## 兼容性预检

`GFCompatibilityProfile` 不猜测项目能力，也不推导包闭包。项目或工具应把自己已经知道的目标环境、安装包和功能开关显式写入 Profile，再交给预检器检查。

```gdscript
var profile: GFCompatibilityProfile = GFCompatibilityProfile.from_current_environment({
	"framework_version": "6.0.0",
	"features": PackedStringArray(["content_package", "offline_bundle"]),
})
profile.add_package(&"gf.standard.base", "6.0.0")
profile.add_artifact(&"native_bridge", "res://native/bridge.gdip")

var preflight: GFCompatibilityPreflight = GFCompatibilityPreflight.new()
preflight.configure("Install preflight", profile)
preflight.require_godot_version("4.7.0")
preflight.require_features(PackedStringArray(["content_package"]))
preflight.require_artifact(&"native_bridge", {
	"require_path": true,
})

preflight.require_artifact(&"native_bridge", {
	"expected_kind": &"native_library",
	"require_file_exists": true,
	"expected_sha256": expected_sha256,
	"expected_size_bytes": expected_size,
})

var report: Dictionary = preflight.get_report()
```

预检报告的 `checks` 保留每一项显式检查，`issues` 使用稳定 `kind`，例如 `godot_version_below_minimum`、`feature_missing`、`package_missing`、`artifact_path_mismatch`、`artifact_file_missing`、`artifact_sha256_mismatch` 或 `artifact_size_mismatch`。`require_artifact()` 默认只检查 Profile 中的声明和可选路径；只有调用方显式传入 `require_file_exists`、`expected_sha256` 或 `expected_size_bytes` 时，才读取该 artifact 路径的本地文件 metadata。需要批量检查生成产物新鲜度、source digest 或缓存状态时，继续使用 `GFArtifactFreshnessReport`。外部模块已经有自己的校验报告时，可以通过 `merge_report()` 合入同一份结果。

## 产物新鲜度

`GFArtifactFreshnessReport` 适合构建缓存、导入器输出、生成文件或离线 bundle 的本地预检。它只读取文件存在性、长度、修改时间和可选 `sha256`，不会解释文件内容。

```gdscript
var artifacts: GFArtifactFreshnessReport = GFArtifactFreshnessReport.new()
artifacts.add_artifact(&"registry", "user://registry.json", {
	"expected_sha256": expected_sha256,
	"expected_size_bytes": expected_size,
	"recorded_source_digest": old_digest,
	"current_source_digest": current_digest,
})

var report: Dictionary = artifacts.get_report()
```

`include_sha256` 与 `include_modified_time` 只控制最终 artifact 条目是否展示对应字段。若条目声明了 `expected_sha256` 或 `minimum_modified_time`，报告仍会采集并验证该值，再按 include 选项移除展示字段；这样关闭展示不会把显式完整性条件静默变成成功。只有没有相应 expected 条件时，`include_sha256 = false` 才会省去哈希计算。

当前实现按本地路径读取文件元数据，不为扫描期间被并发替换的路径提供文件身份锁或不可变 snapshot 保证。需要把检查结果作为安全发布依据时，调用方应先发布到不可变路径、持有项目自己的发布锁，或在后续统一 artifact snapshot 契约落地后使用该契约。

## 激活事务

`GFActivationTransaction` 适合“先验证，再发布一组状态变更”的通用场景，例如切换资源注册表、替换配置快照、挂载本地数据包或刷新工具索引。每个步骤由调用方提供 apply / rollback / validate 回调；GF 只负责顺序、失败报告和回滚编排。

```gdscript
var transaction: GFActivationTransaction = GFActivationTransaction.new()
transaction.configure(&"activate_catalog", "Catalog activation")
transaction.add_step(
	&"swap_catalog",
	func(context: Dictionary) -> bool:
		return context.has("catalog"),
	func(_context: Dictionary) -> bool:
		return true
)

var report: Dictionary = transaction.commit({ "catalog": catalog })
```

回调返回 `false`、非 `OK` 的 `Error`，或 `{ "ok": false }` 时，该步骤会进入失败报告。同步事务不会隐式等待回调返回的 `Signal` 或 Godot async 状态对象；这类返回值会被报告为 `async_callback_unsupported`。`prepare()` 只会从 pending 进入 prepared，重复 prepare 已准备事务是幂等读取；committed、rolled_back 或 failed 终态只能先在事务操作之外显式 `clear()`。validate/apply/rollback 回调内对同一事务嵌套调用 prepare/commit/rollback 会返回 `transition_in_progress`，回调内的 `clear()`、`configure()` 和 `add_step()` 不会改写正在进行的状态。

`commit()` 在应用阶段失败后会自动逆序回滚此前已经成功应用的步骤；默认情况下，已应用步骤缺少 rollback 回调会让事务保持失败。当前失败的 apply 步骤本身不会自动进入补偿集合，因此可能留下部分副作用的回调必须在返回失败前自行恢复；后续是否把该责任升级为结构化 apply outcome 仍属于单独的产品契约决策。确实不需要回滚的步骤应在 `options` 中显式传入 `rollback_required = false`。`rollback()` 也可由调用方显式触发。

## 使用边界

- 这些类型不执行远程载荷，也不让普通数据包绕过项目的安全策略。
- Profile 中的平台、功能、包和 artifact 标识都由调用方定义；GF 不为某个项目写死能力名称。
- 事务回调必须是调用方已经持有并信任的同步 `Callable`，不要把字符串、资源文件或外部数据解释成可执行逻辑；需要异步 prepare/commit/rollback 时，应在项目层显式编排或等待未来独立 async API。
- 需要具体下载、解压、签名、版本求解或平台服务接入时，应在项目工具或独立插件中组合这些报告结果。
