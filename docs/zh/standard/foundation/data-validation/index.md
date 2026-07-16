# Foundation 数据流程与校验总览

这一组 Foundation 能力覆盖标签查询、黑板字段契约、通用 Dictionary schema、预算账本、集合索引、时间文本、公式、Variant 转换、通用标识、校验报告和轻量结果字典。它们只提供可复用的数据原语，不绑定运行时容器、编辑器 UI、业务字段或项目规则。

## 阅读入口

- [标签、黑板与数据契约](tags-blackboard/index.md)：标签集合、标签查询、可选标签目录、标签表达式、标签来源适配和黑板 Schema。
- [通用 Dictionary Schema](schema-primitives.md)：`GFSchemaField`、`GFDictionarySchema` 的字段声明、默认值、类型转换、嵌套字典和数组元素校验。
- [预算、集合与时间文本](budget-collections-timeline/index.md)：预算账本、值索引、变更批次和时间段文本轨道。
- [公式与 Variant 数据](formula-variant/index.md)：资源化公式、公式参数、公式集合、Variant 深拷贝、显式数据投影和 JSON 兼容转换。
- [通用标识](identity/index.md)：`GFUuid` 的 UUID v4/v7 生成与 canonical 字符串校验。
- [校验报告、策略与结果字典](validation-reporting/index.md)：来源位置、校验问题、校验报告、兼容性预检、artifact 新鲜度、安全文本生成上下文、通用策略注册表、规则套件、Runner、JUnit 导出和轻量结果字典。

## 使用边界

- 这些类型可以被 Kernel、Utilities、扩展和项目代码共同依赖。
- 它们不读取 ProjectSettings，不直接访问场景树，也不假设某个游戏类型的业务语义。
- 需要生命周期、缓存、异步任务、Inspector 控件或导入器 UI 时，应在 Utility、扩展或项目层组合这些基础件。
- 需要具体领域模型时，优先查看 [Domain](../../../extensions/domain/index.md) 或项目自己的数据层。

## API Reference

完整类、方法和信号列表见 [Standard API Reference](../../../reference/api/standard.md)。
