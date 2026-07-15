# OpenClaw 自动化任务升级合同

这个文件不替你改变原有定时执行时间。同步仓库后，请保留你当前自动化的 schedule 和时区，将任务正文升级为下面的完整流程。

当前合同版本为 `2.1.0`。如果现有任务正文没有 `[ALUX_DAILY_CONTRACT_VERSION: 2.1.0]`，先完成一次任务升级并手动 dry run，再等待下一次定时执行；不要新建一个重复的定时任务。

## 应写入自动化的任务正文

```text
[ALUX_DAILY_CONTRACT_VERSION: 2.1.0]

你负责生成、翻译、验收并发布当日的 ALUX AI智能体情报日报。

开始前：
1. 拉取 GitHub 仓库 main 的最新内容。
2. 完整阅读根目录 AGENTS.md、AUTOMATION.md、docs/REPORT_STYLE_GUIDE.md、docs/RESPONSIVE_LAYOUT_STANDARD.md、docs/DAILY_PUBLISH_CHECKLIST.md 和 .baoyu-skills/baoyu-translate/EXTEND.md。
3. 查看 git status、content/zh/ 最新日期、content/en/translation-manifest.json 与现有未完工作。如有未完的当期英文或审核，先续完，不新开日期。

内容生成：
4. 按 docs/REPORT_STYLE_GUIDE.md 生成当日中文母稿，保存为 content/zh/YYYYMMDD_ALUX_AI智能体情报日报.html。
5. 页面布局、类名、颜色、字体层级和响应式行为以 content/zh/ 中日期最新、已验收的报告为基准；保留结构，不复制旧事实和旧判断。
6. 以官方与一手来源为主，对每条信号记录来源、发生了什么、与 ALUX 的关系、可行动产出物和证据边界。

英文精修：
7. 不使用浏览器即时机翻。按项目配置执行“分析 → 初译 → 审校 → 润色”，写成母语级 en-US 科技情报刊物。
8. 将英文 body 母稿保存为 content/en/YYYYMMDD.body.html。它必须保留中文版的 HTML 结构、class、组件顺序、数字和来源 URL，不得包含 html/head/body/style 外壳。
9. 逐项核对标题、lead、信号数、来源数、产品名、版本号、金额、RISC 结论、ALUX 能力边界和外链。英文不得残留未处理中文。
10. 只有完成精修复核后，运行 scripts/update-translation-manifest.ps1 -Date YYYY-MM-DD -MarkReviewed。

构建与验收：
11. 运行 scripts/sync-reports.ps1。不手工编辑 public/index.html 或 public/latest/。脚本必须一次性更新中英首页的日期、标题、摘要、统计和最近更新时间，同时更新 /latest/、/en/latest/、日期页、归档清单和 sitemap。
12. 运行 scripts/verify-site.ps1 与 scripts/render-check.cjs。检查 1920、1440、1024、768、620、430、390、320 px，并检查 621、920、921 px 断点；布局必须与当前已验收站点保持一致。英文热区矩阵宽屏标签列不得低于 172px，620px 及以下改为单列；`.panel-head` 在 920px 及以下上下排列；Logo 与语言切换外框保持 44px 等高。任何文字越过所属单元、与相邻元素重叠或控件错位都必须停止发布。
13. 确认语言切换往返同一期，上一期/下一期正确，ALUX 三角 favicon 正常，canonical 和 hreflang 正确。

发布：
14. 只有所有验收通过才能提交。同一次提交必须包含中文母稿、英文母稿、翻译清单和重建后的 public/。
15. 提交信息使用“发布 YYYY-MM-DD 中英双语日报”，推送 main。
16. 等待 Vercel 部署完成，在 https://ai-agent-daily.alux.network/ 验证中英首页、最新入口、当日中英日期页与语言切换。

硬性规则：
- 中文或英文任何一侧缺失、未 reviewed、哈希过期、验证失败或布局溢出时，整次发布停止。
- 不得删除、绕过或降级 `render-check.cjs` 的 `heat-row` 重叠检测来让发布通过。
- 首页最新日期、最近更新时间、/latest/ 与 /en/latest/ 必须在同一次构建和同一次 Git 提交中更新，不得半套发布。
```

## 自动化修改后的验收

- 任务定时和时区与原任务一致。
- 任务正文已包含中英双语、精修审校、响应式验收、GitHub 推送和正式域名验收。
- 失败时保留工作区和日志，不推送半成品。
- 下一次定时执行前，先用一次手动 dry run 确认新合同可执行。
