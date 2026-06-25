# 通用策略注册表

`GFPolicyProvider` 和 `GFPolicyRegistry` 用于把一组可复用策略挂到通用 artifact 字典上。它适合资源导入预检、构建产物治理、编辑器工具质量规则、内容包审查或项目自定义数据检查；GF 只负责 provider 注册、artifact kind 匹配、优先级排序和结果汇总。

## 典型流程

Provider 声明自己支持的 artifact kind，并在 `_evaluate_policy()` 中返回策略结果。返回空字典表示通过；返回非空字典时，注册表会补齐 `provider_id`、`artifact_kind`、`issues`、`data` 和 metadata。

```gdscript
class TextureSizePolicy:
	extends GFPolicyProvider

	func _init() -> void:
		provider_id = &"texture_size"
		supported_artifact_kinds = PackedStringArray(["resource"])
		priority = 10

	func _evaluate_policy(artifact: Dictionary, _context: Dictionary) -> Dictionary:
		if int(artifact.get("width", 0)) <= 2048:
			return {}
		return make_result(false, &"failed", artifact, [
			{
				"severity": "warning",
				"kind": "large_texture",
				"message": "Texture is larger than the project policy.",
			},
		])
```

```gdscript
var registry := GFPolicyRegistry.new()
registry.register_provider(TextureSizePolicy.new())

var result := registry.evaluate_artifact({
	"kind": "resource",
	"path": "res://art/title.png",
	"width": 4096,
})
```

`evaluate_artifact()` 返回 `ok`、`provider_count`、`result_count`、`results`、`issues` 和输入 artifact 副本。项目工具可以把 `issues` 继续交给 `GFValidationReportDictionary`、诊断面板或 CI 输出。

## 使用边界

策略注册表不解释 artifact 字段，也不规定某类资源或构建产物应该有哪些业务规则。需要稳定 schema 时，项目可以在 provider 的 `input_schema`、`output_schema` 或 metadata 中声明，再由自己的工具读取。

Provider 应保持可重复、可测试，优先返回结构化问题而不是直接写文件、弹窗或修改项目。真正的修复、迁移、导入和发布动作应放在调用方工具链里，由策略结果驱动。
