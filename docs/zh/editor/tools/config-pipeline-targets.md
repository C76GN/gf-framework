# 配置目标与变更管理

[Config Pipeline](config-pipeline.md) 的目标隔离、身份登记与提交校验。

## 消费目标与字段边界

各目标的数据库和访问器路径共用写入器的 URI 规范化，并按忽略大小写的可移植身份检查冲突。首尾空白、点段或大小写别名不能形成独立产物；本次显式路径覆盖也不能占用其他目标或另一种产物的路径。

Profile 的 `consumer_targets` 可声明最多64个 `GFConfigPipelineConsumerTarget`。每个目标给出唯一 `target_id`、根表 `root_tables`、每表可见字段 `visible_fields`，以及独立的数据库和可选访问器输出路径。声明目标后必须选择一个：工作台的消费目标下拉框、CLI 的 `--target`，或 Profile 的 `default_consumer_target`。没有声明消费目标的 Profile 继续构建完整数据库。

```gdscript
var client := GFConfigPipelineConsumerTarget.new()
client.target_id = &"client"
client.root_tables = ["items"]
client.visible_fields = {
    "items": ["id", "name", "category_id"],
    "categories": ["id", "label"],
}
client.output_path = "res://generated/config/client.tres"
profile.consumer_targets = [client]
profile.default_consumer_target = &"client"
```

目标资源属于项目作者声明，可在 Inspector 或项目脚本中编辑。每个可见字段是一个**完整顶层值单元**：结构、数组、映射、多态等类型和值共同保留；这里没有嵌套路径过滤或通配符。需要分离的客户端与服务端数据应在作者 schema 中分成独立字段。未列出的字段、未声明的表默认不可见。

引用闭包由 schema 的引用声明计算，与当前行数、空数组或实际引用值无关。引用来源字段全部隐藏时，该引用不进入目标；复合引用只有部分来源字段可见、引用目标未授权，或目标键不可见时直接失败。必要的 ID 字段必须显式授权，闭包不会替项目扩大字段权限。样本推导 schema 不能作为消费目标授权依据，使用显式 schema 或类型表头声明。

源 IR 先执行作者规则。投影保留可见字段的完整类型与字段规则，移除不再完整的索引、隐藏引用及原始表级元数据；整记录/整表规则不复制到已裁剪 schema。目标始终重新执行跨表引用校验，即使调用方关闭普通数据库验证。IR 已有 schema 与来源定位证据，因此这一步复用原 IR，不增加另一套作者格式。

## 稳定 ID 登记

`GFConfigStableIDRegistry` 维护项目声明的身份与数字 ID 映射及删除墓碑。登记源属于项目；
流水线先验收封闭记录和唯一性，再将新登记与产物一起提交。读取、预览和差异比较不分配 ID。

需要数字 ID 稳定性的表可选用 `stable_id_registry_path` 与 `stable_id_bindings`：

```gdscript
profile.stable_id_registry_path = "res://config/ids.json"
profile.stable_id_bindings = {
    "items": {"symbol_field": "symbol", "id_field": "id"},
}
```

作者记录明确提供符号和1至2147483647的整数 ID；GF 不自动分配 ID，也不修改表格。表名形成独立登记命名空间。登记使用完整作者数据，不受当前消费目标隐藏 `symbol` 或其他表的影响；未启用登记的表仍可使用字符串等 ID。

`build`、`inspect`、`diff` 和 `--dry-run` 只读，登记变化列在报告中。新增符号或删除符号后，普通导出会拒绝待登记变化；使用 `--operation register-ids` 或工作台 **登记 ID 并导出**，才把登记簿、数据库、访问器和 manifest 放入同一个既有文件事务。失败回滚整批产物；事务恢复要求仍以报告为准。

删除产生历史占号记录：原 ID 不能交给其他符号，已登记符号也不能改号。临时停止售卖时，可以保留作者行，用项目自己的可用状态控制业务；确实移除作者行后需要让原身份回归时，必须显式声明恢复。

### 对账范围

`stable_id_scope_tables` 默认是空数组，保留**整簿全量对账**：登记簿中没有出现在本次绑定作者数据里的活动符号都会退役，遗漏整张表也一样。多个模块不能在这个默认模式下分别构建后轮流覆盖同一登记簿。

共用登记簿时，明确列出本次负责的表：

```gdscript
profile.stable_id_scope_tables = ["items"]
profile.stable_id_bindings = {
    "items": {"symbol_field": "symbol", "id_field": "id"},
}
```

非空范围必须与 `stable_id_bindings` 的表集合完全一致：该范围内仍按完整作者表对账，没出现的符号退役；范围外历史表保持不变。不能靠漏写某个范围内的表来表示删除。整张表退役时，绑定一张保留 schema、没有数据行的作者表；直接使用 Registry 时显式传入 `{"items": {}}`，同时给出 `scope_tables: ["items"]`。

### 恢复原身份

```gdscript
profile.stable_id_restorations = {
    "items": {"potion": "1"},
}
```

这明确表示“恢复历史上的 `items/potion/1`”，不是把 `1` 分给新内容。作者表必须重新提供 `symbol = "potion"` 和整数 `id = 1`；恢复声明中的 ID 则采用登记簿同样的**规范十进制字符串**。`"01"`、`"+1"`、`"1.0"`、数字 `1`、其他符号或不同 ID 都不能作为恢复声明。字符串形式也避免工作台 JSON 编辑把 ID 变成浮点数。

成功预览列出 `kind = "restore"`。正常导出仍会拒绝待登记变化，必须通过 **登记 ID 并导出** 或 `--operation register-ids` 与产物同事务提交。重复保留同一恢复声明时，已经活动的原身份不再产生变化，便于重复构建；之后删除该作者行前，应移除相应恢复声明，否则声明与作者映射不一致会失败。

直接调用 `GFConfigStableIDRegistry.preview(assignments, options)` 或 `with_assignments(assignments, options)` 时，`assignments` 的 ID 严格为整数，`options.restorations` 的 ID 严格为上述字符串；`options.scope_tables` 省略或为空都保留整簿语义。预览失败返回 `success = false` 且没有部分变化，构造失败返回 `null`，原登记簿不变。

范围和恢复声明属于保存的 Profile，工作台、CLI 与 Runner 使用同一份配置；它们进入预览输入摘要和构建指纹。修改任一声明后，旧 `expected_input_digest` 不能用于提交，须重新预览。`to_record()` / `from_record()` 只负责记录导入导出，不替代带历史校验的恢复流程。

登记簿由项目纳入版本管理，不能通过删文件“重置”历史。JSON 中 ID 保存为规范十进制文本，读取时严格验证。上限为4096个表命名空间、65536个历史条目及8MiB；活动与退役项都计入预算。恢复不分配新 ID、不释放旧占号，也不提供符号重命名或跨内容复用。

## 差异预览与提交新鲜度

工作台填写 **差异基线 Profile** 后点击 **比较作者变化**。CLI 使用 `--operation diff --baseline-profile res://baseline/build.tres`；基线可来自项目保存的旧版作者文件或独立版本检出。两边均通过同一 GDScript 构建链，适用于 CSV、JSON、ConfigFile 和 XLSX 来源，不依赖导出文件格式。缺失基线明确失败，不伪装成“没有变化”。

报告列出 schema 变化、按稳定 ID 的记录增删、修改字段名和两代引用声明的保守影响闭包，不输出原始业务值。记录顺序变化不会被当作身份变化；没有唯一稳定 ID 或无法完整摘要的值显示 `unknown`。受影响目标是保守上界，不能代替项目业务判断。超出共享工作预算时整次比较失败，不交付部分成功报告。

成功差异报告的 `input_capture.digest`，以及预览导出报告中 `build_result.input_capture.digest`，可传给正式导出的 `--expected-input-digest`。工作台在成功只读操作后自动保留凭据；外部来源、Profile 依赖或登记簿变化后，必须重新预览。CLI 不传该参数时表示构建并提交当前输入，不代表批准过某次旧预览。

输入凭据完整编码内存声明，保留值类型且不因字典插入顺序改变；不会采用诊断报告的集合截断结果。每次声明摘要限制为深度 64、65536 个值和 4 MiB 规范编码字节；超限或包含无法编码的对象等值时，`capture_inputs()` 返回失败与空 `digest`，不能用于批准导出。更新到这一实现后，已有预览凭据需要重新生成。

正式导出在构建前、文件事务前和事务完成前复核作者输入，登记簿自己的写入单独匹配候选摘要。输入变化导致拒绝或整批回滚。文件事务沿用现有工作区独占写入前提，不提供跨进程数据库锁；项目构建与外部编辑应避免同时写同一登记簿或产物。校验、摘要和差异处理是有预算的同步制作期操作，不承诺帧耗时。
