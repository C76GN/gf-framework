# GFTextSearchScorer

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/collections/gf_text_search_scorer.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`5.0.0`

通用文本检索评分器。 对标题、关键字、路径、说明等候选字段进行轻量 token 匹配、相似度评分和排序。 它不读取文件系统、不创建 UI，也不规定候选数据来自资源、命令、设置还是项目内容。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_FIELDS`](#member-gftextsearchscorer-constants-default_fields) | `const DEFAULT_FIELDS: Array[Dictionary] = [` |
| 方法 | [`tokenize`](#member-gftextsearchscorer-methods-tokenize) | `static func tokenize(query: String, options: Dictionary = {}) -> PackedStringArray:` |
| 方法 | [`score_text`](#member-gftextsearchscorer-methods-score_text) | `static func score_text(query: String, text: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`score_candidate`](#member-gftextsearchscorer-methods-score_candidate) | `static func score_candidate(query: String, candidate: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`rank_candidates`](#member-gftextsearchscorer-methods-rank_candidates) | `static func rank_candidates(query: String, candidates: Array[Dictionary], options: Dictionary = {}) -> Array[Dictionary]:` |

## 常量

<a id="member-gftextsearchscorer-constants-default_fields"></a>

### `DEFAULT_FIELDS`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const DEFAULT_FIELDS: Array[Dictionary] = [
```

默认候选字段权重。

结构：

- `DEFAULT_FIELDS`: Array[Dictionary]，每个条目包含 key 和 weight 字段。

## 方法

<a id="member-gftextsearchscorer-methods-tokenize"></a>

### `tokenize`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func tokenize(query: String, options: Dictionary = {}) -> PackedStringArray:
```

把查询文本规范化为去重 token 列表。

参数：

| 名称 | 说明 |
|---|---|
| `query` | 查询文本。 |
| `options` | 可选项；case_sensitive 默认为 false。 |

返回：去重后的 token 列表，保留首次出现顺序。

结构：

- `options`: Dictionary，支持 case_sensitive。

<a id="member-gftextsearchscorer-methods-score_text"></a>

### `score_text`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func score_text(query: String, text: String, options: Dictionary = {}) -> Dictionary:
```

计算查询文本与单段候选文本的匹配报告。

参数：

| 名称 | 说明 |
|---|---|
| `query` | 查询文本。 |
| `text` | 候选文本。 |
| `options` | 可选项；require_all_tokens 默认为 true，case_sensitive 默认为 false。 |

返回：匹配报告。

结构：

- `options`: Dictionary，支持 require_all_tokens、case_sensitive。
- `return`: Dictionary，包含 matched、score 和 matched_tokens。

<a id="member-gftextsearchscorer-methods-score_candidate"></a>

### `score_candidate`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func score_candidate(query: String, candidate: Dictionary, options: Dictionary = {}) -> Dictionary:
```

计算查询文本与一个候选字典的匹配报告。

参数：

| 名称 | 说明 |
|---|---|
| `query` | 查询文本。 |
| `candidate` | 候选字典。 |
| `options` | 可选项；fields 为字段权重数组，require_all_tokens 默认为 true，case_sensitive 默认为 false，duplicate_candidate 默认为 true。 |

返回：匹配报告。

结构：

- `candidate`: Dictionary，字段由 options.fields 指定，默认读取 title、name、keywords、detail 和 path。
- `options`: Dictionary，支持 fields、require_all_tokens、case_sensitive、duplicate_candidate。
- `return`: Dictionary，包含 matched、score、matched_tokens、field_scores 和 candidate。

<a id="member-gftextsearchscorer-methods-rank_candidates"></a>

### `rank_candidates`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func rank_candidates(query: String, candidates: Array[Dictionary], options: Dictionary = {}) -> Array[Dictionary]:
```

按查询文本排序候选字典。

参数：

| 名称 | 说明 |
|---|---|
| `query` | 查询文本。 |
| `candidates` | 候选字典数组。 |
| `options` | 可选项；include_unmatched 默认为 false，limit 小于等于 0 表示不限制，case_sensitive 默认为 false。 |

返回：排序后的匹配报告数组。

结构：

- `candidates`: Array[Dictionary]，每个候选字段由 options.fields 指定。
- `options`: Dictionary，支持 fields、require_all_tokens、case_sensitive、duplicate_candidate、include_unmatched、limit。
- `return`: Array[Dictionary]，每项包含 matched、score、matched_tokens、field_scores、candidate 和 index。
