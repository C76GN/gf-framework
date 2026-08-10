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

`tests/gf_core/**/test_*.py` 必须各自只有一个 `CHECK_DEFINITIONS` 命名 owner，且该
owner 必须能从受治理 suite 到达；空测试模块同样失败。该规则由
`test_gf_maintenance_test_evidence.py` 锁定，不能把 tracked 测试文件的存在误当作执行证据。

需要验证目录链接边界的 GUT 必须复用
`res://tests/gf_core/support/gf_test_directory_link_fixture.gd`：Windows 建立普通账户可用的
directory junction，POSIX 建立 symlink；强制夹具创建失败必须让当前测试失败，不能 pending
或提前形成绿色空测。

需要管理多项延迟清理时，使用
`res://tests/gf_core/support/gf_test_lifecycle_scope.gd` 注册 LIFO cleanup，并在
`after_each()` 中 `await scope.assert_clean(self)`；不要通过清空 error tracker、
隐藏 orphan 输出或保留强引用来绕过生命周期断言。
