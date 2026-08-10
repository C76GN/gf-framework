# API Reference

本区由源码 API 注释生成，作为当前可寻址 `class_name` owner、成员签名和机器标签的完整参考。正文指南负责解释概念、边界和工作流；这里负责精确检索。

已知边界：classless `Gf` AutoLoad 是公开入口，但当前 Catalog schema 尚未决定如何表达 singleton owner，因此暂不计入下列统计；生成器会显式锁定这一项，并拒绝任何新增 classless public surface 静默进入同一缺口。

## 范围

- 源码根目录：`addons/gf`
- 公开类：`813`
- 公开成员：`12043`
- 公开方法：`7428`

## 模块

| 模块 | 类 | 成员 | 方法 | 页面 |
|---|---:|---:|---:|---|
| Kernel | 74 | 1108 | 799 | [kernel.md](kernel.md) |
| Standard | 454 | 7272 | 4593 | [standard.md](standard.md) |
| Action Queue | 16 | 214 | 136 | [extensions-action-queue.md](extensions-action-queue.md) |
| Asset Metadata | 4 | 33 | 24 | [extensions-asset-metadata.md](extensions-asset-metadata.md) |
| Behavior Tree | 22 | 89 | 65 | [extensions-behavior-tree.md](extensions-behavior-tree.md) |
| Camera | 7 | 130 | 43 | [extensions-camera.md](extensions-camera.md) |
| Capability | 11 | 148 | 103 | [extensions-capability.md](extensions-capability.md) |
| Combat | 51 | 609 | 261 | [extensions-combat.md](extensions-combat.md) |
| Extensions / Content Package | 7 | 109 | 71 | [extensions-content-package.md](extensions-content-package.md) |
| Decision | 8 | 111 | 62 | [extensions-decision.md](extensions-decision.md) |
| Dialogue | 5 | 75 | 36 | [extensions-dialogue.md](extensions-dialogue.md) |
| Domain | 18 | 295 | 185 | [extensions-domain.md](extensions-domain.md) |
| Feedback | 8 | 141 | 65 | [extensions-feedback.md](extensions-feedback.md) |
| Flow | 7 | 138 | 84 | [extensions-flow.md](extensions-flow.md) |
| Interaction | 6 | 82 | 29 | [extensions-interaction.md](extensions-interaction.md) |
| Network | 38 | 602 | 323 | [extensions-network.md](extensions-network.md) |
| Physics | 4 | 50 | 23 | [extensions-physics.md](extensions-physics.md) |
| Save | 52 | 651 | 414 | [extensions-save.md](extensions-save.md) |
| Turn Based | 4 | 49 | 24 | [extensions-turn-based.md](extensions-turn-based.md) |
| Tool Packages | 17 | 137 | 88 | [tools.md](tools.md) |

## 类索引

完整类索引独立生成在 [classes/index.md](classes/index.md)，单类页面可从模块索引或类索引进入。
