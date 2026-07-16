# GFNetworkContractGenerator

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/editor/gf_network_contract_generator.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

根据 GFNetworkContract 生成强类型消息辅助脚本。 生成结果保持为 GDScript 轻量封装，围绕 GFNetworkMessage / GFNetworkUtility 提供构造、发送、匹配和 payload 读取函数，不绑定任何具体业务协议。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_OUTPUT_DIR`](#member-gfnetworkcontractgenerator-constants-default_output_dir) | `const DEFAULT_OUTPUT_DIR: String = "res://gf/generated/network"` |
| 方法 | [`generate`](#member-gfnetworkcontractgenerator-methods-generate) | `func generate( contract: GFNetworkContract, output_path: String = "", overwrite_existing: bool = true, options: Dictionary = {} ) -> Error:` |
| 方法 | [`generate_with_report`](#member-gfnetworkcontractgenerator-methods-generate_with_report) | `func generate_with_report( contract: GFNetworkContract, output_path: String = "", options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`generate_many`](#member-gfnetworkcontractgenerator-methods-generate_many) | `func generate_many( contract_paths: PackedStringArray, output_dir: String = DEFAULT_OUTPUT_DIR, overwrite_existing: bool = true, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`build_source`](#member-gfnetworkcontractgenerator-methods-build_source) | `func build_source(contract: GFNetworkContract, options: Dictionary = {}) -> String:` |
| 方法 | [`save_source`](#member-gfnetworkcontractgenerator-methods-save_source) | `func save_source(output_path: String, source: String, overwrite_existing: bool = true) -> Error:` |
| 方法 | [`save_source_with_report`](#member-gfnetworkcontractgenerator-methods-save_source_with_report) | `func save_source_with_report(output_path: String, source: String, options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfnetworkcontractgenerator-constants-default_output_dir"></a>

### `DEFAULT_OUTPUT_DIR`

- API：`public`

```gdscript
const DEFAULT_OUTPUT_DIR: String = "res://gf/generated/network"
```

默认生成脚本输出目录。

## 方法

<a id="member-gfnetworkcontractgenerator-methods-generate"></a>

### `generate`

- API：`public`

```gdscript
func generate( contract: GFNetworkContract, output_path: String = "", overwrite_existing: bool = true, options: Dictionary = {} ) -> Error:
```

生成单个契约访问器脚本。

参数：

| 名称 | 说明 |
|---|---|
| `contract` | 网络契约资源。 |
| `output_path` | 输出脚本路径；为空时按 contract_id 推导。 |
| `overwrite_existing` | 为 false 时目标已存在会返回 ERR_ALREADY_EXISTS。 |
| `options` | 可选项，支持 class_name。 |

返回：Godot 错误码。

结构：

- `options`: Dictionary，支持 class_name。

<a id="member-gfnetworkcontractgenerator-methods-generate_with_report"></a>

### `generate_with_report`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func generate_with_report( contract: GFNetworkContract, output_path: String = "", options: Dictionary = {} ) -> Dictionary:
```

生成单个契约访问器脚本并返回生成产物报告。

参数：

| 名称 | 说明 |
|---|---|
| `contract` | 网络契约资源。 |
| `output_path` | 输出脚本路径；为空时按 contract_id 推导。 |
| `options` | 可选项，支持 class_name、overwrite_existing、dry_run、scan_filesystem 和 metadata。 |

返回：生成产物报告。

结构：

- `options`: Dictionary，可包含 class_name、overwrite_existing、dry_run、scan_filesystem 和 metadata。
- `return`: Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、size_bytes 和 metadata。

<a id="member-gfnetworkcontractgenerator-methods-generate_many"></a>

### `generate_many`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func generate_many( contract_paths: PackedStringArray, output_dir: String = DEFAULT_OUTPUT_DIR, overwrite_existing: bool = true, options: Dictionary = {} ) -> Dictionary:
```

批量生成多个契约访问器脚本。

参数：

| 名称 | 说明 |
|---|---|
| `contract_paths` | 契约资源路径列表。 |
| `output_dir` | 输出目录。 |
| `overwrite_existing` | 为 false 时目标已存在会跳过。 |
| `options` | 可选项，支持 class_name、dry_run、scan_filesystem 和 metadata。 |

返回：生成报告。

结构：

- `options`: Dictionary，可包含 class_name、dry_run、scan_filesystem 和 metadata。
- `return`: Dictionary，GFValidationReportDictionary 格式，包含 ok、generated_count、attempted_count、skipped_count、artifact_summary、generated、issues、issue_count 和 next_actions。

<a id="member-gfnetworkcontractgenerator-methods-build_source"></a>

### `build_source`

- API：`public`

```gdscript
func build_source(contract: GFNetworkContract, options: Dictionary = {}) -> String:
```

构建契约访问器源码。测试或项目工具可直接调用该方法。

参数：

| 名称 | 说明 |
|---|---|
| `contract` | 网络契约资源。 |
| `options` | 可选项，支持 class_name。 |

返回：GDScript 源码。

结构：

- `options`: Dictionary，支持 class_name。

<a id="member-gfnetworkcontractgenerator-methods-save_source"></a>

### `save_source`

- API：`public`

```gdscript
func save_source(output_path: String, source: String, overwrite_existing: bool = true) -> Error:
```

保存生成源码到指定路径。

参数：

| 名称 | 说明 |
|---|---|
| `output_path` | 输出脚本路径。 |
| `source` | 源码文本。 |
| `overwrite_existing` | 为 false 时目标已存在会返回 ERR_ALREADY_EXISTS。 |

返回：Godot 错误码。

<a id="member-gfnetworkcontractgenerator-methods-save_source_with_report"></a>

### `save_source_with_report`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func save_source_with_report(output_path: String, source: String, options: Dictionary = {}) -> Dictionary:
```

保存生成源码到指定路径并返回生成产物报告。

参数：

| 名称 | 说明 |
|---|---|
| `output_path` | 输出脚本路径。 |
| `source` | 源码文本。 |
| `options` | 保存选项，支持 overwrite_existing、dry_run、scan_filesystem 和 metadata。 |

返回：生成产物报告。

结构：

- `options`: Dictionary，可包含 overwrite_existing、dry_run、scan_filesystem 和 metadata。
- `return`: Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、size_bytes 和 metadata。
