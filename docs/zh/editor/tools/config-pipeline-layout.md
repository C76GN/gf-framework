# Config Pipeline 结构化表格布局

对具有嵌套结构或多行集合的 CSV / XLSX，显式设置 `parse_options.layout`。布局阶段只还原 Dictionary / Array；标量转换、默认值、枚举和多态判别仍由[结构化类型定义](../../standard/utilities/io/config-remote-outbox/config-provider/provider-schema/schema-declaration.md)负责。复杂表应提供显式 `source.schema`。

任务创建、保存与执行入口见 [Config Pipeline 导表工具包](config-pipeline.md)。

## 多行集合示例

```gdscript
source.parse_options = {
	"layout": {
		"header_rows": [1],
		"record_key_column": 1,
		"columns": [
			{ "column": 1, "path": ["id"] },
			{ "column": 2, "path": ["name"] },
		],
		"collections": [
			{
				"kind": "array",
				"path": ["effects"],
				"columns": [
					{ "column": 3, "path": ["kind"] },
					{ "column": 4, "path": ["amount"] },
				],
			},
		],
	},
}
```

对应表格：

| id | name | kind | amount |
| --- | --- | --- | --- |
| 1 | Pulse | Damage | 12 |
| | | Damage | 8 |
| 2 | Burst | Damage | 30 |

第一条记录产生两个 `effects` 元素。集合里的 `kind` 是普通字段，由多态类型定义选择具体结构。空单元格表示缺失，不自动创建额外 `null` 字段；需要显式空字符串时可设置非空的 `layout.empty_string_token`。

## 布局规则

- `orientation` 为 `rows`（默认）或 `columns`；后者按列组织记录，诊断仍保留转置前的真实单元格。
- `header_rows` 指定一个或多个逻辑表头行。多层表头可以组成字段路径；显式 `columns` 绑定优先。字段名中的点号不会被偷偷解释成路径分隔符。
- `path` 使用字符串键和整数下标组成的段数组。标量集合元素使用空路径 `[]`；禁止重复绑定、数组空洞和标量/容器冲突。
- `record_key_column` 启用连续记录分组；同键或空键延续当前记录，首行空键和非连续重现的记录键失败。续行重复标量必须一致，防止后写覆盖。
- `collections` 支持 `array` 和 `map`。映射额外设置 `key_column`，重复键失败；没有元素内容的行不追加空对象。
- 未绑定且非空的列失败；明确不参与数据的列放入 `ignored_columns`。全空数据行默认拒绝，可显式设置 `blank_rows: "skip"`。
- XLSX 合并单元格仅在表头区展开。数据区合并不猜测填充值；公式仍使用文件中已保存的缓存值。
- `parse_options.sheet_names` 按明确顺序合并多个工作表；每张表独立分组，不跨 sheet 延续记录。任一 sheet 失败则整表失败，唯一性和跨表引用仍由后续校验处理。

物理来源和逻辑路径一起进入校验报告。结构化布局与普通布局共享输入、节点、深度和工作量预算；工作台的预览限制继续适用。
