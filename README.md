<div align="center">

# ALUX AI智能体情报日报

### ALUX AI Agent Intelligence Daily

持续追踪全球 AI Agent 的产品、技术、安全、融资与基础设施演进，<br>
并将关键信号映射到生产级运行时、长交易、能力安全与可重放证据链。

[中文首页](https://ai-agent-daily.alux.network/) · [English](https://ai-agent-daily.alux.network/en/) · [中文最新一期](https://ai-agent-daily.alux.network/latest/) · [English Latest](https://ai-agent-daily.alux.network/en/latest/) · [ALUX](https://alux.network/)

</div>

> [!IMPORTANT]
> 新电脑上的 Agent 或 OpenClaw 必须先读 [`AGENTS.md`](./AGENTS.md) 与 [`AUTOMATION.md`](./AUTOMATION.md)。不要只上传中文 HTML；中文母稿、母语级英文、首页与最新入口、日期归档、翻译审核清单和 `public/` 成品必须作为同一次完整发布处理。

---

## 关于本刊

本仓库是 **ALUX AI智能体情报日报** 的官方发布与长期归档仓库。本刊面向 AI Agent 基础设施与生产化进程，关注的不只是模型能力更新，更关注智能体进入真实业务后必须面对的执行、权限、恢复、审计与跨组织协作问题。

每一期均以公开资料、官方发布与可核验来源为基础，提炼值得长期追踪的行业信号，并保留原始来源链接。中文版与英文版共享相同的事实、数字、结构、来源和证据边界；英文不是浏览器即时机翻，而是经过分析、初译、审校与润色的 en-US 刊物级版本。

## 核心关注

- **产品与平台**：AI Agent 产品、开发框架、工作入口与企业采用。
- **运行时与基础设施**：持久任务、长程执行、状态恢复、沙箱与可观测性。
- **安全与治理**：身份、授权、能力边界、审计证据与责任链。
- **市场与资本**：融资、商业模式、生态合作与产业结构变化。
- **ALUX 映射**：将外部信号映射到 ALUX 的运行时、长交易、能力安全与可重放证据体系。

## 阅读入口

| 内容 | 中文 | English |
| --- | --- | --- |
| 首页与完整归档 | [正式首页](https://ai-agent-daily.alux.network/) | [English Home](https://ai-agent-daily.alux.network/en/) |
| 始终指向最新一期 | [/latest/](https://ai-agent-daily.alux.network/latest/) | [/en/latest/](https://ai-agent-daily.alux.network/en/latest/) |
| 固定日期地址 | `/YYYY/MM/DD/` | `/en/YYYY/MM/DD/` |
| 机器可读归档 | [/archive.json](https://ai-agent-daily.alux.network/archive.json) | [/en/archive.json](https://ai-agent-daily.alux.network/en/archive.json) |

每期固定日期地址长期保留，不被后续日报覆盖。首页、最近更新时间、中英最新入口、日期页、归档清单与站点地图由同一次构建生成，任何一项缺失或验证失败时整次发布停止。

## 仓库结构

```text
content/zh/                         中文 HTML 母稿，内容事实的第一来源
content/en/*.body.html              与中文结构一致的 en-US 英文正文母稿
content/en/translation-manifest.json  翻译状态、审核时间与双语哈希
assets/                             ALUX 图标与日报公共样式
templates/                          中英首页与错误页模板
scripts/                            构建、翻译清单、验证、渲染与发布脚本
docs/                               编辑规范、视觉规范、运维与每日清单
automation/                         OpenClaw 自动化任务正文与机器可读合同
public/                             Vercel 实际发布目录；只由脚本生成
AGENTS.md                            所有 Agent 的第一入口与硬性规则
AUTOMATION.md                        自动化与各类 Agent 的接续说明
更新并发布日报.cmd                  Windows 一键发布入口
```

`content/` 是源数据，`public/` 是生成结果。不要手工编辑 `public/index.html`、`public/latest/` 或某个公开日期页；下一次构建会覆盖这些文件。

## Agent / OpenClaw 接续

克隆仓库后按顺序完整读取：

1. [`AGENTS.md`](./AGENTS.md)
2. [`AUTOMATION.md`](./AUTOMATION.md)
3. [`docs/REPORT_STYLE_GUIDE.md`](./docs/REPORT_STYLE_GUIDE.md)
4. [`docs/DAILY_PUBLISH_CHECKLIST.md`](./docs/DAILY_PUBLISH_CHECKLIST.md)
5. [`.baoyu-skills/baoyu-translate/EXTEND.md`](./.baoyu-skills/baoyu-translate/EXTEND.md)
6. [`automation/OPENCLAW_DAILY_TASK.md`](./automation/OPENCLAW_DAILY_TASK.md)

保留原自动化任务的执行时间和时区，只替换任务正文。可直接采用 [`automation/OPENCLAW_DAILY_TASK.md`](./automation/OPENCLAW_DAILY_TASK.md)，或让 Agent 读取 [`automation/task-contract.json`](./automation/task-contract.json) 更新自己的任务。

## 每日发布顺序

1. 拉取 `main` 并检查未完成工作；未完成的中英同一期优先续完。
2. 按最新已验收版式生成 `content/zh/YYYYMMDD_ALUX_AI智能体情报日报.html`。
3. 生成同结构的 `content/en/YYYYMMDD.body.html`，完成事实、数字、术语、RISC 结论和来源 URL 复核。
4. 仅在英文完成母语级精修后，将当期写入审核清单。
5. 一次性生成中英首页、最新页、日期页、归档清单、站点地图与最近更新时间。
6. 完成结构、哈希、链接、SEO、Logo、语言切换和 8 档视口渲染验收。
7. 将中文母稿、英文母稿、审核清单、配置和 `public/` 放在同一 Git 提交中推送；Vercel 自动部署后核验正式域名。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\update-translation-manifest.ps1 -Date YYYY-MM-DD -MarkReviewed
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-reports.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-site.ps1
node .\scripts\render-check.cjs
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\publish.ps1
```

首次使用渲染验收前，在仓库根目录安装依赖：

```powershell
npm install
```

更完整的本地构建、异常恢复和部署说明见 [`docs/OPERATIONS.md`](./docs/OPERATIONS.md)。

## 发布硬门槛

- 同一日期的中文或英文任一缺失，不发布。
- 英文未标记 `reviewed`、审核哈希过期或残留未处理中文，不发布。
- 中英结构、数字、外链、证据边界不一致，不发布。
- 手机、平板或桌面出现横向溢出、遮挡、孤字异常或关键点击区过小，不发布。
- 首页最新日期、标题、摘要、数量、最近更新时间、`/latest/`、`/en/latest/`、日期页、归档和 sitemap 不在同一次构建与提交中更新，不发布。

## 内容说明

本刊内容用于行业研究与技术观察。公开来源与外部链接保留在各期正文中，相关商标与名称归其各自权利人所有。
