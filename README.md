<div align="center">

# ALUX AI智能体情报日报

### ALUX AI Agent Intelligence Daily

持续追踪全球 AI Agent 的产品、技术、安全、融资与基础设施演进，<br>
并将关键信号映射到生产级运行时、长交易、能力安全与可重放证据链。

[正式站点](https://ai-agent-daily.alux.network/) · [最新一期](https://ai-agent-daily.alux.network/latest/) · [历史归档](https://ai-agent-daily.alux.network/#archive) · [ALUX](https://alux.network/)

</div>

---

## 关于本刊

本仓库是 **ALUX AI智能体情报日报** 的官方发布与长期归档仓库。本刊面向 AI Agent 基础设施与生产化进程，关注的不只是模型能力更新，更关注智能体进入真实业务后必须面对的执行、权限、恢复、审计与跨组织协作问题。

每一期均以公开资料、官方发布与可核验来源为基础，提炼值得长期追踪的行业信号，并保留原始来源链接。

## 核心关注

- **产品与平台**：AI Agent 产品、开发框架、工作入口与企业采用。
- **运行时与基础设施**：持久任务、长程执行、状态恢复、沙箱与可观测性。
- **安全与治理**：身份、授权、能力边界、审计证据与责任链。
- **市场与资本**：融资、商业模式、生态合作与产业结构变化。
- **ALUX 映射**：将外部信号映射到 ALUX 的运行时、长交易、能力安全与可重放证据体系。

## 阅读与归档

| 入口 | 地址 | 说明 |
| --- | --- | --- |
| 正式首页 | [ai-agent-daily.alux.network](https://ai-agent-daily.alux.network/) | 最新一期与完整历史目录 |
| 最新一期 | [/latest/](https://ai-agent-daily.alux.network/latest/) | 始终指向当前最新日报 |
| 日期归档 | `/YYYY/MM/DD/` | 每一期长期保留的固定地址 |
| 机器可读归档 | [`/archive.json`](https://ai-agent-daily.alux.network/archive.json) | 日期、标题、链接与 SHA-256 清单 |

历史日报不会被后续内容覆盖。首页和 `/latest/` 随新一期更新，每个日期归档地址保持不变，可用于长期引用。

## 发布原则

- 一个公开仓库承载全部历史日报，不按日期重复创建仓库。
- 一个 Vercel 项目持续部署，正式域名保持不变。
- 每日新增一期日期归档，同时更新首页、最新入口与归档清单。
- 发布前校验源文件、日期归档和 `archive.json` 的 SHA-256 一致性。

## 仓库结构

```text
public/                  公开站点与日期归档
templates/               首页与错误页模板
scripts/                 同步、校验与发布脚本
vercel.json              Vercel 部署配置
更新并发布日报.cmd        Windows 一键发布入口
```

Vercel 仅发布 `public` 目录；模板、脚本和本地配置不会成为公开网页内容。

<details>
<summary><strong>维护者发布流程</strong></summary>

1. 将新一期 HTML 放入日报源目录，文件名使用 `YYYYMMDD_ALUX_AI智能体情报日报.html`。
2. 双击 `更新并发布日报.cmd`。
3. 脚本会同步日期归档、更新首页与 `/latest/`、生成归档数据并完成一致性校验。
4. 变更推送至 GitHub `main` 分支后，Vercel 自动部署正式版本。

也可以手动执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-reports.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-site.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\publish.ps1
```

</details>

## 内容说明

本刊内容用于行业研究与技术观察。公开来源与外部链接保留在各期正文中，相关商标与名称归其各自权利人所有。
