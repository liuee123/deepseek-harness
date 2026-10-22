# Issue tracker: 本地 Markdown

本仓库的 issue 与 spec 以 Markdown 文件形式存放在 `.scratch/` 下。本地不使用远端 tracker;仓库的 GitHub Issues 及其 `kind/*`、`area/*`、`source/*` 标签策略服务于 pull request,不用于本工作流。

## 约定

- 一个 feature 一个目录:`.scratch/<feature-slug>/`
- spec 文件为 `.scratch/<feature-slug>/spec.md`
- 实现 issue 一个 ticket 一个文件:`.scratch/<feature-slug>/issues/<NN>-<slug>.md`,从 `01` 开始编号,绝不写成单个合并的 tickets 文件
- triage 状态写在各 issue 文件靠近顶部的 `Status:` 行(角色字符串见 `triage-labels.md`)
- 评论与对话历史追加到文件底部的 `## Comments` 标题下

## 当技能要求「发布到 issue tracker」

在 `.scratch/<feature-slug>/` 下新建文件(必要时创建目录)。

## 当技能要求「获取相关 ticket」

读取被引用的路径对应文件。用户通常会直接给出路径或 issue 编号。

## Wayfinding 操作

供 `/wayfinder` 使用。**map** 是一个文件,每张 ticket 对应一个 **child** 文件。

- **Map**:`.scratch/<effort>/map.md`(承载 Notes / Decisions-so-far / Fog 正文)。
- **Child ticket**:`.scratch/<effort>/issues/NN-<slug>.md`,从 `01` 开始编号,正文写问题。`Type:` 行记录 ticket 类型(`research`/`prototype`/`grilling`/`task`);`Status:` 行记录 `claimed`/`resolved`。
- **阻塞**:靠近顶部的 `Blocked by: NN, NN` 行。当它列出的每个文件都是 `resolved` 时,ticket 解除阻塞。
- **Frontier**:扫描 `.scratch/<effort>/issues/` 中处于 open、未阻塞、未认领状态的文件;编号最小者优先。
- **认领**:在任何工作开始前设置 `Status: claimed` 并保存。
- **解决**:在 `## Answer` 标题下追加答案,设置 `Status: resolved`,然后把上下文指针(要旨 + 链接)追加到 `map.md` 的 Decisions-so-far。
