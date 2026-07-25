# GF Core Tests

GUT tests mirror the framework source layers:

- `maintenance`: static checks for API comments, source layout, and generated-code conventions.
- `kernel`: core architecture, base contracts, editor helpers, and extension infrastructure.
- `standard`: foundation, input, utilities, sequence, command, and state-machine tests.
- `extensions`: tests for optional GF extensions, grouped by extension ID.
- `fixtures`: shared scenes, installers, and small scripts used by multiple tests.
- `support`: lifecycle scopes and GUT run hooks shared by the full suite.

Run all tests with:

```powershell
python tools\gf_maintenance.py check --check gut --failed-only
```

该入口会先导入干净项目，再运行 GUT，并校验 Godot 日志、整套测试通过摘要与
`GF_TEST_LIFECYCLE_GATE` 结构化结果。未由 GUT warning 断言消费的
`push_warning`、新增 orphan Node 或 Godot 退出期泄漏都会让检查失败。

需要管理多项延迟清理时，使用
`res://tests/gf_core/support/gf_test_lifecycle_scope.gd` 注册 LIFO cleanup，并在
`after_each()` 中 `await scope.assert_clean(self)`；不要通过清空 error tracker、
隐藏 orphan 输出或保留强引用来绕过生命周期断言。
