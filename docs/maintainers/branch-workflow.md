# 分支与发布流程

`main` 是默认分支，只接收正式大版本和兼容补丁。`develop` 始终面向下一大版本。两条分支独立演进，通过 PR、最新目标分支检查、`GF repository policy` 和 `GF merge gate` 保护合并。`main` 保持线性历史。

## 日常开发和稳定补丁

| 变更 | 短分支基线 | PR 目标 | 分支示例 |
| --- | --- | --- | --- |
| 新能力、重构、开发线修复 | 最新 `develop` | `develop` | `fix/save-rollback` |
| 稳定版兼容修复 | 当前正式 tag | `main` | `hotfix/12.0.2` |
| 大版本发布 | 最新 `develop`，在发布分支纳入当前 `main` | `main` | `release/13.0.0` |
| 开启下一大版本 | 最新 `develop` | `develop` | `chore/start-14.0.0` |

同一个 bug 影响两条线时，从各自基线分别提 PR 和验证。稳定线按当前正式版的 API、数据及行为契约修复。开发线按下一大版本的设计修复，需要迁移的改动补齐升级说明。补丁发布后，开发线继续使用当前开发版本和 API 基线。

## API 基线

开发线在 `.github/repository-policy.json` 的 `development_api_baseline` 固定本周期的稳定 tag 和完整提交 SHA。`13.0.0-dev.*` 使用 `12.0.0`。开发检查验证 annotated tag 指向配置中的提交，支持该提交位于独立的稳定线，并在整个周期使用同一版本比较。

稳定补丁和大版本候选与当前最新正式版比较。发布 PR 门禁显式选用 `main` 上已发布的基线。例如，在已纳入 `main` 的 `release/13.0.0` 分支上，当前正式版本为 `12.0.1` 时执行：

```powershell
python tools/gf_maintenance.py api-baseline-diff --version 13.0.0 --base-tag 12.0.1 --enforce-version --json
```

## 提升大版本

1. 从最新 `develop` 创建内部 `release/<version>` 分支。在该短分支合并当前 `main`，使候选包含两条分支的最新提交。逐项复核稳定线独有的补丁，确认新版本中的实现或写明有意的迁移变化。
2. 完成正式版本元数据、升级说明和 [发布检查](../../.codex/skills/gf-release-flow/references/release-checks.md)。最后一次 Ready Full 前暂停两条线的其他合并，并取消可能触发的自动合并。合并前重新核对候选包含两条分支的最新提交。任一基线前移时更新候选并重新验证。
3. 通过 PR squash 合入 `main`。在该提交上等待 Full CI、构建并验证发行物，再推送不带 `v` 的 annotated tag。核对 GitHub Release 与 tag。
4. 正式发布完成后，从最新 `develop` 提交 `chore/start-<下一大版本>` PR。将开发版本推进到 `<下一大版本>-dev.0`，用唯一的 `[未发布]` 段开启 changelog，并把 `development_api_baseline` 改为实际发布的 tag 和完整提交 SHA。通过该 PR 落地新周期元数据后恢复日常合并。

## 发布失败后的恢复

- 打 tag 前发现候选问题，从当前 `main` 开 `release/<当前候选版本>` 修复 PR，重新运行 Full 和发行物预检。
- 发布工作流遇到临时设施故障时，在同一 tag 重试。
- tag 已推送且 GitHub Release 尚未正式发布时，如需修源码，通过 `release/<下一补丁号>` 修正。将未正式发布的 tag 和完整提交 SHA 记录到 `abandoned_release_tags`，继续以上一个正式版为发布比较基线。大版本开发周期切换使用最终成功发布的 tag。

## 分支保护审计

运行 `python tools/gf_repository_policy.py protection --include-develop --json` 核对两条分支。写入保护前，先确认检查绑定 GitHub Actions App `15368`，再取得维护者对 `--apply` 的明确授权。发生部分写入时，通过 `completed_mutations` 核对已完成的步骤。
