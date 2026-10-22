# Triage 标签

技能以五个规范 triage 角色表述。本文件把这些角色映射到本仓库 issue tracker 实际使用的标签字符串。

| mattpocock/skills 中的标签 | 本仓库 tracker 中的标签 | 含义 |
| --- | --- | --- |
| `needs-triage` | `needs-triage` | 维护者需要评估该 issue |
| `needs-info` | `needs-info` | 等待报告者补充信息 |
| `ready-for-agent` | `ready-for-agent` | 规格完整,可交给 AFK agent |
| `ready-for-human` | `ready-for-human` | 需要人工实现 |
| `wontfix` | `wontfix` | 不予处理 |

当技能提到某个角色(例如「应用 AFK-ready triage 标签」)时,使用表中对应的标签字符串。

本仓库的 tracker 是本地 Markdown,因此这些字符串写为 `.scratch/<feature>/issues/<NN>-<slug>.md` 中 issue 文件的 `Status:` 行值,而不是应用到远端 issue 上。若你采用不同的字符串,请修改右列。

这些字符串刻意不加前缀。仓库的标签体系把 `kind/*` 保留给 pull request,Issue 使用 GitHub 原生 Issue Type,`source/*` 保留给 Issue 的创建来源;这些运维标签与上述几族并存,但不满足其中任何一族。
