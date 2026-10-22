# Domain 文档

工程技能应如何消费本仓库的领域文档。本仓库把词汇与决策记录放在自己的位置,因此请阅读这些内容,而不是寻找 `CONTEXT.md` 或 `docs/adr/`。

## 探索之前先读

- **`docs/glossary.md`** — 规范领域词汇。每个概念只保留一个规范术语,各条目通过锚点互链。先读你将要工作区域的条目;在改动 `packages/` 之前,先读 `capability-seam`、`agent-scope` 和 `loop-hierarchy` 条目。
- **`docs/architecture.md`** — 按顺序组织的组合、核心包、循环、seam 与扩展点地图。`AGENTS.md` 要求在改动 `packages/` 之前阅读它。
- **`.agents/notes/`** — 决策记录。生命周期与类别都编码在路径中,形式为 `{lifecycle}/{class}/yyyy-mm-dd-topic-title.md`。
  - `proposed/` — 实现前评审的提案,尚未构建。
  - `implemented/` — 已发布的决策,随实际发布内容保持同步。
  - `rejected/` — 已考虑并拒绝;仅在需要避免重复提出已定论错误时阅读。
  - `archived/` — 冻结的历史。**永远不要把它当作当前权威。**
- **`docs/AGENTS.md`** — 文档标准、层级分类与字数预算。写任何文档之前先读它。

如果其中某项缺失,静默继续。不要标记其缺失,也不要建议创建 `CONTEXT.md` 或 `docs/adr/` — 上述位置已经承担了这些角色,并且本仓库强制「一个事实一个家」。

## 使用词汇表的术语

当你的输出要命名某个领域概念时 —— 在 issue 标题、重构提案、假设、测试名称中 —— 使用 `docs/glossary.md` 定义的术语。不要滑向条目明确避免的同义词:capability seam 是完整能力,绝不是它的某个角色,因此请用角色、类、服务、contract 或扩展点来命名其组成部分。

如果你需要的概念不在词汇表中,这是一个信号:要么你在发明项目不使用的语言(重新考虑),要么存在真实缺口(记录下来交给 `/domain-modeling`)。

## 标记决策记录冲突

如果你的输出与某个 implemented Agent Note 相矛盾,请明确提出来,而不是静默覆盖:

> _与 [统一 GitHub 标签体系](../../.agents/notes/implemented/process/2026-08-08-unified-github-label-taxonomy.md) 矛盾,但值得重新讨论,因为……_

记录在 `proposed/` note 中的决策尚不具约束力。`archived/` 中的决策在任何方向上都无权威 —— 它只是历史。
