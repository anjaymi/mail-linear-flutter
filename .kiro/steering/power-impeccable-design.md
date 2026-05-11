---
inclusion: fileMatch
fileMatchPattern: '**/*.{dart,html,css,scss,tsx,jsx,vue,svelte}'
---

# Power · Impeccable Design

> 本文件模拟 Kiro Power 的 POWER.md 入口。Kiro 在匹配到 UI/设计类文件或用户触发词时自动加载本文件，等同于"启用一个设计能力插件"。

## 何时激活

当本工作区出现以下**任意一项**时，把本 Power 视为当前对话的激活 Power：

- 打开 `.dart` / `.html` / `.css` / `.scss` / `.tsx` / `.jsx` / `.vue` / `.svelte` 文件（已由 fileMatchPattern 触发）
- 用户消息出现触发词：`#ui`、`#design`、`#impeccable`、"设计""审美""视觉""polish""审查""太素""太闹""留白""对齐""排版""字重""配色""层级""节奏""动效""微交互""可访问性""对比度"
- 用户让你 polish / critique / redesign / shape / audit / distill / clarify / colorize / animate 某个界面

激活后**告诉用户一句**："已激活 Impeccable Design Power — 子命令: <pick>"。

## Power 提供的子命令

每个子命令对应 `~/.kiro/skills/impeccable/reference/<name>.md`。用户不用记名字，你按下表挑最贴近的一个：

| 场景 | 子命令 | 说明 |
|---|---|---|
| 不难看但想更好 | `polish` | 只打磨字重 / 留白 / 对齐 / 分隔 / 颜色 |
| 找 UI 问题 / 评审 | `audit` | 输出 P0/P1/P2 问题清单 |
| 太素 / 没主角感 | `bolder` | 字阶拉开、主色果断、加视觉张力 |
| 太闹 / 信息过载 | `quieter` | 降噪、灰阶、去装饰、拉层级 |
| 想要惊艳 | `delight` / `overdrive` | 小惊喜 or 技术力炫技 |
| 换配色 / 检查对比 | `colorize` / `color-and-contrast` | |
| 调排版 | `typeset` / `typography` | |
| 调动效 | `animate` / `motion-design` | |
| 整信息架构 | `distill` / `clarify` / `cognitive-load` | |
| 改布局节奏 | `layout` / `spatial-design` | |
| 交互微调 | `interaction-design` | |
| 响应式 (Web) | `responsive-design` | |
| 可访问性加固 | `harden` | |
| 写 UX 文案 | `ux-writing` | |
| 初始化产品认知 | `teach` / `product` / `personas` / `brand` | 生成 / 补齐 PRODUCT.md |

## 执行规则

1. 用 `discloseContext` 激活 `impeccable`，这是权威手册。
2. 选定子命令后，读取 `~/.kiro/skills/impeccable/reference/<name>.md` 的细则执行。
3. **Flutter 项目适配**（本仓库 `mail_linear_flutter/` 是 Flutter）：impeccable 默认举 HTML/CSS 例子——遇到 `.dart` 文件必须把建议翻译成 Widget 代码，不要输出 `<div>` / CSS 片段。
4. 颜色/字号优先走主题 token（`Theme.of(context).colorScheme.*` / `.textTheme.*`），不要硬编码。
5. **不阻塞**：若项目根没 `PRODUCT.md`，提醒一句"审查会偏通用，想先 `/impeccable teach` 生成一份产品认知吗？"，但继续本次任务。

## 配套按钮（Agent Hooks）

已在面板里预置：

- `[Design] ✨ Polish 打磨`
- `[Design] 🔍 Audit 审查`
- `[Design] 🎨 Bolder 加劲`
- `[Design] 🔇 Quieter 降噪`

点按钮等同于带着当前文件手动激活本 Power 的对应子命令。
