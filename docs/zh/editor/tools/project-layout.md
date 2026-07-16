# Project Layout 项目结构工具包

`gf.tool.project_layout` 是可选工具包，用于把项目目录结构、命名规则、生成物边界和 Feature 模块契约写成可校验的 profile。它不属于运行时扩展，不要求项目必须采用某个业务目录，也不把项目规则反向写死进 GF 内核或标准库。

GF 推荐以“内聚式 Feature 模块”为默认路线：一个业务能力的脚本、场景、资源、测试、文档和局部工具优先放在同一个 Feature 根目录下。只有确实跨 Feature 复用的内容才进入 `shared`，只有应用装配和入口逻辑才进入 `app`。

## 推荐结构

```text
res://
  app/
    scenes/
    scripts/
  features/
    inventory/
      scripts/
      scenes/
      resources/
      tests/
    combat/
      scripts/
      scenes/
      resources/
      tests/
  shared/
    scripts/
    resources/
  generated/
  tests/
  tools/
  gf_project_profile.json
```

这套结构的重点不是目录名本身，而是边界语义：

- `app`：项目入口、场景装配、启动流程和跨 Feature 编排。
- `features/<feature_id>`：单个业务能力的内聚边界，禁止把脚本、场景和资源分散到全局大桶后再靠命名关联。
- `shared`：明确跨 Feature 复用的通用能力，避免成为业务逻辑倾倒区。
- `generated`：生成文件和可再生中间产物，防止和手写文件混在一起。
- `tests`：项目测试、契约测试和 smoke 场景。
- `tools`：项目自有编辑器期、导入期、构建期工具。

## Profile 模板

工具包提供模板：

```text
res://addons/gf/tools/project_layout/profiles/feature_cohesive_v1.json
```

项目可以把它复制为：

```text
res://gf_project_profile.json
```

然后按项目需要调整 `roots`、`allowed_subdirs`、`allowed_files`、`max_files` 和严重级别。模板只是起点，不应该为了符合模板而制造空目录或迁移没有收益的文件。

## 脚手架

`GFProjectLayoutScaffolder` 可以按 profile 创建必需目录，并可选创建 Feature 模块目录。它默认只创建 profile 中标记为 `required` 的 zone；`shared`、`generated`、`tests` 这类可选目录需要显式启用，避免空目录变成新的维护负担。执行前会校验 profile 结构、Feature ID、计划路径和回滚路径；实际创建中途失败时，会尝试撤销本次已经创建的目录，避免留下半成品脚手架。

```gdscript
var scaffolder: GFProjectLayoutScaffolder = GFProjectLayoutScaffolder.new()
var result: Dictionary = scaffolder.scaffold_default_profile({
	"root_path": "res://",
	"feature_ids": PackedStringArray(["inventory", "combat"]),
	"dry_run": true,
})
```

确认 `result.created_paths` 和 `result.issues` 后，把 `dry_run` 改为 `false` 或移除该字段即可实际创建目录。需要为全新项目一次性创建可选根目录时，可以传入：

```gdscript
{
	"include_optional_zones": true,
	"include_optional_feature_subdirs": true,
}
```

脚手架只做目录创建和 Feature ID 校验，不移动已有文件、不改写 `project.godot`，也不会把某个参考项目的目录强制套给所有项目。迁移旧项目时，应先用 `project-profile-boundary` 看报告，再分 Feature 小步搬迁。

## 本地校验器

`GFProjectLayoutValidator` 可在 Godot 内直接读取同一份 profile，输出项目结构校验报告。它适合编辑器按钮、项目自测、CI smoke 或迁移脚本在不调用 Python 维护工具时复用目录规则。Validator 会严格校验规则类型、严重级别、扫描根和深度预算；未知规则或非法严重级别会进入报告，而不是被静默忽略。

```gdscript
var validator: GFProjectLayoutValidator = GFProjectLayoutValidator.new()
var result: Dictionary = validator.validate_default_profile({
	"root_path": "res://",
})
```

报告包含 `success`、`issues`、`error_count`、`warning_count`、`file_count`、`directory_count` 和逐条 `rule_results`。内置 validator 覆盖必需 zone、根目录文件白名单、路径命名、Feature 模块契约、生成物边界和大桶目录上限。更复杂的项目级 profile gate 仍可使用 `project-profile-boundary`，两者共享“profile 是项目侧策略、GF 只提供通用机制”的边界。

## 校验规则

`project-profile-boundary` 支持这些通用规则：

- `path_exists`：要求关键路径存在。
- `files_under_roots`：要求匹配文件落在指定根目录。
- `extension_allowlist` / `extension_denylist`：按目录限制扩展名。
- `forbid_root_files`：根目录文件必须显式列入白名单。
- `naming_convention`：用正则约束路径、文件名或文件名 stem。
- `feature_module_contract`：约束 Feature 模块 ID、必需子目录、允许子目录，以及是否允许模块根目录直接放文件。
- `generated_boundary`：要求生成物留在声明的生成目录。
- `bucket_size`：给遗留大桶目录设置文件数量上限，防止继续膨胀。

维护仓库或 CI 可以运行：

```powershell
python tools\gf_maintenance.py project-profile-boundary --profile gf_project_profile.json --json
```

没有 profile 时检查会通过；使用非默认路径时显式传 `--profile`。

## 设计取舍

GF 不默认采用镜像式 `scripts/`、`scenes/`、`resources/` 全局分离作为主路线。镜像式结构适合小项目或强工具约束项目，但在业务增长后容易让一个 Feature 横跨多个目录，改动审查和模块迁移成本更高。

内聚式结构把业务边界放在第一层，适合长期演进、模块拆分、按 Feature 做测试和资源归属审查。它的风险是 `features` 内部可能变得不一致，所以需要 profile 把 Feature ID、允许子目录、生成物边界和命名约定固定下来。

最佳实践是把项目结构规则作为项目侧 profile 管理：GF 提供通用 validator 和模板，项目保留调整权。
