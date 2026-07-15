# 中英双语日报运维手册

## 1. 仓库是完整交付物

本仓库同时保存中文母稿、英文精修母稿、翻译追踪数据、模板、生成脚本、验收脚本和 Vercel 成品。任何一台新电脑只要克隆仓库，就应能在不依赖旧电脑外部目录的前提下继续发布。

`public/` 是可重建的部署结果；`content/`、`templates/`、`assets/`、`scripts/` 和翻译配置才是必须持久保存的工作数据。

## 2. 目录与文件规则

```text
content/
├─ zh/
│  └─ YYYYMMDD_ALUX_AI智能体情报日报.html
└─ en/
   ├─ YYYYMMDD.body.html
   └─ translation-manifest.json
```

中文母稿是完整 HTML 文档。英文母稿只保存 `<main class="page">` 到 `</main>` 的 body 内容，共享中文页面的结构与基础样式，再由构建脚本注入英文排版覆盖、站点导航、语言切换、前后期链接、canonical 和 hreflang。

## 3. 日常发布

### 3.1 准备中文母稿

- 日期使用中国标准时间当天日期。
- 文件名必须与日期一致。
- 页面必须包含 `doctype`、`html lang="zh-CN"`、viewport、`title`、`h1` 和 `.lead`。
- 外链使用 HTTPS，新窗口链接保留 `target="_blank" rel="noopener"`。
- 不得引用本地盘符、`file:` 地址或未入库资产。

### 3.2 准备英文母稿

先读 `.baoyu-skills/baoyu-translate/EXTEND.md`，再执行精修流程：

1. 分析文章结构、读者、专名、数字、RISC 结论与 ALUX 能力边界。
2. 完整初译，保留 HTML 标签、类名、条目顺序与来源 URL。
3. 逐段审校事实和英文自然度，修正中式英语、硬译、冗长与语义漂移。
4. 统一术语、大小写、标题风格和标点，做最终润色。
5. 对比中英两版的外链集合、`.section`、`.signal`、`.sources` 数量和全部数字。

### 3.3 更新翻译清单

`translation-manifest.json` 每期记录：

- `date`
- `sourceFile`
- `translationFile`
- `sourceSha256`
- `translationSha256`
- `status`，只有完成精修复核后才能为 `reviewed`
- `reviewedAt`

中文母稿或英文母稿改动后，旧哈希会让构建硬失败。这是为了防止修改中文后误发布过期英文。

首页“最近更新”使用翻译清单中最新的 `reviewedAt`，并统一显示为中国标准时间。这样时间来自已入库、可复核的审核事件，不受另一台电脑的文件修改时间或系统时区影响；新一期日期、审核时间和中英最新入口会在同一次构建中一起更新。

### 3.4 生成和验证

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-reports.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-site.ps1
node .\scripts\render-check.cjs
```

`sync-reports.ps1` 会同时生成：

- 中英首页和全部日期页
- `/latest/` 与 `/en/latest/`
- 中英 `archive.json`
- 带双语 alternate 的 `sitemap.xml`
- 站内导航、语言切换和上一期/下一期链接
- 与翻译审核记录绑定的中英首页“最近更新”时间

`verify-site.ps1` 负责内容、哈希、路径、链接和 SEO 属性验证。`render-check.cjs` 负责真实 Chrome 中的桌面、平板、手机、窄屏和关键断点渲染验收，并用真实文字边界硬性检测英文热区、面板标题、相邻单元重叠、整页裁切以及 Logo/语言切换对齐。

## 4. 提交与部署

一次完整发布应同时提交：

- 新增或修正后的中文母稿
- 对应英文精修母稿
- 翻译清单
- 如有改动的术语表、模板、脚本和说明
- 重建后的 `public/`

提交消息使用：

```text
发布 YYYY-MM-DD 中英双语日报
```

推送 `main` 后 Vercel 自动部署。验收时以正式域名为准，检查中英首页、最新页、最早/中间/最新三期日期页、语言往返切换、归档清单与 sitemap。

## 5. 新电脑或新 Agent 接班

1. 克隆仓库并进入仓库根目录。
2. 阅读 `AGENTS.md`、`README.md`、本手册和翻译清单。
3. 执行 `git status` 与验证脚本，确认仓库是已发布状态还是未完中间状态。
4. 以 `content/zh/` 的最新日期为基准，检查英文母稿和翻译清单是否已对应。
5. 如果三者已对齐，下一任务就是新增下一期；如果未对齐，先完成现有日期的翻译或审核，不开新期数。
