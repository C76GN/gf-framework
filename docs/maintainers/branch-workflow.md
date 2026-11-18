# 分支与发布流程

`main` 是 GitHub 默认分支，承载稳定版本。`develop` 承载下一大版本。日常工作从 `develop` 开短分支，经 PR 合入。稳定端与开发端共用 Draft Quick 和 Ready Full 规则，两条长期分支均要求 PR、最新目标分支和 GitHub Actions 的两个必需检查。`main` 使用线性历史。`develop` 允许通过合并提交接收正式发布提交。

## 从 12.0.0 切换

1. 先按现有流程将分支规则和 CI 合入 `main`。这时普通 PR 仍指向 `main`，版本为 `12.0.0-dev.*`。
2. 从最新 `main` 开 `release/12.0.0`，更新正式版本元数据并提交 PR。Ready Full 通过后 squash 合入。此时进入发布窗口，暂停普通合并。
3. 等合入后的 `main` Full CI 成功。在该提交完成发行物预检，再推送不带 `v` 的 annotated tag。等 Release workflow 完成，并验证正式 GitHub Release 与该 tag。
4. 从 `12.0.0` tag 指向的提交创建远端 `develop`。等待该分支第一次 push 的 Full CI 通过，应用双分支保护。保护检查完成前先暂缓合并。
5. 从 `develop` 开 `chore/start-13.0.0` PR，将框架与内置扩展版本同步到 `13.0.0-dev.0`，将当前 changelog 开为唯一的 `[未发布]` 段。合入后，日常 PR 转向 `develop`。仍在进行的 PR 以 `develop` 更新基线，再改目标并等待新的 Ready Full。

开启新一轮开发时，未发布段仍需包含版本概述和一个有效的非空分类。若眼下没有待发布的行为变化，在升级指南中说明已安装的稳定版仍可使用，下一大版本的升级说明将在有实际变更时补充。第一条实际变更进入后更新这段说明。

在首次保护前，先检查远端还没有 `develop`。使用能触发 Actions 的维护者身份推送分支。

```powershell
git fetch origin --tags
git ls-remote --heads origin refs/heads/develop
$releaseCommit = git rev-parse 'refs/tags/12.0.0^{commit}'
git push origin "${releaseCommit}:refs/heads/develop"
```

先在 Actions 确认 `develop` 自己的 push run 成功。初始 SHA 与 `main` 相同也要等这次运行。使用具备 Administration、Actions、Checks 和 Contents 所需权限的令牌审计。只有得到维护者明确授权时才执行写入。

```powershell
python tools/gf_repository_policy.py protection --include-develop --json
python tools/gf_repository_policy.py protection --include-develop --apply --json
```

写入前预检两条分支当前 SHA 上由 GitHub Actions App `15368` 提供的必需检查，并确认当前正式 tag 和 `develop` 的 push CI。先核对两条分支保护，再启用仓库的合并提交选项。发生部分写入时查看 `completed_mutations`，重新审计后再应用。

## 日常修复和版本发布

假设当前正式版本是 `12.0.0`，`develop` 的目标始终是 `13.0.0-dev.*`。

| 变更 | 开分支的基线 | PR 目标 | 版本 |
| --- | --- | --- | --- |
| 新能力、重构和开发线修复 | `develop` | `develop` | `13.0.0-dev.*` |
| 稳定版兼容修复 | 已发布的 `12.0.0` tag | `main` | `hotfix/12.0.1` |
| 大版本发布 | 已同步的 `develop` 最新提交 | `main` | `release/13.0.0` |
| 发布回流 | `develop`，合并实际打 tag 的 `main` 提交 | `develop` | `sync/12.0.1` 或 `sync/13.0.0` |

两条线需要同一修复时，可以先在稳定线做最小兼容修复，发布后随回流进入开发线。若两边实现已经分化，分别验证各自的行为与兼容性，在回流 PR 里解决冲突。开发线可以采用需要迁移的设计，并补齐迁移说明。只有稳定线的用户也受影响时，才准备兼容补丁。

## 发布窗口和回流

1. 在发布候选最后一次 Ready Full 前冻结两条线的其他合并，并取消可能在窗口内触发的自动合并。GitHub 的严格检查追踪 PR 自己的目标分支，另一条分支移动时，之前通过的检查可能仍显示为绿。切换后的大版本在合入前再次确认候选包含最新 `develop` 提交。兼容补丁基于当前正式 tag。若任一基线前移，更新候选并等新的 Ready Full。
2. 根据 [发布检查](../../.codex/skills/gf-release-flow/references/release-checks.md) 验证候选。将发布 PR squash 合入 `main`，等该提交 Full CI 成功，随后在这个提交上打 tag 并发布。tag 和 GitHub Release 均完成后再回流。
3. 从最新 `develop` 创建 `sync/<version>`，用 `git merge --no-ff` 合并已发布 tag 指向的提交。保留开发线的未发布说明及适用的开发元数据。补丁回流保持下一大版本。大版本回流在同一个 PR 中推进目标，例如发布 `13.0.0` 后改为 `14.0.0-dev.0`。
4. 确认回流 PR 包含当前正式发布的 `main` 提交，等 Ready Full 通过后在 GitHub 选 **Create a merge commit**。等待 `develop` push CI 确认正式发布提交仍可从分支到达，再恢复普通开发。API 基线依赖历史可达的稳定 tag，squash 和 rebase 会丢掉回流需要的祖先关系。若误选，保持发布窗口并重新提真正包含正式提交的回流 PR。

## 发布失败后的恢复

- 打 tag 前若发行物预检发现问题，从当前 `main` 开 `release/<当前候选版本>` 修复 PR，重新跑 Full 和发行物预检。
- 若发布工作流因临时设施故障失败，在同一 tag 重试。
- 若 tag 已推送、GitHub Release 尚未正式发布且必须修源码，停止该 tag 的发布重试并保留失败证据。在 `release/<下一补丁号>` PR 中修正源码和版本元数据，同时在 `.github/repository-policy.json` 的 `abandoned_release_tags` 记录失败版本与它指向的完整 `main` SHA。CI 核对失败 tag 确实指向当前候选并且尚未正式发布，随后按上一个可用稳定 tag 校验 API。兼容性和迁移说明仍以消费者上一正式版为准。
- 例如 `12.0.0` 的发布失败且必须改源码时，可发布修正后的 `12.0.1` 来完成切换。从实际成功发布的 tag 创建 `develop`，目标仍为 `13.0.0-dev.0`。后续大版本出现同类问题也按实际成功发布的 tag 回流。
