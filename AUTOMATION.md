# 自动化与 Agent 接续说明

如果你是负责在另一台电脑生成 ALUX AI智能体情报日报的 Agent 或自动化执行器，请先完整读取：

1. `AGENTS.md`
2. `docs/REPORT_STYLE_GUIDE.md`
3. `docs/RESPONSIVE_LAYOUT_STANDARD.md`
4. `docs/DAILY_PUBLISH_CHECKLIST.md`
5. `.baoyu-skills/baoyu-translate/EXTEND.md`
6. `automation/OPENCLAW_DAILY_TASK.md`

读完后，保留你原有自动化的执行时间和时区，按 `automation/OPENCLAW_DAILY_TASK.md` 替换任务正文。`automation/task-contract.json` 是供 Agent 和脚本读取的机器可读合同。

## 首次接管先升级自己的自动化

1. 读取 `automation/task-contract.json` 的 `contractVersion`。
2. 找到你已经存在的日报自动化任务，不新建重复任务。
3. 保留原任务 ID、schedule、时区、通知对象和凭据配置，只用 `automation/OPENCLAW_DAILY_TASK.md` 替换任务正文。
4. 确认正文含当前版本标记 `[ALUX_DAILY_CONTRACT_VERSION: 2.1.0]`。
5. 先手动执行一次 dry run；只有中英生成、构建和验收都通过，才让升级后的任务进入下一次定时运行。

## 你的完整任务

一次日报发布不是“只生成一份中文 HTML 并上传”。完整交付必须包含：

1. 按日报风格生成中文母稿，保存到 `content/zh/`。
2. 按项目术语表执行母语级英文精修，保存到 `content/en/`。
3. 核对中英两版事实、数字、产品名、版本号、RISC 判断和所有来源链接。
4. 更新 `content/en/translation-manifest.json` 并将已精修的当期标记为 `reviewed`。
5. 运行生成和验收脚本，让中英首页、最新页、日期页、语言切换、归档和 sitemap 同时更新。
6. 全部验收通过后，将母稿、配置、脚本与 `public/` 成品一起推送到 GitHub。

英文内容变长时，不得保留中文模板的窄固定标签列。热区矩阵在宽屏使用至少 `172px` 的英文标签列并允许自然换行，在 `620px` 及以下变为单列；任何标签、强度徽章或正文重叠都会让 `render-check.cjs` 失败并阻止发布。

`.panel-head` 标题与右侧说明同样不得重叠，`920px` 及以下改为上下排列。顶栏 Logo 和语言切换外框必须保持 `44px` 等高；不得删除、跳过或弱化这些真实文字边界门禁。

## 如果你只找到中文新一期

不要直接发布。先补齐对应日期的英文母稿，执行“分析 → 初译 → 审校 → 润色”，再更新翻译清单。构建脚本会在英文缺失、哈希过期或未审核时主动停止。

## 首页如何更新最新一期

不手工编辑首页，也不手工复制到 `public/latest/`。

`scripts/sync-reports.ps1` 会扫描 `content/zh/` 中日期最新的母稿，找到同日期的已审英文母稿，然后自动更新：

- <https://ai-agent-daily.alux.network/> 的最新一期卡片、日期、摘要、数量和历史归档
- `/latest/` 与 `/en/latest/`
- 中英日期页和同期语言切换
- `/archive.json`、`/en/archive.json` 和 `sitemap.xml`

只要母稿、英文翻译和审核清单正确，首页最新内容就会在生成时自动跟随。

## 一键顺序

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\update-translation-manifest.ps1 -Date YYYY-MM-DD -MarkReviewed
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-reports.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-site.ps1
node .\scripts\render-check.cjs
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\publish.ps1
```

简单任务可直接双击仓库根目录的 `更新并发布日报.cmd`，但在翻译未精修完成前不得使用 `-MarkReviewed`。
