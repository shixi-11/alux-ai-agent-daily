# OpenClaw 自动化任务升级合同

这个文件不替你改变原有定时执行时间。同步仓库后，请保留你当前自动化的 schedule 和时区，将任务正文升级为下面的完整流程。

当前合同版本为 `2.6.0`。如果现有任务正文没有 `[ALUX_DAILY_CONTRACT_VERSION: 2.6.0]`，保留原任务 ID、执行时间、时区和凭据，只替换任务正文，完成一次手动 dry run 后再等待下一次定时执行；不要新建一个重复的定时任务。

## 应写入自动化的任务正文

```text
[ALUX_DAILY_CONTRACT_VERSION: 2.6.0]

你负责生成、翻译、验收并发布当日的 ALUX AI智能体情报日报。

运行配置固定为 `model=openai/gpt-5.6-sol`、`thinking=high`、`speed=standard`、`fallbacks=[]`；不得自行改成 Ultra、快速档或备用模型。

开始前：
1. 拉取 GitHub 仓库 main 的最新内容。
2. 完整阅读根目录 AGENTS.md、AUTOMATION.md、docs/OPERATIONS.md、docs/DOMAIN_ROUTING.md、docs/REPORT_STYLE_GUIDE.md、docs/RESPONSIVE_LAYOUT_STANDARD.md、docs/DAILY_PUBLISH_CHECKLIST.md、docs/PUBLIC_REPOSITORY_BOUNDARY.md、automation/task-contract.json 和 .baoyu-skills/baoyu-translate/EXTEND.md。
3. 查看 git status、content/zh/ 最新日期、content/en/translation-manifest.json 与现有未完工作。如有未完的当期英文或审核，先续完，不新开日期。

内容生成：
4. 按 docs/REPORT_STYLE_GUIDE.md 生成当日中文母稿，保存为 content/zh/YYYYMMDD_ALUX_AI智能体情报日报.html。
5. 页面布局、类名、颜色、字体层级和响应式行为以 content/zh/ 中日期最新、已验收的报告为基准；保留结构，不复制旧事实和旧判断。
6. 以官方与一手来源为主，对每条信号记录来源、发生了什么、与 ALUX 的关系、可行动产出物和证据边界。

英文精修：
7. 英文翻译合同固定为：目标语言美式英语（en-US）；翻译模式为精译并完整执行“分析 → 初译 → 独立审校 → 润色”；目标读者是全球 AI Agent、基础设施、技术与商业读者；文风是母语级科技情报出版物，专业、简洁、准确、权威，不逐字直译。独立审校必须由不同 subagent/editor 或隔离的新审校上下文完成；不得使用浏览器即时机翻、由初译者同一遍自行认证，或省略任一阶段。
8. 将英文 body 母稿保存为 content/en/YYYYMMDD.body.html。它必须保留中文版的 HTML 结构、class、组件顺序、数字和来源 URL，不得包含 html/head/body/style 外壳。
9. 逐项核对标题、lead、信号数、来源数、产品名、版本号、金额、RISC 结论、ALUX 能力边界和外链。英文不得残留未处理中文。
10. 只有完成精修复核后，运行 scripts/update-translation-manifest.ps1 -Date YYYY-MM-DD -MarkReviewed。

构建与验收：
11. 使用当前系统可用的 PowerShell 7（macOS/Linux 用 `pwsh`）运行 scripts/sync-reports.ps1。不手工编辑 public/index.html 或 public/latest/。脚本必须一次性更新中英首页的日期、标题、摘要、统计和最近更新时间，同时更新 `/daily/latest/`、`/daily/en/latest/`、`/daily/` 下的中英日期页、归档清单和 sitemap。
12. 运行 scripts/verify-site.ps1 与 scripts/render-check.cjs。检查 1920、1440、1024、768、620、430、390、320 px，并检查 621、920、921 px 断点；布局必须与当前已验收站点保持一致。英文热区矩阵宽屏标签列不得低于 172px，620px 及以下改为单列；`.panel-head` 在 920px 及以下上下排列；Logo 与语言切换外框保持 44px 等高。任何文字越过所属单元、与相邻元素重叠或控件错位都必须停止发布。
13. 确认语言切换往返同一期，上一期/下一期正确，ALUX 三角 favicon 正常，canonical 和 hreflang 正确。

发布：
14. 只有所有验收以及 `scripts/verify-release-boundary.cjs YYYY-MM-DD` 通过才能提交。同一次提交必须包含中文母稿、英文母稿、翻译清单和重建后的 public/。日常发布白名单之外的任何文件出现改动都要停止，不得把研究包、manifest、ledger、prompt、日志、截图、工具输出、本地路径、私人身份或凭据带进 GitHub。
15. 提交信息使用“发布 YYYY-MM-DD 中英双语日报”，由 `scripts/publish.ps1` 直接提交并推送正式仓库 main；不创建 PR、不等待人工合并，也不要求用户手动操作 GitHub。
16. 等待 Vercel 部署完成，运行 `node scripts/verify-official-deployment.cjs YYYY-MM-DD`，在 https://ai.alux.network/daily/ 验证中英首页、最新入口、当日中英日期页、语言切换和成品哈希；同时验证 https://ai-agent-daily.alux.network/ 及其英文、最新和日期路径均只经过一次永久重定向到新主地址。验证失败时不得发送 Telegram。
17. 正式域名通过验证后，只向本机私密配置中的 Telegram 接收者发送纯文字链接通知，不发送 HTML、ZIP、图片或其他日报附件；私人 chat ID 不得写入公开仓库。正文必须严格使用以下格式并保留空行：

【ALUX AI智能体情报日报】

固定入口：
https://ai.alux.network/daily/

YYYY-MM-DD：
https://ai.alux.network/daily/YYYY/MM/DD/

硬性规则：
- 中文或英文任何一侧缺失、未 reviewed、哈希过期、验证失败或布局溢出时，整次发布停止。
- 英文未完整通过分析、初译、审校和润色，或文风退化为逐字直译时，整次发布停止。
- 不得删除、绕过或降级 `render-check.cjs` 的 `heat-row` 重叠检测来让发布通过。
- 首页最新日期、最近更新时间、`/daily/latest/` 与 `/daily/en/latest/` 必须在同一次构建和同一次 Git 提交中更新，不得半套发布。
- 不得使用临时隧道、Vercel 预览域名或旧兼容域名替代新主地址；不得在新主地址内容哈希与旧域名单次 308 兼容验证全部通过前发 Telegram。
- DNS 已完成配置；正常日报发布不得修改 DNS。公开域名与路由操作以 `docs/DOMAIN_ROUTING.md` 为准，服务商账号、验证信息和控制台数据不得写入仓库。
- Telegram 文案中的空行是固定格式，不得压成一段，不得增添问候、工作过程、摘要或解释。
- 固定域名承担日报长期存储、双语切换与历史归档；Telegram 不再重复发送日报附件。
```

## 自动化修改后的验收

- 任务定时和时区与原任务一致。
- 任务正文已包含中英双语、精修审校、响应式验收、GitHub 推送和正式域名验收。
- 失败时保留本地工作区和日志，不推送半成品，也不把这些内部文件提交到 GitHub。
- 下一次定时执行前，先用一次手动 dry run 确认新合同可执行。
