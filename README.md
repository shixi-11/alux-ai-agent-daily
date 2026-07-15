# ALUX AI 智能体情报日报站点

这是日报的独立发布仓库。它与 `ALUX` 官网源码、官网 GitHub 仓库和官网 Vercel 项目完全分离。

## 站点结构

- `/`：最新一期与历史目录
- `/latest/`：永远指向当前最新一期的固定入口
- `/YYYY/MM/DD/`：每一期不可变的日期归档地址
- `public/archive.json`：机器可读的归档清单与 SHA-256

Vercel 只发布 `public` 目录。脚本、模板与本地项目配置不会成为公开网页。

## 每日发布

1. 把新日报放到上一级目录，文件名保持 `YYYYMMDD_ALUX_AI智能体情报日报.html`。
2. 双击 `更新并发布日报.cmd`。
3. 脚本会校验日报、生成日期归档、更新首页和 `/latest/`、核对 SHA-256，然后提交并推送到 GitHub。
4. Vercel 从 `main` 分支自动部署，不需要每天新建仓库、项目或域名。

历史日报不会被“最新一期”覆盖。只有首页和 `/latest/` 会随新日报更新；每个日期链接长期保留。

## 手动命令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-reports.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-site.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\publish.ps1
```

## 发布边界

- 日报源文件：上一级 `AI智能体情报日报` 目录。
- 日报站点仓库：当前 `日报站点` 目录。
- 正式域名：`https://ai-agent-daily.alux.network/`。
- 不修改 `F:\shixi\ALUX\alux.network`，不复用官网仓库或官网 Vercel 项目。
