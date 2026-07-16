# 结构校验与实体恢复

项目可以继承 `GFSaveSource` 或注册自定义 `GFNodeSerializer`，也可以在需要补建实体时注册 `GFSaveEntityFactory`。默认能力提供 Transform、CanvasItem、Control、Range 等通用节点状态片段，并可通过 `GFSavePipelineStep` 在采集/应用前后插入校验、版本适配或调试标记。

## Scope 与 Payload 校验

`inspect_scope()` / `validate_payload_for_scope()` 用于开发期提前发现重复 key、缺失目标或载荷不匹配。报告会包含 `healthy`、`error_count`、`warning_count`、`summary` 与 `next_action`，便于编辑器面板、CI 或测试直接消费。

这两个接口属于结构诊断，只读取 `scope_key`、`source_key`、启用开关、阶段和目标路径等导出属性，不执行项目自定义 `get_scope_key()`、`can_save_scope()`、`get_source_key()` 或 `get_target_node()` 方法。

`load_scope()` 从存储读取后会先校验载荷格式与当前 Scope 树，不会把明显不匹配的文件继续应用。`validate_payload_for_scope()` 和 `apply_scope()` 都会拒绝非 Dictionary 的 `scope` descriptor、`sources`、`scopes`、子 Scope 载荷、Source entry、Source descriptor、Source `data` 和 Serializer `data`，把结构错误写入结果而不是继续应用，并清理本次事务使用的临时实体上下文。

## 实体恢复与事务

若 `GFSaveScope.restore_policy` 允许工厂恢复，工厂创建出的实体必须自身就是 `GFSaveSource`，或子树中能找到 `GFSaveSource`；否则该实体会被释放，不会残留在场景树中。恢复出的 Source 会被对齐并校验到 payload source key；无法对齐时立即释放并按缺失处理。`after_entity_created()` 返回后实体和 Source 仍必须有效；如果 Hook 删除了刚创建的节点，本次 Source 会按缺失处理。

默认 `transactional_apply = true` 时，本次应用中新建的工厂实体会在后续 Source 或子 Scope 应用失败时回滚释放，避免读档一半失败后留下半恢复场景。

`gather_scope()` 遇到重复 Source key、重复子 Scope key 或子 Scope 采集失败时会整体返回空载荷，并把错误写入共享的 `GFSavePipelineContext`，避免生成缺失子树的部分存档。

## 编辑器诊断

插件菜单 `工具 > GF > 校验当前场景 SaveGraph` 与 `GF Workspace > Save` 页面会扫描当前编辑场景里的 `GFSaveScope` 并展示同一套健康报告。刷新健康报告不要求项目自定义 SaveScope/SaveSource 脚本声明 `@tool`。

工作区页面还可以按需采集预览 payload 和 pipeline trace。预览载荷会执行实际采集逻辑；如果项目希望在编辑器中运行自定义保存代码，应让对应脚本安全支持 `@tool`。
