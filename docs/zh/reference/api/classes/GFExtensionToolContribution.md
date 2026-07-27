# GFExtensionToolContribution

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/extension/gf_extension_tool_contribution.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`8.0.0`

扩展编辑器工具贡献文件的稳定 schema 解析器。 该类型只定义贡献文件协议，不负责加载脚本、验证资源存在性或管理编辑器生命周期。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`SCHEMA_VERSION`](#member-gfextensiontoolcontribution-constants-schema_version) | `const SCHEMA_VERSION: int = 2` |
| 常量 | [`PATH_FIELDS`](#member-gfextensiontoolcontribution-constants-path_fields) | `const PATH_FIELDS: Array[String] = [` |
| 常量 | [`ALLOWED_FIELDS`](#member-gfextensiontoolcontribution-constants-allowed_fields) | `const ALLOWED_FIELDS: Array[String] = [` |
| 方法 | [`parse_dictionary`](#member-gfextensiontoolcontribution-methods-parse_dictionary) | `static func parse_dictionary(data: Dictionary, expected_extension_id: String = "") -> Dictionary:` |

## 常量

<a id="member-gfextensiontoolcontribution-constants-schema_version"></a>

### `SCHEMA_VERSION`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const SCHEMA_VERSION: int = 2
```

当前支持的贡献文件 schema 版本。

<a id="member-gfextensiontoolcontribution-constants-path_fields"></a>

### `PATH_FIELDS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const PATH_FIELDS: Array[String] = [
```

所有可声明的工具贡献路径字段。

<a id="member-gfextensiontoolcontribution-constants-allowed_fields"></a>

### `ALLOWED_FIELDS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const ALLOWED_FIELDS: Array[String] = [
```

工具贡献文件允许的全部顶层字段。

## 方法

<a id="member-gfextensiontoolcontribution-methods-parse_dictionary"></a>

### `parse_dictionary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func parse_dictionary(data: Dictionary, expected_extension_id: String = "") -> Dictionary:
```

校验并规范化一个工具贡献字典。 未知字段、非当前 schema（包括 v1 与未来版本）、错误扩展 ID、非数组路径字段、 非字符串或空路径都会使报告失败。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 待校验的 JSON object 数据。 |
| `expected_extension_id` | 非空时要求 contribution 的 extension_id 与其一致。 |

返回：schema 校验报告。

结构：

- `data`: Dictionary，字段必须属于 ALLOWED_FIELDS。
- `return`: Dictionary，包含 ok、data 和 errors；data 包含 schema_version、extension_id 及全部 PATH_FIELDS。
