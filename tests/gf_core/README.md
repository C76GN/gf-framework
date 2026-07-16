# GF Core Tests

GUT tests mirror the framework source layers:

- `maintenance`: static checks for API comments, source layout, and generated-code conventions.
- `kernel`: core architecture, base contracts, editor helpers, and extension infrastructure.
- `standard`: foundation, input, utilities, sequence, command, and state-machine tests.
- `extensions`: tests for optional GF extensions, grouped by extension ID.
- `fixtures`: shared scenes, installers, and small scripts used by multiple tests.

Run all tests with:

```powershell
python tools\gf_maintenance.py check --check gut --failed-only
```

该入口会先导入干净项目，再运行 GUT，并校验 Godot 日志与整套测试通过摘要。
