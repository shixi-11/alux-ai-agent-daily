# ALUX AI Agent Intelligence Daily · Agent 接班说明

本文件是所有继续维护者的第一入口。克隆或同步仓库后，先读本文件，再读 `README.md`、`AUTOMATION.md` 与 `docs/OPERATIONS.md`。OpenClaw Agent 还必须读 `automation/OPENCLAW_DAILY_TASK.md`，并用该合同升级现有定时任务的正文。

当前自动化合同版本为 `2.0.0`。OpenClaw 发现现有日报任务没有 `[ALUX_DAILY_CONTRACT_VERSION: 2.0.0]` 时，必须保留原任务 ID、执行时间、时区和凭据，只替换任务正文并完成一次 dry run；不得另建一个重复任务。

## 任务目标

维护 ALUX AI智能体情报日报的中英双语正式站点：

- 正式域名：<https://ai-agent-daily.alux.network/>
- 中文首页：`/`
- 英文首页：`/en/`
- 中文日期页：`/YYYY/MM/DD/`
- 英文日期页：`/en/YYYY/MM/DD/`
- 中英两版必须指向同一期、保留同一组事实与来源链接。

## 权威数据与生成结果

| 目录 | 用途 | 是否可直接编辑 |
| --- | --- | --- |
| `content/zh/` | 中文 HTML 母稿，一期一份 | 是 |
| `content/en/` | 英文精修 body 母稿与翻译清单 | 是 |
| `.baoyu-skills/baoyu-translate/EXTEND.md` | 翻译语言、读者、文风与术语表 | 是，修改后要重审受影响译文 |
| `templates/` | 中英首页与 404 模板 | 是 |
| `assets/` | 日报页共享导航与响应式样式 | 是 |
| `scripts/` | 生成、审核、渲染与发布逻辑 | 是 |
| `public/` | Vercel 部署成品 | 否；只能由脚本重建 |

`content/` 是仓库内的唯一内容权威源。不得依赖仓库外的本地文件夹，不得只修改 `public/`。

## 新一期的固定流程

1. 查看 `content/zh/`、`content/en/translation-manifest.json` 与 Git 状态，确认最新日期和未完事项。
2. 新建 `content/zh/YYYYMMDD_ALUX_AI智能体情报日报.html`。不覆盖历史日期。
3. 按项目翻译配置执行“分析 → 初译 → 审校 → 润色”，新建 `content/en/YYYYMMDD.body.html`。
4. 核对中英两版的数字、产品名、版本号、融资金额、RISC 判断和外部来源链接。
5. 更新翻译清单，只有人工或 Agent 精修复核后才可标记 `reviewed`。
6. 依次执行：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-reports.ps1
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-site.ps1
   node .\scripts\render-check.cjs
   ```

7. 检查生成截图和验证输出；只有全部通过后才可提交和推送。

## 翻译标准

- 目标语言：`en-US`。
- 读者：全球 AI Agent、基础设施、技术与商业读者。
- 文风：母语级科技情报刊物，专业、简洁、准确、权威；不逐字硬译。
- 不得发明事实、更改数字、替换来源或扩大 ALUX 已有能力。
- 英文母稿中不得残留未处理的中文。中国公司或机构名应使用其官方英文名或可识别的罗马化。
- 术语以 `.baoyu-skills/baoyu-translate/EXTEND.md` 为准。

## 强制验收门槛

- 中英日期集合完全一致，不允许只发布单语新一期。
- 清单中的中文源哈希、英文母稿哈希与当前文件一致，状态为 `reviewed`。
- 中英两版的外链集合、重点信号数、章节数和来源数一致。
- 首页、最新页、最早/中间/最新日期页在 1920、1440、1024、768、620、430、390、320 px 下无横向溢出、裁切、单字孤行或导航遮挡。
- 语言切换必须指向同一期；`canonical` 与 `hreflang` 必须正确。
- 中文站名固定为 `ALUX AI智能体情报日报`，不在 `AI` 与 `智能体` 之间加空格。

## 禁止事项

- 不直接编辑 `public/`。
- 不使用浏览器即时机器翻译或客户端假切换。
- 不在英文未审校、验证脚本失败或 Git 工作区含不明变更时发布。
- 不修改、删除或覆盖历史日期链接。
- 不把密钥、OAuth、`.env.local` 或 `.vercel/` 提交到 GitHub。

## 接续已有任务

如果工作区已有未提交变更，先阅读 `git diff`、翻译清单和验证输出，从现有进度继续；不要重做已完成的期数，不要用旧快照覆盖当前母稿。
