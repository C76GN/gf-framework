# 完整性校验

需要更严格的存档维护时，可以启用 codec 元信息、checksum 和版本迁移。

```gdscript
storage.include_storage_metadata = true
storage.use_integrity_checksum = true
storage.require_integrity_checksum = true
storage.save_version = 2
storage.default_values_for_new_keys = {
	"settings": {
		"assist_mode": false,
	},
}

storage.data_integrity_failed.connect(func(file_name: String, error: String) -> void:
	push_warning("%s failed integrity check: %s" % [file_name, error])
)
```

`use_integrity_checksum` 会在 `__gf_storage_document.integrity` 中写入 `algorithm` 与 `digest`，并在读取时校验。业务载荷仍位于独立的 `payload` 字段，框架不会向业务字典注入 `_meta`。

从 `2.0.0` 起，启用完整性校验时默认要求载荷必须包含 checksum，缺失 checksum 会被视为读取失败。

对已经符合当前文档结构、但没有 checksum 的数据，可显式把 `GFStorageUtility.require_integrity_checksum` 或 `GFStorageCodec.require_integrity_checksum` 设为 `false`，验证后按新设置写回。这个选项不放宽文档结构校验；旧纯 JSON 和旧 envelope 须走[离线导入](legacy-compatibility.md)。

JSON checksum 输入会按 codec 的 JSON 表示归一化。当前 codec 默认通过 `GFVariantJsonCodec` 为超出 JSON 安全整数范围的 Int64 和其他受支持的 Godot 值生成类型标记，读取时恢复；不要绕过 codec，直接用普通 `JSON.stringify()` / `JSON.parse_string()` 替代这一往返。

Checksum 用于检测意外损坏，不提供来源认证。校验选项不改变业务版本迁移政策，也不能代替对业务字段的验证。
